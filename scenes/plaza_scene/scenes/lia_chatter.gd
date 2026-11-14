class_name LiaChatter
extends RefCounted

# =========================
# What Lía says while she holds Alice's sleeve
# =========================
## Lía's speech bubbles while she walks along with Alice, in three phases
## that follow the search: EARLY (no clue yet), MIDDLE (one clue) and LATE
## (two clues: on the way to the fountain). Each entry is
## [Lía's line, Alice's short answer]. Alice says hers out loud in her own
## bubble a moment later; leave it "" and she just says nothing.
##
## Written in Spanish; every line also needs its row in
## translations/game_text.csv (Spanish text -> English). Texts from the
## approved "Escena Lia v2" (narrative/twee/escena_lia_v2.twee, Burbujas Lia).
## The change is in how Alice answers: short and awkward early, following
## the jokes in the middle, worried about Lía late.
const EARLY: Array = [
	["¿Por qué llevas auriculares si no escuchas nada?", "...Costumbre."],
	["¿Vives sola?", "Con mi gato."],
	["Tu pelo parece un nido. Me gusta.", "...Gracias. Creo."],
	["¿Por qué caminas mirando el suelo?", "Para no tropezar."],
	["¿Tú tienes mamá? ¿Dónde está?", ""],
	["¿Por qué caminas tan rápido?", "Perdón."],
]
const MIDDLE: Array = [
	["¡Mira! ¡Una paloma!", "Es la quinta que me enseñas."],
	["¿Crees que ese señor conocía a mi mamá?", "No lo sé. Pero la vio. Algo es algo."],
	["Mi mamá tiene un vestido rosa. ¿Ya te lo dije?", "Unas cuantas veces. Rosa. Lo tengo."],
	["¿Tu gato sabe hacer trucos?", "Sabe esconder zapatos."],
	["Si fueras un animal, ¿cuál serías?", "Un gato. Para dormir todo el día."],
	["Cuando sea grande voy a tener un perro enorme.", "¿Más grande que tú?"],
]
const LATE: Array = [
	["¿Falta mucho para la fuente?", "Ya casi. ¿Estás cansada?"],
	["¿Tienes miedo? Yo un poquito.", "Yo también. Un poquito."],
	["¿Y si mi mamá ya se fue a casa?", "No creo que se haya ido. Todavía nos queda buscarla."],
	["Tengo un poquito de hambre.", "Yo también. Luego buscamos algo, ¿vale?"],
	["Ya casi no tengo ganas de llorar.", "Si te vuelven las ganas, no pasa nada."],
	["¿Tú te habías perdido antes? Antes de hoy, digo.", "Sí. Aunque normalmente me las arreglo sola."],
]

## The phase for how many clues Alice has found.
static func for_clues(clue_count: int) -> Array:
	match clue_count:
		0:
			return EARLY
		1:
			return MIDDLE
		_:
			return LATE
