#!/usr/bin/env python3
"""Análisis de los resultados de La Habitación 13 (solo biblioteca estándar).

Lee una carpeta con un JSON por participante (los que guarda el juego en
user://resultados/) y genera, junto a ellos o en --salida:

  resultados_consolidados.csv   una fila por participante
  analisis_resultados.md        resumen: trivia, ganancia, preguntas y encuesta

Los archivos marcados con "simulated": true se ignoran salvo con
--include-simulated; si se incluyen, los informes lo advierten claramente.

Uso:
  python dev/analyze_results.py CARPETA [--include-simulated] [--salida CARPETA]
"""

import argparse
import csv
import json
import statistics
import sys
from pathlib import Path

TOTAL_QUESTIONS = 8
TOTAL_MEMORIES = 20
MIN_CORRELATION_N = 3
SURVEY_ITEMS = [
    ("u1", "Entendí fácilmente cómo se juega."),
    ("u2", "Los controles respondieron bien."),
    ("u3", "El apartado visual y sonoro me pareció coherente y atractivo."),
    ("u4", "La dificultad me pareció adecuada."),
    ("l1", "Aprendí algo nuevo sobre acoso, duelo o salud mental."),
    ("l2", "El juego me hizo reflexionar."),
    ("r1", "Recomendaría el juego a otras personas."),
]
SCALE = range(1, 6)
FINISH_COMPLETE = "completo"
FINISH_EARLY = "anticipado"
FINISH_TYPES = (FINISH_COMPLETE, FINISH_EARLY)
CSV_NAME = "resultados_consolidados.csv"
REPORT_NAME = "analisis_resultados.md"
DONT_KNOW = -1
CORRECT_INDEX = 0  # en los datos, la opción correcta de cada pregunta es la 0
SAMPLE_WARNING = (
    "> **ATENCIÓN: estos son DATOS DE EJEMPLO (participantes simulados), "
    "no resultados reales de personas.**"
)


def load_records(folder, include_simulated):
    """Devuelve (registros, simulados_ignorados, archivos_ilegibles)."""
    records, ignored, unreadable = [], 0, []
    for path in sorted(Path(folder).glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            unreadable.append(path.name)
            continue
        if not isinstance(data, dict):
            unreadable.append(path.name)
            continue
        if data.get("simulated") and not include_simulated:
            ignored += 1
            continue
        records.append(data)
    return records, ignored, unreadable


def is_correct(answer):
    return answer is not None and answer != DONT_KNOW and answer == CORRECT_INDEX


def finish_type_of(record):
    """Los JSON antiguos no tienen finish_type: se tratan como «completo»."""
    return FINISH_EARLY if record.get("finish_type") == FINISH_EARLY else FINISH_COMPLETE


def has_both_trivias(record):
    return (record.get("pre") or {}).get("score") is not None and (
        record.get("post") or {}
    ).get("score") is not None


def normalized_gain(pre, post, total=TOTAL_QUESTIONS):
    """(final − inicial) / (total − inicial); 0 si ya se acertó todo al inicio."""
    return 0.0 if pre >= total else (post - pre) / (total - pre)


def mean_and_deviation(values):
    """Media y desviación típica muestral (n − 1); 0 con menos de dos datos."""
    if not values:
        return 0.0, 0.0
    deviation = statistics.stdev(values) if len(values) > 1 else 0.0
    return statistics.mean(values), deviation


def learning_stats(records):
    """Cifras de aprendizaje de los participantes con las dos trivias."""
    complete = [r for r in records if has_both_trivias(r)]
    pre = [r["pre"]["score"] for r in complete]
    post = [r["post"]["score"] for r in complete]
    gains = [b - a for a, b in zip(pre, post)]
    normalized = [normalized_gain(a, b) for a, b in zip(pre, post)]
    improved = sum(1 for g in gains if g > 0)
    return {
        "with_both": len(complete),
        "pre": mean_and_deviation(pre),
        "post": mean_and_deviation(post),
        "gain_mean": statistics.mean(gains) if gains else 0.0,
        "normalized_mean": statistics.mean(normalized) if normalized else 0.0,
        "improved_percent": 100.0 * improved / len(complete) if complete else 0.0,
    }


def finish_stats(records):
    """Cuántos terminaron la historia y cuántos antes de tiempo, y hasta dónde llegaron estos."""
    by_type = {kind: [r for r in records if finish_type_of(r) == kind] for kind in FINISH_TYPES}
    rounds = [r["max_round_reached"] for r in by_type[FINISH_EARLY] if isinstance(r.get("max_round_reached"), (int, float))]
    return {
        "counts": {kind: len(group) for kind, group in by_type.items()},
        "learning": {kind: learning_stats(group) for kind, group in by_type.items()},
        "early_round_mean": statistics.mean(rounds) if rounds else None,
        "early_round_n": len(rounds),
    }


def summarize(records):
    """Todas las cifras del informe, calculadas aquí y en un solo sitio."""
    complete = [r for r in records if has_both_trivias(r)]
    return {
        **learning_stats(records),
        "participants": len(records),
        "finish": finish_stats(records),
        "questions": question_rates(complete),
        "survey": survey_stats(records),
        "memories": memories_stats(records),
        "comments": [
            (r.get("participant_id", "?"), r["survey"]["comment"].strip())
            for r in records
            if (r.get("survey") or {}).get("comment", "").strip()
        ],
    }


def question_rates(complete):
    """% de acierto inicial y final por pregunta (solo con las dos trivias)."""
    ids = sorted({q for r in complete for q in r["pre"]["answers"]})
    rates = []
    for question_id in ids:
        pre_hits = sum(is_correct(r["pre"]["answers"].get(question_id)) for r in complete)
        post_hits = sum(is_correct(r["post"]["answers"].get(question_id)) for r in complete)
        rates.append((question_id, 100.0 * pre_hits / len(complete), 100.0 * post_hits / len(complete)))
    return rates


def memories_stats(records):
    """Recuerdos de objeto encontrados, cinemática saltada y relación con la ganancia."""
    found = [len(r["memories_found"]) for r in records if isinstance(r.get("memories_found"), list)]
    seen = [r["cinematic_skipped"] for r in records if isinstance(r.get("cinematic_skipped"), bool)]
    paired = [(len(r["memories_found"]), r["post"]["score"] - r["pre"]["score"])
              for r in records if isinstance(r.get("memories_found"), list) and has_both_trivias(r)]
    correlation = None
    if len(paired) >= MIN_CORRELATION_N:
        try:
            correlation = statistics.correlation([a for a, _ in paired], [b for _, b in paired])
        except statistics.StatisticsError:
            correlation = None  # una de las dos series es constante
    return {
        "n": len(found),
        "mean": statistics.mean(found) if found else 0.0,
        "skipped_percent": 100.0 * sum(seen) / len(seen) if seen else 0.0,
        "skipped_n": len(seen),
        "correlation": correlation,
        "correlation_n": len(paired),
    }


def survey_stats(records):
    answered = [r["survey"] for r in records if (r.get("survey") or {}).get("u1") is not None]
    stats = {}
    for item_id, _text in SURVEY_ITEMS:
        values = [s[item_id] for s in answered if s.get(item_id) is not None]
        distribution = {value: values.count(value) for value in SCALE}
        stats[item_id] = (len(values), statistics.mean(values) if values else 0.0, distribution)
    return stats


def write_csv(records, path):
    question_ids = sorted({q for r in records for q in (r.get("pre") or {}).get("answers", {})})
    header = (
        ["participant_id", "version", "completed", "attempts", "play_seconds", "pre_score", "post_score", "gain", "normalized_gain", "memories_found", "cinematic_skipped", "finish_type", "max_round_reached", "ended_early"]
        + ["pre_" + q for q in question_ids]
        + ["post_" + q for q in question_ids]
        + [item_id for item_id, _ in SURVEY_ITEMS]
        + ["comment"]
    )
    with open(path, "w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        for r in records:
            pre, post, survey = r.get("pre") or {}, r.get("post") or {}, r.get("survey") or {}
            row = [r.get("participant_id"), r.get("version"), r.get("completed"), r.get("attempts"),
                   r.get("play_seconds"), pre.get("score"), post.get("score"), r.get("gain"), r.get("normalized_gain"),
                   len(r.get("memories_found") or []), r.get("cinematic_skipped"),
                   finish_type_of(r), r.get("max_round_reached", ""), finish_type_of(r) == FINISH_EARLY]
            row += [pre.get("answers", {}).get(q, "") for q in question_ids]
            row += [post.get("answers", {}).get(q, "") for q in question_ids]
            row += [survey.get(item_id, "") for item_id, _ in SURVEY_ITEMS]
            row.append(survey.get("comment", ""))
            writer.writerow(row)


def format_report(summary, any_simulated, ignored, unreadable):
    lines = ["# Análisis de resultados — La Habitación 13", ""]
    if any_simulated:
        lines += [SAMPLE_WARNING, ""]
    lines += [
        f"- Participantes analizados: **{summary['participants']}** "
        f"(con trivia inicial y final: {summary['with_both']})",
        f"- Simulados ignorados: {ignored}",
    ]
    if unreadable:
        lines.append(f"- Archivos ilegibles (omitidos): {', '.join(unreadable)}")
    finish = summary["finish"]
    counts = finish["counts"]
    lines += [
        f"- Terminaron la historia (**{FINISH_COMPLETE}**): {counts[FINISH_COMPLETE]}",
        f"- Terminaron antes de tiempo (**{FINISH_EARLY}**): {counts[FINISH_EARLY]}",
    ]
    if finish["early_round_mean"] is not None:
        lines.append(f"- Ronda más lejana alcanzada por los anticipados (media): **{finish['early_round_mean']:.2f}** (n = {finish['early_round_n']}; 0 = referencia, 10 = última)")
    lines += ["", "## Trivia (sobre 8)", "", "Todos los participantes con las dos trivias:", "", "| Medida | Media | Desviación (n−1) |", "|---|---|---|"]
    lines.append("| Inicial | %.2f | %.2f |" % summary["pre"])
    lines.append("| Final | %.2f | %.2f |" % summary["post"])
    lines += [
        "",
        f"- Ganancia media (final − inicial): **{summary['gain_mean']:+.2f}**",
        f"- Ganancia normalizada media: **{summary['normalized_mean']:.3f}**",
        f"- Participantes que mejoraron: **{summary['improved_percent']:.1f} %**",
    ]
    lines += ["", "## Aprendizaje según cómo terminaron", "",
              "| Tipo | n con ambas trivias | Inicial (media) | Final (media) | Ganancia media | Ganancia normalizada | % que mejoró |",
              "|---|---|---|---|---|---|---|"]
    for kind in FINISH_TYPES:
        part = finish["learning"][kind]
        lines.append(f"| {kind} | {part['with_both']} | {part['pre'][0]:.2f} | {part['post'][0]:.2f} | {part['gain_mean']:+.2f} | {part['normalized_mean']:.3f} | {part['improved_percent']:.1f} % |")
    lines += ["", "Los anticipados jugaron menos y suelen ser una muestra distinta: compara los dos grupos con cautela.",
              "", "## Acierto por pregunta", "", "| Pregunta | Inicial | Final |", "|---|---|---|"]
    for question_id, pre_rate, post_rate in summary["questions"]:
        lines.append(f"| {question_id} | {pre_rate:.1f} % | {post_rate:.1f} % |")
    memories = summary["memories"]
    correlation = memories["correlation"]
    lines += [
        "",
        "## Recuerdos y cinemática",
        "",
        f"- Recuerdos de objeto encontrados (media, de {TOTAL_MEMORIES}): **{memories['mean']:.2f}** (n = {memories['n']})",
        f"- Participantes que saltaron la cinemática final: **{memories['skipped_percent']:.1f} %** (n = {memories['skipped_n']})",
        "- Correlación (Pearson) entre recuerdos encontrados y ganancia: "
        + (f"**{correlation:.3f}** (n = {memories['correlation_n']})" if correlation is not None
           else f"no calculable (n = {memories['correlation_n']}; hace falta n ≥ {MIN_CORRELATION_N} y que ninguna serie sea constante)"),
    ]
    lines += ["", "## Encuesta (1 = totalmente en desacuerdo, 5 = totalmente de acuerdo)", "",
              "| Ítem | n | Media | 1 | 2 | 3 | 4 | 5 |", "|---|---|---|---|---|---|---|---|"]
    for item_id, text in SURVEY_ITEMS:
        count, mean, distribution = summary["survey"][item_id]
        cells = " | ".join(str(distribution[v]) for v in SCALE)
        lines.append(f"| {item_id} · {text} | {count} | {mean:.2f} | {cells} |")
    lines += ["", "## Comentarios", ""]
    if summary["comments"]:
        lines += [f"- ({pid}) {comment}" for pid, comment in summary["comments"]]
    else:
        lines.append("_Sin comentarios._")
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("carpeta", help="carpeta con los JSON de los participantes")
    parser.add_argument("--include-simulated", action="store_true", help='incluye los marcados "simulated": true')
    parser.add_argument("--salida", help="carpeta de salida (por defecto, la misma)")
    args = parser.parse_args(argv)
    if not Path(args.carpeta).is_dir():
        print(f"No existe la carpeta: {args.carpeta}", file=sys.stderr)
        return 2
    records, ignored, unreadable = load_records(args.carpeta, args.include_simulated)
    output = Path(args.salida or args.carpeta)
    output.mkdir(parents=True, exist_ok=True)
    write_csv(records, output / CSV_NAME)
    any_simulated = any(r.get("simulated") for r in records)
    summary = summarize(records)
    (output / REPORT_NAME).write_text(format_report(summary, any_simulated, ignored, unreadable), encoding="utf-8")
    print(f"{summary['participants']} participantes analizados ({ignored} simulados ignorados). Salida en {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
