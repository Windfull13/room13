# Inventario de audio — La Habitación 13

Generado por `dev/audio/build_audio.py` (no editar a mano). Cifras medidas sobre los archivos ya escritos.

- Pico máximo de cualquier archivo: ≤ -3 dBFS. Sin componente continua.
- Sonoridad: RMS con puerta en bloques de 400 ms; cada categoría apunta a un valor y la prueba exige ±4 dB.
- El volumen de juego de cada sonido se ajusta en `scripts/audio/sound_catalog.gd` (volume_db).
- **Fácil de reemplazar**: sí en todos. Basta con poner otro archivo con el mismo nombre (WAV/OGG/MP3) en la misma carpeta; `AudioManager` lo encuentra aunque cambie la extensión.

| Archivo | Origen | Categoría | Duración | Pico | Sonoridad | Costura del bucle | Fácil de reemplazar |
|---|---|---|---|---|---|---|---|
| `assets/audio/ambient_room.ogg` | Generado (dev/audio/build_audio.py) | ambiente | 24.00 s | -8.7 dBFS | -22.0 dB | 0.19 | sí |
| `assets/audio/ambient_traffic.ogg` | Generado (dev/audio/build_audio.py) | ambiente | 24.00 s | -6.8 dBFS | -22.0 dB | 0.72 | sí |
| `assets/audio/anomaly_dead_line.wav` | Generado (dev/audio/build_audio.py) | efectos | 2.20 s | -18.6 dBFS | -24.0 dB | — | sí |
| `assets/audio/anomaly_knocks.wav` | Generado (dev/audio/build_audio.py) | efectos | 1.60 s | -6.0 dBFS | -24.0 dB | — | sí |
| `assets/audio/anomaly_music_box.wav` | Generado (dev/audio/build_audio.py) | efectos | 6.00 s | -13.7 dBFS | -24.0 dB | — | sí |
| `assets/audio/anomaly_phone_ring.wav` | Generado (dev/audio/build_audio.py) | efectos | 1.30 s | -9.7 dBFS | -24.0 dB | — | sí |
| `assets/audio/danger_heartbeat.ogg` | Generado (dev/audio/build_audio.py) | ambiente | 1.80 s | -7.7 dBFS | -21.9 dB | 0.13 | sí |
| `assets/audio/door_cross.wav` | CC0 · Kenney rpg-audio/doorClose_4.ogg | efectos | 0.61 s | -5.7 dBFS | -24.0 dB | — | sí |
| `assets/audio/door_locked.wav` | CC0 · Kenney rpg-audio/metalLatch.ogg | efectos | 0.27 s | -3.8 dBFS | -24.4 dB | — | sí |
| `assets/audio/door_unlock.wav` | CC0 · Kenney rpg-audio/doorOpen_1.ogg | efectos | 0.93 s | -3.8 dBFS | -24.2 dB | — | sí |
| `assets/audio/fade.wav` | Generado (dev/audio/build_audio.py) | efectos | 0.70 s | -12.1 dBFS | -24.0 dB | — | sí |
| `assets/audio/fail.wav` | Generado (dev/audio/build_audio.py) | efectos | 0.90 s | -9.5 dBFS | -24.0 dB | — | sí |
| `assets/audio/footstep.wav` | CC0 · Kenney rpg-audio/footstep04.ogg | efectos | 0.33 s | -3.8 dBFS | -24.2 dB | — | sí |
| `assets/audio/jumpscare_armario.wav` | Generado (dev/audio/build_audio.py) | sustos | 1.40 s | -4.1 dBFS | -20.0 dB | — | sí |
| `assets/audio/jumpscare_cama.wav` | Generado (dev/audio/build_audio.py) | sustos | 1.50 s | -3.8 dBFS | -20.1 dB | — | sí |
| `assets/audio/jumpscare_cuervo.wav` | Generado (dev/audio/build_audio.py) | sustos | 1.40 s | -8.7 dBFS | -20.0 dB | — | sí |
| `assets/audio/jumpscare_espejo.wav` | Generado (dev/audio/build_audio.py) | sustos | 1.50 s | -3.8 dBFS | -20.0 dB | — | sí |
| `assets/audio/jumpscare_oscuridad.wav` | Generado (dev/audio/build_audio.py) | sustos | 1.80 s | -6.6 dBFS | -20.0 dB | — | sí |
| `assets/audio/jumpscare_testigo_cuarto.wav` | Generado (dev/audio/build_audio.py) | sustos | 1.50 s | -8.0 dBFS | -20.0 dB | — | sí |
| `assets/audio/jumpscare_testigo_esquina.wav` | Generado (dev/audio/build_audio.py) | sustos | 1.40 s | -12.2 dBFS | -20.0 dB | — | sí |
| `assets/audio/jumpscare_tres_senales.wav` | Generado (dev/audio/build_audio.py) | sustos | 1.80 s | -3.8 dBFS | -20.0 dB | — | sí |
| `assets/audio/jumpscare_ventana.wav` | Generado (dev/audio/build_audio.py) | sustos | 1.30 s | -3.8 dBFS | -20.2 dB | — | sí |
| `assets/audio/memory_murmur.wav` | Generado (dev/audio/build_audio.py) | efectos | 9.00 s | -8.0 dBFS | -24.0 dB | — | sí |
| `assets/audio/memory_rain.ogg` | Generado (dev/audio/build_audio.py) | ambiente | 12.00 s | -8.3 dBFS | -22.1 dB | 0.42 | sí |
| `assets/audio/memory_ticking.wav` | Generado (dev/audio/build_audio.py) | efectos | 9.00 s | -13.4 dBFS | -24.0 dB | — | sí |
| `assets/audio/message_close.wav` | CC0 · Kenney rpg-audio/bookClose.ogg | efectos | 0.24 s | -4.3 dBFS | -24.0 dB | — | sí |
| `assets/audio/message_open.wav` | CC0 · Kenney rpg-audio/bookFlip3.ogg | efectos | 0.24 s | -3.8 dBFS | -26.1 dB | — | sí |
| `assets/audio/music/music_calm.ogg` | Generado (dev/audio/build_audio.py) | musica | 32.00 s | -8.6 dBFS | -20.0 dB | 0.28 | sí |
| `assets/audio/music/music_end.ogg` | Generado (dev/audio/build_audio.py) | musica | 32.00 s | -4.7 dBFS | -20.0 dB | 1.06 | sí |
| `assets/audio/music/music_menu.ogg` | Generado (dev/audio/build_audio.py) | musica | 32.00 s | -4.9 dBFS | -20.0 dB | 1.46 | sí |
| `assets/audio/music/music_tense.ogg` | Generado (dev/audio/build_audio.py) | musica | 24.00 s | -9.8 dBFS | -19.9 dB | 1.07 | sí |
| `assets/audio/success.wav` | CC0 · Kenney interface-sounds/confirmation_001.ogg | efectos | 0.30 s | -13.4 dBFS | -24.1 dB | — | sí |
| `assets/audio/ui_click.wav` | CC0 · Kenney interface-sounds/select_002.ogg | efectos | 0.05 s | -7.9 dBFS | -24.0 dB | — | sí |
| `assets/audio/ui_decision_anomaly.wav` | CC0 · Kenney interface-sounds/switch_002.ogg | efectos | 0.62 s | -3.8 dBFS | -25.0 dB | — | sí |
| `assets/audio/ui_decision_no_anomaly.wav` | CC0 · Kenney interface-sounds/switch_007.ogg | efectos | 0.62 s | -3.8 dBFS | -25.2 dB | — | sí |
| `assets/audio/ui_hover.wav` | CC0 · Kenney interface-sounds/tick_004.ogg | efectos | 0.07 s | -8.1 dBFS | -24.0 dB | — | sí |

Voces (pendientes de grabar, opcionales): `assets/audio/voices/voice_phone_msg.ogg`, `voice_cinematic_wife.ogg`, `voice_cinematic_girl.ogg` (ver `docs/guion_de_voces.md`).
