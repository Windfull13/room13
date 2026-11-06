# Créditos — La Habitación 13

## Autoría

- **Diseño y desarrollo:** equipo de La Habitación 13 (proyecto universitario).
- **Integrantes del equipo:** Ángelo Franco Orozco
- **Docente / asignatura:** Programación multimedia y videojuegos
- **Motor:** Godot Engine 4 — licencia MIT, <https://godotengine.org/license>.
- **Arte:** pixel art creado para este proyecto con la ayuda de Ziva (IA).
- **Viñetas de recuerdo y cinemática final:** dibujadas por código (siluetas en
  un lienzo de 192×108 ampliado sin suavizado), obra original del proyecto.

## Tipografías

Licencia: **SIL Open Font License 1.1** (uso libre, también comercial). Los
textos de licencia están junto a las fuentes, en `assets/fonts/`.

- **UnifrakturCook** (negra gótica, títulos) — Peter Wiegel.
- **Pirata One** (gótica legible, botones y textos) — Rodrigo Fuenzalida y Nicolas Massi.

## Audio

Todo el audio vive en `assets/audio/` (música en `assets/audio/music/`) y se
regenera con `python dev/audio/build_audio.py` (necesita numpy, scipy y
soundfile). Para cambiar un sonido basta con sustituir el archivo por otro con
el **mismo nombre**; si cambia el formato (`.wav`, `.ogg` o `.mp3`), el juego
también lo encuentra. El volumen, el bus y el bucle de cada sonido están en
`scripts/audio/sound_catalog.gd`.

### Sonidos CC0 (dominio público)

Autor: **Kenney Vleugels — [kenney.nl](https://www.kenney.nl)**.
Licencia: **Creative Commons Zero 1.0** —
<https://creativecommons.org/publicdomain/zero/1.0/>. No exige atribución;
se indica igualmente.

Cambios aplicados: mezcla a mono, remuestreo a 44,1 kHz, fundido de 10 ms al
final y masterizado común (sin componente continua, sonoridad de su categoría
y pico por debajo de −3 dBFS). Formato: WAV de 16 bits.

| Archivo del juego | Original | Pack |
|---|---|---|
| `assets/audio/footstep.wav` | `footstep04.ogg` | [RPG Audio](https://kenney.nl/assets/rpg-audio) |
| `assets/audio/message_open.wav` | `bookFlip3.ogg` | [RPG Audio](https://kenney.nl/assets/rpg-audio) |
| `assets/audio/message_close.wav` | `bookClose.ogg` | [RPG Audio](https://kenney.nl/assets/rpg-audio) |
| `assets/audio/door_locked.wav` | `metalLatch.ogg` | [RPG Audio](https://kenney.nl/assets/rpg-audio) |
| `assets/audio/door_unlock.wav` | `doorOpen_1.ogg` | [RPG Audio](https://kenney.nl/assets/rpg-audio) |
| `assets/audio/door_cross.wav` | `doorClose_4.ogg` | [RPG Audio](https://kenney.nl/assets/rpg-audio) |
| `assets/audio/ui_click.wav` | `select_002.ogg` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) |
| `assets/audio/ui_decision_anomaly.wav` | `switch_002.ogg` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) |
| `assets/audio/ui_decision_no_anomaly.wav` | `switch_007.ogg` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) |
| `assets/audio/success.wav` | `confirmation_001.ogg` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) |
| `assets/audio/ui_hover.wav` | `tick_004.ogg` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) |

### Sonidos sintetizados para este proyecto

Generados por `dev/audio/build_audio.py` (ruido, osciladores, filtros y
envolventes; semilla fija 13, así que se regeneran idénticos). Son obra
original del proyecto y no tienen licencias de terceros.

| Archivo | Qué es |
|---|---|
| `assets/audio/music/music_menu.ogg` | Música del menú (bucle de 32 s) |
| `assets/audio/music/music_calm.ogg` | Música tranquila, habitación de referencia (bucle de 32 s) |
| `assets/audio/music/music_tense.ogg` | Música tensa, rondas de decisión (bucle de 24 s) |
| `assets/audio/music/music_end.ogg` | Música de la cinemática final (bucle de 32 s) |
| `assets/audio/ambient_room.ogg` | Murmullo grave de la habitación (bucle de 24 s) |
| `assets/audio/danger_heartbeat.ogg` | Latido del aviso de peligro (bucle de 1,8 s) |
| `assets/audio/fail.wav` | Fallo sin susto |
| `assets/audio/fade.wav` | Fundido tras un fallo |
| `assets/audio/jumpscare_cama.wav` | Susto de la figura bajo la cama |
| `assets/audio/jumpscare_armario.wav` | Susto de la figura del armario |
| `assets/audio/jumpscare_ventana.wav` | Susto de la figura de la ventana |
| `assets/audio/jumpscare_espejo.wav` | Susto del espejo |
| `assets/audio/jumpscare_testigo_cuarto.wav` | Susto del Testigo (escritorio) |
| `assets/audio/jumpscare_testigo_esquina.wav` | Susto del Testigo (cama) |
| `assets/audio/jumpscare_tres_senales.wav` | Susto de las tres señales |
| `assets/audio/jumpscare_cuervo.wav` | Susto del cuervo |
| `assets/audio/jumpscare_oscuridad.wav` | Susto de la oscuridad (faros, lluvia y frenada, sin imagen) |
| `assets/audio/ambient_traffic.ogg` | Tráfico lejano y lluvia fina (bucle de 24 s) |
| `assets/audio/anomaly_phone_ring.wav` | Anomalía «el teléfono suena»: timbre de dos tonos |
| `assets/audio/anomaly_knocks.wav` | Anomalía «golpes en la puerta»: tres golpes suaves |
| `assets/audio/anomaly_music_box.wav` | Anomalía «caja de música»: melodía propia de 5 s |
| `assets/audio/anomaly_dead_line.wav` | Anomalía «teléfono descolgado»: tono de línea muerta |
| `assets/audio/memory_murmur.wav` | Recuerdo «Infancia»: murmullo lejano de niños |
| `assets/audio/memory_rain.ogg` | Recuerdo «La noche» y cinemática: lluvia suave (bucle de 12 s) |
| `assets/audio/memory_ticking.wav` | Recuerdo «El después»: tic-tac lento con zumbido grave |

El recuerdo «Familia» reutiliza `anomaly_music_box.wav`. El inventario completo,
con las medidas de cada archivo, está en `docs/audio_inventario.md`.

### Voces (pendientes de grabar)

Las tres voces son opcionales y todavía no existen: el juego muestra el texto
igualmente. No se usa voz sintética. El guion, con quién dice cada línea y el
nombre de archivo esperado, está en `docs/guion_de_voces.md`.

| Archivo esperado | Voz | Intérprete |
|---|---|---|
| `assets/audio/voices/voice_phone_msg.ogg` | Mujer adulta («ella») | _(pendiente)_ |
| `assets/audio/voices/voice_cinematic_wife.ogg` | Mujer adulta («ella») | _(pendiente)_ |
| `assets/audio/voices/voice_cinematic_girl.ogg` | Niña («la niña») | _(pendiente)_ |

Los bucles se cierran con un fundido cruzado y se codifican en Vorbis con
calidad suficiente para que la costura no haga clic; el script lo mide tras
codificar y falla si alguno supera el límite.
