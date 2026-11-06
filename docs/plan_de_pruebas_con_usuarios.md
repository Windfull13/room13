# Plan de pruebas con usuarios — La Habitación 13

## Objetivo

Medir tres cosas:
- **Aprendizaje:** trivia inicial frente a final y ganancia normalizada.
- **Experiencia de uso:** encuesta u1–u4.
- **Reflexión y recomendación:** l1, l2 y r1.

También se registra la exploración (recuerdos de objeto encontrados) y si se salta la cinemática final.

## Participantes

- **Cuántos:** al menos **12**, idealmente 15–20. Con n ≥ 3 el análisis ya calcula la correlación entre recuerdos y ganancia, pero con menos de ~12 las cifras sirven solo como orientación.
- **Quiénes:** estudiantes o adultos que acepten temas de duelo, acoso y salud mental. No se recluta a personas en duelo reciente ni en situación de crisis. Los menores de edad solo participan con autorización de su tutor y del centro.
- **Exclusión:** cualquiera que lo pida en cualquier momento, sin dar explicaciones.

## Antes de la sesión

1. Exporta o abre el juego en cada equipo (ver `README.md`) y comprueba que arranca.
2. Borra o mueve los JSON de pruebas anteriores de la carpeta de resultados (**OPCIONES → ABRIR CARPETA DE RESULTADOS**).
3. Rellena `help_lines` en `resources/learning/learning_content.tres` con los teléfonos de ayuda de vuestro país o centro, para que aparezcan al final.
4. Prepara auriculares, una sala tranquila y unos 25–35 minutos por persona.

## Instrucciones para el participante (leer en voz alta)

> «Vas a jugar a un videojuego sobre acoso, duelo y salud mental. Tiene momentos de tensión y algún susto. No es una prueba sobre ti: evaluamos el juego. Antes y después responderás unas preguntas; si no sabes una, elige "No lo sé". Puedes parar cuando quieras con Esc. Al principio el juego te pedirá permiso para guardar tus respuestas de forma anónima; puedes decir que no y jugar igual.»

No ayudes durante la partida salvo con problemas técnicos. Si alguien se bloquea más de 5 minutos, puedes recordarle que el texto de «Cómo jugar» está en la pausa.

## Modo feria: a quién se le ofrece TERMINAR Y EVALUAR

Cada fallo reinicia la partida, así que muchos visitantes no llegarán a la ronda 10 y sin ayuda no responderían la trivia final. Con `FAIR_MODE = true` (`scripts/settings/fair_mode.gd`), la **pausa de la partida** (Esc) ofrece el botón **TERMINAR Y EVALUAR** solo a quien:

1. ya hizo la trivia inicial (eligió **PARTICIPAR Y GUARDAR** o **JUGAR SIN GUARDAR**), y
2. lleva al menos **240 s** de juego (`FAIR_MIN_PLAY_SECONDS`; no cuentan las pantallas de texto ni la pausa).

El botón pide confirmación y lleva a la trivia final, los resultados, la encuesta y la ayuda, sin cinemática ni epílogo. Si alguien sale con MENÚ PRINCIPAL antes de contestar la trivia final, se le avisa de que no responderá la trivia final y su sesión se cerrará. Quien juega sin guardar puede terminar igual, pero no se escribe ningún archivo.

Para el equipo en la feria:
- No ofrezcáis el botón de palabra antes de los 240 s: aparece solo. Si alguien quiere dejarlo antes, explicadle que puede seguir jugando hasta que aparezca.
- Tras la pantalla de agradecimiento, si nadie toca nada durante 30 s (`FAIR_IDLE_RETURN_SECONDS`) el equipo vuelve al menú y abre una sesión nueva: queda listo para la siguiente persona.
- Para una sesión de laboratorio normal, poned `FAIR_MODE = false`: todo se comporta como antes.

## Consentimiento

- La pantalla «Antes de entrar» explica el propósito y pide consentimiento con **PARTICIPAR Y GUARDAR** o **JUGAR SIN GUARDAR**. Sin consentimiento no se escribe nada.
- Si vuestra institución lo exige, añadid un consentimiento informado en papel antes de empezar.
- Los datos no contienen nombres. El identificador es aleatorio, de 8 caracteres hexadecimales, y no permite saber quién jugó.

## Después de la sesión

1. Pregunta cómo se siente la persona y recuérdale la pantalla de ayuda.
2. Opcional: 2–3 minutos de comentarios en voz alta. Anótalos sin datos personales.

## Recopilar los resultados

En cada equipo, los JSON están en:

`C:\Users\<usuario>\AppData\Roaming\Godot\app_userdata\Room 13\resultados\<id>.json`

Copia todos los `.json` de todos los equipos a **una sola carpeta**, por ejemplo `resultados_estudio/`. Los nombres no chocan porque cada identificador es distinto.

## Analizar

```
python dev/analyze_results.py resultados_estudio
```

Se generan `resultados_estudio/resultados_consolidados.csv` y `resultados_estudio/analisis_resultados.md`. Los datos simulados (`"simulated": true`) se ignoran salvo con `--include-simulated`. Para practicar con datos de ejemplo:

```
python dev/analyze_results.py dev/out/ejemplo_resultados --include-simulated
```

## Qué cifras reportar

| Indicador | Dónde | Cómo leerlo |
|---|---|---|
| n de participantes (y con ambas trivias) | encabezado del informe | Base de todo lo demás |
| Trivia inicial y final: media ± desviación | «Trivia (sobre 8)» | Nivel antes y después |
| Ganancia media y ganancia normalizada media | ídem | Normalizada: 0,3–0,7 ≈ ganancia media; > 0,7 alta |
| % de participantes que mejoraron | ídem | Alcance del aprendizaje |
| Acierto por pregunta, inicial → final | «Acierto por pregunta» | Qué temas funcionan y cuáles no |
| Media y distribución de u1–u4 | «Encuesta» | Usabilidad (≥ 4 deseable) |
| Media de l1, l2 y r1 | ídem | Aprendizaje percibido, reflexión y recomendación |
| Recuerdos encontrados (media de 20) y % que saltó la cinemática | «Recuerdos y cinemática» | Exploración e implicación |
| Correlación recuerdos–ganancia | ídem | Solo orientativa: correlación no es causalidad |
| Comentarios | «Comentarios» | Citas textuales, sin datos personales |

### Cómo interpretar los datos con finalizaciones anticipadas

Cada JSON lleva `finish_type`: **completo** (terminó la historia, 10 rondas seguidas) o **anticipado** (usó TERMINAR Y EVALUAR), y `max_round_reached` (0 = referencia, 10 = última). El informe da las cifras de aprendizaje **globales** y **por tipo**, el número de cada grupo y la ronda media que alcanzaron los anticipados.

- Los dos grupos no son comparables sin más: los anticipados no eligieron al azar, son quienes no consiguieron terminar. Reportad siempre las dos cifras (global y por tipo) con su n.
- Los anticipados vieron menos contenido (menos tarjetas y recuerdos, ni cinemática ni epílogo): una ganancia menor no indica que el juego sea peor, y una igual o mayor tampoco prueba que baste con jugar menos.
- Con n pequeño en un grupo, tratad las medias como orientativas y no hagáis comparaciones estadísticas.
- Los JSON de versiones anteriores, sin `finish_type`, se cuentan como completos.

Indicad siempre que es un estudio piloto sin grupo de control. Sin ese grupo, la mejora no se puede atribuir solo al juego: también influye repetir las mismas preguntas.
