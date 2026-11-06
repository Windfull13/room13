# Guion de voces — La Habitación 13

Las voces son **opcionales**. Si un archivo no existe, el juego muestra el texto igual y no da ningún error. No se usa voz sintética.

## Cómo añadirlas

1. Graba cada línea en mono, a 44,1 kHz o 48 kHz, en un lugar silencioso (sin música ni efectos).
2. Exporta a **OGG Vorbis** (también vale WAV) con el nombre exacto de la tabla.
3. Copia el archivo a `assets/audio/voices/` y abre el proyecto en Godot para que lo importe.
4. Mientras suena una voz, la música baja 8 dB y vuelve a su volumen al terminar (o al saltar).

Deja unos 0,3 s de silencio al principio y al final. Mantén el pico por debajo de −3 dBFS.

## Líneas

| Archivo esperado | Quién | Texto exacto | Tono | Duración aprox. | Dónde suena |
|---|---|---|---|---|---|
| `voice_phone_msg.ogg` | Voz de mujer adulta («ella»), mensaje de contestador | «Aquí llueve mucho. Vamos despacio, ¿sí? Guárdanos algo de cena. Te queremos.» | Cálido y cotidiano, algo apresurado, como quien llama desde el coche con lluvia de fondo. Sin dramatismo: no sabe lo que va a pasar. | 6–7 s | Recuerdo del teléfono (anomalía «El teléfono suena»), al abrir el panel de recuerdo |
| `voice_cinematic_wife.ogg` | Voz de mujer adulta («ella») | «Cuídate, ¿sí?» | Suave, cercana, casi susurrada; una sonrisa en la voz. | 1,5–2 s | Cinemática «La última puerta», cuando aparecen las dos siluetas |
| `voice_cinematic_girl.ogg` | Voz de niña («la niña», unos 7–9 años) | «Hasta mañana.» | Tranquila y cariñosa, como una despedida antes de dormir. | 1–1,5 s | Cinemática «La última puerta», justo después de la voz anterior |

## Comprobación

Con los archivos en su sitio, `AudioManager.play_voice(id)` devuelve `true`. La prueba `tests/test_memories_objects.gd` comprueba con un archivo temporal que la música baja y se restaura. Sin archivos, comprueba que no hay errores.
