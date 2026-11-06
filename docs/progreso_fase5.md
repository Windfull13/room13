# Progreso — Fase 5 (recuerdos, pulido, documentación y exportación)

| Bloque | Estado | Fecha | Notas |
|---|---|---|---|
| A — UX y pistas | hecho | 2026-11-04 | Teclas 1/2 (acciones decide_*), F11 + casilla (autoload DisplayManager, UserSettings), pistas luminosas en EntityAmbience.CUES (teléfono 156 px, puerta 120 px). tests/test_polish_ux.gd 30/30; learning_views, menu y anomaly_catalog en verde. |
| B — Memorias | hecho | 2026-11-04 | 20 recuerdos de objeto (object_memories.tres, MemorySpot, panel RECUERDO con escritura a 40 c/s), 4 viñetas de pasillo (MemoryVignette + scenes/memories/), cinemática scenes/cinematic/last_door.tscn (saltable con E 1 s), voces opcionales (AudioManager.play_voice, docs/guion_de_voces.md), memories_found/cinematic_skipped en JSON y análisis. Suites test_memories_objects 122, test_memories_corridor 39, test_memories_cinematic 21; learning_data/flow, audio, door_flow, game_flow, data_integrity y simulations (20 partidas) en verde. Trampa: Array[ClaseDelJuego] exportado provocaba fugas al salir → Array[Resource]. |
| C — Pulido de audio y visual | hecho | 2026-11-04 | build_audio.py: reverb, capas y limitador; master por categoría (música −20, ambiente −22, efectos −24, sustos −20 dB, pico ≤ −3 dBFS, sin DC); volume_db del catálogo compensado para mantener la mezcla. test_polish_audio 14/14. Pantallas: dev/screen_catalog.gd + test_polish_layout 61/61 (15 pantallas × 4 resoluciones; corregidos el aviso de saltar de la cinemática y el recorte del scroll). Capturas reales en docs/evidencias (60). |
| D — Documentación y evidencias | hecho | 2026-11-05 | README, arquitectura, manual, plan de pruebas con usuarios, CREDITS completo, run_tests.gd --report (y --only=), dev/capture_evidence.gd (60 capturas + índice). test_polish_docs 29/29. |
| E — Exportación y verificación final | hecho salvo exportación real | 2026-11-05 | Versión 1.0.0 y export_presets.cfg listos. No hay plantillas de Windows instaladas (solo web): `--export-release` falla por «No export template found»; exportación y prueba de humo del .exe pendientes (pasos en README). Estabilidad: 50 partidas completas, 0 huérfanos, 19 → 19 reproductores. Suite completa con --report: 1461/1461, EXIT 0, 0 líneas ERROR. |

## Cómo retomar
- Pruebas de una suite: crear temporalmente `tests/zz_one.gd` (runner que lee `ZIVA_SUITE`) y borrarlo al terminar.
- Suite completa: `godot --headless --path . --script res://tests/run_tests.gd`.
