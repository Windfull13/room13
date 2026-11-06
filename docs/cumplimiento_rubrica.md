# Cumplimiento de la rúbrica — La Habitación 13

Contraste del juego (versión 1.0.0, modo feria incluido) con los 7 criterios del proyecto final. Las cifras salen de ejecutar comandos sobre el proyecto (recuentos de archivos, `tests/run_tests.gd --report`, `dev/audio/build_audio.py`, `dev/capture_evidence.gd`); no están escritas de memoria. Estado: ✅ cumple · ⚠️ parcial · ❌ falta.

## Resumen

| # | Criterio | Peso | Estado | Evidencia verificada | Pendiente (depende del equipo) |
|---|---|---|---|---|---|
| 1 | Funcionamiento técnico y mecánicas | 30 % | ⚠️ | **1534 comprobaciones aprobadas, 0 fallidas** en 25 suites (`docs/informe_de_pruebas.md`). 11 rondas sobre una sola habitación (`resources/rooms/`), **36 anomalías** (10 fáciles, 18 medias, 8 difíciles; 9 peligrosas con su susto propio), selector por tramos sin repeticiones, reinicio al fallar. Estabilidad: 200 partidas perfectas y 200 con un fallo, **50 partidas completas** del menú al menú (con recuerdos, cinemática saltada y sin saltar) y **30 finalizaciones anticipadas** del modo feria: 0 nodos huérfanos y reproductores de audio estables (19 → 19). Teclado y ratón; F11 y ajustes guardados. | **Exportar el `.exe`** (no hay plantillas de Windows en este equipo; preset listo en `export_presets.cfg`, pasos en `README.md`). Prueba en otro equipo y con un monitor distinto. |
| 2 | Diseño visual y sonoro | 10 % | ⚠️ | Pixel art coherente (**115 PNG** en `assets/generated/`), fuentes góticas OFL, interfaz con un solo tema (`UiTheme`, `ButtonFx`). **15 pantallas × 4 resoluciones = 60 capturas** (`docs/evidencias/`), todas sin controles fuera, solapados ni recortados (`tests/test_polish_layout.gd`). **36 archivos de audio** (4 música, 4 ambiente, 19 efectos, 9 sustos; CC0 de Kenney y generados), pico máximo −3,8 dBFS, sin continua, sonoridad por categoría dentro de ±4 dB, bucles sin clic (`docs/audio_inventario.md`, `tests/test_polish_audio.gd`). | **Grabar las 3 voces** (opcionales; guion en `docs/guion_de_voces.md`). Que una persona escuche el audio y valore la ambientación: yo no he podido oírlo. |
| 3 | Propósito pedagógico e impacto social | 15 % | ⚠️ | Propósito y consentimiento al inicio; **10 tarjetas de aprendizaje + 1 de cierre** garantizadas en los pasillos; historia de entrada (4 páginas) y epílogo (2); **4 recuerdos de pasillo** y **20 recuerdos de objeto**; cinemática final; pantalla de ayuda con aviso de emergencias. Temas: acoso, duelo, culpa, autocuidado y apoyo profesional (`resources/learning/learning_content.tres`). Todo con textos editables. | **Rellenar `help_lines`** con teléfonos y webs de ayuda reales (hoy vacía). Que alguien del ámbito (psicología, orientación) revise el tratamiento del duelo y el acoso. El impacto real no está medido: depende de los datos de la feria. |
| 4 | Evaluación del aprendizaje (trivia inicial y final) | 15 % | ✅ | **8 preguntas** (4 opciones + «No lo sé»), trivia inicial y final con las mismas preguntas; puntuación, ganancia y ganancia normalizada (`TriviaScorer`); pantalla de resultados por pregunta con temas mejorados y a repasar; JSON anónimo por participante con consentimiento; `dev/analyze_results.py` con media y desviación, ganancia, % que mejoró, acierto por pregunta, correlación con los recuerdos y desglose por completos/anticipados. Probado sobre 12 participantes **simulados** con cifras calculadas a mano (`tests/test_learning_data.gd`, `tests/test_fair_mode.gd`). Modo feria: cualquiera con ≥ 240 s de juego puede llegar a la trivia final sin completar las 10 rondas. | **Datos reales**: no hay ninguno todavía; lo que muestra el análisis hoy son datos de ejemplo. Sin grupo de control, la mejora no se puede atribuir solo al juego (ver `docs/plan_de_pruebas_con_usuarios.md`). |
| 5 | Experiencia de usuario y coevaluación | 10 % | ⚠️ | «Cómo jugar» desde el menú, el pre-juego y la pausa (texto leído del InputMap); teclas 1/2 además de los botones; pausa con volumen; confirmaciones al terminar o salir en el modo feria; regreso automático al menú a los 30 s para el siguiente visitante. **Encuesta de 7 ítems** (1–5) y comentario opcional, analizada por el script. Plan de sesiones en `docs/plan_de_pruebas_con_usuarios.md`. | **Coevaluación real**: se recogerá en la feria. Ninguna persona ajena al equipo ha jugado todavía, así que la facilidad de uso está comprobada por pruebas automáticas, no por usuarios. |
| 6 | Creatividad e innovación | 10 % | ✅ | Sección «Creatividad e innovación» del `README.md`, con cada afirmación comprobada en el código: una habitación base para 11 rondas, memoria y reinicio como mecánica, 36 anomalías con tema, dificultad, pista y significado, entidades que reaccionan al entorno, narrativa por capas (tarjetas, recuerdos de pasillo, recuerdos de objeto, cinemática), evaluación integrada y arquitectura por datos. | — |
| 7 | Documentación y presentación | 10 % | ⚠️ | `README.md`, `docs/arquitectura.md` (diagramas Mermaid), `docs/manual_de_usuario.md`, `docs/plan_de_pruebas_con_usuarios.md`, `docs/aprendizaje_y_evaluacion.md`, `docs/catalogo_anomalias.md` (36 filas), `docs/entidades_y_sustos.md`, `docs/audio_inventario.md`, `docs/guion_de_voces.md`, `docs/informe_de_pruebas.md` (autogenerado) y este documento; `CREDITS.md` con fuentes y licencias; **60 capturas** con índice en `docs/evidencias/README.md`. `docs/` tiene 11 documentos `.md` (con este). | **Nombres del equipo y asignatura** en `CREDITS.md` (siguen como marcadores). **Presentación (diapositivas)**: no existe. |

## Detalle de las cifras

| Cifra | Valor | Cómo se obtuvo |
|---|---|---|
| Anomalías | 36 (9 peligrosas) | `resources/anomalies/*.tres`; peligrosas = `is_dangerous = true` |
| Dificultad | 10 fáciles · 18 medias · 8 difíciles | campo `difficulty` de los `.tres` |
| Rondas | 11 (1 referencia + 10) | `resources/rooms/*.tres`, todas con `room_base.tscn` |
| Preguntas de trivia | 8 | `resources/learning/questions/*.tres` |
| Recuerdos de objeto / de pasillo | 20 / 4 | `object_memories.tres` y `scenes/memories/` |
| Archivos de audio | 36 | `dev/audio/audio_metrics.json` |
| Capturas | 60 (15 pantallas × 4 resoluciones) | `docs/evidencias/` |
| Suites de pruebas | 25 | `tests/test_*.gd` |
| Comprobaciones aprobadas | 1534 de 1534 | `tests/run_tests.gd --report` |

## Honestidad sobre el estado de cada criterio

- **1 es ⚠️ y no ✅** porque nunca se ha ejecutado un ejecutable exportado. Todo lo demás se ha probado en el editor y en modo headless.
- **2 es ⚠️** porque la calidad estética y sonora es subjetiva y solo se ha medido: no se ha escuchado ni valorado con personas, y faltan las voces.
- **3 es ⚠️** porque el contenido está completo pero el efecto sobre las personas no se ha medido, y falta una revisión por alguien del ámbito.
- **4 es ✅** por la integración y el análisis, que están implementados y probados. Las conclusiones sobre aprendizaje quedan vacías hasta que haya datos reales.
- **5 es ⚠️** porque la coevaluación todavía no existe.

## Qué no se pudo verificar

- **El ejecutable exportado**: no hay plantillas de exportación de Windows (`--export-release` falla con «No export template found»). No se ha probado el `.exe` ni su arranque.
- **El audio al oído**: las medidas (pico, sonoridad, empalme de bucles) son objetivas, pero nadie ha escuchado el resultado. La mezcla se compensó al masterizar y no se ha comprobado a oído.
- **Las voces**: no están grabadas; solo se ha probado con un archivo de prueba que la música baja y se restaura.
- **Personas jugando**: ningún usuario ajeno ha probado el juego. No se ha medido si los sustos funcionan, si las viñetas emocionan, si la dificultad es adecuada ni cuánto cuesta llegar a los 240 s en una feria real.
- **Rendimiento en otros equipos**: solo se ha ejecutado en este ordenador (gráfica Intel UHD).
- **Otras resoluciones o escalados de pantalla**: la maquetación se comprobó a 4 resoluciones con el mismo estirado `canvas_items` del juego, pero no en una ventana real a cada tamaño ni con escalado de Windows distinto del 100 %.
- **Efecto sobre el aprendizaje**: el análisis se ha probado con datos simulados; no hay evidencia real de que el juego enseñe.
- **Revisión de contenido sensible**: el tratamiento del duelo, el acoso y la salud mental no ha sido revisado por un profesional.
- **El icono en el `.exe`**: el icono está configurado para el proyecto y la ventana (`config/icon`), pero no se ha incrustado en el ejecutable (requiere `rcedit`).
