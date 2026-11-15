# Revisión de español neutro (doblaje)

Fecha: 2026-11-15. Sesión de Escritura.

**Objetivo:** que el juego suene en un español neutro de doblaje, sin marcas fuertes de España ni de un solo país de Latinoamérica, y sin perder la voz de cada personaje: Lía sigue siendo una niña y Alice sigue siendo Alice.

**Alcance.** Revisé todo el texto que ve el jugador:
- todas las timelines (`dialogic/timeline/**`);
- la columna `es` de `translations/game_text.csv`;
- las constantes de texto de los `.gd`;
- las frases de los puzzles de ansiedad (`*.tres`);
- los textos de las escenas (Labels, `lines`, `thought_lines`, `prompt_text`).

**Nada está cambiado todavía.** Esto es solo una propuesta. Cuando la apruebes, la sesión Código la aplica.

**Cómo leerlo:** cada línea aparece como **original → propuesta**, con su `#id` o, si no tiene, el archivo donde está. Las que llevan *(opcional)* son matices: suenan algo regionales, pero se entienden en todas partes. Las decisiones generales están al final.

**Para Código:**
- Las líneas de las timelines conservan su `#id`; solo hay que rehacer el inglés si cambia el sentido, y casi nunca cambia.
- `game_text.csv` usa el texto en español como clave. Si cambia una frase de ahí, hay que cambiar a la vez la clave del CSV y la constante del `.gd` o el texto de la escena donde aparece.

---

## 1. Apartamento (`dialogic/timeline/apartment/`)

| Archivo | Id | Original | Propuesta | Nota |
|---|---|---|---|---|
| bathroom_glass.dtl | #id:51 | (respira hondo) **Vale.** Un par de frases. Como si fuera de verdad. | (respira hondo) **Bueno.** Un par de frases. Como si fuera de verdad. | "Vale" como "de acuerdo" es de España. |
| bathroom_glass.dtl | #id:66 | (suspira) Bueno. Con eso **alcanza**. | (suspira) Bueno. Con eso **basta**. | "Alcanzar" con el sentido de "bastar" es latinoamericano. |
| bathroom_glass.dtl | #id:67 | **Allá afuera** no va a ser igual. Pero algo es algo. | **Ahí afuera** no va a ser igual. Pero algo es algo. | *(opcional)* |
| bathtub.dtl | #id:70 | (ve el patito de **hule** flotando) Y tú... sigues aquí también. | (ve el patito de **goma** flotando) Y tú... sigues aquí también. | "Hule" es de México. |
| kitchen.dtl | #id:7d | (mirando **la nevera vacía**) Ni siquiera huevos... | (mirando **el refrigerador vacío**) Ni siquiera huevos... | Coherencia: #id:86 ya dice "Mi refrigerador". |
| room_desk.dtl | #id:99 | ...No hay **servicio de delivery**... | ...No hay **servicio a domicilio**... | "Delivery" es un anglicismo regional. |
| room_desk.dtl | #id:a4 | **Aún no encuentro el delivery...** | **Sigo sin encontrar servicio a domicilio...** | Ídem. |
| room_desk.dtl | #id:a8 | (mira la luz del sol...) **Qué linda mañana hace hoy.** | (mira la luz del sol...) **Qué mañana tan bonita hace hoy.** | Ver la decisión sobre "lindo" (§7). |

## 2. Tienda de Leo (`dialogic/timeline/leo_store/` y `leo_store.tscn`)

| Archivo | Id / clave | Original | Propuesta | Nota |
|---|---|---|---|---|
| leo_store_checkout.dtl | #id:fc | ...Desde ahí **seguro te ubicas**. | ...Desde ahí **seguro que te orientas**. | "Ubicarse" por "orientarse" es latinoamericano. |
| leo_store_checkout.dtl | #id:ff | Eh... es un edificio gris. Con un balcón **chiquito**... | Eh... es un edificio gris. Con un balcón **pequeño**... | *(opcional)* "Chiquito" le da ternura a Alice, pero es diminutivo regional. |
| leo_store_greeting.dtl | #id:13a | ...y se desvía hacia **las góndolas** | ...y se desvía hacia **los estantes** | "Góndola" (estantería de súper) es del Cono Sur. |
| leo_store_shelf_cleaning.dtl | #id:13d | (se esconde detrás de **la góndola**) Detergente, esponjas... | (se esconde detrás **del estante**) Detergente, esponjas... | Ídem. |
| leo_store.tscn + game_text.csv | `...es muy lindo.` | ...es muy lindo. | Sin cambio (ver §7). | Decisión tuya: ¿"lindo" o "guapo"? |

## 3. Metro y terminal (`dialogic/timeline/metro/`, escenas del prólogo)

| Archivo | Id / clave | Original | Propuesta | Nota |
|---|---|---|---|---|
| metro_notice_board.dtl | #id:154 | ...Se busca **camarero**... experiencia mínima. | ...Se busca **personal para cafetería**... experiencia mínima. | "Camarero" es de España y "mesero" de México; así se evitan los dos. |
| ticket_store.dtl | #id:162 | (mira la ventanilla de **tickets**) Ha subido otra vez. | (mira la ventanilla de **boletos**) Ha subido otra vez. | Para el metro, "boleto" (ver §7). |
| ticket_store.dtl | #id:164 | (saca **el ticket** de su bolsillo) Menos mal que compré el mío antes. | (saca **el boleto** de su bolsillo) Menos mal que compré el mío antes. | |
| ticket_store.dtl | #id:166 | (guarda **el ticket**, junto a la cartera) Todo justo. Como siempre. | (guarda **el boleto**, junto a la cartera) Todo justo. Como siempre. | |
| unknown_station.tscn + game_text.csv | `Ya tengo billete.` | Ya tengo **billete**. | Ya tengo **boleto**. | "Billete" de transporte es de España. |
| two_young_guys.dtl | #id:168 | **¡No te digo!** El último nivel es imposible. | **¡Te lo juro!** El último nivel es imposible. | "¡No te digo!" es una muletilla regional poco clara. |

## 4. Calle (`dialogic/timeline/street/`, `street_zone_1.tscn`, puzzles de la calle)

| Archivo | Id / clave | Original | Propuesta | Nota |
|---|---|---|---|---|
| street_ad_column.dtl | #id:19c | (Un **volante** pegado en la columna...) | (Un **folleto** pegado en la columna...) | "Volante" (flyer) es de México y alrededores. |
| street_zone_1.tscn + game_text.csv | `El mismo volante del minimercado.` | El mismo **volante** del minimercado. | El mismo **folleto** del minimercado. | Ídem (dos AmbientThought de la escena). |
| street_cafe.dtl | #id:1b3 | **Igual**, no entraría. Hay mucha gente. | **De todos modos**, no entraría. Hay mucha gente. | "Igual" con el sentido de "de todas formas" es del Cono Sur y México. |
| street_car.dtl | #id:1b6 | (Un **coche** negro **aparcado**...) | (Un **auto** negro **estacionado**...) | Ver §7. |
| street_car.dtl | #id:1bc | ...Yo también lo hago en todos los **coches**. | ...Yo también lo hago en todos los **autos**. | |
| street_car.dtl | #id:1be | ...Yo lo hago en todos los **coches**. | ...Yo lo hago en todos los **autos**. | |
| street_car.dtl | #id:1c0 | (sonríe) Tranquila**, mujer**. Yo también me miro en todos los **coches**. | (sonríe) Tranquila. Yo también me miro en todos los **autos**. | El vocativo "mujer" suena a España. |
| street_car.tres | extra_words | "coche" | "auto" | Es un distractor del puzzle y no toca las claves de las respuestas. |
| street_cat.dtl | #id:1c9 | **Seguro sigue** en la puerta, esperándome. | **Seguro que sigue** en la puerta, esperándome. | *(opcional)* Ver §7. |
| street_couple.dtl | #id:1cd | (Una pareja discute **al pie del paso de cebra**...) | (Una pareja discute **junto al paso peatonal**...) | "Paso de cebra" es de España. |
| street_zone_1.tscn + game_text.csv | `Solo por el paso de cebra.` | Solo por el **paso de cebra**. | Solo por el **paso peatonal**. | |
| street_grandma.dtl | #id:1f4 | ...justo detrás de la torre de cristal. **No tiene pérdida.** | ...justo detrás de la torre de cristal. **Es fácil de encontrar.** | "No tiene pérdida" es un modismo de España. |
| street_pets_closed.dtl | #id:200 | (Un cartel en la puerta dice "Cerrado por **reformas**".) | (Un cartel en la puerta dice "Cerrado por **remodelación**".) | "Reformas" de un local es de España. |
| street_zone_1.tscn + game_text.csv | `Hay alguien dentro comiéndose un bocadillo...` | Hay alguien dentro comiéndose un **bocadillo**. No miro. No miro. | Hay alguien dentro comiéndose un **sándwich**. No miro. No miro. | "Bocadillo" (sándwich) es de España. |
| street_zone_1.tscn + game_text.csv | `Un portero automático...` | Un **portero automático**. Odio hablar por esas cosas. | Un **intercomunicador**. Odio hablar por esas cosas. | Cada país lo llama distinto; este es el término general. |
| street_zone_1.tscn + game_text.csv | `Seguro hay una tienda cerca.` | **Seguro hay** una tienda cerca. | **Seguro que hay** una tienda cerca. | *(opcional)* Ver §7. |

## 5. Plaza: escena de Lía (`dialogic/timeline/plaza/`, `plaza.gd`, `lia_chatter.gd`, `lia_curiosity.gd`, `plaza.tscn`)

Varias de estas líneas las escribí yo; las corrijo igual.

| Archivo | Id / clave | Original | Propuesta | Nota |
|---|---|---|---|---|
| plaza_lia_meet.dtl | #id:29a | (Lía toma tanto aire que se le inflan **los cachetes**...) | (Lía toma tanto aire que se le inflan **las mejillas**...) | "Cachetes" es latinoamericano. Va en la narración, no en boca de Lía. |
| plaza_lia_meet.dtl | #id:29b | ...Un poco. Sí, estoy asustada. Pero **igual** vamos a buscar. | ...Un poco. Sí, estoy asustada. Pero **aun así** vamos a buscar. | "Igual" con el sentido de "de todas formas". |
| plaza_lia_meet.dtl | #id:29c | Lía: **Vale.** Si estamos las dos, menos asustadas. | Lía: **Bueno.** Si estamos las dos, menos asustadas. | |
| plaza_lia_meet.dtl | #id:37b | Alice: ...**Vale.** Buscamos a tu mamá. | Alice: ...**Está bien.** Buscamos a tu mamá. | |
| plaza_lia_fountain.dtl | #id:2d8 | Tu mamá vino hasta la fuente. Si seguimos moviéndonos, **igual** nos la seguimos perdiendo. | Tu mamá vino hasta la fuente. Si seguimos moviéndonos, **a lo mejor** nos la seguimos perdiendo. | "Igual" con el sentido de "quizá" es de España. |
| plaza_lia_fountain.dtl | #id:304 | (Dos niñas de la mano. Una con **gafas redondas**...) | (Dos niñas de la mano. Una con **lentes redondos**...) | Ver §7. |
| plaza_lia_fountain.dtl | #id:30e | (Dos niñas de la mano. Una con **gafas redondas** y una mochila...) | (Dos niñas de la mano. Una con **lentes redondos** y una mochila...) | |
| plaza_dog_lady.dtl | #id:3b5 | ...Pero Toby no, **¿a que no, Toby?** | ...Pero Toby no, **¿verdad que no, Toby?** | "¿A que no?" es de España. |
| plaza_ice_cream_extra.dtl | #id:383 | ¿Ah, sí? Pues **vais** bien... | ¿Ah, sí? Pues **van** bien... | Vosotros → ustedes. |
| plaza_teen.dtl | #id:353 | ...Una señora **se da vuelta**. Alice quiere desaparecer. | ...Una señora **se gira**. Alice quiere desaparecer. | "Darse vuelta" es rioplatense. |
| plaza_teen.dtl | #id:35b | ...Todo el mundo **queda** ahí. | ...Todo el mundo **se encuentra** ahí. | "Quedar" con el sentido de "citarse" es de España. |
| plaza_teen_extra.dtl | #id:399 | (se encoge de hombros, pero casi sonríe) **Ya.** | (se encoge de hombros, pero casi sonríe) **Ajá.** | *(opcional)* "Ya" por "vale, entendido" es de España. |
| lia_chatter.gd + game_text.csv | `Es la quinta que me enseñas.` | Es la quinta que me **enseñas**. | Es la quinta que me **muestras**. | "Enseñar" con el sentido de "mostrar" es de España. |
| lia_chatter.gd + game_text.csv | `Yo también. Luego buscamos algo, ¿vale?` | ...Luego buscamos algo, **¿vale?** | ...Luego buscamos algo, **¿sí?** | |
| plaza.gd + game_text.csv | `Alguien la va a ayudar...` | ...Alguien que no tenga un tren que **coger**. | ...Alguien que no tenga un tren que **tomar**. | "Coger" es la marca que más chirría en Latinoamérica. |
| plaza.gd + game_text.csv | `No pasa nada. La vamos a encontrar igual.` | ...La vamos a encontrar **igual**. | ...La vamos a encontrar **de todos modos**. | Cabinas, con Lía. |
| plaza.tscn + game_text.csv | `Igual también está esperando a alguien.` | **Igual** también está esperando a alguien. | **A lo mejor** también está esperando a alguien. | Paseante. |
| lia_curiosity.gd + game_text.csv | `¿Qué pone ahí?` | ¿Qué **pone** ahí? | ¿Qué **dice** ahí? | "Pone" referido a un texto escrito es de España. |
| lia_curiosity.gd + game_text.csv | `Pone «café».` | **Pone** «café». | **Dice** «café». | |
| lia_curiosity.gd + game_text.csv | `Cuando sea mayor voy a tener una igual.` | Cuando sea **mayor** voy a tener una igual. | Cuando sea **grande** voy a tener una igual. | Coherencia con «Cuando sea grande voy a tener un perro enorme». |
| lia_curiosity.gd + game_text.csv | `Cuando sea mayor voy a poner un anuncio...` | Cuando sea **mayor** voy a poner un anuncio. «Se busca mamá». | Cuando sea **grande** voy a poner un anuncio. «Se busca mamá». | |
| lia_curiosity.gd + game_text.csv | `Sé caerme. Eso se me da muy bien.` | Sé caerme. **Eso se me da muy bien.** | Sé caerme. **En eso soy muy buena.** | *(opcional)* "Dársele bien algo" suena más a España. |

**Guardia nuevo (aparte).** La rama de seguridad de la fuente, reescrita con un guardia, está en el Twine "Escena Lia v2" (pasaje *Fuente Seguridad*). Ya está escrita en neutro.

## 6. Lo que revisé y se queda igual

Lo comento para que no parezca un olvido. Todo esto se entiende y se usa en doblaje neutro:
- **Comida y tecnología:** "computadora", "laptop", "PC", "TV", "control de la consola", "jugos", "papas fritas".
- **Transporte y ciudad:** "metro", "conducir", "acera", "cajero".
- **Ropa y objetos:** "auriculares", "cartera" (de dinero), "bolígrafo", "libreta".
- **Trato:** "usted" y "ustedes" ("Quédense aquí", "¿me dejan pasar?").
- **Diminutivos de Lía:** "despacito", "un poquito". Son de niña y comunes a los dos lados.
- **Otras:** "Ok...", "cool", "recoger".

---

## 7. Decisiones generales

Para que todo el juego diga siempre lo mismo:

| Concepto | Se usa | Se evita |
|---|---|---|
| Vehículo | **auto**, **estacionado** | coche, carro, aparcado |
| Lo que lleva Alice en la cara | **lentes** | gafas, anteojos |
| Electrodoméstico | **refrigerador** | nevera, frigorífico |
| Pase del metro | **boleto** | billete; "ticket" queda solo para el recibo de la tienda (el papel donde Leo escribe su número) |
| Teléfono | **teléfono** | móvil, celular |
| Para cruzar la calle | **paso peatonal** | paso de cebra |
| Papel de propaganda | **folleto** | volante, flyer |
| Sujetar / subirse | **tomar** (un tren), **agarrar** (algo con la mano) | coger |
| Asentir | **Bueno**, **Está bien**, **De acuerdo**; coletilla **¿sí?** | vale, ¿vale? |
| Segunda persona del plural | **ustedes** | vosotros, os, vais, sois… |
| Texto escrito | **dice** | pone |
| Mostrar algo | **mostrar** | enseñar (con ese sentido) |
| "Quizá" | **a lo mejor**, **quizá** | igual (con ese sentido) |
| "De todas formas" | **de todos modos**, **aun así** | igual (con ese sentido) |
| Futuro de Lía | **cuando sea grande** | cuando sea mayor, de mayor |
| Girarse | **girarse**, **darse la vuelta** | darse vuelta |
| Diminutivos | Normales en Lía (poquito, despacito) | Regionales en narración o en Alice (cachetes, chiquito) |
| "Seguro" | **seguro que** + verbo *(opcional)* | "seguro" sin "que" |
| Atractivo | **Pendiente de tu decisión.** Hoy se dice "lindo" ("...es muy lindo", "Qué linda mañana"). Propongo dejar "lindo" para personas, porque se entiende en todas partes y suena tierno, y usar "bonito" para cosas. | |
