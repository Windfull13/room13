# La Habitación 13

Videojuego de terror psicológico en pixel art, hecho en **Godot 4.7.2 (GDScript)**, para generar conciencia sobre el **acoso, el duelo y el cuidado de la salud mental**. No es terapia ni sustituye la ayuda profesional.

Una sola habitación se repite en 11 rondas: la primera es de referencia y en las otras 10 decides si algo ha cambiado (**HAY ANOMALÍA**) o si todo sigue igual (**NO HAY ANOMALÍA**). Si fallas, vuelves a empezar desde la referencia. Entre rondas cruzas un pasillo con tarjetas de aprendizaje y, en algunos, un recuerdo. Antes y después de jugar hay una trivia de 8 preguntas, una encuesta y una pantalla de ayuda. Los resultados se guardan de forma anónima si el participante lo acepta.

## Requisitos

- **Godot 4.7.2** (versión estándar, no .NET) para abrir y ejecutar el proyecto.
- Para regenerar el audio (opcional): Python 3.10+ con `numpy`, `scipy` y `soundfile`.
- Para analizar resultados: Python 3 (solo biblioteca estándar).

## Ejecutar

1. Abre Godot, pulsa **Importar** y elige `project.godot`.
2. Pulsa **F5** (o el botón ▶). La escena principal es `scenes/main_menu.tscn`.

Desde la línea de comandos: `godot --path .`

## Controles

Los controles se leen del InputMap, y la pantalla «Cómo jugar» los muestra siempre actualizados.

| Acción | Tecla |
|---|---|
| Moverte | W, A, S, D o las flechas |
| Examinar un objeto o la puerta / cerrar un mensaje | E |
| HAY ANOMALÍA / NO HAY ANOMALÍA | 1 / 2 (o clic en los botones) |
| Pausa, volumen, cómo jugar y salir al menú | Esc |
| Pantalla completa | F11 (o la casilla de OPCIONES) |
| Saltar la cinemática final | mantener E durante 1 s |

En las pantallas de menú y de trivia también funcionan las flechas, Enter y el ratón, y en la trivia las teclas 1–5.

## Modo feria

Pensado para exponer el juego: casi nadie acierta las 10 rondas seguidas (cada fallo reinicia), así que sin esto no habría datos de evaluación. Las constantes están en `scripts/settings/fair_mode.gd`:

| Constante | Valor | Qué hace |
|---|---|---|
| `FAIR_MODE` | `true` | Interruptor general. Con `false` el juego se comporta como antes. |
| `FAIR_MIN_PLAY_SECONDS` | 240 | Segundos de juego a partir de los cuales la pausa ofrece **TERMINAR Y EVALUAR**. |
| `FAIR_IDLE_RETURN_SECONDS` | 30 | Sin actividad en la pantalla de agradecimiento, vuelve al menú y cierra la sesión. |

- **TERMINAR Y EVALUAR** aparece solo en la pausa de la partida, tras hacer la trivia inicial y con al menos 240 s de juego. Pide confirmación y lleva a una página de finalización anticipada, la trivia final, los resultados, la encuesta y la ayuda (sin cinemática ni epílogo). No es un cronómetro: no afecta a la partida.
- **MENÚ PRINCIPAL** desde la pausa pide confirmación si ya se hizo la trivia inicial y aún no la final.
- El JSON guarda `finish_type` («completo» o «anticipado»), `max_round_reached` y `ended_early`. Los textos están en `resources/learning/learning_content.tres`.

## Exportar (Windows)

El preset ya está en `export_presets.cfg`:
- **Windows Desktop**, x86_64.
- Ejecutable `build/La Habitacion 13.exe`, con el PCK incrustado.
- Incluye `*.md`, porque el menú lee `CREDITS.md`.
- Excluye `dev/*`, `tests/*`, `legacy/*`, `docs/*`, `resources/legacy_*/*`, el plugin de editor `addons/ziva_agent/*` y `build/*`.

**En este equipo no están instaladas las plantillas de exportación de Windows**: solo están las de Web. Por eso la exportación real no se ha hecho. Pasos para exportar:

1. En Godot: **Editor → Gestionar plantillas de exportación… → Descargar e instalar** (versión 4.7.2.stable). Así se crean `windows_release_x86_64.exe` y `windows_debug_x86_64.exe` en `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
2. **Proyecto → Exportar…**, elige el preset **Windows Desktop** y pulsa **Exportar proyecto** (desmarca «Exportar con depuración»). También se puede hacer por consola:
   `godot --headless --path . --export-release "Windows Desktop" "build/La Habitacion 13.exe"`
3. Prueba de humo: `"build/La Habitacion 13.exe" --quit-after 300` debe arrancar y cerrarse sin errores en la consola.

## Pruebas

```
godot --headless --path . --script res://tests/run_tests.gd            # todas las suites
godot --headless --path . --script res://tests/run_tests.gd --report   # y escribe docs/informe_de_pruebas.md
```

El código de salida es 1 si falla alguna comprobación. `ZIVA_PLAYTHROUGHS=N` acorta las simulaciones de partidas. La comprobación de las pistas luminosas abre una ventana un momento, porque necesita dibujar de verdad.

Herramientas que necesitan ventana:
- `godot --path . res://dev/contact_sheet.tscn`: hoja de contacto de las 36 anomalías.
- `godot --path . res://dev/capture_evidence.tscn`: capturas de `docs/evidencias/`.

## Creatividad e innovación

- **Una sola habitación reutilizada como base de 11 rondas.** La repetición hace que lo importante sea recordar y observar, y las variaciones se definen con datos (`scenes/rooms/room_base.tscn`, las 11 rondas de `resources/rooms/` apuntan a la misma escena).
- **Detección de anomalías con reinicio completo al fallar.** La memoria y la atención son la mecánica central (`scripts/game_manager.gd`: un fallo vuelve a la habitación de referencia y empieza otra partida).
- **36 anomalías con tema, dificultad progresiva, pista y significado.** Cada una tiene un tema (16 posibles: acoso, duelo, culpa, aislamiento, autocuidado…), una dificultad que el selector hace subir con las rondas, una pista y un significado de 90 caracteres como máximo (`resources/anomalies/`, `scripts/anomaly_selector.gd`; catálogo en `docs/catalogo_anomalias.md`).
- **Entidades que reaccionan al entorno y sustos únicos solo ante el error crítico.** La lámpara parpadea, el armario vibra o la habitación se apaga cerca de una entidad (`scripts/entity_ambience.gd`). Cada una de las 9 anomalías peligrosas tiene su propio susto (`scenes/jumpscares/`, `scripts/jumpscares/`), que solo salta si se ignora la amenaza o el Testigo alcanza al jugador; un fallo sobre una anomalía inofensiva reinicia sin susto.
- **Narrativa por capas.** Tarjetas de aprendizaje garantizadas en los 11 pasillos (`resources/learning/learning_content.tres`), recuerdos de pasillo en las rondas 3, 5, 7 y 9 (`scripts/memories/`, `scenes/memories/`), 20 recuerdos opcionales de objeto (`resources/learning/object_memories.tres`) y una cinemática final saltable (`scripts/cinematic/`).
- **Evaluación integrada del aprendizaje.** Trivia inicial y final de 8 preguntas con «No lo sé», análisis por participante en pantalla, script de análisis agregado y encuesta de coevaluación (`scripts/learning/`, `scripts/ui/learning/`, `dev/analyze_results.py`).
- **Arquitectura guiada por datos, SOLID y más de mil pruebas automatizadas con informe autogenerado.** Anomalías, rondas, preguntas, textos y recuerdos son recursos editables; la lógica (`TriviaScorer`, `ResultsStore`, `AnswerEvaluator`) no depende de nodos; `tests/run_tests.gd --report` escribe `docs/informe_de_pruebas.md` (`docs/arquitectura.md`, `tests/`).

## Estructura

```
scenes/            menú, partida, habitación, pasillo, sustos, aprendizaje, recuerdos, cinemática
scripts/           lógica del juego (GameManager, Room, AnomalySelector, EntityAmbience…)
  audio/           AudioManager (autoload) y SoundCatalog
  learning/        Session (autoload), trivia, resultados, cómo jugar, flujo pre/post-juego
  memories/        recuerdos de objeto, viñetas del pasillo y sus datos
  cinematic/       «La última puerta»
  settings/        UserSettings, DisplayManager (autoload, pantalla completa) y FairMode (modo feria)
  ui/              tema, botones animados y vistas de aprendizaje
resources/         datos editables: anomalías (36), rondas, aprendizaje, recuerdos
assets/            sprites, fuentes OFL, audio (CC0 + generado), voces opcionales
dev/               herramientas: audio, galería, hoja de contacto, capturas, análisis de resultados
docs/              documentación, evidencias e informe de pruebas
tests/             suites de pruebas y runner
```

## Documentación

- [Arquitectura](docs/arquitectura.md)
- [Manual de usuario](docs/manual_de_usuario.md)
- [Aprendizaje y evaluación](docs/aprendizaje_y_evaluacion.md)
- [Plan de pruebas con usuarios](docs/plan_de_pruebas_con_usuarios.md)
- [Informe de pruebas](docs/informe_de_pruebas.md)
- [Cumplimiento de la rúbrica](docs/cumplimiento_rubrica.md)
- [Catálogo de anomalías](docs/catalogo_anomalias.md)
- [Entidades y sustos](docs/entidades_y_sustos.md)
- [Inventario de audio](docs/audio_inventario.md)
- [Guion de voces](docs/guion_de_voces.md)
- [Evidencias visuales](docs/evidencias/README.md)
- [Créditos](CREDITS.md)
