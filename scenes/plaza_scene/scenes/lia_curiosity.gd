class_name LiaCuriosity
extends RefCounted

# =========================
# What catches Lía's eye
# =========================
## Lines for the plaza's curiosity points (CuriosityPoints/<name> in
## plaza.tscn), keyed by the point's node name, in two versions: "early"
## (before the first clue) and "late" (from the first clue on). A point can
## split "late" by whether Alice already talked to a helper: "late_met" /
## "late_not_met" plus the helper's clue id in "helper".
## In each version: "lia" is one to three bubbles Lía says while she looks at
## it, "alice" Alice's answer out loud in her own bubble ("" = she says
## nothing) and, optionally, "lia_after" a last bubble of Lía's after it.
## Each line needs its row in translations/game_text.csv.
## Texts from the "Escena Lia v2" (narrative/twee/escena_lia_v2.twee).
const LINES := {
	"PetShopWindow": {
		"early": {"lia": ["¡Una tienda de animales! ¿Hay perritos?"], "alice": "No veo ninguno."},
		"late": {"lia": ["¿Tú tienes animales?", "Yo quiero un perro, pero mi mamá dice que la casa es pequeña."], "alice": "Yo tengo un gato. Cabe en cualquier sitio."},
	},
	"CoffeeBoard": {
		"early": {"lia": ["¿Qué pone ahí?", "Yo leo despacito."], "alice": "Pone «café»."},
		"late": {"lia": ["Ca... fé.", "¡Lo leí sola!"], "alice": "Muy bien. Más rápido que yo."},
	},
	"IceCreamVan": {
		"helper": "ice_cream",
		"early": {"lia": ["¡Un camión de helados!", "¡Es rosa!"], "alice": "...Sí. Muy rosa."},
		"late_met": {"lia": ["El señor dijo que luego me da un helado.", "De chocolate."], "alice": "Si te lo prometió, te lo dará."},
		"late_not_met": {"lia": ["Cuando encontremos a mi mamá, le pido un helado.", "Y otro para ti."], "alice": "...De fresa, entonces."},
	},
	"Guitarist": {
		"early": {"lia": ["Toca bonito.", "¿Por qué nadie le da dinero?"], "alice": "No lo sé."},
		"late": {"lia": ["¡Mi mamá canta esa!", "Bueno, canta otra. Pero parecida."], "alice": "Parecida también cuenta."},
	},
	"Picnic": {
		"early": {"lia": ["¡Un perrito!", "¿Lo puedo tocar?"], "alice": "Mejor no. No es nuestro."},
		"late": {"lia": ["Cuando encontremos a mi mamá, podemos hacer un picnic.", "Tú también vienes."], "alice": "...Ya veremos."},
	},
	"RedBike": {
		"early": {"lia": ["¡Una bici roja!", "Cuando sea mayor voy a tener una igual."], "alice": ""},
		"late": {"lia": ["¿Tú sabes ir en bici?"], "alice": "Sé caerme. Eso se me da muy bien."},
	},
	"GardenTables": {
		"early": {"lia": ["¿Esos dos son novios?"], "alice": "No lo sé. No mires tanto."},
		"late": {"lia": ["Si me siento en esa mesa, ¿parezco mayor?"], "alice": "Un poco. Como de ocho."},
	},
	# Not a CuriosityPoint: the start of the pigeon moment (plaza.gd), the
	# same way. "lia_after" is what Lía says running back to the sleeve when
	# Alice walks on instead of staying. One version for both phases.
	"Pigeons": {
		"early": {"lia": ["¡Palomas!", "¡Mira! ¡Esa es más gorda!", "Ven a verla. ¡Ven!"], "alice": "Lía...", "lia_after": "¡Espérame! ¡Adiós, paloma gorda!"},
		"late": {"lia": ["¡Palomas!", "¡Mira! ¡Esa es más gorda!", "Ven a verla. ¡Ven!"], "alice": "Lía...", "lia_after": "¡Espérame! ¡Adiós, paloma gorda!"},
	},
	"AdColumn": {
		"early": {"lia": ["¿Por qué esa columna tiene papeles pegados?"], "alice": "Son anuncios."},
		"late": {"lia": ["Cuando sea mayor voy a poner un anuncio. «Se busca mamá».", "...No, mejor no."], "alice": "Mejor no. Seguimos buscando."},
	},
}

## The version for this point given how far the search is.
static func for_point(point_name: String) -> Dictionary:
	var point: Dictionary = LINES.get(point_name, {})
	var key := "early"
	if not GameManager.lia_clues.is_empty():
		key = "late"
		if point.has("helper"):
			key = "late_met" if GameManager.lia_has_met(point["helper"]) else "late_not_met"
	var version: Dictionary = point.get(key, {})
	return {
		"lia": version.get("lia", []),
		"alice": version.get("alice", ""),
		"lia_after": version.get("lia_after", ""),
	}
