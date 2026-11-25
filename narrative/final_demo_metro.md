# Nuevo final de la demo: el último tren (propuesta)

> Estado: **PROPUESTA**, pendiente de aprobación del usuario. No se ha tocado ningún archivo del juego.
> Español neutro (doblaje). Coherente con `twee/escena_clara_v2.twee`: Alice llega a la plaza de noche, oye a Clara terminar una canción y después se sienta en la banca y se pone los auriculares.
> El tren **siempre** se pierde y no es culpa del jugador: ninguna línea da a entender que Alice «falló», solo que llegó tarde por un segundo.

Cada array corresponde a un hueco de la cutscene de Código 2. Son líneas de nube (`ThoughtBox.say`, claves en `game_text.csv`), salvo `ENDING_LINES`, que es el interludio. Debajo de cada array va una alternativa por si el usuario prefiere otro tono.

---

## TRAIN_ARRIVING_LINES
Entra el tren; Alice está lejos y todavía tiene el control.
```gdscript
const TRAIN_ARRIVING_LINES: Array[String] = [
	"¡El tren!",
	"Si corro, llego.",
]
```
Alternativa: `"¿Ese es el tren?"`, `"¡Espera, espera!"`

## DOORS_CLOSING_LINES
Las puertas se cierran delante de ella.
```gdscript
const DOORS_CLOSING_LINES: Array[String] = [
	"No, no, no...",
]
```
Alternativa: `"¡No!"`

## TRAIN_GONE_LINES (v2: indica hacia dónde ir)
El tren se va y el andén se queda vacío. Después vienen 2,5 s de silencio.
Problema que vio el usuario al jugar: después de perder el tren, el jugador no sabía que tenía que volver arriba. Estas líneas lo sugieren desde la voz de Alice, sin sonar a tutorial: «subir a la calle» es lo que ella quiere hacer, no una orden al jugador. La referencia al prólogo se quita porque alargaba demasiado la nube.

### ✅ APROBADA por el usuario (mezcla de A y B)
```gdscript
const TRAIN_GONE_LINES: Array[String] = [
	"Por un segundo.",
	"¿Y ahora qué, Alice?",
	"Tendré que subir a la calle y buscar otra forma de llegar a casa.",
	"Y ya debe estar anocheciendo...",
]
```
`en`:
- "Missed it by a second." (clave existente)
- "Now what, Alice?"
- "I'll have to go back up to the street and find another way home."
- "And it must be getting dark by now..."

Comentario del usuario: la B «suena más a su Alice», la A le resultaba algo genérica.

---
Opciones originales (histórico):

**Opción A**, conserva «Por un segundo.»:
```gdscript
const TRAIN_GONE_LINES: Array[String] = [
	"Por un segundo.",
	"Tendré que subir a la calle y buscar otra forma de llegar a casa.",
	"Y ya debe estar anocheciendo...",
]
```
`en`:
- "Missed it by a second."
- "I'll have to go back up to the street and find another way home."
- "And it must be getting dark by now..."

**Opción B**, más cerca del borrador del usuario:
```gdscript
const TRAIN_GONE_LINES: Array[String] = [
	"¿Y ahora qué, Alice?",
	"Tendré que volver a la calle y buscar otra forma de llegar.",
	"Y allá arriba ya empieza a hacer frío...",
]
```
`en`:
- "Now what, Alice?"
- "I'll have to go back out to the street and find another way."
- "And it's already getting cold up there..."

Notas:
- «debe estar anocheciendo» y «allá arriba» están pensados para el andén: desde abajo Alice no ve el cielo, así que lo supone. Además, «arriba» refuerza la dirección. El anochecer se confirma en el interludio («Afuera, ya es de noche.»).
- «Por un segundo.» ya tiene clave en `game_text.csv`; en la opción A el `en` actual puede quedarse. Las demás líneas son claves nuevas.
- Nota para Código 2: si el jugador se queda en el andén, HEARS_CLARA sigue saliendo al acercarse a la escalera, como ahora. Así la voz confirma la dirección que sugirió el pensamiento.

## HEARS_CLARA_LINES
Oye la voz de Clara desde arriba y se gira hacia la escalera.
```gdscript
const HEARS_CLARA_LINES: Array[String] = [
	"¿Alguien está cantando?",
	"Viene de arriba.",
]
```
Alternativa: `"...¿Una canción?"`
Nota para Código 2: conviene que la voz suene sola un momento antes de que salga la nube.

## ENDING_LINES (sustituye a NIGHT_LINES)
Interludio al subir. Las líneas entre «» son pensamientos de Alice.
```gdscript
const ENDING_LINES: PackedStringArray = [
	"Alice sube las escaleras de la estación. Afuera, ya es de noche.",
	"La plaza se ve diferente sin la luz del sol. O tal vez es ella, que la mira con otros ojos.",
	"Tiene el número de Leo y el dibujo de Lía en el bolsillo.",
	"Tiene hambre. Tiene frío. No sabe dónde va a dormir.",
	"«Pero ayudé a alguien. Eso hice.»",
	"Y algo en su pecho no es miedo. No del todo.",
	"La voz sigue ahí, en algún lugar de la plaza. Alice la sigue.",
	"No llora. Canta.",
]
```
- «Ayudé a alguien. Eso hice.» viene de `plaza_missed_train.dtl` (#id:31d). Aquí funciona como el pensamiento que da la vuelta al «tiene hambre, tiene frío».
- Ya tienen traducción en `game_text.csv` «Tiene el número de Leo…», «Tiene hambre…» y «No llora. Canta.». Son claves nuevas la 1, la 2, la 5, la 6 (antes empezaba con «Pero») y la 7.
- Alternativa para el cierre, si «No llora» resulta ambiguo: `"Al otro lado de la plaza, alguien no llora. Canta."`

`en` sugerido para las claves nuevas:
- "Alice climbs the station stairs. Outside, night has fallen."
- "The plaza looks different without the sunlight. Or maybe it's her, seeing it with new eyes."
- "«But I helped someone. That's what I did.»"
- "And something in her chest isn't fear. Not entirely."
- "The voice is still there, somewhere in the plaza. Alice follows it."

---

## ¿Qué pasa con `plaza_missed_train.dtl`?

Recomiendo que **quede sin uso**. Se puede borrar el timeline y retirar sus ids 318–31f del CSV.

| id | Línea | Qué pasa con ella |
|---|---|---|
| 318, 319 | Reja bajada, entrada cerrada | ❌ Ya no hay reja. |
| 31a | (No tengo dinero. No tengo teléfono…) | ❌ Repite el tono de TRAIN_GONE. |
| 31b | (Y ahora, ni siquiera tengo el metro.) | ❌ La cubre TRAIN_GONE. |
| 31c | (aprieta el dibujo de Lía contra el pecho) | ❌ Es un gesto; solo serviría con animación. |
| 31d | Ayudé a alguien. Eso hice. | ✅ Pasa a ENDING_LINES como «». |
| 31f | (se pone los auriculares) + `headphones_on` | ❌ **Quitar**: con auriculares no oiría la voz, y en Clara v2 se los pone en la banca. |

Nota para Código 2: el anochecer (`SKY_NIGHT`) ya no debería dispararse en el andén; lo cuenta el interludio al salir.

---

## HURRY_LINES — ✅ APROBADA por el usuario
Se quitó la 2 («Si me apresuro, todavía lo alcanzo.») porque se parecía demasiado a la 4. Quedan 5 líneas y no se repite ninguna cuando se acaban.
```gdscript
const HURRY_LINES: Array[String] = [
	"El tren... ¡rápido!",
	"Deja de perder el tiempo, Alice.",
	"Voy a perder el tren si no me apresuro.",
	"Las puertas siguen abiertas. Muévete, Alice.",
	"¿Qué estás haciendo, Alice? ¡El tren!",
]
```
`en`: "The train... quick!" · "Stop wasting time, Alice." · "I'm going to miss the train if I don't hurry." · "The doors are still open. Move, Alice." · "What are you doing, Alice? The train!"

---
Propuesta original (histórico):
Salen si el jugador se entretiene o vuelve atrás **antes** de que se cierren las puertas, mientras el tren espera con ellas abiertas. Cada una es una nube de una línea, y la urgencia va subiendo de la primera a la última. En la voz de Alice: se habla a sí misma y suena ansiosa, nunca como un tutorial.
```gdscript
const HURRY_LINES: Array[String] = [
	"El tren... ¡rápido!",
	"Si me apresuro, todavía lo alcanzo.",
	"Deja de perder el tiempo, Alice.",
	"Voy a perder el tren si no me apresuro.",
	"Las puertas siguen abiertas. Muévete, Alice.",
	"¿Qué estás haciendo, Alice? ¡El tren!",
]
```
`en`:
- "The train... quick!"
- "If I hurry, I can still make it."
- "Stop wasting time, Alice."
- "I'm going to miss the train if I don't hurry."
- "The doors are still open. Move, Alice."
- "What are you doing, Alice? The train!"

Notas para Código 2:
- Mostrarlas **en orden**, no al azar, para que la urgencia suba. Al llegar a la última, repetir solo las dos últimas (o dejar de mostrar), no volver a empezar con «El tren... ¡rápido!».
- Se usa «apresurarse» en vez de «apurarse» porque es más neutro para doblaje.
- Ninguna dice «último tren»: ese cartel era del final viejo (la reja) y ya no está en el guion.
- «Todavía lo alcanzo» es lo que Alice cree. Que el tren se pierda siempre es lo que da sentido a TRAIN_GONE («Por un segundo.»).
