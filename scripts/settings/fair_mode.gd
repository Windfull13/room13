class_name FairMode
extends RefCounted

## Modo feria. Con FAIR_MODE = false el juego se comporta como antes: no hay
## botón TERMINAR Y EVALUAR, la pausa no pide confirmaciones y no hay regreso
## automático al menú. Es solo una opción de la pausa: no es un cronómetro del
## juego y no afecta a la partida.

const FAIR_MODE := true
## Segundos de juego (de Session) a partir de los cuales se ofrece terminar.
const FAIR_MIN_PLAY_SECONDS := 240
## Sin actividad en la pantalla de agradecimiento, vuelve al menú pasado este tiempo.
const FAIR_IDLE_RETURN_SECONDS := 30

## Las pruebas lo cambian para comprobar el juego con el modo apagado.
static var enabled: bool = FAIR_MODE


## ¿Se ofrece TERMINAR Y EVALUAR en la pausa de la partida?
static func can_offer_finish(has_initial_trivia: bool, play_seconds: float) -> bool:
	return enabled and has_initial_trivia and play_seconds >= FAIR_MIN_PLAY_SECONDS


## ¿Salir al menú desde la pausa pide confirmación? Solo si aún falta la trivia final.
static func menu_needs_confirmation(has_initial_trivia: bool, has_final_trivia: bool) -> bool:
	return enabled and has_initial_trivia and not has_final_trivia
