# Aprendizaje y evaluación — La Habitación 13

## Flujo completo

```
Menú → INICIAR PARTIDA (sesión nueva, identificador nuevo)
  PRE-JUEGO   propósito y consentimiento → trivia inicial → cómo jugar → historia (4 páginas)
  PARTIDA     11 rondas; en cada pasillo, una tarjeta de aprendizaje (10 + 1 de cierre)
              pasillos hacia las rondas 3, 5, 7 y 9: además, un recuerdo enmarcado con su pie
              tras acertar una anomalía no peligrosa: su objeto puede guardar un recuerdo (opcional)
  CINEMÁTICA  «La última puerta» (~48 s; mantener E 1 s la salta)
  POST-JUEGO  epílogo (2 páginas) → trivia final → resultados → encuesta → ayuda y agradecimiento
Volver al menú → cierra la sesión
```

- El pre-juego ocurre **una vez por sesión**: un fallo en la partida vuelve a la habitación de referencia, no al pre-juego.
- «CÓMO JUGAR» está en el menú principal, en el pre-juego y en la pausa (tanto la de la partida como la de pre/post-juego).
- Esc abre la pausa en todas las pantallas de pre y post-juego sin perder el punto en el que se estaba.
- Las tarjetas no se pueden saltar. Duración del pasillo con tarjeta: `max(3,4 s; 2,2 + 0,045 × caracteres)`, con tope de 7 s.

## Modo feria: terminar y evaluar

Con `FAIR_MODE = true` (`scripts/settings/fair_mode.gd`), un participante que no consigue acertar las 10 rondas seguidas puede cerrar su sesión desde la pausa de la partida:

```
Pausa → TERMINAR Y EVALUAR → confirmación → página «Has decidido terminar aquí…»
  → trivia final → resultados → encuesta → ayuda → menú
```

No pasa por la cinemática ni por el epílogo, y `cinematic_skipped` queda en `null`. Los textos (incluida la página de finalización anticipada) están en `learning_content.tres`. A los 30 s sin actividad en la pantalla de agradecimiento, el juego vuelve al menú y abre una sesión nueva.

## Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Textos (propósito, consentimiento, historia, epílogo, tarjetas, encuesta, ayuda, cómo jugar) | `resources/learning/learning_content.tres` |
| Una pregunta de la trivia | `resources/learning/questions/qNN_tema.tres` |
| Sesión del participante (autoload `Session`) | `scripts/learning/session.gd` |
| Puntuación y ganancia (sin nodos) | `scripts/learning/trivia_scorer.gd` |
| Guardado de resultados (sin nodos) | `scripts/learning/results_store.gd` |
| Texto de «Cómo jugar» desde el InputMap | `scripts/learning/howto_text.gd` |
| Conductor de pre y post-juego | `scripts/learning/learning_flow.gd`, `scenes/learning/pre_game.tscn`, `post_game.tscn` |
| Vistas (solo muestran) | `scripts/ui/learning/` |
| Recuerdos de objeto (20) y sus textos | `resources/learning/object_memories.tres` |
| Recuerdos del pasillo (4) y textos de la cinemática | `resources/learning/memory_texts.tres` |
| Viñetas y cinemática | `scenes/memories/`, `scenes/cinematic/last_door.tscn` |
| Voces opcionales | `assets/audio/voices/` (guion en `docs/guion_de_voces.md`) |
| Análisis | `dev/analyze_results.py` |

## Cómo editar preguntas y textos

**Textos:** abre `resources/learning/learning_content.tres` en el Inspector de Godot (o en un editor de texto) y cambia los campos. Para las tarjetas del pasillo hay una por ronda de decisión (`corridor_cards`, 10 entradas) más `closing_card`; mantenlas en 140 caracteres o menos (lo comprueba una prueba).

**Preguntas:** cada `.tres` de `resources/learning/questions/` tiene `id`, `topic`, `text`, `options` (4), `correct_index` y `explanation`. Por convención la correcta es la opción 0; el juego baraja las 4 al mostrarlas y guarda siempre el **índice original**. «No lo sé» se añade siempre al final y se guarda como `-1`. Si cambias el número de preguntas, actualiza también `TOTAL_QUESTIONS` en `dev/analyze_results.py` (el juego usa el recuento real).

**Líneas de ayuda locales:** `help_lines` empieza vacía. Añade ahí teléfonos o webs (una por entrada) y aparecerán en la pantalla de ayuda; si está vacía no se muestra nada.

**Controles:** el texto de «Cómo jugar» usa los marcadores `{mover}`, `{interactuar}` y `{pausa}`, que se sustituyen por las teclas reales del InputMap.

## Datos que se guardan

Un JSON por participante, que se actualiza al terminar cada etapa (consentimiento + trivia inicial, trivia final, encuesta). Si el participante elige **JUGAR SIN GUARDAR** no se escribe nada. Si la escritura falla, el juego continúa sin errores.

```json
{
  "participant_id": "3fa91c07",     // 8 caracteres hexadecimales, anónimo
  "version": "0.3.0",
  "consent": true,
  "started_at": "...", "finished_at": "...", "completed": true,
  "attempts": 2,                    // partidas empezadas en la sesión
  "play_seconds": 812.4,
  "pre":  { "answers": { "q01_acoso": 0, "...": -1 }, "score": 3 },
  "post": { "answers": { "...": 0 },                  "score": 7 },
  "gain": 4,
  "normalized_gain": 0.8,           // (final − inicial) / (8 − inicial); 0 si inicial = 8
  "survey": { "u1": 5, "u2": 4, "u3": 4, "u4": 3, "l1": 5, "l2": 5, "r1": 4, "comment": "" },
  "memories_found": ["caja_de_musica", "reloj_detenido"],   // recuerdos de objeto leídos
  "cinematic_skipped": false,       // null si no llegó a la cinemática (p. ej. terminó antes de tiempo)
  "finish_type": "completo",        // o "anticipado" (TERMINAR Y EVALUAR)
  "max_round_reached": 10,          // 0 = referencia, 10 = última ronda de decisión
  "ended_early": false
}
```

Las respuestas son el índice original de la opción elegida; `-1` = «No lo sé». Lo que aún no ha ocurrido (por ejemplo `post` si alguien abandona) queda en `null`.

## Dónde se guardan en Windows

`user://resultados/<id>.json` equivale a:

```
C:\Users\<usuario>\AppData\Roaming\Godot\app_userdata\Room 13\resultados\
```

(En este equipo: `C:\Users\ASUS\AppData\Roaming\Godot\app_userdata\Room 13\resultados\`.) En OPCIONES hay un botón **ABRIR CARPETA DE RESULTADOS** que la abre.

## Recopilar y analizar varios participantes

1. Pide a cada participante la carpeta `resultados` (o sus archivos `.json`) y junta todos los `.json` en una sola carpeta.
2. Ejecuta (solo necesita Python 3, sin instalar nada):

```
python dev/analyze_results.py CARPETA
```

Genera en esa carpeta (o en `--salida OTRA`) `resultados_consolidados.csv` (una fila por participante) y `analisis_resultados.md` (n, media y desviación típica muestral de la trivia inicial y final, ganancia media, ganancia normalizada media, % que mejoró, acierto inicial → final por pregunta, media de recuerdos de objeto encontrados, % que saltó la cinemática, correlación de Pearson entre recuerdos y ganancia si n ≥ 3, media y distribución de cada ítem de la encuesta y comentarios).

Los archivos con `"simulated": true` se ignoran salvo con `--include-simulated`.

Los JSON sin `finish_type` (de versiones anteriores) se cuentan como «completo». El informe añade: n total, n con las dos trivias, cuántos son completos y cuántos anticipados, la media de `max_round_reached` de los anticipados y las cifras de aprendizaje globales y desglosadas por tipo de finalización.

## Datos de ejemplo

`dev/out/ejemplo_resultados/` contiene **12 participantes simulados** (no son personas reales), generados por `dev/generate_example_results.py`, para probar el análisis:

```
python dev/analyze_results.py dev/out/ejemplo_resultados --include-simulated
```

Cifras que se pueden comprobar a mano: trivia inicial media 3,50 (suma 42), final 5,67 (suma 68), ganancia media +2,17, ganancia normalizada media 0,564, 10 de 12 participantes que mejoran (83,3 %), 6,75 recuerdos de media (suma 81), 33,3 % que salta la cinemática (3 de los 9 que la vieron) y correlación recuerdos–ganancia 0,604.

Desglose: 9 completos (inicial 3,33, final 5,44, ganancia +2,11, normalizada 0,530, mejoran 77,8 %) y 3 anticipados (los participantes 1, 6 y 10: inicial 4,00, final 6,33, ganancia +2,33, normalizada 0,667, mejoran 100 %; llegaron a las rondas 4, 7 y 9, media 6,67). Una correlación con datos de ejemplo no dice nada sobre personas reales.
