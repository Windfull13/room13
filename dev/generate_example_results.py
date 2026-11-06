#!/usr/bin/env python3
"""Genera 12 participantes SIMULADOS en dev/out/ejemplo_resultados/.

Son datos inventados solo para probar dev/analyze_results.py; llevan
"simulated": true y no representan a ninguna persona real. La tabla es fija,
así que las cifras esperadas se pueden comprobar a mano:

  inicial  = 3 4 2 5 3 6 4 2 5 3 4 1   (suma 42, media 3,5)
  final    = 6 7 5 7 6 8 6 2 8 5 7 1   (suma 68, media 5,667)
  recuerdos= 5 9 4 8 6 12 7 2 11 6 10 1 (suma 81, media 6,75)
  saltan la cinemática los participantes 2, 5 y 8 (3 de los 9 que la vieron)
  terminan antes de tiempo los participantes 1, 6 y 10 (rondas 4, 7 y 9); no ven la cinemática
"""

import json
from pathlib import Path

QUESTION_IDS = [
    "q01_acoso", "q02_espectadores", "q03_duelo", "q04_culpa",
    "q05_apoyo", "q06_autocuidado", "q07_accidente", "q08_infancia",
]
PRE_SCORES = [3, 4, 2, 5, 3, 6, 4, 2, 5, 3, 4, 1]
POST_SCORES = [6, 7, 5, 7, 6, 8, 6, 2, 8, 5, 7, 1]
SURVEY_IDS = ["u1", "u2", "u3", "u4", "l1", "l2", "r1"]
MEMORY_IDS = [
    "telefono_sonando", "telefono_descolgado", "foto_cambiada", "foto_invertida", "retrato_ajeno",
    "dibujo_en_la_pared", "peluche_girado", "muneca_en_el_suelo", "caja_de_musica", "carta_abierta",
    "llaves_en_el_suelo", "reloj_detenido", "lampara_apagada", "silla_ausente", "luz_en_la_ventana",
    "planta_con_flor", "comida_sin_tocar", "espejo_cubierto", "notas_bajo_la_puerta", "golpes_en_la_puerta",
]
MEMORIES_FOUND = [5, 9, 4, 8, 6, 12, 7, 2, 11, 6, 10, 1]
SKIPPED_CINEMATIC = {1, 4, 7}
# Finalizaciones anticipadas (modo feria): no vieron la cinemática (null) y llegaron a la ronda indicada.
EARLY_FINISH = {0: 4, 5: 7, 9: 9}
FULL_ROUND = 10
COMMENTS = {2: "Las tarjetas del pasillo me hicieron pensar.", 5: "Me gustó la ambientación.", 9: "Un poco difícil al final."}
OUTPUT = Path(__file__).parent / "out" / "ejemplo_resultados"


def answers_for(participant, score, kind):
    """Acierta `score` preguntas empezando en una posición que depende del participante."""
    correct = {(participant + k) % 8 for k in range(score)}
    answers = {}
    for position, question_id in enumerate(QUESTION_IDS):
        if position in correct:
            answers[question_id] = 0
        elif kind == "pre" and position % 4 == 0:
            answers[question_id] = -1  # «No lo sé»
        else:
            answers[question_id] = 1 + (participant + position) % 3
    return answers


def build(participant):
    pre, post = PRE_SCORES[participant], POST_SCORES[participant]
    survey = {item: 3 + (participant * (k + 1)) % 3 for k, item in enumerate(SURVEY_IDS)}
    survey["comment"] = COMMENTS.get(participant, "")
    return {
        "simulated": True,
        "participant_id": "5eed%04x" % (participant + 1),
        "version": "1.0.0",
        "consent": True,
        "started_at": "2026-01-01T10:%02d:00" % participant,
        "finished_at": "2026-01-01T10:%02d:30" % (participant + 20),
        "completed": True,
        "attempts": 1 + participant % 4,
        "play_seconds": 600.0 + 25 * participant,
        "pre": {"answers": answers_for(participant, pre, "pre"), "score": pre},
        "post": {"answers": answers_for(participant, post, "post"), "score": post},
        "gain": post - pre,
        "normalized_gain": 0.0 if pre >= 8 else (post - pre) / (8 - pre),
        "survey": survey,
        "memories_found": [MEMORY_IDS[(participant + k) % len(MEMORY_IDS)] for k in range(MEMORIES_FOUND[participant])],
        "cinematic_skipped": None if participant in EARLY_FINISH else participant in SKIPPED_CINEMATIC,
        "finish_type": "anticipado" if participant in EARLY_FINISH else "completo",
        "max_round_reached": EARLY_FINISH.get(participant, FULL_ROUND),
        "ended_early": participant in EARLY_FINISH,
    }


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for participant in range(12):
        record = build(participant)
        (OUTPUT / (record["participant_id"] + ".json")).write_text(
            json.dumps(record, ensure_ascii=False, indent="\t"), encoding="utf-8"
        )
    print("Escritos 12 participantes simulados en", OUTPUT)


if __name__ == "__main__":
    main()
