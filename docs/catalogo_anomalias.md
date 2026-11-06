# Catálogo de anomalías

Generado por `dev/export_catalog.gd` a partir de `resources/anomalies/*.tres`. No editar a mano.

36 anomalías, ordenadas por dificultad.

| id | nombre | objeto | tema | dificultad | peligrosa | pista | significado | efecto o sonido |
|---|---|---|---|---|---|---|---|---|
| `alfombra_movida` | La alfombra está girada | alfombra | PERCEPCION | EASY | no | la alfombra aparece girada | Algo se ha movido en el fondo de tu casa. | — |
| `espejo_girado` | El espejo del revés | espejo | IDENTIDAD | EASY | no | el espejo está dado la vuelta | Una imagen de ti que no te corresponde. | — |
| `foto_invertida` | La fotografía boca abajo | foto | DUELO | EASY | no | la foto familiar mira a la pared | Apartar la vista de lo que duele mirar. | — |
| `lampara_apagada` | La lámpara está apagada | lampara | AGOTAMIENTO | EASY | no | la lámpara está apagada | Una luz puesta donde nadie va a usarla. | — |
| `oscuridad_total` | La habitación a oscuras | luz | AISLAMIENTO | EASY | sí | la luz se apaga y solo se distinguen contornos | Un fragmento de la pérdida: luz, lluvia, carretera. | trafico_lejano (sound_only, sonido ambient_traffic) · susto jumpscare_oscuridad_total |
| `peluche_girado` | El peluche mira a la pared | peluche | INFANCIA | EASY | no | el peluche mira a la pared | Apartar de tu vista lo que te consolaba. | — |
| `reloj_torcido` | El reloj está torcido | reloj | AGOTAMIENTO | EASY | no | el reloj cuelga inclinado | Lo que ya no se sostiene recto. | — |
| `silla_ausente` | La silla ha desaparecido | silla | AISLAMIENTO | EASY | no | falta la silla junto a la mesa | El vacío que deja lo cotidiano cuando falta. | — |
| `silla_girada` | La silla girada | silla | PERCEPCION | EASY | no | la silla apunta hacia la habitación | Alguien estuvo sentado aquí, mirándote. | — |
| `telefono_sonando` | El teléfono suena | telefono | RELACIONES | EASY | no | suena el teléfono, vibra y parpadea una lucecita roja | Alguien aún quiere hablar contigo. | telefono_suena (tremble en Phone, sonido anomaly_phone_ring, cada 6.0 s) |
| `aranna_en_el_suelo` | Una araña en el suelo | arana | MIEDO | MEDIUM | no | una araña cruza el suelo | Lo pequeño que también habita esta casa. | — |
| `caja_de_musica` | Una caja de música | escritorio | FAMILIA | MEDIUM | no | melodía tenue y una cajita sobre el escritorio | Una melodía de cuando la casa estaba llena. | caja_musica (sound_only, sonido anomaly_music_box, cada 10.0 s) |
| `carta_abierta` | Una carta abierta | carta | CULPA | MEDIUM | no | carta abierta en el suelo | Lo que dejaste a medias. | — |
| `comida_sin_tocar` | La comida sin tocar | escritorio | AUTOCUIDADO | MEDIUM | no | vaso de agua y plato intactos sobre el escritorio | Cuidarte también se puede olvidar. | — |
| `cuervo_en_el_marco` | Un cuervo en la ventana | ventana | DUELO | MEDIUM | sí | cuervo en el alféizar y luz más gris | El presagio que se ignora hasta que es tarde. | cielo_oscuro (pulse en Window/Sprite) · susto jumpscare_cuervo_en_el_marco |
| `dibujo_en_la_pared` | Un dibujo en la pared | dibujo | INFANCIA | MEDIUM | no | dibujo infantil en la pared | La soledad explicada con pocos trazos. | — |
| `espejo_cubierto` | El espejo cubierto | espejo | AUTOESTIMA | MEDIUM | no | un papel tapa parte del espejo | Cuando mirarte duele, tapas el espejo. | — |
| `figura_armario` | Algo en el armario | armario | INFANCIA | MEDIUM | sí | rendija con ojos en el armario | Lo que guardas y no quieres volver a mirar. | armario_vibra (tremble en Wardrobe) · susto jumpscare_figura_armario |
| `figura_cama` | Algo bajo la cama | cama | INFANCIA | MEDIUM | sí | mano pálida bajo la cama | El miedo de la infancia que nunca se fue. | cama_cruje (tremble en Bed) · susto jumpscare_figura_cama |
| `figura_ventana` | Alguien al otro lado del cristal | ventana | AISLAMIENTO | MEDIUM | sí | rostro pálido en el cristal | Sentirte observado y no poder cerrar ciertos recuerdos. | ventana_fria (pulse en Window/Sprite) · susto jumpscare_figura_ventana |
| `golpes_en_la_puerta` | Golpes en la puerta | puerta | ACOSO | MEDIUM | no | tres golpes suaves, la puerta vibra y parpadea una línea de luz bajo ella | Los recuerdos que siguen llamando a la puerta. | puerta_golpes (tremble en Door, sonido anomaly_knocks, cada 9.0 s) |
| `llaves_en_el_suelo` | Unas llaves en el suelo | llaves | AISLAMIENTO | MEDIUM | no | llaves junto a la puerta | Una salida que estuvo en tu mano. | — |
| `luz_en_la_ventana` | Una luz cálida en la ventana | ventana | ESPERANZA | MEDIUM | no | luz cálida en la ventana | Un recuerdo amable que aún está a tiempo. | — |
| `marca_en_la_puerta` | Una marca en la puerta | puerta | DUELO | MEDIUM | no | huella oscura y puerta torcida | La última vez que alguien salió de aquí. | — |
| `muneca_en_el_suelo` | Una muñeca en el suelo | muneca | ACEPTACION | MEDIUM | no | muñeca de trapo en el suelo | Un objeto que guarda más ternura que dolor. | — |
| `notas_bajo_la_puerta` | Papeles bajo la puerta | puerta | ACOSO | MEDIUM | no | tres papeles arrugados junto a la puerta | Palabras ajenas que aprendiste a creer. | — |
| `planta_invertida` | La planta está al revés | planta | AUTOCUIDADO | MEDIUM | no | la planta crece hacia abajo | Una vida que se abandonó a sí misma. | — |
| `telefono_descolgado` | El teléfono descolgado | telefono | AISLAMIENTO | MEDIUM | no | teléfono descolgado y tono de línea muerta tenue | Las llamadas que no hiciste a tiempo. | linea_muerta (sound_only, sonido anomaly_dead_line, cada 5.0 s) |
| `figura_en_el_espejo` | El reflejo que no eres tú | espejo | IDENTIDAD | HARD | sí | reflejo que no te imita | Lo que ves de ti cuando el duelo y la culpa te deforman. | espejo_parpadea (flicker en Mirror) · susto jumpscare_espejo |
| `foto_cambiada` | La fotografía ha cambiado | foto | RECUERDOS | HARD | no | los rostros del retrato sonríen distinto | El recuerdo que la memoria deforma sin permiso. | — |
| `planta_con_flor` | Una flor en la planta | planta | ESPERANZA | HARD | no | una flor diminuta en la planta | Algo sigue floreciendo, aunque no lo cuides. | — |
| `reloj_detenido` | El reloj se ha detenido | reloj | DUELO | HARD | no | agujas detenidas en una hora imposible | El tiempo que se paró aquel día. | — |
| `retrato_ajeno` | Un rostro desconocido | retrato | RELACIONES | HARD | no | un rostro desconocido en el retrato | Lo que has olvidado de quienes te rodean. | — |
| `testigo_cuarto` | El Testigo | testigo | CULPA | HARD | sí | presencia alta y quieta tras el escritorio | La mirada que juzga; la voz interior que repasa cada decisión. | lampara_parpadea (flicker en Lamp) · susto jumpscare_testigo_cuarto |
| `testigo_esquina` | El Vigilante de la esquina | testigo | CULPA | HARD | sí | El Vigilante, de espaldas junto a la cama | Los que miran sin intervenir, como cuando eras niño. | habitacion_se_apaga (dim) · susto jumpscare_testigo_esquina |
| `tres_senales` | Tres señales | varios | MIEDO | HARD | sí | figura, ventana y huella a la vez | El acoso; sentir que te siguen, te marcan y no te dejan en paz. | telefono_vibra (tremble en Phone) · susto jumpscare_tres_senales |
