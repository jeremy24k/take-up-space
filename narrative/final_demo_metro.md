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

## TRAIN_GONE_LINES
El tren se va y el andén se queda vacío. Después vienen 2,5 s de silencio.
```gdscript
const TRAIN_GONE_LINES: Array[String] = [
	"Por un segundo.",
	"La última vez que tomé el metro, me quedé dormida. Esta vez ni siquiera alcancé a subir.",
]
```
Alternativa más corta: `"Se fue."`, `"Qué silencio."`
La segunda línea recuerda el prólogo (se durmió en el tren). Si queda larga en la nube, se puede partir en dos: `"La última vez que tomé el metro, me quedé dormida."` / `"Esta vez ni siquiera alcancé a subir."`

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
