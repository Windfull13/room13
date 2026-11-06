"""Construye todo el audio de La Habitación 13 en assets/audio/.

- Efectos CC0: descarga dos packs de Kenney (CC0 1.0) y convierte los archivos
  elegidos a WAV mono de 16 bits a 44,1 kHz.
- Todo se masteriza igual: sin componente continua, a la sonoridad de su
  categoría (música, ambiente, efectos, sustos; RMS con puerta de 400 ms) y con
  el pico por debajo de -3 dBFS. Los bucles reciben una sola ganancia para no
  tocar la costura. Las medidas reales (tras decodificar) quedan en
  dev/audio/audio_metrics.json y el inventario en docs/audio_inventario.md.
- El resto se sintetiza aquí: ruido, osciladores, filtros y envolventes.
  Los bucles se cierran con un fundido cruzado para que no hagan clic.

Requisitos: Python 3.10+, numpy, scipy y soundfile (libsndfile con Vorbis).
Uso:        python dev/audio/build_audio.py
"""

import io
import pathlib
import urllib.request
import zipfile
import zlib

import numpy as np
import soundfile as sf
from scipy import ndimage, signal

ROOT = pathlib.Path(__file__).resolve().parents[2]
SFX_DIR = ROOT / "assets" / "audio"
MUSIC_DIR = SFX_DIR / "music"
RATE = 44100
## Techo de pico de todos los archivos (dBFS).
PEAK_CEILING_DB = -3.0
## Margen bajo el techo: la codificación Vorbis puede subir algún pico unas décimas.
PEAK = 10 ** ((PEAK_CEILING_DB - 0.8) / 20)
## Sonoridad objetivo por categoría: RMS con puerta en bloques de 400 ms (dB).
LOUDNESS_TARGETS = {"musica": -20.0, "ambiente": -22.0, "efectos": -24.0, "sustos": -20.0}
## Lo máximo que el limitador puede bajar un pico: más aplastaría el sonido.
MAX_LIMITING_DB = 7.0
LOUDNESS_TOLERANCE = 4.0
METRICS_PATH = ROOT / "dev" / "audio" / "audio_metrics.json"
INVENTORY_PATH = ROOT / "docs" / "audio_inventario.md"
SEED = 13
CACHE_DIR = ROOT / "dev" / "audio" / "cache"
# Calidad Vorbis de los bucles: con 0.2 la costura queda limpia (ver seam_ratio).
LOOP_COMPRESSION = 0.2
# Costura máxima admitida. Un bucle cortado sin fundido cruzado da 10-45.
SEAM_LIMIT = 1.5
USER_AGENT = "Mozilla/5.0 (compatible; build_audio.py)"

KENNEY_PACKS = {
    "rpg-audio": "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip",
    "interface-sounds": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
}

# Nombre en el juego -> (pack de Kenney, archivo original).
CC0_SOUNDS = {
    "footstep": ("rpg-audio", "footstep04.ogg"),
    "message_open": ("rpg-audio", "bookFlip3.ogg"),
    "message_close": ("rpg-audio", "bookClose.ogg"),
    "door_locked": ("rpg-audio", "metalLatch.ogg"),
    "door_unlock": ("rpg-audio", "doorOpen_1.ogg"),
    "door_cross": ("rpg-audio", "doorClose_4.ogg"),
    "ui_click": ("interface-sounds", "select_002.ogg"),
    "ui_hover": ("interface-sounds", "tick_004.ogg"),
    "ui_decision_anomaly": ("interface-sounds", "switch_002.ogg"),
    "ui_decision_no_anomaly": ("interface-sounds", "switch_007.ogg"),
    "success": ("interface-sounds", "confirmation_001.ogg"),
}

rng = np.random.default_rng(SEED)


def reseed(sound_name):
    """Cada sonido tiene su propia semilla: añadir uno nuevo no cambia los demás."""
    global rng
    rng = np.random.default_rng(SEED + zlib.crc32(sound_name.encode()))


# ---------------------------------------------------------------------------
# Piezas de síntesis
# ---------------------------------------------------------------------------

def samples(seconds):
    return int(round(seconds * RATE))


def timeline(seconds):
    return np.arange(samples(seconds)) / RATE


def white(seconds):
    return rng.uniform(-1.0, 1.0, samples(seconds))


def brown(seconds):
    noise = highpass(np.cumsum(white(seconds)), 18)
    return noise / np.abs(noise).max()


def _filter(x, kind, cutoff, order=2):
    sos = signal.butter(order, cutoff, kind, fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, cutoff, order=2):
    return _filter(x, "lowpass", cutoff, order)


def highpass(x, cutoff, order=2):
    return _filter(x, "highpass", cutoff, order)


def bandpass(x, low, high, order=2):
    return _filter(x, "bandpass", [low, high], order)


def oscillator(frequency, seconds, shape="sine"):
    """`frequency` puede ser un número o una curva (glissando)."""
    count = samples(seconds)
    curve = np.broadcast_to(np.asarray(frequency, dtype=float), (count,))
    phase = 2 * np.pi * np.cumsum(curve) / RATE
    if shape == "saw":
        return signal.sawtooth(phase)
    return np.sin(phase)


def glide(start, end, seconds, curve=1.0):
    progress = np.linspace(0.0, 1.0, samples(seconds)) ** curve
    return start + (end - start) * progress


def decay(seconds, tau, attack=0.004):
    t = timeline(seconds)
    rise = np.clip(t / attack, 0.0, 1.0) if attack > 0 else 1.0
    return rise * np.exp(-t / tau)


def swell(seconds, peak_at):
    """Sube hasta `peak_at` (0-1 de la duración) y vuelve a cero."""
    t = np.linspace(0.0, 1.0, samples(seconds))
    rise = np.sin(0.5 * np.pi * np.clip(t / peak_at, 0, 1))
    fall = np.cos(0.5 * np.pi * np.clip((t - peak_at) / (1 - peak_at), 0, 1))
    return np.where(t < peak_at, rise, fall)


def lfo(seconds, period, depth, phase=0.0):
    return 1.0 - depth * 0.5 * (1 - np.cos(2 * np.pi * timeline(seconds) / period + phase))


def mix_at(target, sound, at_seconds, gain=1.0):
    start = samples(at_seconds)
    end = min(len(target), start + len(sound))
    target[start:end] += gain * sound[: end - start]
    return target


def soften_edges(x, fade_in=0.003, fade_out=0.04):
    x = x.copy()
    a, b = samples(fade_in), samples(fade_out)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def normalize(x, peak=PEAK):
    return x * (peak / max(np.abs(x).max(), 1e-9))


def limit(x, drive=1.6):
    """Saturación suave antes de normalizar: controla los picos sin recortar."""
    return np.tanh(drive * x / np.abs(x).max())


def loopify(x, loop_seconds, cross_seconds):
    """Bucle sin costura: el sobrante tras el final se funde sobre el inicio."""
    n, f = samples(loop_seconds), samples(cross_seconds)
    head = x[:n].copy()
    w = np.linspace(0.0, 1.0, f)
    head[:f] = head[:f] * np.sqrt(w) + x[n:n + f] * np.sqrt(1 - w)
    return head


def reverb(x, seconds=1.4, mix=0.25, tone=3500.0, predelay=0.018):
    """Reverb sencilla por convolución: ruido que decae, filtrado y algo retrasado."""
    length = samples(seconds)
    impulse = lowpass(white(seconds), tone) * np.exp(-np.arange(length) / (RATE * seconds / 6.0))
    impulse = np.concatenate([np.zeros(samples(predelay)), impulse])
    wet = signal.fftconvolve(x, impulse)[: len(x)]
    wet *= np.abs(x).max() / max(np.abs(wet).max(), 1e-9)
    return (1.0 - mix) * x + mix * wet


def remove_dc(x):
    return highpass(x - x.mean(), 15, 2)


def block_levels(x, block_seconds=0.4, hop_seconds=0.1):
    block = min(samples(block_seconds), len(x))
    hop = max(1, samples(hop_seconds))
    powers = [np.mean(x[i:i + block] ** 2) for i in range(0, max(1, len(x) - block + 1), hop)]
    return np.array(powers) + 1e-12


def loudness_db(x):
    """RMS con puerta: bloques de 400 ms; fuera los de menos de -60 dB y los 20 dB bajo el más fuerte."""
    powers = block_levels(x)
    levels = 10 * np.log10(powers)
    keep = (levels > -60.0) & (levels > levels.max() - 20.0)
    return 10 * np.log10(powers[keep].mean())


def limiter(x, ceiling=PEAK, window_seconds=0.006):
    """Limitador sin distorsión: la ganancia baja (suavemente) solo donde un pico supera el techo."""
    window = max(3, samples(window_seconds))
    envelope = ndimage.maximum_filter1d(np.abs(x), size=window)
    gain = np.minimum(1.0, ceiling / np.maximum(envelope, 1e-9))
    kernel = np.hanning(window)
    smooth = np.convolve(gain, kernel / kernel.sum(), mode="same")
    return np.clip(x * np.minimum(gain, smooth), -ceiling, ceiling)


def master_loop(x, category):
    """Bucles: restar la media y una sola ganancia, para no tocar la costura (sin filtros ni limitador)."""
    x = x - x.mean()
    gain = 10 ** ((LOUDNESS_TARGETS[category] - loudness_db(x)) / 20)
    return x * min(gain, PEAK / np.abs(x).max())


def master(x, category):
    """Sin continua, a la sonoridad de su categoría y con el pico por debajo de -3 dBFS.
    Si el sonido tiene picos muy altos, el limitador no baja más de MAX_LIMITING_DB."""
    x = remove_dc(x)
    target = LOUDNESS_TARGETS[category]
    raw_peak_db = 20 * np.log10(np.abs(x).max() + 1e-12)
    ceiling_db = 20 * np.log10(PEAK)
    gain_db = target - loudness_db(x)
    for _ in range(8):
        limit_gain = ceiling_db + MAX_LIMITING_DB - raw_peak_db
        capped = gain_db >= limit_gain
        gain_db = min(gain_db, limit_gain)
        y = limiter(x * 10 ** (gain_db / 20))
        error = target - loudness_db(y)
        if abs(error) < 0.3 or (capped and error > 0):
            break
        gain_db += error
    return y


def pad(frequencies, seconds, detune=0.12, brightness=900):
    voice = np.zeros(samples(seconds))
    for f in frequencies:
        voice += oscillator(f, seconds) + 0.5 * oscillator(f + detune, seconds)
        voice += 0.18 * oscillator(f * 2 - detune, seconds) + 0.06 * lowpass(oscillator(f, seconds, "saw"), brightness)
    return voice / len(frequencies)


def bell(frequency, seconds=3.0, tau=1.1):
    partials = [(1.0, 1.0), (2.76, 0.45), (5.4, 0.2), (8.93, 0.08)]
    tone = sum(g * oscillator(frequency * r, seconds) * decay(seconds, tau / r ** 0.5) for r, g in partials)
    return tone


def thump(start_hz, end_hz, seconds, tau):
    return oscillator(glide(start_hz, end_hz, seconds, 0.5), seconds) * decay(seconds, tau)


def knock(seconds=0.25):
    body = sum(g * oscillator(f, seconds) * decay(seconds, t) for f, g, t in [(190, 1.0, 0.05), (430, 0.5, 0.03), (900, 0.2, 0.015)])
    click = bandpass(white(seconds), 800, 3000) * decay(seconds, 0.008, 0.0005)
    return body + 0.6 * click


def noise_sweep(seconds, start_hz, end_hz, width=0.35, steps=40):
    """Ruido filtrado cuyo centro se desplaza (chirrido, aullido)."""
    out = np.zeros(samples(seconds))
    chunk = len(out) // steps
    source = white(seconds + 0.1)
    for i in range(steps):
        center = start_hz * (end_hz / start_hz) ** (i / (steps - 1))
        band = bandpass(source, center * (1 - width), center * (1 + width))
        window = np.zeros(len(out))
        lo, hi = max(0, (i - 1) * chunk), min(len(out), (i + 2) * chunk)
        window[lo:hi] = np.hanning(hi - lo)
        out += band[: len(out)] * window
    return out


# ---------------------------------------------------------------------------
# Sonidos sintetizados
# ---------------------------------------------------------------------------

def ambient_room():
    """Tono de habitación: rumor grave, zumbido eléctrico, aire y crujidos lejanos con su eco."""
    seconds, cross = 24.0, 3.0
    total = seconds + cross
    rumble = lowpass(brown(total), 140, 4)
    hum = sum(g * oscillator(f, total) for f, g in [(50, 0.22), (100, 0.09), (150, 0.035)])
    air = 0.12 * bandpass(white(total), 450, 1400) * lfo(total, 7.0, 0.3)
    creaks = np.zeros(samples(total))
    for at in (4.5, 13.0, 19.5):
        creak = noise_sweep(0.6, 320, 520, 0.12, 12) * swell(0.6, 0.4)
        mix_at(creaks, creak, at, 0.08)
    body = (rumble + hum + air) * lfo(total, 12.0, 0.35) + reverb(creaks, 1.6, 0.6, 2000)
    return loopify(body, seconds, cross)


def danger_heartbeat():
    seconds = 1.8
    beat = np.zeros(samples(seconds + 0.2))
    for at in (0.05, 0.95):
        mix_at(beat, thump(72, 44, 0.45, 0.09), at)
        mix_at(beat, lowpass(white(0.05), 320) * decay(0.05, 0.012), at, 0.5)
        mix_at(beat, thump(62, 40, 0.4, 0.08), at + 0.2, 0.7)
    drone = 0.12 * oscillator(35, seconds + 0.2)
    return loopify(beat + drone, seconds, 0.1)


def music_menu():
    """Menú: drone de tres notas que respira, campanas lejanas con eco y una melodía lenta."""
    seconds, cross = 32.0, 4.0
    total = seconds + cross
    body = pad([55.0, 82.41, 130.81], total) * lfo(total, 16.0, 0.6)
    body += 0.16 * lowpass(brown(total), 300)
    bells = np.zeros(samples(total))
    for at, f in [(2.0, 440.0), (6.0, 392.0), (10.0, 329.63), (18.0, 392.0), (22.0, 349.23), (26.0, 293.66)]:
        mix_at(bells, bell(f, 3.5, 1.2), at, 0.2)
    air = 0.05 * bandpass(white(total), 2000, 6000) * lfo(total, 8.0, 0.8)
    return loopify(body + reverb(bells, 2.6, 0.55, 2800) + air, seconds, cross)


def music_calm():
    """Referencia: acordes suaves en dos capas y notas sueltas con mucho espacio."""
    seconds, cross = 32.0, 4.0
    total = seconds + cross
    low = pad([73.42, 110.0], total, brightness=600)
    high = pad([174.61, 329.63], total, brightness=1200) * lfo(total, 8.0, 0.8)
    body = 0.8 * low + 0.35 * high
    notes = np.zeros(samples(total))
    for at, f in [(2.0, 293.66), (6.0, 440.0), (10.0, 349.23), (14.0, 392.0), (18.0, 440.0), (22.0, 523.25), (26.0, 329.63)]:
        mix_at(notes, bell(f, 2.5, 0.8), at, 0.16)
    return loopify(body + reverb(notes, 2.2, 0.5, 3000), seconds, cross)


def music_tense():
    """Decisión: drone grave que late, cúmulo disonante que crece y silbidos que barren."""
    seconds, cross = 24.0, 3.0
    total = seconds + cross
    drone = pad([41.2, 58.27], total, detune=0.3, brightness=500) * lfo(total, 1.0 / 3.0, 0.15)
    cluster = pad([311.13, 329.63], total, detune=0.9, brightness=2000) * (1 - lfo(total, 12.0, 1.0))
    pulses = np.zeros(samples(total))
    for i in range(int(total / 1.5)):
        mix_at(pulses, thump(60, 38, 0.5, 0.12), 0.4 + i * 1.5, 0.35)
    body = drone + 0.25 * cluster + lowpass(pulses, 200)
    for at in (5.0, 17.0):
        mix_at(body, 0.25 * noise_sweep(3.0, 1500, 2400, 0.08) * swell(3.0, 0.6), at)
    return loopify(reverb(body, 1.8, 0.3, 2400), seconds, cross)


def music_end():
    seconds, cross = 32.0, 4.0
    total = seconds + cross
    body = pad([110.0, 130.81, 164.81, 196.0], total, brightness=700) * lfo(total, 16.0, 0.5)
    for at, f in [(3.0, 659.25), (13.0, 587.33), (23.0, 523.25)]:
        mix_at(body, 0.14 * bell(f, 3.0, 1.2), at)
    return loopify(body, seconds, cross)


def fail():
    seconds = 0.9
    body = thump(58, 34, seconds, 0.25)
    body += 0.4 * lowpass(brown(seconds), 250) * decay(seconds, 0.3, 0.02)
    body += 0.25 * (oscillator(55, seconds) + oscillator(58.3, seconds)) * decay(seconds, 0.35, 0.03)
    return soften_edges(body, fade_out=0.15)


def fade():
    seconds = 0.7
    body = bandpass(brown(seconds) + 0.3 * white(seconds), 200, 900) * swell(seconds, 0.45)
    return soften_edges(body, 0.01, 0.1)


def hit(seconds=0.35):
    return thump(90, 40, seconds, 0.12) + 0.8 * lowpass(white(seconds), 1800) * decay(seconds, 0.03, 0.001)


def jumpscare_cama():
    seconds = 1.5
    body = np.zeros(samples(seconds))
    mix_at(body, hit(), 0.0)
    scrape = noise_sweep(1.4, 600, 2600, 0.25) * (0.6 + 0.4 * oscillator(30, 1.4)) * swell(1.4, 0.25)
    return mix_at(body, 0.9 * scrape, 0.04)


def jumpscare_armario():
    seconds = 1.4
    body = np.zeros(samples(seconds))
    slam = sum(g * oscillator(f, 0.6) * decay(0.6, t) for f, g, t in [(170, 1.0, 0.12), (310, 0.6, 0.08), (520, 0.35, 0.05)])
    mix_at(body, slam + 0.7 * bandpass(white(0.6), 120, 1500) * decay(0.6, 0.04, 0.001), 0.0)
    for i, at in enumerate(np.cumsum([0.12, 0.1, 0.09, 0.08, 0.08, 0.1])):
        mix_at(body, (0.45 - i * 0.06) * knock(0.2), at)
    creak = lowpass(oscillator(glide(240, 85, 1.1), 1.1, "saw"), 1200) * swell(1.1, 0.3)
    return mix_at(body, 0.5 * creak, 0.25)


def jumpscare_ventana():
    seconds = 1.3
    body = np.zeros(samples(seconds))
    for _ in range(14):
        f = rng.uniform(2000, 7000)
        mix_at(body, oscillator(f, 0.5) * decay(0.5, rng.uniform(0.04, 0.15), 0.0005), rng.uniform(0.0, 0.08), rng.uniform(0.1, 0.25))
    mix_at(body, highpass(white(0.15), 2500) * decay(0.15, 0.03, 0.0005), 0.0, 0.9)
    wind = noise_sweep(1.25, 380, 950, 0.2) * swell(1.25, 0.35)
    return mix_at(body, 0.8 * wind, 0.05)


def jumpscare_espejo():
    seconds = 1.5
    body = np.zeros(samples(seconds))
    for f, g in [(220.0, 1.0), (233.08, 0.8), (311.13, 0.5)]:
        mix_at(body, g * bell(f, seconds, 0.7), 0.0)
    whisper = bandpass(white(seconds), 1800, 5200) * lfo(seconds, 0.21, 0.9) * swell(seconds, 0.5)
    mix_at(body, 0.35 * whisper, 0.0)
    return mix_at(body, 0.8 * hit(0.3), 0.0)


def jumpscare_testigo_cuarto():
    seconds = 1.5
    approach = swell(seconds, 0.92) ** 1.5
    roar = sum(oscillator(f, seconds, "saw") for f in (70, 73.5, 77))
    roar = lowpass(roar, 900) * (0.7 + 0.3 * oscillator(18, seconds)) + 0.5 * lowpass(white(seconds), 1500)
    body = roar * approach
    body = mix_at(body, 1.2 * thump(120, 35, 0.8, 0.25), 0.0)
    return limit(body, 1.4)


def jumpscare_testigo_esquina():
    seconds = 1.4
    pitch = glide(380, 1700, seconds, 0.35) * (1 + 0.03 * oscillator(9, seconds))
    shriek = oscillator(pitch, seconds, "saw")
    shriek = bandpass(shriek, 300, 6000) * swell(seconds, 0.2)
    body = shriek + 0.5 * highpass(white(seconds), 1200) * decay(seconds, 0.12, 0.001)
    return limit(body, 1.3)


def jumpscare_tres_senales():
    seconds = 1.8
    body = np.zeros(samples(seconds))
    mix_at(body, knock(0.3), 0.0, 1.0)
    mix_at(body, knock(0.3), 0.33, 1.0)
    stab = sum(oscillator(f, 0.75, "saw") for f in (98.0, 103.83, 138.59, 146.83))
    stab = lowpass(stab, 1400) * decay(0.75, 0.5, 0.005)
    mix_at(body, hit(0.4), 1.05, 1.0)
    return mix_at(body, 0.6 * stab, 1.05)


def jumpscare_cuervo():
    """Aleteo de plumas y un graznido áspero: el presagio."""
    seconds = 1.4
    body = np.zeros(samples(seconds))
    for i in range(9):
        burst = bandpass(white(0.12), 500, 3500) * decay(0.12, 0.04, 0.002)
        mix_at(body, burst, 0.02 + i * 0.075 * (1.0 + 0.05 * i), 0.9 - i * 0.07)
    caw = oscillator(glide(980, 520, 0.55, 0.7) * (1 + 0.06 * oscillator(38, 0.55)), 0.55, "saw")
    caw = bandpass(caw, 700, 2600) * swell(0.55, 0.2)
    mix_at(body, 0.9 * caw, 0.2)
    mix_at(body, 0.7 * caw, 0.82)
    mix_at(body, 0.9 * thump(100, 45, 0.4, 0.1), 0.0)
    return limit(body, 1.2)


def jumpscare_oscuridad():
    """Lluvia, faros que se acercan, frenada y un golpe sordo. Todo amortiguado."""
    seconds = 1.8
    rain = highpass(white(seconds), 2500) * 0.12 * np.ones(samples(seconds))
    approach = lowpass(brown(seconds), 260, 3) * swell(seconds, 0.45) ** 1.5 * 1.1
    body = rain + approach
    screech = bandpass(oscillator(glide(2300, 900, 0.5, 0.6), 0.5, "saw"), 800, 3000) * swell(0.5, 0.25)
    mix_at(body, 0.55 * screech, 0.55)
    mix_at(body, 0.9 * lowpass(white(0.35), 700) * decay(0.35, 0.09, 0.002), 1.1)
    mix_at(body, 1.1 * thump(70, 32, 0.6, 0.14), 1.1)
    ring = oscillator(3100, 0.7) * decay(0.7, 0.35, 0.05)
    mix_at(body, 0.07 * ring, 1.18)
    return limit(body, 1.3)


def ambient_traffic():
    """Tráfico lejano y lluvia fina: algo pasa siempre al otro lado de la ventana."""
    seconds, cross = 24.0, 3.0
    total = seconds + cross
    rain = highpass(white(total), 3000) * 0.05
    bed = lowpass(brown(total), 220, 2) * 0.35
    for at in (3.5, 9.0, 15.5, 21.0):
        passing = lowpass(brown(4.0), 420, 2) * swell(4.0, 0.5) ** 2
        mix_at(bed, 0.55 * passing, at)
    return loopify(rain + bed, seconds, cross)


def anomaly_phone_ring():
    """Timbre de teléfono antiguo: dos campanillas golpeadas a 20 Hz, carcasa y eco de la habitación."""
    seconds = 1.3
    body = np.zeros(samples(seconds))
    for at in (0.0, 0.5):
        length = 0.42
        hammer = 0.55 + 0.45 * np.sign(oscillator(20, length))
        burst = sum(g * oscillator(f, length) for f, g in [(1150.0, 1.0), (1290.0, 0.8), (2480.0, 0.25), (3170.0, 0.12)])
        shell = bandpass(white(length), 700, 1600) * 0.15
        mix_at(body, (burst * hammer + shell) * swell(length, 0.15), at)
    return soften_edges(reverb(lowpass(body, 5000), 0.8, 0.3, 4000), 0.005, 0.1)


def anomaly_knocks():
    """Tres golpes de nudillo en una puerta de madera: ataque, panel que resuena y eco."""
    seconds = 1.6
    body = np.zeros(samples(seconds))
    for at, gain, pitch in ((0.02, 0.85, 1.0), (0.32, 0.75, 0.97), (0.7, 0.65, 0.94)):
        knuckle = lowpass(knock(0.28), 1100)
        panel = oscillator(112.0 * pitch, 0.4) * decay(0.4, 0.09) + 0.4 * oscillator(240.0 * pitch, 0.4) * decay(0.4, 0.05)
        mix_at(body, knuckle, at, gain)
        mix_at(body, panel, at, 0.5 * gain)
    return soften_edges(reverb(body, 0.9, 0.3, 2500), 0.0, 0.2)


def anomaly_music_box():
    """Caja de música: púas metálicas con parciales inarmónicos, el clic del cilindro y eco."""
    seconds = 6.0
    body = np.zeros(samples(seconds))
    notes = [659.25, 783.99, 1046.5, 987.77, 783.99, 880.0, 698.46, 587.33, 659.25, 783.99, 523.25]
    for i, f in enumerate(notes):
        detune = 1.0 + rng.uniform(-0.002, 0.002)
        tine = sum(g * oscillator(f * detune * r, 1.2) * decay(1.2, 0.4 / r ** 0.4, 0.002) for r, g in [(1.0, 1.0), (3.0, 0.22), (5.4, 0.07)])
        click = bandpass(white(0.01), 3000, 7000) * decay(0.01, 0.002, 0.0002)
        mix_at(body, 0.25 * click, 0.08 + i * 0.42)
        mix_at(body, tine, 0.1 + i * 0.42, 1.0 - 0.025 * i)
    mechanism = 0.02 * bandpass(white(seconds), 1500, 4000) * (0.5 + 0.5 * np.sign(oscillator(12, seconds)))
    return soften_edges(reverb(body + mechanism, 1.6, 0.35, 5000), 0.0, 0.5)


def anomaly_dead_line():
    """Línea muerta: tono de 425 Hz por un auricular (300-3400 Hz), con siseo y zumbido de red."""
    seconds = 2.2
    tone = oscillator(425.0, seconds) * (1.0 + 0.02 * oscillator(0.7, seconds))
    line = 0.05 * white(seconds) + 0.08 * oscillator(50.0, seconds) + 0.04 * oscillator(150.0, seconds)
    return bandpass(tone + line, 300, 3400) * swell(seconds, 0.2) ** 0.7


def memory_murmur():
    """Murmullo lejano de niños en un pasillo: voces sin palabras, muy filtradas."""
    seconds = 9.0
    body = 0.35 * lowpass(brown(seconds), 260)
    for i in range(14):
        at = rng.uniform(0.0, seconds - 1.2)
        length = rng.uniform(0.5, 1.1)
        center = rng.uniform(380.0, 900.0)
        voice = bandpass(white(length), center * 0.8, center * 1.25) * swell(length, 0.35)
        voice *= 0.6 + 0.4 * oscillator(rng.uniform(4.0, 7.0), length)
        mix_at(body, voice, at, rng.uniform(0.4, 0.9))
    return lowpass(body, 1400) * swell(seconds, 0.15) ** 0.5


def memory_rain():
    """Lluvia suave y continua (bucle): gotas finas sobre un rumor grave."""
    seconds, cross = 12.0, 2.0
    total = seconds + cross
    hiss = bandpass(white(total), 1800, 7000) * 0.35
    patter = highpass(white(total), 2500) * (0.6 + 0.4 * lfo(total, 0.7, 0.8))
    bed = lowpass(brown(total), 220) * 0.7
    return loopify(hiss + 0.2 * patter + bed, seconds, cross)


def memory_ticking():
    """Tic-tac lento con un zumbido grave debajo."""
    seconds = 9.0
    body = 0.25 * (oscillator(46.0, seconds) + 0.5 * oscillator(92.3, seconds)) * lfo(seconds, 4.5, 0.3)
    for i in range(int(seconds / 1.2)):
        tick = bandpass(white(0.05), 2200 if i % 2 == 0 else 1700, 4200) * decay(0.05, 0.006, 0.0005)
        mix_at(body, tick, 0.2 + i * 1.2, 0.9)
    return soften_edges(body, 0.3, 0.6)


SYNTH_SFX = {
    "memory_murmur": memory_murmur,
    "memory_ticking": memory_ticking,
    "anomaly_phone_ring": anomaly_phone_ring,
    "anomaly_knocks": anomaly_knocks,
    "anomaly_music_box": anomaly_music_box,
    "anomaly_dead_line": anomaly_dead_line,
    "jumpscare_cuervo": jumpscare_cuervo,
    "jumpscare_oscuridad": jumpscare_oscuridad,
    "fail": fail,
    "fade": fade,
    "jumpscare_cama": jumpscare_cama,
    "jumpscare_armario": jumpscare_armario,
    "jumpscare_ventana": jumpscare_ventana,
    "jumpscare_espejo": jumpscare_espejo,
    "jumpscare_testigo_cuarto": jumpscare_testigo_cuarto,
    "jumpscare_testigo_esquina": jumpscare_testigo_esquina,
    "jumpscare_tres_senales": jumpscare_tres_senales,
}
SYNTH_LOOPS = {
    SFX_DIR / "ambient_room.ogg": ambient_room,
    SFX_DIR / "danger_heartbeat.ogg": danger_heartbeat,
    SFX_DIR / "ambient_traffic.ogg": ambient_traffic,
    SFX_DIR / "memory_rain.ogg": memory_rain,
    MUSIC_DIR / "music_menu.ogg": music_menu,
    MUSIC_DIR / "music_calm.ogg": music_calm,
    MUSIC_DIR / "music_tense.ogg": music_tense,
    MUSIC_DIR / "music_end.ogg": music_end,
}


# ---------------------------------------------------------------------------
# Escritura y comprobación
# ---------------------------------------------------------------------------

def to_mono(x):
    return x.mean(axis=1) if x.ndim > 1 else x


def resample(x, rate):
    if rate == RATE:
        return x
    g = np.gcd(rate, RATE)
    return signal.resample_poly(x, RATE // g, rate // g)


def category_of(name):
    if name.startswith("music_"):
        return "musica"
    if name.startswith("jumpscare_"):
        return "sustos"
    if name in ("ambient_room", "ambient_traffic", "danger_heartbeat", "memory_rain"):
        return "ambiente"
    return "efectos"


def write_wav(path, x):
    sf.write(path, master(x, category_of(path.stem)), RATE, subtype="PCM_16")


def write_ogg(path, x, block=4096):
    """Por bloques: libsndfile 1.2 se cuelga al codificar Vorbis largo de una vez."""
    data = master_loop(x, category_of(path.stem))
    with sf.SoundFile(path, "w", RATE, 1, format="OGG", subtype="VORBIS", compression_level=LOOP_COMPRESSION) as out:
        for start in range(0, len(data), block):
            out.write(data[start:start + block])


def seam_ratio(x):
    """Salto en la costura del bucle frente al salto típico entre muestras.
    Por debajo de ~1 la costura no se distingue de la señal (sin clic)."""
    jump = abs(x[0] - x[-1])
    typical = np.percentile(np.abs(np.diff(x)), 99)
    return jump / max(typical, 1e-9)


def describe(path, x):
    peak = 20 * np.log10(np.abs(x).max() + 1e-12)
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
    return f"{path.relative_to(ROOT).as_posix():45s} {len(x) / RATE:6.2f} s  pico {peak:6.1f} dB  rms {rms:6.1f} dB"


def download_packs():
    """Los packs CC0 se leen de dev/audio/cache; si faltan, se descargan allí."""
    CACHE_DIR.mkdir(exist_ok=True)
    packs = {}
    for name, url in KENNEY_PACKS.items():
        cached = CACHE_DIR / f"kenney_{name}.zip"
        if not cached.exists():
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=60) as response:
                cached.write_bytes(response.read())
        if not zipfile.is_zipfile(cached):
            cached.unlink()
            raise SystemExit(f"{name}: la descarga no es un zip. Descarga el pack de kenney.nl y guárdalo en {cached}")
        packs[name] = zipfile.ZipFile(cached)
    return packs


def import_cc0(packs):
    for game_name, (pack, file_name) in CC0_SOUNDS.items():
        archive = packs[pack]
        member = next(m for m in archive.namelist() if m.endswith("/" + file_name))
        x, rate = sf.read(io.BytesIO(archive.read(member)))
        x = soften_edges(resample(to_mono(x), rate), 0.0, 0.01)
        x = np.concatenate([x, np.zeros(samples(0.01))])
        path = SFX_DIR / f"{game_name}.wav"
        write_wav(path, x)
        print("CC0  ", describe(path, sf.read(path)[0]), f"<- Kenney {pack}/{file_name}")


def build_synth():
    for name, build in SYNTH_SFX.items():
        reseed(name)
        path = SFX_DIR / f"{name}.wav"
        write_wav(path, soften_edges(build(), 0.0, 0.03))
        print("SINT ", describe(path, sf.read(path)[0]))
    seams_ok = True
    for path, build in SYNTH_LOOPS.items():
        reseed(path.stem)
        write_ogg(path, build())
        decoded = sf.read(path)[0]
        seam = seam_ratio(decoded)
        seams_ok &= seam <= SEAM_LIMIT
        print("SINT ", describe(path, decoded), f" costura {seam:.2f}", "ok" if seam <= SEAM_LIMIT else "CLIC")
    return seams_ok


def measure(path, origin):
    """Mide el archivo ya escrito (decodificado, tal como lo leerá el juego)."""
    x = sf.read(path)[0]
    entry = {
        "file": path.relative_to(ROOT).as_posix(),
        "name": path.stem,
        "category": category_of(path.stem),
        "origin": origin,
        "bytes": path.stat().st_size,
        "seconds": round(len(x) / RATE, 3),
        "peak_dbfs": round(20 * np.log10(np.abs(x).max() + 1e-12), 2),
        "dc": round(float(x.mean()), 6),
        "loudness_db": round(float(loudness_db(x)), 2),
    }
    if path.suffix == ".ogg":
        entry["seam"] = round(float(seam_ratio(x)), 3)
    return entry


def origin_of(name):
    if name in CC0_SOUNDS:
        pack, file_name = CC0_SOUNDS[name]
        return f"CC0 · Kenney {pack}/{file_name}"
    return "Generado (dev/audio/build_audio.py)"


def write_reports(entries):
    import json
    METRICS_PATH.write_text(json.dumps({"peak_ceiling_dbfs": PEAK_CEILING_DB, "targets": LOUDNESS_TARGETS,
                                        "tolerance_db": LOUDNESS_TOLERANCE, "files": entries}, indent=1, ensure_ascii=False), encoding="utf-8")
    lines = ["# Inventario de audio — La Habitación 13", "",
             "Generado por `dev/audio/build_audio.py` (no editar a mano). Cifras medidas sobre los archivos ya escritos.", "",
             f"- Pico máximo de cualquier archivo: ≤ {PEAK_CEILING_DB:.0f} dBFS. Sin componente continua.",
             "- Sonoridad: RMS con puerta en bloques de 400 ms; cada categoría apunta a un valor y la prueba exige ±4 dB.",
             "- El volumen de juego de cada sonido se ajusta en `scripts/audio/sound_catalog.gd` (volume_db).",
             "- **Fácil de reemplazar**: sí en todos. Basta con poner otro archivo con el mismo nombre (WAV/OGG/MP3) en la misma carpeta;"
             " `AudioManager` lo encuentra aunque cambie la extensión.", "",
             "| Archivo | Origen | Categoría | Duración | Pico | Sonoridad | Costura del bucle | Fácil de reemplazar |",
             "|---|---|---|---|---|---|---|---|"]
    for e in entries:
        seam = f"{e['seam']:.2f}" if "seam" in e else "—"
        lines.append(f"| `{e['file']}` | {e['origin']} | {e['category']} | {e['seconds']:.2f} s | {e['peak_dbfs']:.1f} dBFS | {e['loudness_db']:.1f} dB | {seam} | sí |")
    lines += ["", "Voces (pendientes de grabar, opcionales): `assets/audio/voices/voice_phone_msg.ogg`, `voice_cinematic_wife.ogg`, `voice_cinematic_girl.ogg` (ver `docs/guion_de_voces.md`)."]
    INVENTORY_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def check_categories(entries):
    ok = True
    for category in LOUDNESS_TARGETS:
        values = [e["loudness_db"] for e in entries if e["category"] == category]
        mean = sum(values) / len(values)
        spread = max(abs(v - mean) for v in values)
        ok &= spread <= LOUDNESS_TOLERANCE
        print(f"{category:9s} media {mean:6.1f} dB  desviación máx. {spread:4.1f} dB", "ok" if spread <= LOUDNESS_TOLERANCE else "FUERA")
    return ok


def main():
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    import_cc0(download_packs())
    if not build_synth():
        raise SystemExit("Algún bucle supera SEAM_LIMIT en la costura.")
    paths = sorted(list(SFX_DIR.glob("*.wav")) + list(SFX_DIR.glob("*.ogg")) + list(MUSIC_DIR.glob("*.ogg")))
    entries = [measure(p, origin_of(p.stem)) for p in paths]
    write_reports(entries)
    if not check_categories(entries):
        raise SystemExit("Alguna categoría se sale de ±4 dB.")


if __name__ == "__main__":
    main()
