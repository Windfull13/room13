extends RefCounted

## Recuento de comprobaciones del runner de pruebas.
## Se carga por ruta (preload) para no depender del registro global de clases.

var passed := 0
var failed := 0
var failures: Array[String] = []


func start(suite_name: String) -> void:
	print("· ", suite_name)


## Cada comprobación se imprime, también las correctas: la salida del runner
## es la evidencia de lo que se ha verificado.
func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("    ok: ", description)
	else:
		failed += 1
		failures.append(description)
		print("    FALLO: ", description)