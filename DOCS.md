# Take Up Space — Referencia del proyecto

Juego 2D pixel art en **Godot 4.7**. Alice sale de su apartamento a comprar
comida para su gato Wilson, coge el metro y se queda dormida.

- **Nombre:** *Take Up Space* (`config/name` en `project.godot`). La carpeta y el
  repo siguen llamándose `testing-dual`: renombrarlos no afecta al juego, las
  rutas internas son `res://` y UIDs.
- **Escena principal:** `scenes/prologue_scene/scenes/apartment.tscn` (el apartamento)
- **Idioma:** código y comentarios en **inglés**; texto que ve el jugador en **español**

---

## 1. Estructura de carpetas

```
autoload/      Singletons (GameManager, FadeTransition)
global/        Piezas reutilizables en cualquier escena
  npcs/        NPC base (sprite sheet por columnas)
player/        Alice
scenes/
  prologue_scene/
    scenes/    Las escenas jugables
    script/    basic_door.gd
    wilson/    El gato
dialogic/      Personajes (.dch) y diálogos (.dtl)
fonts/         m3x6.ttf, BitMap.ttf
addons/        Dialogic, AsepriteWizard, TileMapDual
```

---

## 2. Flujo del juego

El juego arranca en la pantalla de idioma (`scenes/language_select/`, §12),
que pasa al apartamento.

**Midgame (en construcción):** `scenes/plaza_scene/scenes/plaza.tscn` + `plaza.gd`.
La plaza al atardecer, después de la tienda de Leo (salto de tiempo en el
interludio): Lía busca a su madre, Alice pierde el último tren por ayudarla y,
de noche, Clara. La secuencia de Lía está en la sección 15.
Mismas capas y tilesets que `street_zone_1`. El mapa: plaza cuadrada con
cuatro jardines vallados, una plazoleta central con la fuente, calles arriba y
abajo, y la boca del metro en la esquina inferior derecha. Alice entra por el
hueco del muro de abajo (626, 1291); cámara de 0–1280 × 0–1308.
- **Calzadas** (`SuperiorLayer/StreetRoadColisions`, oculta): la de abajo
  bloqueada salvo los tres pasos de cebra (columnas 1–2, 19–20 y 37–38); la de
  arriba, entera.
- **Boca del metro** (esquina inferior derecha): una sola pieza de escalera
  (`Buildings2`, atlas `buildings` 1–3 × 6–9; la copia apilada en `Buildings`
  se quitó porque se leía como dos entradas), con sombra proyectada abajo a la
  derecha en `Shadow` (como en la zona 1) y el recinto abierto hacia la acera
  y hacia la izquierda: solo quedan la valla del borde derecho y la de abajo.
- **Bordes** (`MapBoundaries`): izquierda y derecha ("No hace falta alejarme.
  El metro está aquí...") y el hueco de entrada ("Por ahí vine...").
`SunFilter` en tono de atardecer y el ambiente de la calle. La tienda de Leo
lleva aquí (interludio con el salto de tiempo); la noche lleva a `demo_end`
hasta que exista Clara.

**Las líneas al salir del edificio** están en `apartment.gd` (`LEAVING_LINES`),
que las pone en la escalera al cargar, y no en la escena: un editor con una
copia vieja de `apartment.tscn` las borró varias veces al guardar (Godot guarda
las escenas abiertas al darle a Ejecutar). Para cambiar el texto, edita ese
array (y su fila en `game_text.csv`).

**La portada** (`ui/cover.aseprite`, la ilustración del título) aparece a
pantalla completa al salir del edificio: la escalera del apartamento tiene
`interlude_image` y `interlude_image_before_line = 2`, así que
`FadeTransition.transition_with_interlude()` la muestra entre "El aire de la
mañana..." y "Camina rápido..." (1,4 s de fundido, 3,5 s quieta, se salta con
Espacio). Cubre la pantalla recortando un poco arriba y abajo, y se filtra en
lineal porque es ilustración, no pixel art. Vuelve, oscurecida, de fondo en
`demo_end`.

```
apartment.tscn ──global/stairs/stairs.gd──►  metro_stations.tscn  ──metro_train.gd──►  metro_train_interior.tscn
(apartamento,                  (andén de                                  (vagón: se sienta → se duerme →
 bloqueado hasta                salida)                                    el trabajador la despierta)
 tener los 4 objetos)
                                                                                        │
                                                                              ExitDoorArea (target_scene_path)
                                                                                        ▼
                                                                          unknown_station.tscn
                                                                          (tren se va → pierde el teléfono →
                                                                           trabajador la ignora → interactuables
                                                                           ambientales opcionales → ExitArea)
                                                                                        │
                                                                                        ▼
                                                                        apartment.tscn (PLACEHOLDER)
```

**El prólogo, de principio a fin, es jugable** — pero la salida de `unknown_station.tscn`
(`ExitToStreet`/`ExitToStreet2`, ambas en `ExitAreas`) apunta de vuelta a `apartment.tscn`
a propósito, como placeholder: la escena de la calle todavía no existe. Cuando la crees,
solo hay que cambiar `next_scene_path` en esos dos nodos.

**La mochila se lleva al revisarla.** La primera vez que Alice la mira
(`apartment/alice_backpack`, con `quest_step == 3`) cuenta lo que falta, da
la pista de los zapatos ("alguien de por aquí siempre se los lleva al baño
cuando se aburre") y se la cuelga: emite `prep_items_unlocked` y
`item_picked:alice_backpack`. Antes había que volver al cuarto a buscarla
después de juntar todo, y los playtests 6 y 8 lo marcaron como un rodeo
artificial.

**El tercer objeto cierra la preparación.** `alice_wallet`,
`alice_headphones` y `alice_shoes` llevan, justo después de su
`item_picked`, una rama `if GameManager.has_all_prep_items()` con la
despedida ("Ojalá me emocionara... No. Wilson me necesita. Lo voy a
hacer."), la decisión de ensayar ("Pero antes... un par de frases frente al
espejo del baño.") y la señal `step_4`. Como la señal se procesa antes que la
condición, solo la dice el último objeto, sea cual sea el orden.

**La puerta del departamento** (`outside_door.gd`) se abre con
`quest_step >= 4` **y** `GameManager.mirror_practice_done`. Mientras no,
`alice_cant_leave_yet` dice lo que toca según el paso:
- paso 0 (aún no sabe que Wilson tiene hambre): "Wilson está maullando...
  Debería ver qué le pasa." (con maullido);
- pasos 1–2: "Tengo que conseguir comida para Wilson.";
- paso 3: "Todavía no puedo. Aún necesito {GameManager.missing_prep_text}."
  `missing_prep_text` (GameManager) da "la mochila" si aún no la abrió, y si
  no, lo que falte de verdad ("la cartera y los zapatos"), ya traducido
  (`tr()`, filas en `game_text.csv`);
- paso 4 sin ensayar: "Todavía no. Primero el espejo." El
espejo (`apartment/bathroom_glass`) tiene tres estados: antes de la
preparación, las ojeras de siempre; con todo listo, el ensayo (ver
`AnxietyPuzzle`); después, "Ya. Basta de practicar.", para que no se repita.

Después de la despedida de Wilson, la puerta funciona como una puerta
automática **solo para Alice** (Wilson no la mueve), y se abre y se cierra
cada vez que ella pasa, en los dos sentidos. Antes se cerraba para siempre
con el primer cuerpo que salía de su área, Wilson incluido: si Alice volvía
a entrar al piso, quedaba atrapada en el pasillo negro detrás de la puerta
cerrada (bloqueo del playtest 8).

Todos los cambios de escena pasan por **`FadeTransition.transition_to_scene()`**
(directo, o vía `SceneTransitionArea`/`ExitArea`, que lo llaman por dentro).
Nunca uses `get_tree().change_scene_to_file()` a mano: te saltas el fundido.

---

## 3. Autoloads

### `GameManager`
Estado que sobrevive entre escenas.

| Cosa | Para qué |
|---|---|
| `quest_step` | Fase de la misión (0-4) |
| `collected_items` | IDs de objetos recogidos |
| `missing_prep_items` | Cartera, auriculares, zapatos |
| `prep_items_unlocked` | Alice ya miró la mochila. `apartment/alice_backpack` lo usa para no repetir el monólogo largo: las siguientes veces solo nombra lo que falta |
| `target_door_id` | Por qué puerta subió al tren → dónde aparece dentro |
| `has_phone` | Se pone en `false` vía `[signal arg="no_phone"]` en `unknown_station_lost_phone` |
| `mirror_seen` | Ya se miró al espejo del baño ("Tienes ojeras"), señal `mirror_seen`. El ensayo la saluda con "Hola otra vez, Alice." |
| `mirror_practice_done` | Ya ensayó frente al espejo, señal `mirror_practice_done`. La puerta del departamento no se abre sin esto |
| `wilson` | Referencia al gato |

Escucha `Dialogic.signal_event` y avanza `quest_step` con las señales
`step_1`…`step_4`.

### `AppExit` (`autoload/AppExit.gd`) — cerrar el juego
`AppExit.quit_game()` es la única forma de cerrar el juego desde código. En
macOS se salta el cierre normal de Godot para evitar un crash del addon
TileMapDual, y también atiende Cmd+Q y el botón de cerrar la ventana. Detalles
en "Cosas pendientes". Por eso, en macOS, "Salir" termina con código 137
(`OS.kill`): es a propósito, no un fallo (lo vio el playtest del 2026-11-14).

### `ThoughtBox` (`autoload/ThoughtBox.gd`) — la mente de Alice
El juego tiene **dos lenguajes visuales**, los dos con Dialogic:

| Style | Dónde | Para qué | Cómo se cierra |
|---|---|---|---|
| `dialogue` (`dialogic/styles/dialogue_style.tres`) | Caja abajo, con nombre, retrato y ▼ | Conversaciones y monólogos de los `.dtl` | Espacio. Frena a Alice |
| `thought` (`dialogic/styles/thought_style.tres`) | Nube arriba, lila translúcida, sin nombre ni ▼ | Pensamientos: los del suelo, los bordes del mapa y las líneas de objetos inertes | Sola (auto-avance nativo), con Espacio, o al caminar si es de un objeto. No frena a Alice |

- **`thought` hereda de `dialogue`**, que a su vez hereda del estilo VN de
  Dialogic. Comparten raíz, así que cambiar de uno a otro solo reaplica
  ajustes sobre la misma caja: no se reconstruye nada y no hay parpadeo.
  `thought` solo cambia la capa `"13"` (textbox): tamaño 640×96, a 24 px del
  borde de arriba (`box_margin_bottom` 648), panel propio (la nube), texto
  centrado, sin ▼, sin barra de auto-avance, sin sonido de tipeo y sin las
  animaciones de Dialogic (las hace `ThoughtBox`).
- Están registrados en `dialogic/layout/style_list`, y `dialogue` es el
  `default_style`. Se editan en la pestaña **Styles** de Dialogic.
- **`ThoughtBox.say(lines, close_on_move, hold_base)`** es la única entrada
  (se puede esperar con `await`). Arma un timeline en memoria que empieza con
  `[style name="Thought"]`, más una línea de texto instantáneo por cada
  pensamiento, sin hablante. Le pone el meta `thought` y activa el
  **auto-avance nativo** de Dialogic (`auto_advance.enabled_forced`, con
  `fixed_delay` = `hold_base`, 2 s por defecto, + 0,03 s por letra). Al
  terminar, devuelve el auto-avance a como estaba, así que `dialogue` nunca lo
  hereda.
- **Por qué el estilo va dentro del timeline y no por código:**
  `Dialogic.start()` borra el estilo base, y cada línea de texto vuelve al
  estilo base si el actual es otro. Con el evento `[style]`, `thought` pasa a
  ser el base mientras dura el pensamiento. La primera línea de la siguiente
  conversación devuelve `dialogue` sola.
- **Conversación que arranca encima de un pensamiento** (por ejemplo, el tren
  llega mientras hay una nube): `Dialogic.start()` solo limpia su estado si no
  hay un layout activo, así que el estilo base seguía siendo `Thought` y la
  conversación salía en la nube, con la etiqueta del nombre cortada arriba.
  `ThoughtBox._on_timeline_started` lo corrige: si empieza algo que no es un
  pensamiento y el estilo es `Thought`, vuelve al estilo por defecto
  (`change_style("")`) antes de la primera línea.
- Si llega un pensamiento con una conversación en pantalla, espera a que
  termine. Si ya había otro pensamiento, lo reemplaza.
- **Arrancan de a uno** (`_starting`). Si dos llegan en el mismo paso (un NPC
  de ambiente y un `ThoughtTrigger` del suelo, por ejemplo), el segundo espera
  a que el primero esté en pantalla y recién entonces lo reemplaza. Antes los
  dos arrancaban mientras subían las burbujitas: Dialogic iniciaba el segundo
  cuando el primero todavía no se veía, `_on_timeline_started` lo tomaba por
  una conversación, apagaba el avance automático y la nube no se cerraba nunca.
- `ThoughtBox.is_showing()` dice si lo que está en pantalla es un pensamiento.
  El `Player` lo usa para no frenarse y para poder interactuar igual (Espacio
  sigue siendo de las conversaciones, no de los pensamientos).
- **Dialogic corre un solo timeline a la vez:** mientras hay una nube, ocupa
  Dialogic. Por eso los pensamientos tienen que ser cortos.

**El toque maestro (juice).** Todo con `Tween`, sin tocar `addons/dialogic`:
- **Burbujitas desde la cabeza:** antes de la nube, 3 burbujas lila (radios
  4, 6 y 9 px, borde claro, sin antialiasing) aparecen una tras otra
  (0,06 s) en el camino de la cabeza de Alice a la nube (al 16 %, 36 % y
  62 %). Se desvanecen cuando la nube terminó de entrar. Se dibujan en una
  `CanvasLayer` propia de `ThoughtBox` (clase interna `ThoughtBubble`).
- **Entrada con escala y deriva:** la nube (el nodo `Sizer` de la capa de
  texto) entra desde 0,92 de escala, 4 px más abajo y transparente, en 0,22 s
  con *ease out back*. Sube flotando, al revés que la caja de abajo, que
  entra desde abajo. Por eso `thought_style.tres` pone las animaciones propias
  de Dialogic en `NONE`.
- **Salida hacia arriba:** cada pensamiento termina con
  `[signal arg="thought_out"]` + `[wait time="0.22" hide_text="false"]`.
  La señal dispara un fundido de 0,22 s mientras la nube sube 6 px, y el wait
  le da tiempo en pantalla. Si se cierra al caminar, se anima igual antes de
  terminar el timeline.
- **La nube es una nube de verdad (nine-slice):** `thought_panel.tres` es un
  `StyleBoxTexture` de `dialogic/styles/thought_cloud.aseprite`. Es arte de
  44×32 px, importado por AsepriteWizard como textura con `sheet/scale = 3`,
  así que queda en 132×96. Los cortes son de 36 px por lado (12 de arte): las
  esquinas son fijas, y el tramo del medio es un lóbulo grande (arriba y
  abajo) o uno chico (a los costados) que se **repite** con `TILE_FIT`. Así la
  nube suma lóbulos al crecer en vez de estirarse. Las esquinas no invaden el
  tramo que se repite, y por eso las uniones no se notan. El script que la
  generó (lóbulos = círculos, contorno = borde del relleno) se puede editar a
  mano en Aseprite sin problema.
  - Si cambias el tamaño del arte, actualiza `texture_margin_*` y que la
    altura de la caja (96) siga siendo esquinas + un número entero de
    repeticiones.
  - Se probó antes un arte de 24×24 con bultos de 6 px: en 640 px de ancho
    parecía un ribete festoneado, no una nube.
- **La nube se evapora:** cada frame, la opacidad del panel
  (`modulate_color`) baja de 1 a 0,55 con `auto_advance.get_progress()`, y
  vuelve entera con la línea siguiente. El texto queda nítido. El jugador ve
  cuánto le queda a la línea sin una barra.
- **Los dos estilos comparten caja:** al terminar un pensamiento, y al
  empezar cualquier conversación, `_reset_cloud()` devuelve escala, posición,
  opacidad y borde a la normalidad.
- **Retrato que se apaga:** `leave` usa por defecto la animación **"recede
  out"** (`dialogic/animations/leave_default`). El retrato se enfría a gris,
  se encoge al 96 % hacia sus pies, baja 6 px y se desvanece. Pasar de hablar
  a pensar se siente como un cambio de foco, no un corte. Vive en
  `addons/dialogic_additions/TakeUpSpace/` (la carpeta oficial de extensiones
  de Dialogic, `index.gd` + `Animations/recede_out.gd`), que es **nuestra**,
  no del addon.
- Sin sonido por ahora: falta el `.wav` de respiro.

### `FadeTransition`
`CanvasLayer` en la capa 100 con un `ColorRect` negro encima de todo.

```gdscript
await FadeTransition.fade_out(1.0)
await FadeTransition.fade_in(1.0)
await FadeTransition.transition_to_scene("res://ruta.tscn")
await FadeTransition.transition_with_interlude("res://ruta.tscn", ["Línea 1", "Línea 2"])
```

`transition_with_interlude` muestra unas líneas (m3x6, centradas) con la
pantalla en negro antes de cargar la escena. **Espacio adelanta línea a
línea** (2026-11-14, playtest: las cartelas tras la tienda y tras el metro
cerrado no se podían saltar): pulsado durante el fundido de entrada, la línea
se completa al instante; pulsado mientras está en pantalla, se va con un
fundido rápido (`INTERLUDE_SKIP_FADE`, 0,2 s). Cada línea limpia la pulsación,
así que una pulsación salta una sola línea (`_show_interlude_item`,
`_fade_item`; vale también para la ilustración). Antes, una pulsación durante
el fundido de entrada se perdía. La
narración sale en lila; lo que Alice piensa se escribe entre «» y sale en
blanco (p. ej. «Le di mi número. ¿Qué hice?»). Es
un puente entre dos lugares para que Alice no parezca teletransportarse. La
escalera del edificio (`Staircase` en `apartment.tscn`, propiedad
`interlude_lines` de `stairs.gd`) lo usa para ir al metro: "La calle estaba
más ruidosa de lo que recordaba." / "Solo hasta el metro. Nada más." Antes se
pasaba del edificio directo al andén y el tester creyó que Alice vivía dentro
del metro.

---

## 4. El jugador (`player/player.gd`)

`class_name Player`, grupo `"player"`.

**Animaciones** — el nombre se arma solo: `idle_`/`walk_` + `front`/`back`/`side`
(`side` usa `flip_h`). Sentada: `sit_down`, `sit_sleepy`, `sit_asleep`.

**API para cutscenes** — úsala siempre, no toques el `AnimatedSprite2D` por fuera:

```gdscript
player.lock_control()                       # bloquea movimiento E interacción
player.unlock_control()
player.play_animation("sit_down", "idle_front")   # el 2º es fallback si no existe
```

`lock_control()` sobrevive a un diálogo que ocurra dentro de la cutscene: al
terminar el diálogo, Alice sigue bloqueada hasta que llames `unlock_control()`.

**Silueta** (2026-11-15): con `xray_silhouette` (export, activado) el Player
crea un `CharacterXray` (sección 5) al empezar cada escena. En todo el juego,
cuando algo alto la tapa, se ve su silueta lila justo en la parte tapada.
(Sustituye a `set_silhouette` y `SilhouetteZone`, que solo servían en la
torre de cristal.)

**Sprite por capas (2026-10-25).** Alice se dibuja desde un solo archivo,
`player/alice.aseprite`, con cinco capas: `body` (Alice descalza), `backpack`,
`shoes`, `headphones_neck` y `headphones_head`. Se importa con
"Aseprite SpriteFrames (Split By Layer)" (`aseprite_wizard.plugin.spriteframes-split`),
que genera un `.ase_layer` por capa en `player/alice_layers/`, cada uno un
`SpriteFrames` con las mismas 9 animaciones.
- En `player.tscn`, `AnimatedSprite2D` es el cuerpo, y tiene cuatro hijos
  (`Backpack`, `Shoes`, `HeadphonesNeck`, `HeadphonesHead`) con el mismo
  `offset`. El código solo maneja el cuerpo; `_sync_outfit()` copia
  animación, frame y `flip_h` a cada capa visible. Se engancha a
  `frame_changed`/`animation_changed` del cuerpo (en `_process` iban un frame
  atrasadas y parpadeaban) y también corre en `_process` por el `flip_h`, que
  no tiene señal.
- **Qué lleva puesto** (`_refresh_outfit()`, con `GameManager.outfit_changed`):
  cada pieza se ve cuando la recogió (`alice_backpack`, `alice_shoes`,
  `alice_headphones` en `GameManager.collected_items`). Los auriculares van al
  cuello, y en la cabeza solo si `GameManager.headphones_on_head`. Salen todas
  las combinaciones, también las que no tenían versión dibujada (zapatos sin
  mochila, etc.).
- **Auriculares en la cabeza, en momentos concretos:** se los pone al sentarse
  en el tren, después del pensamiento del asiento y antes de cabecear
  (`metro_train_interior.gd::_fall_asleep`, `set_headphones_on_head(true)`), y
  se los quita al bajarse perdida (`unknown_station_lost_phone.dtl`, `[signal
  arg="headphones_off"]`, "(se quita los auriculares y mira a su alrededor)").
  Desde Dialogic: `[signal arg="headphones_on"]` / `"headphones_off"`.
- Para retocar a Alice se edita una sola capa. La capa de un accesorio solo
  tiene sus píxeles (salen de comparar las versiones que se dibujaron
  completas): nunca borra nada del cuerpo, solo pinta encima. El orden de
  capas importa: `shoes` va sobre `backpack`.
- `metro_train_interior.tscn` tenía su propia copia vieja de las animaciones
  de Alice incrustada en la escena; se quitó para que use la del jugador.
- **Los tiempos de cada frame viven en `alice.aseprite`**, no en Godot: la
  importación los copia. `sit_sleepy` y `sit_asleep` van a 1/3 s por frame
  (3 fps, la respiración lenta al dormirse). **Las tres animaciones de caminar
  duran lo mismo por vuelta: 0,8 s** (`walk_front` 0,12/0,16/0,08/0,16/0,16/0,12;
  `walk_back` 0,16/0,16/0,08/0,08/0,16/0,16; `walk_side` 6 × 0,133). Alice
  avanza siempre a la misma velocidad, así que si una vuelta dura más que otra
  las piernas (y los pasos, que suenan en `step_frames`) cambian de ritmo al
  girar; antes `walk_side` duraba 0,6 s y las otras 1 s. Si retocas una,
  mantén el total en 0,8 s. Antes estaban ajustados a mano en el
  `SpriteFrames` incrustado en `player.tscn`; al pasar a capas se perdieron y
  Alice "dormía" a 10 fps. `alice.aseprite.import` tiene
  `animation/round_fps=false`: con el redondeo, 3 fps se volvían 4.
- Si se abre una escena suelta (la calle, por ejemplo) sin pasar por el
  apartamento, Alice sale descalza y sin mochila: no recogió nada.

---

## 5. Piezas reutilizables (`global/`)

### `InteractableArea` — la base de todo
`Area2D` en la **capa/máscara 4**, con un `Label` que aparece al acercarse.

```gdscript
@export timeline_name   # si tiene valor, interactuar lanza ese diálogo
@export prompt_text     # texto del cartel, sin necesitar script propio
signal interacted
```

Para especializarla: `extends "res://global/interactable_area.gd"` y sobrescribe
`update_label_text()`, `interact()` o `_collect_item()`.

**Hijas que ya existen:**

| Script | Qué hace |
|---|---|
| `pickable_item.gd` | Objeto recogible; se borra si ya está en `GameManager`. La mochila solo muestra "[Recoger]" cuando ya están los otros tres objetos; antes muestra "[Espacio]". Su `AreaDetector` tiene que ser bastante más grande que su colisión: el de los auriculares de la cama (16×11, casi como el objeto) apenas se alcanzaba y se amplió a 40×34 (2026-11-14) |
| `lamp_interactable.gd` | Sincroniza un `PointLight2D` con `Dialogic.VAR.lamp_is_on` |
| `seat_interactable.gd` | Sienta a Alice y emite `player_sat_down` |
| `train_door_area.gd` | Secuencia de subir al tren |
| `scene_transition_area.gd` | Cambia de escena; se puede bloquear |

### `SceneTransitionArea`
Cambia de escena cuando el jugador **interactúa** (hereda de `InteractableArea`,
necesita `[Espacio]`).

```gdscript
@export_file target_scene_path
@export spawn_point              # opcional: Marker2D de SpawnPoints en la escena destino
var is_locked                    # si está bloqueada emite blocked_interaction
signal blocked_interaction       # ...para que la escena reaccione (diálogo, pensamiento)
signal transition_started
```

**Punto de aparición** (2026-11-14): `spawn_point` se guarda en
`GameManager.spawn_point` antes del fundido. La escena destino lo lee una vez
con `GameManager.take_spawn_point()` y pone a Alice en `SpawnPoints/<nombre>`
(solo la calle lo hace, `_place_at_spawn_point()` en `street_zone_1.gd`). La
salida de la tienda de Leo tiene `spawn_point = "LeoStore"`: antes, al salir
sin comprar, Alice aparecía en la salida del metro, en la otra punta del
mapa. Desde el 2026-11-14 esa salida ya no deja ir a la calle (sin pagar,
Alice se niega; pagado, va a la plaza), pero el punto se queda por si algún
día vuelve a llevar a la calle.
Para otra puerta: un `Marker2D` en `SpawnPoints` de la escena destino, el
nombre en la `SceneTransitionArea`, y que la escena destino llame a
`take_spawn_point()` en su `_ready`.

### `PassageArea` (`global/passage_area.gd` + `.tscn`)
Paso sin arte entre dos habitaciones de la misma escena (2026-11-14). Al
pisarla (cuerpo de Alice, `collision_mask = 2`) funde a negro un momento
(`fade_time`, 0,2 s), pone a Alice en `exit_point` (un `Marker2D`) mirando a
`exit_facing` y le devuelve el control. Va una en cada extremo, y el
`exit_point` de cada una tiene que quedar fuera del área de la otra. Uso: la
puerta del salón al baño del piso (`BathroomPassage` en `apartment.tscn`):
el pasillo entre las dos habitaciones está tapado por baldosas negras de
`SuperiorLayer` y Alice desaparecía unos 60 px.

### `CharacterXray` (`global/character_xray.gd`) — silueta tipo Diablo
(2026-11-15; sustituye a `SilhouetteZone`, que solo servía detrás de la
torre de cristal. Hasta el 2026-11-23 se llamaba `AliceXray` y solo servía
para Alice).

**Una instancia por personaje** (2026-11-23):
- La de Alice la crea el Player (`xray_silhouette`), en lila.
- Un `WalkingNPC` con el export `xray_silhouette` activado crea la suya al
  arrancar, con `xray_color` y `xray_min_coverage` (grupo «X-ray
  silhouette» del inspector). Hoy solo Lía: amarillo pastel
  `Color(1, 0.88, 0.5, 0.7)`, sacado del amarillo de su vestido (`#f4c224`)
  y aclarado para que sea igual de suave que el lila de Alice. Umbral 0,85:
  es más bajita, y con 0,7 un seto le tapaba lo bastante como para sacar la
  silueta. Toby no la lleva: su ruta nunca queda tapada.
- Cada instancia tiene sus dos `SubViewport` de 96×96, y las dos siluetas
  conviven sin molestarse (probado: Lía tras el camión de helados y Alice
  tras un edificio a la vez).
- La de Lía no se dibuja mientras ella está oculta o inactiva
  (`_set_npc_active`), porque cuelga de ella.
- Para apagarla en una cutscene: `lia.xray.active = false`. Hoy no hace
  falta en ninguna.
- Probado en la plaza: tras los árboles y tras el camión sale; tras un seto
  y en la banca del principio, no.

Lo que sigue explica Alice, pero vale igual para cualquiera. Cuando algo alto tapa a Alice (edificios, paredes,
árboles, la torre), su silueta lila semitransparente sale **solo en la parte
tapada**, en cualquier escena, sin zonas. Lo crea el Player
(`xray_silhouette`). Cómo funciona:
- **¿Qué píxeles están tapados?** Un `SubViewport` que comparte el mundo
  (`world_2d`) renderiza la zona alrededor de Alice (96×96 px de mundo, al
  zoom de la cámara y alineada píxel a píxel con la pantalla) **sin ella y sin
  los personajes**: `canvas_cull_mask` se salta la capa de visibilidad 20
  (`HIDDEN_LAYER_BIT`), donde se ponen Alice, la propia silueta y los
  personajes. Donde la pantalla es igual a ese render, Alice no se ve ahí:
  algo la tapa. Tintes (`CanvasModulate`, atardecer, noche) y luces
  (`PointLight2D`, también de color) son iguales en los dos renders y se
  anulan. Antes se probó a comparar con el color que debería tener (con el
  tinte aplicado), pero las luces de color la daban por tapada.
- **Personajes:** NPCs, Lía, Toby, Wilson y palomas (`CharacterBody2D` que no
  sean el Player, y `PigeonFlock`) van a la capa excluida, también los que
  aparecen después (`node_added`). Así, uno delante de Alice nunca cuenta como
  algo que la tapa.
- **Solo lo alto:** la silueta sale si al menos el 70 % de Alice está tapado
  (`MIN_COVERAGE`). Cada píxel muestrea una rejilla de 6×8 puntos sobre su
  dibujo (sus límites, cacheados por frame de animación) y cuenta los tapados.
  Barandillas, setos, bancos, torniquetes o papeleras le tapan como mucho las
  piernas y parte del cuerpo (la mitad, más o menos) y no la disparan;
  árboles, edificios y la torre pasan de sobra. **Limitación:** no clasifica
  por tipo de objeto (las capas mezclan árboles y farolas con setos y bancos,
  y clasificar baldosa a baldosa obligaría a listar cada una de cada
  tileset), así que algo alto que la tape menos del 70 % (asoma más de un
  30 %) no la muestra, y algo bajo que la tapara más (no pasa con el arte
  actual) sí.
- **Su forma:** otra `SubViewport` dibuja sin luz una copia de todas sus capas
  (cuerpo, mochila, zapatos, auriculares), sincronizada cada frame.
- **El dibujo:** un `Sprite2D` encima de todo el mundo (`z_index` 4000), justo
  después de un `BackBufferCopy`, con su textura en blanco (si el shader
  fallara no se pinta nada) y un shader que compara cada píxel.
  `debug_mask` (uniform) pinta rojo = silueta, amarillo = tapada por algo bajo
  y verde = visible.
- **Coste:** prácticamente nulo en las pruebas (~0,1 ms; a 99–100 fps igual,
  con y sin). Optimización: si ni Alice ni la cámara se mueven, el render sin
  ella se actualiza cada 2 frames (`STILL_UPDATE_EVERY`); al moverse, cada
  frame (si no, la silueta parpadearía).
- La torre de cristal se sigue dibujando encima de la calzada: es perspectiva
  (un edificio alto delante de la calle), no un error.

### `ExitArea` (`global/exit_area.gd`)
Cambia de escena **sola**, al entrar en su radio — sin `[Espacio]`, sin depender
de ningún asset propio (es un `Area2D` invisible). Pensada para salidas genéricas
(puertas, escaleras sin arte interactivo propio) que no necesitan la coreografía
completa de `stairs.gd`.

```gdscript
@export exit_direction        # UP/DOWN/LEFT/RIGHT — dirección fija del paso
@export walk_forward_distance # en píxeles; 0 = no camina, solo funde
@export fade_start_delay      # el fundido arranca A MITAD del paso, no al final
@export_file next_scene_path  # vacío = solo juega el paso, sin cambiar de escena
```

El paso (`Tween` sobre `global_position`) **no se espera** (`await`) antes de
lanzar el fundido — por eso el corte cae mientras Alice todavía se está moviendo,
no cuando termina.

Además tiene `spawn_point` (el `Marker2D` de `SpawnPoints` donde aparece en
la escena siguiente, como `SceneTransitionArea`) y, desde 2026-11-18,
**`walk_off_screen`** (apagado por defecto). Si está encendido, en vez del
paso, Alice camina sola en `exit_direction` hasta salir del encuadre: va con
el control bloqueado y sin física, así que cruza el borde del mapa, y la
cámara se queda quieta. Solo entonces se emite `walked_out` y empieza el
fundido. Sin `next_scene_path`, la escena hace su propio final al recibir
`walked_out`. La caminata es `Player.walk_off_screen(direction)`, a la
velocidad normal de Alice. Al llegar fuera de cuadro se queda quieta (idle)
antes de emitir `walked_out`. Además, **los pasos de Alice nunca suenan
mientras el negro de `FadeTransition` tapa más de la mitad**
(`Player.FOOTSTEP_MAX_FADE`): antes se oían en bucle durante el interludio
final del andén, porque seguía «andando» fuera de cuadro (2026-11-23). Úsalo en salidas que se leen como «irse del
sitio» (a la calle, por el borde del mapa), **no en puertas**, donde
funciona el paso con fundido.

### `SpawnPoint` (`global/spawn_point.gd`)
Un `Marker2D` de `SpawnPoints` con dos opciones: `walk_in` y `direction`
(UP/DOWN/LEFT/RIGHT). La escena que llega lo usa con
`SpawnPoint.arrive(player, marcador, mirada_por_defecto)`, sin `await`, desde
su `_place_at_spawn_point()`.
- Con `walk_in`, la cámara ya está en el punto y Alice empieza fuera de
  pantalla, por el lado contrario a `direction`. Entra caminando hasta el
  punto (`Player.walk_in_from_off_screen`), mira hacia `direction` y
  recupera el control. Si llega de otra escena, espera fuera de pantalla a
  que el negro del fundido se aclare (`FadeTransition.is_covering()`), para
  que la entrada se vea.
- Sin `walk_in`, aparece directamente en el punto mirando hacia `direction`.
  Un `Marker2D` normal también vale: aparece ahí, mirando hacia la dirección
  por defecto que pase la escena.

**Dónde está activado (2026-11-18):**
- `unknown_station.tscn`: `ExitToStreet` y `ExitToStreet2` tienen
  `walk_off_screen` y salen hacia arriba, a la calle. Sus
  `walk_forward_*` / `fade_start_delay` ya no se usan.
- `plaza.tscn`: `SpawnPoints/FromStreet` (635, 1274) tiene `walk_in` y
  entra hacia arriba. `leo_store.gd` lo pide al ir a la plaza
  (`GameManager.spawn_point = "FromStreet"` antes del interludio).
- `plaza_metro.tscn`: `SpawnPoints/FromPlaza` tiene `walk_in` (entra
  escalera abajo, hacia la derecha) y `ExitToPlaza` tiene `walk_off_screen`
  hacia la izquierda, sin `next_scene_path`: el final de la demo lo hace la
  escena al recibir `walked_out`.
- Sin activar, porque son puertas o escaleras: la tienda de Leo, el tren,
  el apartamento, la salida del metro a la calle y `MetroExit` (la subida
  del andén a la plaza).

### `BoundaryArea` (`global/boundary_area.gd` + `.tscn`)
Límite del mapa. Hereda de `InteractableArea`, pero **se dispara al pisarla**,
sin `[Espacio]` y sin mostrar etiqueta, como `ThoughtTrigger`. La escena la deja
en `collision_layer = 0` y `collision_mask = 2`, así que solo la ve el cuerpo de
Alice (`body_entered`) e ignora su `InteractionDetector`.

1. `lock_control()`. Si tiene `timeline_name`, lanza ese diálogo y espera a
   que termine. Si tiene `thought_lines`, muestra la **nube de pensamiento**
   (`ThoughtBox.say`) sin esperarla: se dispara al caminar, así que por
   la regla de la sección 6 no debe frenar con una caja de diálogo.
2. La hace caminar `push_distance` px en `push_direction`
   (UP/DOWN/LEFT/RIGHT, siempre **hacia dentro** del mapa) con un `Tween`.
3. La deja mirando hacia dentro y le devuelve el control. El empujón tiene que
   sacar su cuerpo del área para que vuelva a dispararse la próxima vez.

Se repite cada vez que vuelve al borde, salvo que `one_time_interaction` esté
activo. Emite `interacted` al empezar y `pushed_back` al terminar, por si la
escena quiere cambiar el `timeline_name` (por ejemplo, otro texto la segunda vez).
Las señales corren al instante, así que la escena puede cambiar
`thought_lines` en `interacted` y Alice ya piensa el texto nuevo (la entrada
de la plaza lo hace según la etapa, sección 15).
Uso: instanciar `boundary_area.tscn`, darle un `RectangleShape2D` propio a su
`CollisionShape2D` y fijar `thought_lines` (o `timeline_name`) y
`push_direction`. En la calle usan la línea "Mejor no me alejo más. Si me
pierdo más, no sabré volver." (antes era el timeline `street_boundary`, que se
borró).

**Sin acotaciones en la nube.** "(se detiene y mira hacia atrás)", "(mira las
vidrieras)" o "(mira a su alrededor)" funcionan en la caja de abajo, que es
una escena, pero en la nube se leen como si Alice pensara la acotación. Lo que
va en la nube es solo lo que piensa.

### `CharacterShadow` (`global/character_shadow.tscn`)
La sombra bajo los pies de cada personaje (2026-10-25): una elipse plana del
mismo color que las sombras de la calle (`shadow-tile`: negro al 29 %), para
que los personajes se apoyen en el suelo.
- Dos tamaños dibujados en Aseprite: `character_shadow.aseprite` (14×7,
  personas) y `character_shadow_small.aseprite` (10×6, gatos; `small = true`).
  No va centrada (`centered = false` + `offset` redondeado): con un tamaño
  impar (como el 7 de 14×7) caería en medio píxel y se vería borrosa.
- Va **como hija del sprite** del personaje, no del personaje, con
  `show_behind_parent`: así siempre se dibuja justo debajo del sprite (si fuera
  hermana, el y-sort podía ponerla encima). Se coloca sola al arrancar en la
  línea de los pies: el borde inferior del frame del sprite (contando su
  `offset`, que cambia por instancia) menos `feet_margin` (2 px), centrada ahí
  para que asome alrededor del calzado. Es `@tool`, así que se ve en el editor.
- Ya está en las plantillas, así que la tienen todos: Alice (`player.tscn`),
  `base_npc.tscn` (todos los de la hoja), `walking_npc.tscn` (peatones,
  trabajador del metro) y Wilson (`small`). El gato de la calle la tiene
  `small` como override de su instancia.
- Leo no la lleva: está detrás del mostrador, no se le ven los pies, y la
  sombra se dibujaría sobre el mostrador.

### `NpcTalkArea` (`global/npcs/scenes/npc_talk_area.tscn`)
`InteractableArea` para **cualquier personaje con el que Alice puede hablar**.
Es una escena heredada de `interactable_area.tscn` que ya trae el globito "..."
(`InteractionHint`), así ningún NPC que habla se queda sin él y no hay que
colocarlo a mano.

- **Dónde flota el globito:** es la posición del propio nodo `InteractionHint`.
  Se coloca arrastrándolo en el editor (la instancia tiene **Hijos editables**
  activado) y eso es lo que se ve en el juego. Antes había un export
  `hint_position` que pisaba esa posición al arrancar, así que mover el
  globito en el editor no servía de nada; los valores que tenía cada escena se
  pasaron a la posición del nodo (2026-10-25). Casi siempre el área está
  corrida respecto del NPC (está donde se para Alice para hablar), así que se
  ajusta por instancia para que quede 2 px sobre la cabeza.
- **El globito y el "[Espacio]" se turnan:** el globito avisa de lejos que se
  puede hablar; cuando Alice se acerca y aparece el cartel, el globito se
  esconde (`InteractionHint.set_suppressed`, conectado al
  `visibility_changed` del `Label`) y vuelve al alejarse. Antes salían los dos,
  uno encima del otro.
- Si la charla es de una sola vez (`one_time_interaction`), al usarla el
  globito se retira (`InteractionHint.retire()`) y no vuelve.
- **Personajes que se mueven:** si el área es hija de un nodo con
  `y_sort_enabled` (Wilson, el trabajador de la terminal, el gato de la
  calle), el globito entra en ese y-sort (`InteractionHint.use_depth_sorting`):
  baja a `z_index` 0, se ordena a la altura de los pies del personaje y se
  dibuja sobre su cabeza con `offset`. Así, si una pared o un árbol tapa al
  personaje, también tapa el globito. Antes tenía `z_index` 10 siempre y
  flotaba solo cuando Wilson pasaba por detrás de algo (en el baño, por
  ejemplo). Los NPCs quietos, cuya área cuelga de `InteractableDetectors`,
  siguen con el globito por encima de todo.
- **`set_hint_position()`** mueve el globito en tiempo de juego. Wilson lo usa
  porque su sprite cambia de alto: mientras maúlla, el globito va sobre el
  texto "MEOW!" (-26); sentado o caminando, justo sobre su cabeza (-21). Con
  una sola altura, el globito quedaba flotando lejos de él.
- La usan: los 8 NPCs de la calle, Leo, el oficinista y los dos chicos del
  metro, el trabajador, la chica sentada y el chico de auriculares de la
  terminal, y Wilson. La ventanilla de tickets no, porque es un objeto.
- Ojo con los `BaseNPC`: el dibujo está centrado en el nodo (no en los pies),
  así que la cabeza queda unos 15 px más arriba del origen, no 30.

### Orden de profundidad de los NPCs (y-sort)
Todos los NPCs se ordenan con faroles, bancos y árboles **por el mismo punto
que Alice: 7 px por encima de la base del dibujo** (sus pies). Alice lo
consigue con `offset (0, -9)` en su sprite de 32 px. En `base_npc.tscn` y
`walking_npc.tscn` el nodo raíz tiene `y_sort_enabled` y el sprite está en
`position (0, 9)` con `offset (0, -9)`: el dibujo queda donde siempre, pero
Godot ordena por la posición del sprite (porque el padre tiene y-sort), que
ahora cae en los pies. Antes ordenaban por el centro del dibujo, 9 px más
arriba que Alice, y un farol los tapaba antes de tiempo.

**Regla para subir o bajar un NPC dentro de su nodo** (sentados, la calle):
deja siempre `offset (0, -9)` y mueve el `position` del sprite:
`position.y = centro del dibujo + 9`. Por ejemplo, los de la calle tienen el
centro en -16 → `position (0, -7)`; los sentados en -20 → `(0, -11)`.
**No cambies solo el `offset`**: movería el dibujo sin mover el punto de
orden. Las sombras se recolocan solas.

**Excepción: sentado en una banca frontal.** La banca (tiles de
`AddonsSuperior`) se ordena por debajo de las patas, así que con el punto de
orden normal la banca tapa a quien está sentado. Ahí se baja el punto de orden
sin mover el dibujo, con el export **`sort_lower`** del `BaseNPC` (en la
raíz): suma esos píxeles al `position` del sprite y los resta al `offset`, y
recoloca la sombra. En la plaza, el chico de auriculares (`Teen`) y el del
periódico (`NewspaperReader`) tienen `sort_lower = 11`: raíz a y=502, punto
de orden a 522, por delante de la banca (512) y del seto (520). Antes se hacía
con un override de `position`/`offset` en el `Sprite2D` hijo, pero el editor
lo borró al guardar la plaza y los dos quedaron detrás de la banca.

### `RemarkInteractable` (`global/remark_interactable.tscn`)
Para lo que **parece interactivo pero tiene poco que contar**: NPCs
ambientales, puertas cerradas, la segunda máquina expendedora. Usa el mismo
"[Espacio]" de `InteractableArea`, y al pulsar muestra **una línea de Alice en
la nube de pensamiento** (`ThoughtBox.say(..., close_on_move = true)`). La
línea se escribe en la escena, sin `.dtl` propio.
- Cuesta una sola pulsación: el texto sale entero, Alice sigue caminando, y la
  nube se va sola, con Espacio, o en cuanto ella camina.
- El mismo Espacio que la cierra no la vuelve a abrir (250 ms de espera).
- Lo que tiene contenido de verdad (`first_timeline`, `timeline_name`) abre la
  caja de abajo, como cualquier `.dtl`.
- Historia: antes se llamaba `ThoughtInteractable` y mostraba el globo sobre
  la cabeza. Después usó la caja de abajo "aligerada" en tiempo real. Ambas
  versiones se reemplazaron por la nube (`ThoughtBox`).

- `lines`: las líneas propias, en orden y en bucle. Con `loop_lines = false`
  se queda en la última.
- `pool`: un `RemarkPool` compartido (`global/remarks/ambient_npc_pool.tres`,
  8 frases de los NPCs). Elige al azar y nunca repite la misma dos veces
  seguidas. Si hay pool, `lines` se ignora.
- `group_id` + `first_timeline`: **coherencia por tipo.** Objetos que se ven
  iguales comparten id (`vending`, `station_map`, `ad_column`). El primero
  que Alice prueba, sea cual sea y **en cualquier escena**, abre
  `first_timeline` (o dice `first_line`); los demás dicen sus `lines`
  ("Otra máquina..."). Lo recuerda `GameManager.seen_object_groups`.
- `timeline_name` (heredado) sigue funcionando: si la escena lo pone desde
  `interacted`, Espacio abre ese diálogo en vez de la línea.
- `speaker`: quién dice la línea (id del `.dch`, por defecto `alice`).
- **La gente de fondo no es `RemarkInteractable`:** usa `AmbientThought`
  (abajo). `RemarkInteractable` queda para objetos y puertas, donde es Alice
  la que decide mirar.

### `AmbientThought` (`global/npcs/scenes/ambient_thought.tscn`)
Para la **gente de fondo**, la que Alice no se anima a hablarle. Es un
`RemarkInteractable` (Espacio = una línea en la nube, rotando entre `lines`, o
una del `pool`), con dos diferencias:
- **Nada flota sobre el NPC.** Ni globito "..." ni "[Espacio]": el cartel del
  área base sigue mostrándose y escondiéndose en los momentos de siempre, pero
  invisible (`self_modulate.a = 0`), y su visibilidad maneja el aviso de Alice.
- **El aviso va sobre Alice:** una nubecita lavanda arriba a la derecha de su
  cabeza (`ThoughtNotice`, ver abajo). Dicen "a Alice se le pasa algo por la cabeza",
  no "esta persona habla". El jugador decide si lo lee.
- Alcance: círculo de 16 px alrededor del NPC, que toca el `InteractionDetector`
  de Alice (16 px delante de ella).
- Líneas: **1 o 2 cortas** por NPC. Cuatro seguidas ya es un monólogo.
- En un `WalkingNPC` va como hijo, así se mueve con él. Se llama
  `AmbientThought`, no `InteractableArea`, para que `street_zone_1.gd` no lo
  congele al pulsar (no hay conversación que esperar).
- **Historia:** primero la gente de fondo tuvo globito "..." (prometía una
  charla que no llegaba). Después, pensamientos automáticos al pasar cerca, sin
  Espacio: sumados a los avisos del suelo, la torre y los bordes, había nube
  todo el tiempo y era abrumador. Lo que funcionaba era que el jugador decida
  cuándo leer; solo faltaba que el aviso no prometiera nada.

### `ThoughtNotice` (`global/thought_notice.gd`, `global/thought_notice.aseprite`)
La nubecita de pensamiento sobre Alice. La crea y maneja `ThoughtBox`:
`ThoughtBox.set_notice(fuente, true/false)`. Varias fuentes pueden pedirla a la
vez y se ve mientras al menos una la pida.
- **Dibujo (15×13):** de la misma familia que el globito "..." de los NPCs
  (tamaño y contorno casi negro `121214`), pero es una nube con bultitos, en
  el lavanda de la nube grande (`d1b8ff`, con luz `efe6ff` y sombra `a58cd8`),
  y en vez de la colita de diálogo tiene dos burbujitas que bajan hacia su
  cabeza. Se lee como "es de ella", no del NPC. (Antes eran tres puntitos
  dibujados por código; se veían raros.)
- **Se dibuja en pantalla, no en el mundo:** vive en la capa de las burbujas de
  `ThoughtBox` y copia cada frame la transformación de Alice en pantalla (zoom
  incluido). En el mundo, el `CanvasModulate` de la calle (`SunFilter`, cálido)
  la teñía de rosa, y paredes y techos la podían tapar.
- Arriba a la derecha de la cabeza (`BASE_POSITION` = (10, −24)), no encima:
  encima suele estar la persona a la que Alice mira.
- Aparece con un pop, flota 2 px, y se apaga con un fundido. Desde el
  2026-11-14 (playtest) el pop es un pulso claro (crece hasta 1,6× y vuelve
  a 1, `POP_SCALE`) y, mientras siga visible, da un pulso suave (1,25×,
  `PULSE_SCALE`) cada 3,5 s (`PULSE_EVERY`). Solo escala, nunca color. Al pulsar Espacio
  se apaga y suben las burbujas de verdad hacia la nube.
- **Nunca mientras se prepara o se muestra un pensamiento** (`_refresh_notice`
  mira `_starting` e `is_showing()`, y se vuelve a evaluar al empezar y al
  terminar cada `say()`). Al pulsar Espacio con una nube en pantalla, entre el
  pensamiento viejo y el nuevo hay ~0,2 s sin timeline (suben las burbujas), y
  el área volvía a pedir el aviso: la nubecita asomaba un instante. Además
  espera 0,12 s (`SHOW_DELAY`) antes de aparecer, para no parpadear nunca.
- **Playtest (2026-11-14):** el tester dijo que la gente de fondo de la plaza
  (guitarrista, señora de las palomas, pareja, lector) "no respondía".
  Comprobado en el juego: con Alice al lado, la nubecita sale y Espacio
  muestra su línea, desde abajo y desde los lados. El problema es que es
  discreta (15×13, 1 px de vaivén) y, si el NPC está justo encima, se
  confunde con su cabeza. Se resolvió con el pulso y el vaivén de 2 px
  (arriba); el "[Espacio]" la primera vez se descartó.

**Regla de coherencia:** si un tipo de objeto responde en algún lugar,
responden todos los que se ven igual. Si un tipo no tiene contenido en ningún
lado (bancos, papeleras, plantas, farolas, grafitis, buzones, hidrantes), no
responde ninguno.

### `AnxietyPuzzle` (`global/anxiety_puzzle/`) — el Rompecabezas de la Ansiedad
Minijuego para los momentos en que Alice se bloquea: tiene que armar su
respuesta eligiendo palabras desordenadas antes de quedarse en blanco.

- **Datos:** cada puzzle es un `AnxietyPuzzleData` (`.tres`): `phrases`
  (clave del resultado → palabras en orden), `extra_words` (distractores que
  no llevan a ningún lado), `prompt`, `time_limit` (20 s) y
  `mistake_penalty` (1,5 s).
- **Idiomas:** las palabras *son* el puzzle, así que no se traducen una a una
  (en inglés la frase tiene otro orden y otro número de palabras). Cada
  `.tres` en español tiene su versión `*_en.tres` al lado, enlazada en
  `translations` (`{"en": ...}`); `run()` elige la del idioma actual con
  `for_current_language()`. Las claves de `phrases` tienen que ser las mismas
  en las dos versiones, porque el timeline ramifica por ellas. Ver §12.
- **Cómo se juega:** las palabras de todas las respuestas, los distractores y
  "(...)" flotan mezclados (`ThoughtWord`: texto m3x6 sin caja, flota a su
  ritmo y tiembla más cuanto menos tiempo queda; la que tiene el foco se
  pinta amarilla y se queda quieta). Flechas para moverse, Espacio o clic
  para elegir. Cada palabra elegida va a la frase de abajo. Si ninguna
  respuesta empieza así, la frase tiembla en rojo, se desarma, todas las
  palabras se vuelven a mezclar en sitios nuevos y se pierde
  `mistake_penalty`. "(...)" o quedarse sin tiempo devuelven `"silence"`.
- **Pistas** (con 12 s y sin ayuda era casi imposible adivinar la frase):
  arriba se muestra `prompt`, un pensamiento de Alice que dice *qué* podría
  decir pero no *cómo* ("¿Le digo la verdad... o que estoy bien?"). Y
  después de cada error, la primera palabra de cada respuesta parpadea en
  amarillo mientras las palabras se reacomodan.
- **El reloj corre desde que aparecen las palabras** en los puzzles reales
  (estación y Leo). Abajo sigue la línea fija con los controles ("Flechas:
  elegir · Espacio: decir · (...): callarse"). Antes esperaba a la primera
  tecla, porque en el tercer playtest el tiempo se acababa antes de entender
  cómo se jugaba; ahora eso lo enseña el ensayo del espejo (`relaxed`, sin
  reloj), así que la presión empieza en el acto.
- **Pensamientos que cambian** (feedback de un comentario en YouTube): en los
  puzzles reales (no en el espejo), cada 1,4–3,2 s (más rápido cuanto menos
  tiempo queda, con un margen al azar para que no tenga ritmo) un distractor
  se desvanece y vuelve en otro sitio como otro pensamiento. Solo cambian los
  distractores: las palabras de las respuestas y "(...)" nunca cambian, así
  que el puzzle siempre se puede resolver. La palabra con el foco tampoco
  cambia (es la que Alice está agarrando). Los pensamientos salen de los
  `extra_words` del puzzle más `INTRUSIVE_THOUGHTS` en `anxiety_puzzle.gd`
  ("¿Me puedo ir a casa?", "Me tengo que ir.", "Todos me miran."...), que
  pasan por `tr()` y están traducidos en `game_text.csv`. Uno de ellos ya
  está en la nube al abrir (`INTRUSIVE_AT_START`). Elegir uno es un error
  como cualquier distractor.
- **Dónde cae cada palabra** (`_place_word`): prueba 80 sitios al azar y se
  queda con el primero que no toca a ninguna otra palabra (con `WORD_GAP` de
  margen). Si no encuentra ninguno, barre toda la nube en una rejilla y elige
  el sitio que menos se solapa (`_overlap_score`: que se pisen las letras
  pesa mucho más que estar demasiado cerca). Antes se quedaba con el último
  sitio que había probado, y con la nube llena un pensamiento que cambiaba
  podía caer encima de otra palabra (pasaba en ~1 de cada 10 cambios).
- **Aviso sin distractores:** si un puzzle real llega sin `extra_words`,
  `run()` lo avisa con `push_warning`. El editor se los borró más de una vez
  (la última, en el commit del espejo).
- **Ojo con el editor:** al guardar los `.tres` de los puzzles desde Godot se
  perdieron una vez los `extra_words` (y el commit los llevó así). Si en el
  juego no aparecen los distractores, revisa que la línea siga en el
  archivo.
  Los bordes se cierran con una viñeta pixelada (`anxiety_vignette.gdshader`).
- **Desde Dialogic:** la timeline emite `[signal arg="anxiety_puzzle:<id>"]`
  y después ramifica con `if {anxiety_result} == "<clave>":`. La escena decide
  qué puzzle es cada id (un diccionario `ANXIETY_PUZZLES` en `leo_store.gd` y
  en `unknown_station.gd`) y llama a
  `AnxietyPuzzle.play_from_dialogic(self, data)`. Esa función pone
  `Dialogic.paused = true` dentro del handler de la señal: Dialogic no pasa al
  siguiente evento hasta que vuelve a `false` (`DialogicGameHandler.handle_event`
  hace `await dialogic_resumed`). Instancia el puzzle, hace `await
  puzzle.run(data)`, guarda el resultado con
  `Dialogic.VAR.set_variable("anxiety_result", ...)` y reanuda.
- **`hint_from_start`** (tutorial): la primera palabra de cada respuesta
  parpadea apenas abre el puzzle, no solo después de un error. Lo usa el
  primer ensayo del espejo (`practice_store`).
  `anxiety_result` está declarada en las variables de Dialogic
  (`project.godot`).
- Es una `CanvasLayer` en la capa 2: por encima de la caja de Dialogic (capa
  1, así el clic no lo atrapa su capa de input) y por debajo del fundido.
- **Frase que no lleva a ningún lado:** la frase tiembla en rojo,
  "No... así no." sale **arriba, en lugar de la consigna**, durante 1,2 s
  (`_show_stumble_line`) y las palabras se reacomodan enseguida, sin dejar
  de poder elegir. Entre el 2026-11-15 y el 2026-11-17 salía grande en el
  centro y tapaba la selección, y al usuario le pareció injusto tras un
  error. Si llegan dos errores seguidos, la consigna vuelve solo cuando acaba
  el último (`_stumble_token`). **Solo cuando se acaba el tiempo** sale la
  frase grande en el centro (`_show_center_line`, 72 px).
- **Al abrir ya hay una palabra elegida** (2026-11-14, playtest: "al empezar
  no hay ninguna palabra seleccionada"): la primera en orden de lectura
  (arriba a la izquierda, por filas de una palabra de alto), nunca "(...)"
  (`_focus_first_word`). Lo mismo tras elegir una palabra o tras un error.
  Para que el Espacio de cerrar el diálogo anterior no la diga sin querer,
  Espacio no hace nada los primeros `OPEN_GRACE` (0,5 s) tras el fundido.
  Antes no había foco hasta la primera flecha.
- **Flechas predecibles** (2026-11-14): la navegación de foco de Godot
  saltaba a palabras inesperadas. `_input` intercepta las flechas antes que la
  GUI y `_word_towards` elige la palabra más cercana en esa dirección:
  puntuación = distancia hacia delante + distancia de lado × `NAV_SIDE_WEIGHT`
  (2), así gana la que está más alineada. Arriba/abajo exige al menos media
  palabra de altura de diferencia (una palabra unos píxeles más alta está en
  la misma fila). Si no hay ninguna en esa dirección, el foco no se mueve.
- **El tiempo se nota sin reloj** (2026-11-14): además de la viñeta que se
  cierra y los pensamientos que cambian más rápido, la viñeta **late** como
  un corazón (doble golpe, `_heartbeat_pulse`): de 1 a 2,1 latidos por
  segundo (`BEAT_RATE`) y más hondo cuanto menos tiempo queda (`BEAT_DEPTH`,
  uniform `beat` del shader). Las palabras tiemblan hasta 2 píxeles de arte al
  final (`MAX_JITTER` 6 px de pantalla en `thought_word.gd`; antes 3).
- **Cuando se acaba el tiempo** (2026-11-14): `_run_out_of_time()` hace que
  las palabras bajen y se desvanezcan (0,5 s) y luego muestra **en el centro**,
  igual que la de fallo (desde el 2026-11-15), una frase de `TIME_OUT_LINES`
  (8 de Guion: "(Se queda en blanco.)", "(Un nudo en la garganta. Nada.)"...),
  al azar y nunca la misma que la vez anterior en cualquier puzzle
  (`_next_time_out_line`, con una `static var`). Tras `TIME_OUT_HOLD` (1,4 s)
  devuelve `"silence"`. Antes el puzzle se cerraba de
  golpe y el tester creyó que el juego no registraba sus pulsaciones. Elegir
  "(...)" sigue cerrando directamente.
- **"Bueno... gracias." con Leo es a propósito:** es la respuesta `"leave"` de
  `leo_number` (dos palabras: Alice se despide sin pedirle el número), con su
  rama en `leo_store_checkout.dtl`. No es un fallo.
- **`relaxed`** (ensayo): sin reloj, sin viñeta que se cierra y sin perder
  tiempo por error. Solo se sale eligiendo una frase o "(...)". Lo usan los
  tres ensayos del espejo.
- **El ensayo del espejo es el tutorial.** Antes de salir, Alice practica
  frente al espejo del baño (`apartment/bathroom_glass`), con tres puzzles
  `relaxed` en `scenes/prologue_scene/puzzles/practice_*.tres` que lanza
  `apartment.gd`. Cada uno enseña una cosa y sube un poco la dificultad:
  1. `practice_store`: "¿Tienen comida para gatos?". Tres palabras, sin
     distractores, con `hint_from_start`. Enseña a armar una frase.
  2. `practice_directions`: "Perdone, ¿dónde está el metro?", con
     distractores y una respuesta torpe, `fumble` = "¿Dónde estoy yo?", a la
     que Alice se ríe de sí misma. Enseña que equivocarse tiene respuesta.
  3. `practice_are_you_ok`: "¿Estás bien?", con `truth` ("No mucho, la
     verdad."), `lie` ("Sí, estoy bien.") y el silencio, que tiene su propia
     respuesta ("Callarse también es una respuesta. Supongo."). Enseña que
     callarse es una opción real, y anticipa la pregunta de Leo.
- **Los puzzles reales son más difíciles** porque el espejo ya enseñó la
  mecánica: el trabajador tiene 18 s, "¿Estás bien?" de Leo 15 s y el del
  número 14 s, los tres con 2 s por error y dos distractores más que antes.
  Si resultan demasiado duros, se ajustan en sus `.tres` (`time_limit`,
  `mistake_penalty`, `extra_words`).
- **Guiños al ensayo:** si falla con el trabajador, Alice piensa "En el
  espejo era más fácil...". Cuando Leo pregunta "¿Estás bien?", antes del
  puzzle: "(la pregunta del espejo... pero el espejo no la miraba así)".
- **Cuándo usarlo** (regla de diseño): la primera interacción importante con
  cada personaje, las confesiones (pedir un número, admitir que no sabe su
  dirección) y la respuesta siguiente a un error social (si en un menú
  normal eligió mentir o callarse). El resto son menús normales, para no
  gastar la mecánica.

### `ThoughtTrigger`
Pensamiento espontáneo de Alice. Se dispara al pisar el área, o desde código
con `show_thought(player)`, que se puede esperar:

```gdscript
await thought_trigger.show_thought(player)
```

Muestra sus líneas (`thought_lines`, o `thought_text` si no hay) en la **nube
de arriba**, con `ThoughtBox.say`. `display_duration` es la base en segundos de
cada línea, a la que se suma un poco por letra. Con `monitoring = false` solo
se dispara desde código. Con `wait_for_current` espera a que termine la nube
que esté en pantalla, en vez de reemplazarla. Con `skip_visits` ignora las
primeras entradas: con 1, solo salta la segunda vez que Alice pasa ("Ya pasé
por aquí. Creo.").
- Antes dibujaba un globo de texto sobre la cabeza de Alice, en una
  `CanvasLayer` propia. Se quitó para que el juego tenga solo dos lenguajes:
  abajo conversación, arriba mente.

### `LightsContainer`
Parpadeo aleatorio de luces + `fade_out_lights(duración)` y `turn_off_lights()`.
Hoy solo lo usa el vagón (`metro_train_interior`), con parpadeo real y la
cutscene del sueño. Las estaciones ya no lo llevan (tenían la lista vacía).

### Iluminación estándar del metro (`global/lights/`)
Desde el 2026-11-18, todas las estaciones de metro usan la misma luz
(variante «A′» del andén de la plaza, elegida por el usuario): luz pareja y
legible, sin puntos quemados por solapamiento ni agujeros negros. La usan
`metro_stations`, `unknown_station` y `plaza_metro`. **El vagón
(`metro_train_interior`) no**: sus luces son la del túnel por las ventanas
y las anima la cutscene del sueño.

- **`global/lights/metro_lamp.tscn`**: una `PointLight2D` con
  `light_fluorescent.tres` (degradado radial de caída rápida), color
  (0.85, 1, 0.97), energía 0.45, escala (2, 1.6). **Una instancia por lámpara
  pintada** (el tile de lámpara de `metro_assets_sheet`, atlas (14..17, 1)),
  dentro de `LightsContainer`. En la instancia solo se cambian `position`,
  `scale` y `energy` (son de la raíz: no hace falta Editable Children).
- **Posición:** centro de la lámpara + 38 px hacia abajo, para que el charco
  caiga en el suelo. Excepción: las lámparas de la pared alta sobre las vías
  (andén de la plaza) van casi en la lámpara (+13 px).
- **Tamaño según la vecina:** el radio visible es ≈ 38,4 px por unidad de
  escala. Con `d` = distancia a la lámpara más cercana:
  - si `d` ≥ 140 px: escala x = clamp(0,45 × d / 38,4, 2, 4);
  - si `d` < 140 px (lámparas muy juntas): escala x = 0,45 × d / 38,4, sin
    mínimo, para que no se solapen;
  - escala y = 0,8 × x (en la pared alta sobre las vías, ≈ 0,6 × x);
  - energía 0.45 si la escala x ≤ 2,5; 0.4 si es mayor.
- **Relleno base:** el `DarkFilter` (`CanvasModulate`) de cada estación en
  azul pizarra **(0.6, 0.65, 0.74)**. El relleno viene de ahí, no de sumar
  halos grandes.
- `light_soft_wide.tres`: versión ancha y suave para luces que no son
  lámparas (la del tren y la de la escalera en `plaza_metro`).
- **No son lámparas y no siguen la regla:** `SignLight` (el resplandor del
  cartel) y `GreenTurnstileLight` (la usa `turnstiles.gd`: no cambiarle el
  nombre ni sacarla de `LightsContainer`).
- Para una estación nueva: una `MetroLamp` por lámpara pintada, con la
  regla de arriba, y el `DarkFilter` con el color estándar.


### `WalkingNPC` (`global/npcs/scripts/walking_npc.gd`)
`CharacterBody2D` para un NPC que camina de un punto A a un punto B en una
cutscene. Misma lógica de animación por dirección que `Player`
(`idle_`/`walk_` + `front`/`back`/`side`), pero **sin** input ni física propia
— el movimiento lo decide quien lo controla.

```gdscript
npc.face_direction(direction)         # gira y aplica el idle correspondiente
await npc.walk_to(target_position)    # Tween en línea recta + animación walk_*

# El propio NPC decide a dónde ir — la escena solo le pasa "el objetivo".
npc.resolve_approach_point(target_position)

npc.start_patrol()        # ronda por patrol_points (se coloca en el primero)
npc.stop_patrol()         # se para donde está, también a mitad de tramo
npc.start_patrol(true)    # vuelve a la ronda andando desde donde está
```

**`pause_near_player`** (px, 0 = nunca): si Alice se acerca a esa distancia
mientras camina, el NPC pausa su tween, la mira, y sigue cuando ella se aleja
`PAUSE_HYSTERESIS` (12 px) más. Hoy solo lo usa el gato de la calle (20 px):
los peatones no se paran por cercanía, solo cuando Alice pulsa Espacio (ver
la calle).

**Reposo lateral:** los peatones y el gato tienen un tag `idle_side` de un solo
frame en su `.aseprite` (el frame 5, el paso con las piernas juntas del
`walk_side`). Mientras está detenido, el NPC sigue mirando a Alice si ella lo
rodea. Si un sprite no tiene el reposo de esa dirección, `face_direction` usa
`idle_front`, y si tampoco existe, detiene el sprite, para que nunca quede
caminando en el lugar.

`resolve_approach_point()` es lo que hace configurable el destino **desde el
NPC**, no desde la escena que lo llama:

```gdscript
@export use_fixed_approach_point   # true: ignora el target y usa su propio marcador
@export approach_offset            # false (por defecto): target + este offset
```

Si añades un hijo `Marker2D` llamado **`ApproachPoint`** al NPC, ese es el punto
fijo que se usa con `use_fixed_approach_point = true` — colócalo donde quieras
en el editor, relativo a dónde arranca el NPC. Es opcional: si no existe, el
switch simplemente no hace nada (`get_node_or_null`, mismo patrón defensivo que
`has_animation()`).

Para un NPC simple, instáncialo directo (como hace `worker_npc.tscn`) y ponle
su propio `SpriteFrames` + opcionalmente su `ApproachPoint`. Para uno con
comportamiento extra, haz `extends "res://global/npcs/scripts/walking_npc.gd"`
— mismo patrón que `InteractableArea`.

> **No es para todo movimiento de NPC.** Wilson (`scenes/prologue_scene/wilson/wilson.gd`)
> usa `NavigationAgent2D` para perseguir a Alice esquivando obstáculos — un
> mecanismo distinto (pathfinding, no un punto fijo). No lo fuerces dentro de
> `WalkingNPC`; si aparece un tercer NPC con pathfinding, esa lógica se
> extrae aparte, no aquí.
>
> La animación `meowing` de Wilson lleva el texto "MEOW!" dibujado en los
> cuadros, así que `wilson.gd` pone `flip_h = false` al entrar en ese estado.
> Si no, heredaba el volteo del último paso de lado y el texto salía espejado.

---

## 6. Diálogos (Dialogic)

### ¿Caja o nube?
**Abajo, conversación; arriba, la mente de Alice.**
- **Caja de abajo** (style `dialogue`): todo lo que viene de un `.dtl`, es
  decir conversaciones y monólogos (los íntimos, sin retrato). Frena a Alice y
  pide Espacio. Las ilustraciones aparecen solo acá.
- **Nube de arriba** (style `thought`, `ThoughtBox`): los pensamientos del
  suelo (`ThoughtTrigger`), los bordes del mapa (`BoundaryArea`) y las líneas
  de objetos inertes y NPCs de fondo (`RemarkInteractable`). Nunca frena y se
  va sola.
- **Interludio en negro** (`FadeTransition.transition_with_interlude`): solo
  para saltos de lugar o de tiempo.
- No se cambia de layout a mitad de una conversación: un pensamiento de Alice
  dentro de una escena va en la caja de abajo, como monólogo. Si alguna vez
  hace falta, en un `.dtl` existe `[style name="Thought"]` ...
  `[style name="Dialogue"]`.
- Reglas descartadas, para no repetirlas: "si aporta a la historia, caja; si
  es suelto, globo" (parecía arbitrario y el globo se leía peor) y "todo lo de
  Espacio en la caja de abajo" (demasiadas pulsaciones para objetos inertes).

- Personajes en `dialogic/characters/*.dch`, diálogos en `dialogic/timeline/**/*.dtl`
- Se lanzan con `Dialogic.start("identificador")`
- **Formato de línea:** siempre `personaje: texto`, con el identificador del
  `.dch` (`alice`, `metro_worker`, `wilson`). Las acciones van igual, entre
  paréntesis: `alice: (suspira)`. Sin los `:`, Dialogic muestra la línea entera
  como narración (literalmente "alice (suspira)"); con un nombre que no existe
  (`Guardia:`) se inventa un personaje temporal en vez de usar el real.
- **Acotaciones de otros = narración.** Lo que hacen Wilson u otras personas no
  lleva nombre: la línea va sin `personaje:`, entre paréntesis y con mayúscula,
  `(Wilson maúlla, impaciente.)`. Dialogic la muestra sin la etiqueta de
  nombre. Antes iban como `wilson: maúlla...` y parecía que hablaba el gato.
  Ojo: en una línea de narración **no uses `:`**, porque Dialogic tomaría lo que
  hay antes como nombre de un personaje temporal.
- **Cada pulsación tiene que aportar algo.** Una acción de Alice no va sola en
  su línea: va delante de lo que dice (`alice: (revisa el interior) Auriculares...
  no están.`). Las pausas que importan se mantienen sin pedir otra pulsación,
  con `[pause=0.8]` dentro de la línea (`alice: ...[pause=0.8] No. Mejor no.`).
  Si el jugador pulsa durante la pausa, se salta como el resto del texto. Así el
  ordenador pasó de 18 a 12 pulsaciones, la mochila de 13 a 8, y el resto en
  proporción, sin perder ningún silencio con función.
- Mantener Espacio pulsado no avanza más de una línea, porque Dialogic usa
  `is_action_just_pressed`.

> **⚠️ El identificador lo decide Dialogic, no tú.** Al reescanear, registra el
> nombre del archivo pelado (`unknown_station_worker`) y solo añade el prefijo de
> carpeta si hay colisión (`metro/ticket_store`). Mira siempre `dtl_directory`
> en `project.godot` para saber el nombre real.
> Si borras un `.dtl` y lo vuelves a crear o restaurar, Dialogic lo registra
> de nuevo **con el nombre corto** (`test_tv` en vez de `apartment/test_tv`), y
> la escena que lo llamaba por el nombre viejo da "There was an error loading
> this timeline". Después de restaurar, revisa `dtl_directory` y **cambia la
> escena al nombre nuevo**. No corrijas `project.godot` a mano con el editor
> abierto: el editor guarda su copia en memoria y lo vuelve a pisar. Así
> quedaron `test_tv`, `rotten_food` y `elevator` en la casa.

**Comunicación diálogo → juego:** el evento `[signal arg="lo_que_sea"]` llega a
`Dialogic.signal_event`. `GameManager`, `pickable_item`, `lamp_interactable` y
`wilson` están escuchando.

> **⚠️ `Dialogic.timeline_ended` es global**, no por diálogo. Conéctate siempre
> con `CONNECT_ONE_SHOT` o comprobando cuál terminó, o cualquier diálogo
> disparará tu callback.

### Ilustraciones de Alice (retratos)

Las ilustraciones de Alice son retratos de Dialogic en `alice.dch`. **Solo se
muestran en momentos de quiebre emocional**, no en cada línea: como mucho una por
escena y dos o tres cambios de expresión por conversación. Dentro de los
pensamientos (la nube de arriba, `ThoughtBox`) y de los interludios en negro de
`FadeTransition` no van.

- **Archivos:** `dialogic/portraits/alice/alice_<expresión>.png`. Es la única
  excepción a la regla "todo en `.aseprite`", porque son ilustraciones en alta
  resolución, no pixel art. Los originales (2000×3000) no entran en el proyecto:
  se recortan de la cabeza a un poco más arriba de las rodillas y se reducen a
  **unos 640 px de alto**. La imagen queda casi a tamaño real en pantalla y el
  filtro nearest del proyecto no la deforma.
- **En `alice.dch`** cada retrato tiene `scale: 0.832` (640/768 de alto de
  pantalla, porque el contenedor escala por altura) y `offset: (40, 0)`.
- **En el timeline:** `join alice (nervous) leftmost` antes de la línea, y
  `leave alice` cuando pasa el momento. Para cambiar de expresión sin salir,
  usa `update alice (worried)`. Siempre en `leftmost`: en otras posiciones la
  ilustración tapa el cuadro de texto. Un `join alice` sin expresión usa
  `default_portrait` (`nervous`), así que no dejes joins sueltos.
- **Expresiones** (archivo original → id): Nervious → `nervous`, Neutral →
  `neutral`, Worried → `worried`, Scare → `scared`, Shocked → `shocked`,
  Chill_Relax → `relaxed`.
- **Dónde aparecen hoy:**

  | Timeline | Momento | Expresión |
  |---|---|---|
  | `apartment/room_desk` (sin quest) | la mañana, el café | `relaxed` |
  | `apartment/wilson_plate` (paso 0) | el plato vacío: molestia, no pánico | `worried` |
  | `apartment/kitchen` (paso 1) | la nevera vacía | `nervous` |
  | `apartment/room_desk` (paso 2) | no hay delivery → tiene que salir → "Por ti lo haré" | `shocked` → `worried` → `neutral` |
  | `apartment/alice_backpack` | le faltan auriculares, cartera, zapatos | `nervous` |
  | | ya tiene todo: "Ojalá me emocionara" → "Lo voy a hacer" | `worried` → `neutral` |
  | `apartment/alice_headphones` | los encuentra | `neutral` |
  | `apartment/alice_shoes` | "sonríe a pesar de todo" | `relaxed` |
  | `apartment/bathroom_glass` | las ojeras → "Nadie va a mirarte tan de cerca" | `scared` → `nervous` |
  | `apartment/bathtub` | el patito de hule | `relaxed` |
  | `apartment/wilson_stay_home` | en la puerta, deja a Wilson | `worried` |
  | `unknown_station_worker` | se despierta sobresaltada ("¡Ah!") | `shocked` |
  | `unknown_station_lost_phone` | "Esta no es mi parada" → "No, no, no..." → "Genial, Alice" | `worried` → `scared` → `worried` |
  | `unknown_station_worker_dismissive` | rama `ask`: "Lo dije. Le pregunté a alguien." / si no: "Qué vergüenza" | `relaxed` / `nervous` |
  | `leo_store_greeting` | se queda paralizada en la puerta | `nervous` |
  | `leo_store_checkout` | "E-eh... hola" (sale antes del rompecabezas) | `nervous` |
  | | rama verdad: "Para mi gato. Wilson." | `neutral` |
  | | rama mentira: "se queda en blanco" → "me perdí" | `shocked` → `nervous` |
  | | alivio por el camino → "no sabe el nombre de su calle" | `relaxed` → `nervous` |
  | | Leo le da el número sin que ella lo pida: "¿En serio?" | `shocked` |
  | | le da su número habiéndolo pedido: "con número incluido. Me gusta." | `relaxed` |

  Antes de cada `[signal arg="anxiety_puzzle:..."]` va un `leave alice`: el
  rompecabezas es un `CanvasLayer` (capa 2) encima de Dialogic (capa 1), y la
  ilustración quedaría debajo de la nube de palabras.

### Ilustraciones de Leo

Igual que las de Alice, pero **siempre en `rightmost`**, enfrente de ella, con
`offset: (-40, 0)` y `scale: 0.832` en `leo.dch`. Archivos:
`dialogic/portraits/leo/leo_<expresión>.png` (340×640, recortadas de las
originales de 1333×2000 con el mismo marco para las tres: de la cabeza hasta
y=1300 del original, un poco más arriba de las rodillas como Alice, así los
dos se ven a la misma escala y no saltan al cambiar de expresión).

- **Expresiones:** `friendly` (la mano abierta, por defecto), `thinking` (la
  mano en la barbilla) y `laughing` (se ríe con la mano en la nuca).
- **A diferencia de Alice**, Leo se queda en pantalla durante toda su
  conversación: entra en su primera línea, cambia de expresión con
  `update leo (...)` y sale con `leave leo` antes de cada rompecabezas y al
  final de cada timeline.
- **Dónde:** `leo_store_greeting` ("¡Bienvenida!", `friendly`),
  `leo_store_checkout` (`friendly` al presentarse; `laughing` en "Buen plan",
  "Es broma", "Me pasa a veces", "¿No sabes el nombre de tu calle?", "Buena
  excusa" y "Alice-sin-nombre-de-calle"; `thinking` en "¿Se te escapó la
  voz?", "¿sabes bien la dirección?", "¿Mi número?" y "Bueno..."), y
  `leo_store_farewell` (`friendly`).

### Ilustraciones de Lía

Como Leo: **siempre en `rightmost`**, enfrente de Alice, se queda en pantalla
toda la conversación (`join` en su primera línea, `update lia (...)` para
cambiar de expresión, `leave lia` antes de que se vaya o termine el timeline).

- **Archivos:** `dialogic/portraits/lia/lia_<expresión>.png` (332×480). Las
  originales son de 2000×3000 y Lía ocupa x 674–1403, y 74–1550. Se recortan
  las tres con el mismo marco (x 650–1430, y 54–1180: de la cabeza a un poco
  más arriba de las rodillas, como Alice y Leo) y se reducen a 480 px de alto.
- **Volteadas en el juego, no en el archivo:** en los dibujos Lía mira a la
  derecha, así que cada retrato de `lia.dch` lleva `mirror: true` para que mire
  hacia Alice. Si llegan ilustraciones nuevas, se guardan tal cual y se activa
  `mirror`.
- **Más pequeña que los adultos:** `scale: 0.625` (480/768 de alto de pantalla)
  en vez del 0.832 de Alice y Leo, porque es una niña de siete años; la cabeza
  le queda más abajo que la de ellos. `offset: (-40, 0)` como Leo.
- **Expresiones** (archivo original → id): HiPaint_…186581 (boca abierta, mano
  en la boca, mira arriba) → `surprised`; HiPaint_…200362 (llora) → `crying`,
  por defecto; HiPaint_…207882 (sonríe con la mano abierta) → `happy`.
- **Dónde:** `plaza_lia_meet` (`crying` cuando pide ayuda, `surprised` en
  "¿En serio?", las preguntas y cuando ve a Alice bloqueada, `happy` al
  ponerse en marcha, al respirar con Alice y al reírse "¡Qué tonta!") y
  `plaza_lia_fountain` (`crying` en "¿Y si no aparece?" y "¿Te vas a ir?",
  `surprised` en "¿Eso es un gato?" y "¡MAMÁ!", `happy` al dibujar y al darle
  el dibujo). Sale con `leave lia` justo antes de `lia_leaves`. Las líneas
  sueltas con los ayudantes (`plaza_ice_cream`, `plaza_dog_lady`,
  `plaza_teen`) siguen sin retrato.

---

## 7. Convenciones

**Nada de `AnimationPlayer`.** Todo lo temporal se hace con `Tween` + `await`.

**Cabeceras de sección** en todos los scripts:
```gdscript
# =========================
# Nombre de la sección
# =========================
```

**Las escenas dirigen, las piezas avisan.** Un `InteractableArea` no debe buscar
nodos hermanos con `get_parent().get_parent()...` — emite una señal y que la
escena decida. Así la pieza sigue funcionando cuando reorganizas el árbol.

**Ocultar un nodo no lo desactiva.** `hide()` no apaga colisiones ni `monitoring`:
tendrás muros invisibles y carteles fantasma. Apágalo todo junto:

```gdscript
npc.visible = activo
npc.process_mode = Node.PROCESS_MODE_INHERIT if activo else Node.PROCESS_MODE_DISABLED
colision.set_deferred("disabled", not activo)
area.set_deferred("monitoring", activo)
```

**La visibilidad es jerárquica.** `hijo.visible = true` no sirve de nada si el
padre está oculto. Al ocultar un contenedor te llevas por delante todo lo de
dentro.

**Los `.uid` se commitean** junto a su `.gd`/`.dtl`/`.dch`. Si faltan, salen
warnings de *invalid UID*. Si creas archivos con el editor abierto, los warnings
desaparecen con **Project → Reload Current Project**.

---

## 8. El vagón del metro (la escena más compleja)

### Antes de subir: la llegada del tren (`metro_stations.gd`)
El tren entra en la estación por dos caminos, el primero que ocurra
(`_call_train()` solo actúa una vez):
- **`TrainTriggerArea`**: la franja de 20 px junto a las vías. Si Alice se
  acerca al borde, el tren llega en el acto.
- **`PlatformArea`**: cubre todo el andén. Al entrar, el tren llega a los
  `platform_wait` segundos (5 por defecto), aunque Alice no se mueva. Antes
  solo existía la franja, y un jugador que esperaba quieto en el andén se
  quedaba sin tren.

**La llegada se ve.** `_call_train()` espera a que termine cualquier diálogo
abierto, bloquea a Alice, hace entrar el tren y lleva la cámara hasta donde
va a frenar (`station_position_x` + `train_view_offset`, 1 s). Se queda hasta
que el tren para y abre las puertas (1,6 s más), vuelve a Alice (0,8 s), la
desbloquea y recién ahí lanza `metro_is_entering_station` ("Ahí viene").
Usa `Player.pan_camera_to()` / `reset_camera()`, igual que la torre de la
calle.

**Al subir**, `metro_train.gd` cierra las puertas (1 s) y, apenas el tren
arranca, funde al vagón tras `fade_after_leaving` (1,2 s). Antes esperaba a
que el tren saliera del todo (`arrival_time × 1,5`) y quedaban unos 10 s de
andén vacío, con Alice ya dentro, que parecían un cuelgue. El tren de la
terminal, sin `next_scene_path`, sigue saliendo entero.

Al entrar al vagón, el primer pensamiento empuja a sentarse: "Ya estoy
dentro... Ahora no puedo echarme atrás." / "Me tiemblan las piernas. Mejor
me siento." Antes nada indicaba que había que buscar un asiento.

`metro_train_interior.tscn` se usa **dos veces sin recargarse**: el mismo nodo se
transforma en sitio, así Alice nunca se mueve del asiento.

**Alice vive en `Train/NPCS`**, el contenedor con y-sort de los pasajeros y
el trabajador, para ordenarse contra ellos. Antes era hija directa de la raíz,
que no tiene y-sort, y como el tren se dibuja antes, el trabajador siempre
quedaba debajo de ella aunque pasara por delante. `_empty_the_car()` salta a
Alice igual que al trabajador. El trabajador llega con `approach_offset =
(-26, 6)`: se frena un poco más allá de Alice (antes −14, se le encimaba) y
6 px más abajo, en el pasillo, para dibujarse delante de ella sentada.

**Los pasajeros piensan** (`AmbientThought` como hijo de cada uno, así se van
con ellos cuando `_empty_the_car()` los oculta y desactiva). Son la misma gente
del andén, y lo dicen: el lector ("Sigue con su periódico. Ni levantó la
vista."), el de auriculares ("El chico de los auriculares. Subimos en la misma
estación." / "Ni me ha visto. Mejor.") y el de la ventana ("Mira por la ventana
como si fuera la primera vez." / "...O como si no quisiera mirar a nadie.").
Ojo: los pasajeros están sentados en la fila de asientos. Desde el pasillo
(mirando hacia arriba) gana el pasajero, que está a ~14 px; pegada a la fila
puede ganar un asiento, y sentarse dispara el viaje.

```
_setup_boarding_mode()      tren en marcha, pasajeros, asientos activos,
                            trabajador y puerta ocultos
        │
   se sienta → SeatInteractable emite player_sat_down
        │
_fall_asleep()              pensamiento → sit_sleepy → sit_asleep →
                            oscurece + para el traqueteo + baja el audio
        │
_setup_awakening_mode()     (con la pantalla a oscuras) vacía el vagón,
                            apaga luces, saca al trabajador y abre la puerta
        │
_wake_up()                  el vagón se aclara + se enciende ExitLight
                            → el trabajador CAMINA hasta el asiento (WalkingNPC.walk_to)
                            → se gira hacia Alice
                            → Dialogic.start(worker_timeline), Alice sigue en
                              sit_asleep hasta que el diálogo lo cambie
                            → a mitad del diálogo, [signal arg="alice_wakes_up"]
                              dispara awakening_animation (sin thought bubble)
                            → sigue el resto de la conversación
                            → Alice mira al frente y recupera el control
```

El trabajador **no** es un `InteractableArea`: es una instancia de
`WalkingNPC` (ver sección 5), con su propio `SpriteFrames` en
`scenes/prologue_scene/worker/worker_npc.tscn`. El diálogo ya no depende de
que el jugador interactúe: se dispara solo dentro de `_wake_up()`, así que
siempre ocurre antes de devolver el control.

**Todo el despertar lo cuenta Dialogic, no pensamientos flotantes.** El
timeline (`dialogic/timeline/metro/unknown_station_worker.dtl`) lleva un
`[signal arg="alice_wakes_up"]` justo en la línea donde Alice abre los ojos.
El script espera exactamente ese evento (`Dialogic.signal_event`, no un
`ThoughtTrigger`) antes de cambiar su animación:

```gdscript
Dialogic.start(worker_timeline)
await _wait_for_signal("alice_wakes_up")
sleeping_player.play_animation_backwards(awakening_animation)
await Dialogic.timeline_ended
```

`_wait_for_signal()` ignora cualquier otro `[signal]` que se dispare mientras
tanto — recuerda que `Dialogic.signal_event` es global (sección 6), así que
sin ese filtro un evento de OTRO diálogo activaría esto por error.

> **Nota de arte:** el `SpriteFrames` del trabajador es un placeholder (un
> único frame estático repetido en las 6 animaciones). Cuando dibujes su
> spritesheet de caminar en Aseprite con esos mismos nombres, sustituye ese
> recurso vía AsepriteWizard — el código ya funciona con `has_animation()`
> guardado, igual que `Player`.

Todo se ajusta desde el inspector del nodo raíz: grupos **Falling Asleep** y
**Awakening**.

**Cabecear y dormirse:** después de `sleepy_delay`, Alice hace `sit_sleepy`
durante `sleepy_loops` vueltas completas (1 en la escena; el script trae 2 por defecto) y recién ahí pasa a
`sit_asleep`, que queda en bucle. Se cuentan vueltas con
`Player.wait_animation_loops()` (que calcula lo que dura una vuelta con los tiempos de sus frames), no con un tiempo fijo: con un tiempo fijo
(`asleep_delay`, 1,5 s) el cabeceo, que dura 1 s por vuelta, se cortaba a la
mitad de la segunda.

**Despertar:** con la señal `alice_wakes_up`, `_come_to()` reproduce
`awakening_animation` (`sit_sleepy`) al revés **una sola vez** y luego deja a
Alice quieta en `awake_animation` (`sit_down`), sentada y despierta. Antes la
reproducía al revés en bucle, sin fin. No se espera: el diálogo sigue mientras
tanto, y si la escena ya la movió, no pisa su pose.

**Salida y asientos se apagan del todo** (`_set_area_active`: visibilidad,
`monitoring` y `monitorable`). Antes la salida se ocultaba y se le apagaba
solo `monitoring` mientras Alice subía: seguía siendo detectable, el
`InteractionDetector` de Alice la encontraba igual y con Espacio en la puerta
se saltaba toda la secuencia de dormirse. Lo mismo pasaba con los asientos
después de despertar (podía volver a sentarse y dormirse). Regla: para que
Alice no pueda usar un área, también `monitorable = false`.

---

## 9. La estación desconocida (`unknown_station.tscn` + `.gd`)

Alice llega aquí dormida-recién-despierta, y se va sola (a pie) por las
escaleras. Todo el guion pasa por Dialogic, sin `ThoughtTrigger` para los
beats principales — **excepto** un pensamiento espontáneo puntual que sí usa
`ThoughtTrigger` a propósito (ver más abajo).

```
_on_train_trigger_area_body_entered()   Alice camina unos pasos
  o _depart_after_fallback()            o pasan `departure_fallback_time` (3 s) sin moverse
        │                               (lo primero que ocurra; `_start_departure()` lo hace una vez)
_depart_train()      metro_train.leave_station() (sin await, corre de fondo)
                      → pausa de `wait_time_for_phone_missing` (1s) para que se
                        sienta la desorientación
                      → si hay un diálogo abierto, espera a que termine
                      → Dialogic.start("unknown_station_lost_phone")
                        (incluye [signal arg="no_phone"] → GameManager.has_phone = false)
        │
[jugador libre — puede hablar con el trabajador y/o los interactuables ambientales]
        │
_on_worker_area_entered()     el InteractableArea del trabajador se dispara SOLO
                              (al entrar en rango, sin `[Espacio]`) — ver nota abajo
        │
InteractableArea.interact()   lanza su timeline_name ("unknown_station_worker_dismissive");
                               one_time_interaction = true → solo ocurre una vez.
                               Él levanta la vista ("¿Sí?") y sale el primer
                               Rompecabezas de la Ansiedad del juego (ver abajo).
                               "Irse" es simplemente que el jugador recupera el
                               control cuando el diálogo termina (Player ya hace
                               lock/unlock solo con Dialogic.timeline_started/ended)
        │
[jugador camina solo hasta ExitToStreet/ExitToStreet2 → ExitArea]
```

**El trabajador (`WorkerNPC`) dispara su diálogo por proximidad, no por botón.**
Es una excepción deliberada a la regla de siempre (`[Espacio]` para todo) —
`unknown_station.gd` escucha el `area_entered` que el propio `InteractableArea`
ya usa para mostrar el cartel, y llama `.interact()` él mismo en cuanto detecta
el `InteractionDetector` de Alice. La conexión vive en la escena, **no** en la
clase base — así el resto del juego sigue siendo siempre por botón.

```gdscript
worker_interactable.area_entered.connect(_on_worker_area_entered)

func _on_worker_area_entered(area: Area2D) -> void:
    if area.get_parent() is Player:
        worker_interactable.interact()
```

### Torniquetes (2026-11-14, playtest)
Son baldosas de `AssetsLayerSuperior` (atlas 8×8): tres torniquetes con poste
(columnas 2/6) y brazo; los dos rojos (brazo `3:8`/`4:8`) bloquean y el verde
(brazo `7:8`/`8:8`, sin colisión) deja pasar. El tester solo podía cruzar por
una franja de unos 12 px y no entendía por qué no pasaba por los rojos:
- **Paso más ancho:** la reja del trabajador (celdas `15–18`/`14` × filas
  44–47) se movió dos celdas a la derecha y el `WorkerNPC` con ella. El hueco
  entre el poste verde y la reja pasó de 24 a 40 px (Alice mide 17).
  **Ojo (2026-11-14):** después, en el editor, la reja se alargó hacia la
  izquierda (piezas 16 y 17 repetidas, desde la celda 92) y el trabajador
  volvió a x 753, así que el hueco vuelve a ser de 24 px. Lo cambió el
  usuario a propósito: no tocar.
- **Los rojos dicen algo:** `RedTurnstiles/RedTurnstileLeft` y `...Right`
  (`BoundaryArea`, 20×8 justo debajo del brazo, x 660 y 692, y 376) la
  devuelven 14 px hacia abajo con un pensamiento. Lo lleva la pieza
  `Turnstiles` (abajo).
- **El verde se distingue:** `LightsContainer/GreenTurnstileLight`, una
  `PointLight2D` verde pequeña sobre la luz del torniquete, que respira.

**`Turnstiles` (`global/turnstiles.gd`)** (2026-11-14): va en el nodo
`RedTurnstiles` de las dos estaciones, cuyos hijos son los `BoundaryArea`
de los torniquetes rojos. Al chocar con uno (en `interacted`, antes de que
lea sus líneas) le pone el pensamiento: la primera vez "Este no
funciona..." y las siguientes "Este tampoco." / "Tiene que haber uno que
funcione." (`FIRST_LINES`/`AGAIN_LINES`, cuenta compartida entre los rojos
de la escena). Si vuelve a chocar antes de 3 s (`QUIET_TIME`, p. ej. con la
flecha mantenida, que la hace rebotar cada medio segundo), la devuelve sin
pensamiento nuevo, para no tapar el que está en pantalla. También hace
respirar su `green_light` (energía 0,7–1,4 en 1,6 s). Pasar por debajo de
los torniquetes no dispara los rojos.

**En `metro_stations`** (la primera estación): un torniquete rojo (poste en
la celda 72, brazo 73–74) y uno verde (poste 76, brazo 77–78), en la fila
81. La valla de la derecha (celdas 80–83) no podía moverse porque al lado
hay una estructura: se acortó a sus dos extremos (`15` en la 82, `18` en la
83), así el paso verde pasó de 24 a 40 px (el centro de Alice cruza entre
x 626 y 646). `RedTurnstiles/RedTurnstile` (x 596, y 668, empuja hacia
abajo: Alice viene de la entrada de abajo) y `GreenTurnstileLight`
(612, 644). Mismo `y_sort_origin` de vallas y torniquetes que en la
terminal. Alice ya tiene billete (la taquilla lo explica): el verde la deja
pasar sin más.

**Orden de dibujado de vallas y torniquetes** (2026-11-14): cada baldosa se
ordenaba por su propia altura y solo la fila de abajo tiene colisión, así
que Alice, al norte de una valla, quedaba entre las filas (pintada encima de
la de arriba). Ahora todas las baldosas de esas piezas (`2:7–9`, `3:8–9`,
`4:8`, `6:7–9`, `7:8–9`, `8:8`, `14:7–9`, `15–18:8–9`) tienen
`y_sort_origin` hasta su fila de abajo (fila 10): si está al norte, queda
detrás de toda la pieza.

**Pilares negros** (2026-11-14): los dos pilares (`WallBorders`, TileMapDual)
solo tenían colisión en su mitad de abajo (`ColisonesDual`, fila 15) y Alice
se metía en la de arriba y desaparecía. Se añadieron las celdas
`(17,14)`, `(18,14)`, `(24,14)` y `(25,14)` a `ColisonesDual`.

### El primer Rompecabezas de la Ansiedad de verdad (el trabajador)
Es el **primer contacto de Alice con un desconocido** (regla 1 del puzzle).
Ya no hace de tutorial: eso lo hace el ensayo frente al espejo del
apartamento (sección 5, `AnxietyPuzzle`). Por eso ya tiene reloj y
distractores: `scenes/prologue_scene/puzzles/station_worker.tres`.
- Pista: "¿Le pregunto dónde estoy... o lo dejo estar?"
- Respuestas: `ask` = "¿Qué estación es esta?" y `leave` = "Nada... perdón.",
  más cuatro distractores ("tren", "casa", "salida" y "perdón" sin punto, que
  se confunde con el de la respuesta) y "(...)".
- 18 s y 2 s por error, sin `hint_from_start`.
- Si falla, además de "Qué vergüenza" piensa "En el espejo era más fácil...".
- `ask`: él contesta sin dejar sus papeles ("Terminal. Fin de línea." / "La
  salida, por las escaleras.") y ella, aliviada (`relaxed`): "Lo dije. Le
  pregunté a alguien." `leave` o silencio: el final de siempre, "Qué
  vergüenza" (`nervous`). Con silencio, ella abre la boca y no le sale nada.
- Lo conecta `unknown_station.gd` (`ANXIETY_PUZZLES` + `_on_dialogic_signal`).

### Interactuables ambientales (`InteractableDetectors`)
Mismo patrón que la estación de salida (`TicketStore`/`ImportantMan` en
`metro_stations.tscn`): instancias sueltas de `interactable_area.tscn` con
`timeline_name`, sin script propio. Cada uno es una línea o dos de Alice sola,
tono bajo, nada de escena. Con Dialogic: `SittingGirl`, `ListeningGuy` y
`Tracks`. Con `RemarkInteractable` (ver sección 5):
- **Máquinas** `VendingMachine` (roja y azul) y `VendingMachine2` (verde y
  azul), grupo `vending`. **Mapas** `StationMap` y `StationMap2`, grupo
  `station_map`. Las áreas de los mapas bajan hasta y≈592: el mapa está
  encerrado por bancos y antes no se podía alcanzar.
- `TicketWindows`, `StaffDoorLeft`/`StaffDoorRight` y `NoticeBoards`.
- **NPCs sin diálogo** (`AmbientThought`, sin globito; la nubecita aparece
  sobre Alice): `OfficeWorker` y `VendingGuy` con línea propia; `SittingBoy`,
  `LeaningBoy` y `CapGuy` con el pool.
- **Los bancos no responden**, en ninguna escena. Se quitó `Bench` y su
  timeline `unknown_station_bench`.

### El `ThoughtTrigger` "Metro"
Sigue existiendo un `ThoughtTrigger` en esta escena (grupo `ThoughtTriggers`),
añadido a propósito para un pensamiento espontáneo de ambiente ("Todos están
en lo suyo... Mejor así."). No contradice la regla de la sección 8 (esa regla
es para los *beats principales* de una secuencia guionada) — para un
pensamiento suelto y puntual, `ThoughtTrigger` sigue siendo la herramienta
correcta.

---

## 10. La calle (`scenes/street_scenes/scenes/street_zone_1.tscn` + `.gd`)

Escena en construcción. Todavía **no está conectada**: las salidas de la
estación desconocida siguen apuntando al apartamento (ver pendientes).

### Capas
Mismo patrón que el metro:
`InferiorLayer` (suelo, sombras) → `MiddleLayer` (y-sort: `Walls`,
`Graffities`, `Addons`, `AddonsSuperior`, `Buildings2`, `Buildings`, `NPCS`,
`Player`) → `SuperiorLayer` (`z_index` 2: `Rooftops` y `ColisonesDual`).

- **`ColisonesDual`** solo bloquea la calzada, para que Alice cruce por los
  pasos de cebra. Las colisiones de los objetos van en los tiles.
- **Cada tile tiene `y_sort_origin` apuntando a la línea donde termina su
  objeto**, no al borde del tile. Regla: la línea de orden tiene que quedar por
  encima del punto más cercano al que Alice puede llegar. Las colisiones a
  medida suelen dejarla pasar más allá del borde del tile, como en la torre de
  vidrio o la puerta de la tienda.
- Los objetos con **caras en diagonal** (el edificio gris, la torre) tienen sus
  columnas laterales ordenadas más arriba que el centro.
- Las paredes y rejas **verticales** no llevan `y_sort_origin`: se ordenan tile
  por tile. Godot no guarda los valores 0, así que un tile "sin valor" puede
  estar en 0 a propósito, como la punta del toldo del edificio gris.
- **Al pintar un edificio nuevo, revisa que sus tiles tengan origen y
  colisión.** Si no tienen, Alice atraviesa la fachada y lo que está detrás
  (por ejemplo la reja) se dibuja encima. Los locales de 3×6 tiles (la
  panadería en el atlas 12–14:6–11 y la tienda de vinilos en 16–18:22–27)
  llevan los mismos valores. El origen va de 176 en la fila de arriba a 16 en
  la base, bajando 32 por fila. Las 3 filas de abajo llevan colisión completa
  de 32×32. Los dos locales de arriba de la panadería (atlas 7–9:21–26 y
  10–12:21–26) usan los mismos orígenes.
  - Las **casas de 3×7 tiles** (arriba a la derecha, atlas 1–3:14–20, 4–6:14–20,
    26–28:0–6 y 7–9:15–20) van de 178 a -14, todas ordenadas en y=66. Llevan
    colisión completa en las filas 4–6 y media colisión arriba en la planta
    baja. La de techo oscuro no tiene la fila de la punta del techo, así que
    empieza en 146.
  - Si un edificio no tiene origen, cada fila se ordena por su cuenta y la
    pared de ladrillo de atrás le pasa por encima.
- **La torre de vidrio** (atlas 25–27:13–19) tiene colisión solo en las dos
  filas de la base, con su forma diagonal. Su parte alta tapa la vereda de la
  manzana de Leo, así que Alice puede pasar por detrás y queda oculta unos
  100 px. Es a propósito: un edificio alto tapa a quien camina detrás.
- **La colisión de un objeto no puede ser más ancha que su dibujo.** El cuerpo
  de Alice mide 17×10, así que cada píxel de colisión invisible se nota. En el
  segundo playtest, casi todos los movimientos perdidos fueron por chocar con
  bordes de macetas, bancos, mesas y rejas. Muchos de esos tiles tenían la
  colisión de 8×8 (o 16×16) completa, aunque el dibujo ocupa solo una mitad.
  Se angostaron 70 tiles al ancho real del dibujo, conservando su alto:
  - 44 en `street _addons_minies` (`TileSetAtlasSource_cmax7`);
  - 26 en `street_addons` (`TileSetAtlasSource_6tevs`).
  Las colisiones con forma a medida no se tocaron.
- **Corrección de esquinas** (`Player._apply_corner_correction`). Si Alice
  camina recto contra el borde de algo y hay lugar libre a menos de 8 px a un
  costado, se desliza sola hacia ese lado. Así no hace falta alinearse al
  píxel con los pasos de cebra: el cruce junto a `FirstCrossing` deja solo
  14 px de margen para el centro de Alice. Tampoco hace falta para rodear
  postes. Contra una pared larga no hace nada, porque no hay hueco cerca.
- **Ojo con los empates.** Si un objeto y un edificio se ordenan en la misma
  línea, gana el edificio. El farol de la esquina del edificio amarillo y el
  edificio estaban los dos en y=96, y el farol quedaba detrás de la cara
  lateral. La columna derecha del edificio (atlas 10:1–7) se bajó a y=88.

### Ambientación
`LightsContainer/SunFilter` es un `CanvasModulate` cálido (`Color(1, 0.9, 0.76)`)
que tiñe toda la escena como luz de sol de tarde. Es el equivalente al
`DarkFilter` azulado del apartamento y el metro. No afecta a la UI ni a Dialogic,
porque esos van en su propio `CanvasLayer`.

### Límites del mapa (`MapBoundaries`)
Cinco `BoundaryArea` en franjas pegadas al borde del mapa (1280×768), por
dentro, todas con el mismo pensamiento (ver `BoundaryArea`): `BoundaryLeft`, `BoundaryRight`,
`BoundaryTop`, `BoundaryBottomLeft` y `BoundaryBottomRight`. Las de abajo están
separadas porque Alice se para en y=744 a la izquierda de la calzada y en y=760
a la derecha. Cada franja cubre el punto donde se para Alice, para que su cuerpo
la pise, y es más estrecha que el empujón de 24 px, para que el empujón la saque.
Si se mueve un área, mantener las dos reglas.

### NPCs
- **Fijos:** instancias de `base_npc.tscn` en `MiddleLayer/NPCS`, como en el
  metro, con su diálogo en `InteractableDetectors`. **En la calle el origen está
  en los pies:** cada instancia sube el dibujo 16 px (`Sprite2D` en
  `position (0, -7)` con `offset (0, -9)`, ver "Orden de profundidad de los
  NPCs") y usa una colisión de pies de 14×8.
- **Ambientales (solo visuales):** también son `base_npc.tscn`, pero no tienen
  área en `InteractableDetectors`, así que no tienen diálogo.
  - `BenchNewspaperNPC` (columna 0, lee el diario) está en la banca de frente
    junto al teléfono. `BenchSittingNPC` (columna 9, sentado de costado
    mirando a la derecha) está en la banca lateral del borde del parque.
  - **Para sentar a uno, su origen va 1 px por debajo de la línea de orden de
    la banca.** Si eso lo deja más abajo de lo que se ve bien, se compensa
    subiendo el `offset` del `Sprite2D`. El NPC queda en el mismo lugar en
    pantalla, pero se ordena en la línea correcta.
    - **Banca de frente:** ordena en y=680, el NPC está en y=681 con offset -16.
      Alice, a la que la banca frena en y≈683, queda delante de él.
    - **Banca lateral:** ordena en y=320, que es el final del tile de abajo
      (y=316) más su origen 4. El NPC está en y=321 con offset -23, para que se
      vea igual que antes (pies en y=314). Con y=314 la banca lo tapaba.
  - Los sentados tienen la colisión desactivada, porque ya bloquea la banca.
  - `VinylWindowNPC` (columna 13, de espaldas con mochila) está parado mirando
    la vidriera de vinilos, con la colisión de pies normal.
  - **Columnas nuevas en `npcs_sprite_sheet.aseprite`**, todavía sin colocar en
    ninguna escena: 14 repartidor con caja, 15 abuela con bastón, 16 guitarrista,
    17 corredora, 18 chica con su perro, 19 niño con globo y 20 grandullón. Las
    columnas 21–29 están libres. El perro y el globo están dentro de la celda de
    32×32, así que la colisión de pies de 14×8 solo cubre a la persona.
- **Peatones:** instancias de `walking_npc.tscn` con su área de interacción
  como hija (`InteractableArea` o `AmbientThought`), para que se mueva con
  ellos. **El recorrido se configura en el propio NPC** (grupo "Patrol" del
  inspector, 2026-10-25): `patrol_points` (se arrastran los `Marker2D`, dos o
  más, en orden), `patrol_speed` (28 px/s) y `patrol_pause` (2,5 s en cada
  extremo, de frente). `street_zone_1.gd` llama `start_patrol()` a cada
  `WalkingNPC` de `NPCS` que tenga al menos dos puntos: va de ida por todos,
  descansa, vuelve al revés, y así siempre. Cada tramo es una línea recta, así
  que para doblar una esquina se agrega un punto.
  - Los marcadores siguen en la carpeta `PedestrianRoutes`, pero los nombres ya
    no importan (antes la ruta se buscaba por el nombre del peatón). No van
    dentro del NPC: se moverían con él.
  - Antes había un export `route_waypoints` con `walk_route()`, que nadie
    llamaba; se reemplazó por esto.
  - Ojo con el editor: si tiene cargada la versión vieja del script, al guardar
    la escena descarta `patrol_points` (pasó una vez). Recargar el proyecto
    después de cambiar exports de un script.
  - **`frames`** (2026-11-05): las animaciones de cada `WalkingNPC` se ponen
    en este export del propio NPC, **no** en `sprite_frames` de su
    `AnimatedSprite2D`. El script es `@tool`: en el editor se ve el sprite de
    verdad (quieto en `idle_front` o `idle_side`). En la plaza, el editor
    borraba al guardar el `sprite_frames` puesto en el hijo y volvía el
    placeholder de la plantilla (pasó tres veces); en la raíz no pasa. Ya lo
    usan Lía, la corredora, Toby, los paseantes de la plaza y los peatones y
    el gato de la calle. En el editor solo corre la vista previa (sin
    `_physics_process` ni `_process`).
  - **`patrol_loop`** (2026-11-03): en vez de ida y vuelta, da vueltas al
    circuito (del último punto vuelve al primero), con `patrol_pause` al
    empezar cada vuelta (0 = sin parar).
  - **`patrol_pause_max`**: si es mayor que `patrol_pause`, cada descanso dura
    un tiempo al azar entre los dos (la corredora: 12–15 s).
  - **`heading`** (variable): hacia dónde va o, mientras descansa, hacia
    dónde irá en el siguiente tramo (aunque el sprite mire a cámara).
  - **`move_animation`** (`"walk"` por defecto): prefijo del ciclo de
    movimiento. `"run"` reproduce `run_side`/`run_front`/`run_back` (la
    corredora y Toby). Si falta el de frente o espaldas usa el de lado,
    volteado según hacia dónde va, así un sprite dibujado solo de lado sirve
    para cualquier ruta. Para estar quieto usa `idle_<dir>`, si no
    `idle_front`, si no `idle_side`.
  - **`follow_trail(lider, distancia, velocidad)` / `stop_trail()`**
    (2026-11-13): sigue el camino real del líder (una cola de sus posiciones)
    a `distancia` px por detrás, con `move_and_slide` y sin ser sólido.
    Pensado para quien va de la mano o de la manga (Lía); ver "La plaza (Lía)".
  - **`follow(lider, offset)` / `stop_following()`**: el NPC se queda a un
    `offset` fijo del líder, como un perro con correa. No se cambia de lado
    al girar (a la ida va detrás y a la vuelta delante, o al revés). Lo
    alcanza suavemente (en marcha se queda unos 9 px corto), corre mientras
    se acerca y, quieto, mira hacia el `heading` del líder: al final de un
    tramo, hacia el siguiente punto. No choca mientras sigue. Hay que llamar
    `stop_following()` antes de moverlo por código.
- **`WalkingNPC.stops_when_talked_to`** (grupo "Interaction" del inspector,
  `true` por defecto) decide si el NPC se frena cuando Alice le habla. Si está
  activado, `street_zone_1.gd` lo congela durante el diálogo
  (`PROCESS_MODE_DISABLED` también pausa su `Tween`) y lo suelta en
  `Dialogic.timeline_ended`. Los dos peatones de la calle lo tienen
  **desactivado**: siguen caminando como si no notaran a Alice, y su
  `InteractableArea` se va con ellos. Por eso el cartel "[Espacio]" solo
  aparece mientras el peatón pasa cerca de Alice, y hay que hablarle al vuelo.
- **`WalkingNPC.talk_animation`**: animación que se reproduce mientras está
  frenado por un diálogo. El sprite pasa a `PROCESS_MODE_ALWAYS` para seguir
  animándose aunque el NPC esté congelado, y al terminar vuelve a la
  animación que tenía.
- **El gato de la calle** (`MiddleLayer/NPCS/StreetCat`): un `WalkingNPC` que
  va y viene por la vereda frente al edificio rojo, al lado de la salida del
  metro (`PedestrianRoutes/StreetCat`, x 290–480, y 1014), así Alice lo cruza
  enseguida. Se frena al hablarle y maúlla (`talk_animation = "meow"`).
  `street_cat` le recuerda a Wilson ("Tienes la misma cara que pone Wilson
  cuando quiere algo"); las veces siguientes, `street_cat_again`, una línea
  corta (`_on_cat_interacted` en `street_zone_1.gd`). El sprite,
  `global/npcs/assets/street_cat.aseprite`, se recortó de la hoja "cat 16x16
  with text" del Free pack (celdas de 32×32 desde x=80): `idle_front` (cuadros
  de frente de la fila de descanso, sin los que se da vuelta), `walk_side`
  (fila "walk right", 8 cuadros) y `meow` (fila "meow sit"). El cuerpo del
  gato termina en la fila 24 de la celda, por eso el `offset` es (0, −8).
- **Arte de los peatones:** cada uno tiene su propio `.aseprite` en
  `global/npcs/assets/`, por ejemplo `pedestrian_red_cap.aseprite`. Se importa con el
  importador **"Aseprite SpriteFrames"** de AsepriteWizard, así que cada etiqueta
  es una animación y el `AnimatedSprite2D` usa el archivo directo. Solo hacen
  falta dos etiquetas: **`idle_front`** (los 3 cuadros de reposo de la hoja de
  NPCs) y **`walk_side`** (mirando a la derecha). Como solo caminan en
  horizontal, `flip_h` resuelve la izquierda. La caminata **sale del `walk_side` de
  Alice** (`player/walk_animation.aseprite`), "vestida" por código con la paleta de
  cada peatón y retocada a mano. La rubia parte del de gorra roja ya corregido,
  con flequillo, mechones, pestaña y más volumen en la nuca, retocados con el MCP
  de Aseprite.
  Lo que generaba Sprite Fusion tenía demasiado detalle para este estilo.
- `WalkingNPC.face_direction()` hacia el frente o la espalda **quita el
  `flip_h`**. Antes, un NPC que venía caminando hacia la izquierda quedaba
  espejado al girarse.
- **Ojo:** `InteractableArea` reacciona a cualquier área de la capa 4, no solo
  a Alice. Si la ruta de un peatón cruza el área de otro NPC, los carteles
  "[Espacio]" se encienden solos. Mantén sus áreas separadas.
- Diálogos en `dialogic/timeline/street/` (ids `street_*`). Ya están revisados,
  no son placeholders. Ver "Tono de los diálogos" más abajo.

### Pensamientos e interacciones
Mismo patrón que la estación desconocida:
- **Apertura: el objetivo en la caja de abajo.** Al entrar a la calle por
  primera vez (`GameManager.street_arrival_seen`), un segundo después del
  fundido, Alice dice `street_arrival`: "No sé dónde estoy. Pero necesito una
  tienda que venda comida para gatos. Wilson me está esperando.". Va en la caja
  y no en la nube porque es el objetivo de toda la calle y no se puede perder.
  No rompe la regla de los dos lenguajes: no se dispara al caminar, es la
  apertura de la escena (como el saludo de Leo). Reemplaza al antiguo
  pensamiento `Arrival`.
- **Primer vistazo a la torre de cristal.** `GlassTowerSighting` es un
  `VisibleOnScreenNotifier2D` que cubre la torre. La primera vez que asoma en
  pantalla (`GameManager.glass_tower_seen`), Alice queda quieta, la cámara se
  desliza hasta la torre (`Player.pan_camera_to()`, 0,9 s), se queda 1,4 s y
  vuelve (`reset_camera()`, 0,7 s). Mientras tanto, en la nube: "Qué edificio más raro... todo de
  cristal.". Si después escucha "la torre de cristal", ya sabe cuál es.
- **Recordatorio si se pierde** (`_tick_lost_reminder` en `street_zone_1.gd`).
  Si pasan 150 s caminando (sin contar diálogos ni cutscenes) sin encontrar una
  pista nueva (`GameManager.clue_added` reinicia el reloj) y sin acercarse a
  menos de 220 px de la tienda, sale en la nube: "Si le preguntara a alguien,
  ya habría llegado. ...No." y, la segunda vez, "Podría fijarme mejor en los
  carteles. O en lo que dice la gente.". Si ya oyó a la chica del teléfono,
  apunta a la torre: "Un minimercado detrás de la torre de cristal, cruzando
  la avenida... Tiene que estar cerca.". Como máximo 2 recordatorios, y ninguno después de entrar a la
  tienda de Leo.
- **`ThoughtTriggers`:** pensamientos espontáneos que se disparan una sola vez
  al pasar: `FirstCrossing`, `Houses`, `ShoppingBlock` y, desde 2026-10-25,
  tres que hablan de Alice y no del objetivo (todos con `wait_for_current`):
  - `WalkNormally` (700, 420), en la vereda frente a la torre, por donde pasa
    la peatona: "Camina normal. ¿Cómo se camina normal?"
  - `BeenHereBefore` (843, 560), vereda derecha de la manzana central, con
    `skip_visits = 1`: "Ya pasé por aquí. Creo." solo la segunda vez.
  Quedan para cuando haya sprites: "¿Cómo hace la gente para hablar tan
  fácil?" (dos amigas charlando).
- **`FirstCrossing` explica la regla del mapa: solo se cruza por los pasos de
  cebra** ("(mira la calle) Mejor cruzo solo por los pasos de cebra.", y
  después "Hay muy poca gente..."). Está en x=540, en la columna del café, por
  donde pasan todos los caminos hacia la primera esquina. Antes estaba en
  x=777, pegado al borde, y aparecía cuando Alice ya había chocado con la calle.
  Tiene `wait_for_current`, para no cortar otro pensamiento. `ShoppingBlock` está en la vereda, junto a la
  panadería, y cierra el desvío: "Una panadería, discos... Nada para
  gatos." Antes decía "Esto es una zona de tiendas. Por
  aquí tiene que haber algo.", y en los dos playtests hizo creer que la tienda
  estaba en esa manzana. El olor a pan quedó solo en el diálogo de la puerta
  (`BakeryDoor`), así no se repite.
- **`InteractableDetectors`:** además de los diálogos de los NPCs fijos, objetos
  clave para la historia (`Shop`, `BakeryDoor`, `ATM`, `Payphone`,
  `SubwayEntrance`, `GlassTower`), cada uno con su `street_*.dtl`.
- **`RemarkInteractable` en la calle** (ver sección 5):
  - `VendingMachines` (grupo `vending`, compartido con la estación).
  - `AdColumn` y `AdColumn2`, la que está junto a la tienda de Leo (grupo
    `ad_column`).
  - **Puertas de tiendas, con diálogo propio en la caja** (`timeline_name`),
    porque tienen acotaciones y más de una línea:
    - `CafeDoor` (junto al inicio, `street_cafe`): "(mira por el cristal; hay
      gente riendo en una mesa) Aquí no venden comida para gatos." / "Igual,
      no entraría. Hay mucha gente."
    - `CafeDoorNorth` (junto a Leo, `street_cafe_north`): "(huele a pan
      tostado) Antes venía a sitios así. Con un libro. Sola." / "Me gustaba.
      Creo."
    - `PizzaDoor` (`street_pizza`): "Huele a pizza." / "Qué hambre..."
    - `VinylDoor` (`street_vinyl`): "¿Quién compra discos hoy en día?" / "(ve
      a una chica en el mostrador comprando uno)" / "Supongo que gente
      cool... No como yo."
  - **Casas y edificios, una línea distinta cada uno** (antes los 7 decían "No
    es mi casa."): `HouseDoorGreen` "Alguien vive aquí y sabe exactamente cómo
    volver.", `HouseDoorGrey` "Si tocara el timbre, ¿qué diría? 'Hola, me
    perdí'... No.", `HouseDoorNorth1` "Hay luz dentro. Alguien está en casa.",
    `HouseDoorNorth2` "Plantas en la ventana. A mí nunca me duran.",
    `HouseDoorNorth3` "Se oye una tele. Como en mi casa.",
    `BuildingDoorNorthwest` "Un portero automático. Odio hablar por esas
    cosas.", `BuildingDoorWest` "Tantos timbres. Tanta gente que no conozco." y
    `ATMBuildingDoor` "Cerrado. Casi me alegro: así no tengo que hablar con
    nadie."
  - **Regla (2026-10-25):** lo que Alice encuentra dice algo de ella (miedo a
    molestar, a la gente, a que la miren; su casa, su rutina), no repite el
    objetivo. Wilson solo se nombra en la llegada y en el gato; la panadería
    ("No. El dinero es justo."), la entrada del metro ("Y volver con las manos
    vacías no es una opción."), los bordes y las máquinas ("Otra máquina. El
    dinero ya tiene dueño.") ya no lo nombran.
  - NPCs sin diálogo (`AmbientThought`): `NewspaperReader` y `VinylBrowser`
    con línea propia, `BenchSitter` con el pool.
  - Las dos bocas del metro ya las cubre la misma área `SubwayEntrance`
    (89×109).
- **La torre de vidrio es una interacción, no un pensamiento.** Antes era un
  `ThoughtTrigger`, pero el jugador seguía caminando y el momento de
  "admirarla" pasaba desapercibido. Ahora `GlassTower` está frente a la puerta
  de vidrio y Alice la mira solo si el jugador se detiene y aprieta Espacio,
  sin cortarle la caminata.
- **La tienda de Leo** es la del rincón de arriba a la derecha. Tiene dos áreas:
  `Shop` es el escaparate, donde Alice ve la comida para gatos
  (`street_shop`), y `ShopDoor` es la puerta, un `SceneTransitionArea`
  ("[Espacio] Entrar") que lleva a `leo_store.tscn` (sección 11).
- La **tienda de vinilos**, al lado de la panadería, todavía no tiene
  interacción.
- **Ojo al colocar un área de interacción:** el detector de Alice es un
  cuadrado de 8×8 que queda 16 px delante de ella, en la dirección en que mira
  (y 5 px más arriba). El área tiene que cubrir ese punto **desde todos los
  lados por los que Alice puede pegarse al objeto**, no solo de frente. En el
  playtest a ciegas, la jugadora no encontró la cabina, el cajero, la
  estudiante, el oficinista ni el volante: con áreas de 30×26 compartidas, la
  mitad de las posiciones pegadas al objeto no activaban el cartel.
  - Ahora cada área tiene su propio `RectangleShape2D_ia_<Nombre>`, del tamaño
    justo para cubrir todas las posiciones donde Alice queda pegada al objeto
    mirándolo, más 2 px. Se calculó con el recorrido de lo caminable.
  - Los peatones usan `RectangleShape2D_ia_pedestrian` (40×34), que se mueve
    con ellos.
  - Las áreas no pueden pisarse entre sí, porque se encenderían dos carteles a
    la vez. Si dos áreas quedan al lado (como `Shop`, el escaparate, y
    `ShopDoor`, la puerta), tienen que dejar entre ellas un hueco más ancho que
    el detector (8 px). Entre esas dos quedan 9 px.
- **`InteractableArea` solo reacciona al detector de Alice** (`_is_player_detector`).
  Antes mostraba y escondía su cartel con cualquier área de la capa 4: cuando
  la rubia pasaba frente al oficinista, el cartel del oficinista se escondía
  aunque Alice siguiera ahí. Además, ningún cartel queda visible durante un
  diálogo, y al terminar vuelve a aparecer si Alice sigue en el área.
- **Si el detector toca dos áreas, gana la más cercana** (`Player._try_to_interact`).
  Antes ganaba la primera de la lista.
- **Globito sobre los NPCs con diálogo** (`global/interaction_hint.tscn`):
  - Es un `Sprite2D` con un "..." dibujado en `interaction_hint.aseprite`
    (13×9). Flota 2 px arriba y abajo, redondeado a píxeles enteros, y se
    esconde mientras haya una conversación en la caja de abajo. Con un
    pensamiento en la nube se queda, porque la nube no frena a Alice.
  - Ya no se pone a mano: viene dentro de `NpcTalkArea` (sección 5). **Solo
    la gente con conversación de verdad lo lleva**: en la calle, la chica del
    teléfono, el repartidor, la abuela y el gato. La gente de fondo usa
    `AmbientThought`, sin globito.

### Pistas hacia la tienda de Leo
La tienda de Leo no se ve desde el inicio. La idea es que el jugador la
encuentre explorando y que **explorar le dé información**. Alice es tímida y
no le pregunta nada a nadie: las pistas le llegan observando y escuchando
("(alcanza a oír) ..."). Todas son opcionales y ninguna bloquea el camino.
Las pistas buenas comparten un detalle para reconocer el lugar: **el cartel de
frutas** del escaparate de Leo.

| Área (`InteractableDetectors`) | Dónde | Tipo | Timeline |
|---|---|---|---|
| `PetsShopDoor` | Puerta de la tienda PETS, arriba de la panadería | **Precisa** (desde 2026-10-25, clue `pets_note`): "Cerrado por reformas", pero debajo hay un papelito a mano: "Mientras tanto, comida para mascotas en el minimercado detrás de la torre". Alice: "Por lo menos alguien pensó en gente como yo." Es la segunda pista precisa, junto con la anciana. | `street_pets_closed` |
| `BrokenPayphone` | Segunda cabina, junto al señor del diario | Falsa: "(levanta el auricular) ... No hay tono." La otra cabina (`Payphone`) tiene el diálogo de "Ni siquiera el mío". | `street_payphone_broken` |
| `VendingMachines` | Máquinas entre la panadería y los vinilos | Falsa, con humor | `street_vending` (grupo `vending`) |
| `BusStopGrandma` | Abuela (`BusStopGrandmaNPC`, col. 15, personaje `grandma` = "Anciana"), en la manzana de arriba a la derecha (se movió desde la parada; el nombre quedó) | **La precisa**: Alice se atreve a preguntarle y ella contesta "Hay un minimercado justo detrás de la torre de cristal." | `street_grandma` |
| `BusStopMap` | Mapa de rutas de la parada | A medias: "Hay tiendas pasando la torre." | `street_bus_stop` |
| `PhoneGirl` | Chica del teléfono (ya existía) | Buena pero vaga: oye "...sí, en el minimercado ese, junto a la torre de cristal...", y Alice **la repite**: "¿Un minimercado? ¿Junto a la torre?" / "Quizá ahí vendan comida para gatos." | `street_phone_girl` |
| `Delivery` | Repartidor (`DeliveryNPC`, col. 14), vereda este de la manzana central | Buena: caja de "Minimercado" con frutas | `street_delivery` |
| `AdColumn` | Columna de afiches de la manzana de Leo | Buena, la confirmación: volante con frutas | `street_ad_column` |

- **Registro:** `street_zone_1.gd` (`CLUE_AREAS`) conecta el `interacted` de
  cada pista buena o a medias con `GameManager.add_clue(id)`. Las falsas no se
  registran. Las pistas viven en `GameManager.found_clues`.
- **Lugares que reaccionan a lo que Alice ya sabe** (`CLUE_REACTIONS` en
  `street_zone_1.gd`). Si Alice vio alguna de las pistas indicadas, el área
  pasa a otro timeline. El cambio se hace en el `interacted` del área, que se
  emite justo antes de que arranque el timeline. Sin esas pistas queda el
  diálogo de siempre.

  | Área | Pistas que la activan | Timeline nuevo |
  |---|---|---|
  | `Shop`, el escaparate de Leo | `delivery_box` o `store_flyer` | `street_shop_found`: "El cartel de frutas... Es aquí." |
  | `GlassTower` | `overheard_store` | `street_glass_tower_clue`: "Junto a la torre de cristal", decía. Aquí delante no hay ningún minimercado... (mira por encima de la torre) ¿Al otro lado de la avenida? |

- **Por qué existe la reacción de la torre:** en el playtest, la jugadora
  escuchó "el de la torre", llegó a la base de la torre y se quedó sin saber
  qué hacer. La tienda de Leo está detrás de la torre, al otro lado de la
  avenida, y desde la base no se ve. Ahí la torre repite la pista y deduce
  la avenida.
- **De vaga a precisa (2026-10-23), en capas.** Cada jugador recibe solo la
  ayuda que necesita, y las citas coinciden entre sí:
  1. **La chica** da el punto de referencia, vago: "junto a la torre de
     cristal". No dice el camino.
  2. **La torre**, si Alice llega a su base habiendo oído a la chica, cita
     esa misma frase y deduce el resto: "¿Al otro lado de la avenida?". La
     dirección es un premio por haber ido, no algo que se regala.
  3. **La anciana** dice "justo detrás de la torre de cristal", y es la única
     vez en la calle que Alice le pregunta algo a alguien: la respuesta clara
     es el premio por atreverse a hablar. Desde 2026-10-25 hay una segunda
     pista precisa, el papelito de la tienda de mascotas cerrada ("...en el
     minimercado detrás de la torre"): premia mirar con atención en vez de
     hablar. (No es
     un Rompecabezas de la Ansiedad a propósito, para no saturar: el de la
     estación y los dos de Leo alcanzan.)
  4. **El recordatorio** (`LOST_TOWER_LINE`), solo tras 150 s sin avanzar:
     "Un minimercado junto a la torre de cristal... Quizá al otro lado de la
     avenida." Es la red de seguridad; quien va bien nunca lo ve.
  Se probó poner "cruzas la avenida y lo ves" en la pista de la chica, pero
  se lo daba todo hecho al jugador. Las cifras del playtest 6 (6–8 min
  perdido) están infladas por la latencia del tester.
- **Las citas tienen que coincidir.** La torre y el recordatorio repiten
  "junto a la torre de cristal", como la chica; lo de la avenida es deducción
  de Alice, no una cita, y "detrás" queda solo para la anciana. **Si se
  cambia una frase, hay que cambiar las otras:** el jugador nota cuando Alice
  "recuerda" una frase que nadie dijo.
- **"Minimercado", no "almacén".** "Almacén" puede ser un depósito o muchas
  otras cosas; "minimercado" es español neutro y se entiende como una tienda
  chica de comida. Se usa en el volante, la caja del repartidor, la chica del
  teléfono y la torre.
- **NPCs de pista vs. de ambiente.** Solo los que dan pistas (la chica del
  teléfono, la abuela de las latas y el repartidor) tienen conversación. Los
  de ambiente (`OfficeMan` —hoy la chica deportista, ver "NPCs repetidos"—,
  `Student` y los peatones
  `PedestrianA`/`PedestrianB`, más `NewspaperReader`, `VinylBrowser` y
  `BenchSitter`) son `AmbientThought`: sin globito; cerca de ellos aparecen
  las burbujitas sobre Alice y Espacio muestra una línea en la nube (su mejor
  momento de los diálogos viejos, recortado a 1 o 2 líneas). Sus `.dtl` (`street_office_man`, `street_student`,
  `street_headphones_guy`, `street_pedestrian_cap`,
  `street_pedestrian_blonde`) se borraron. El gato es la excepción: conserva
  su diálogo (Wilson).
- **Los peatones solo se paran si Alice les "habla"** (Espacio). Pasar al lado
  no los detiene. Al pulsar, `_on_pedestrian_interacted` los congela mirándola
  hasta que termina **su** pensamiento (`RemarkInteractable.remark_finished`),
  no cualquiera: si el Espacio corta un pensamiento del suelo, el fin de ese no
  los suelta. Varios Espacios seguidos solo alargan la parada (contador en el
  meta `talk_holds`), y siguen con el paso que traían. Para que sea fácil
  alcanzarlos caminando, su `AmbientThought` tiene un círculo de 24 px (no
  16). El gato sí se para por cercanía (`pause_near_player`, 20 px).
- **NPCs repetidos (2026-10-25).** El chico de auriculares salía en las cuatro
  escenas. Ahora el andén de salida y el tren comparten gente a propósito
  (subieron al mismo tren), y la estación desconocida y la calle usan
  personajes de la hoja que no salían en ningún lado:

  | Escena | Nodo | Antes (col.) | Ahora (col.) | Texto nuevo |
  |---|---|---|---|---|
  | Estación desconocida | `LinseningGuyNPC` / `ListeningGuy` | auriculares (4) | guitarrista (16) | "Toca como si nadie lo estuviera escuchando." / "Qué envidia." |
  | Estación desconocida | `OficinistManNPC` / `OfficeWorker` | oficinista (7) | hombre calvo (20) | "Tiene cara de pocos amigos. No lo miro." |
  | Estación desconocida | `NormalGuyNPC` / `VendingGuy` | chico (6) | niño del globo (19) | "Un niño con un globo." / "Es el único aquí que no tiene prisa." |
  | Calle | `HeadphonesGuyNPC` / `HeadphonesGuy` | auriculares (4) | chica con perro (18), **quitada** después: su sitio, junto al STOP, lo ocupa la pareja | ("Saca a pasear al perro como si nada." / "Yo tuve que ensayar en el espejo para salir." — línea libre para reubicarla) |
  | Calle | `OfficeManNPC` / `OfficeMan` | oficinista (7) | chica deportista (17) | "Ropa de deporte. Sale a correr... por gusto." / "A mí me cuesta salir hasta para comprar." |

  Los nombres de los nodos se dejaron igual. Siguen repitiéndose el lector de
  diario (andén y calle), la estudiante (andén y calle) y el chico sentado
  (estación desconocida y calle).
- **La pareja que discute (2026-10-25).** Al pie del paso de cebra de arriba,
  junto al café del inicio (x≈737–767), una pareja discute y tapa el paso:
  `CoupleGuyNPC` (col. 10) y `CoupleGirlNPC` (col. 12), más `CoupleBlocker`
  (`StaticBody2D`, capa 1, 34×12 en (752, 899)) para que no se pueda pasar
  entre ellos. `StreetCouple` es un `NpcTalkArea` (globito "...", porque sí
  responden) con `street_couple`:
  - Oye la discusión (personajes `couple_girl` "Chica" y `couple_guy` "Chico")
    y sale un **Rompecabezas de la Ansiedad** (`puzzles/street_couple.tres`,
    15 s): "Perdón... ¿me dejan pasar?" (`ask`) o "Ya terminarán..." (`wait`),
    con distractores "Disculpen", "cruzar", "rápido", "calle". Interrumpir a
    desconocidos es justo un momento de mucha ansiedad (regla 1 del puzzle).
  - `ask`: se callan, "Ay... perdona. Claro." / "Perdón, perdón.", y la señal
    `couple_step_aside` los aparta a los costados (`_clear_couple`): el
    bloqueo y el área se apagan. Alice: "...Lo dije." (`relaxed`). Queda en
    `GameManager.street_couple_cleared`: si vuelve a la calle, siguen
    apartados.
  - `wait`: **Alice se queda escuchando y se entera de chismes**, uno nuevo
    cada vez que espera (`GameManager.street_couple_waits`, que sube con la
    señal `couple_waited`; dura entre visitas):
    1. "¡Y encima invitaste a tu ex al cumpleaños de MI hermana!" / "¡Es amiga
       de tu hermana!..." → Alice: "...¿A su ex?" / "No debería estar
       escuchando esto."
    2. "¿Y lo del perro?..." / "¡Se comió mis zapatos nuevos, Marcos!" →
       Alice (por Wilson y sus zapatos): "Igual que en casa..."
    3. y siguientes: "¡No me hables así delante de la gente!" / "¿Qué gente?
       ¡Si no hay nadie!" → Alice: "...Estoy yo."
  - Silencio: "(abre la boca, pero no le sale nada)" / "Siguen discutiendo."
  - Después de esperar o de callarse, Alice pregunta "¿Lo intento otra vez?" y
    hay un menú: **"Intentar hablarles otra vez"** salta (`jump try`) a la
    etiqueta `label try`, justo antes del puzzle, sin salir de la
    conversación; **"Cruzar por el otro paso"** termina con "Mejor cruzo por
    el otro lado." (`nervous`).
  - Ojo con Dialogic: un menú (`- opción`) tiene que ir **justo después de una
    línea de texto**. Si va después del cierre de un `if/else` (o de un
    comentario `#`), no se muestra y la conversación termina sin preguntar.
    Por eso está la línea "¿Lo intento otra vez?".
  - **Nunca bloquea el juego:** el paso de cebra de la derecha lleva al mismo
    lado.
  - **Se ve de lejos que discuten:** `StreetCouple/ArgueFx` (`AnimatedSprite2D`,
    `assets/couple_argue.aseprite`, tag `argue`, 4 frames de 0,22 s) muestra
    un "!!" amarillo y un "#!" rojo (palabrota de cómic) que se alternan sobre
    él y sobre ella, con un saltito de 1 px, en el estilo del "MEOW!" de
    Wilson (amarillo `#fbf236`, contorno negro que sigue cada signo). Se
    esconde cuando se apartan (`_clear_couple`). Se puede mover arrastrando el
    nodo en el editor.
  - `street_zone_1.gd` despacha `anxiety_puzzle:<id>` con `ANXIETY_PUZZLES`,
    igual que la estación y la tienda de Leo.
- **El coche aparcado (2026-10-25).** Un coche negro aparcado en la calle de
  las casas, junto a la acera de la parada (`MiddleLayer/ParkedCar` en
  (505, 839): `Sprite2D` con la región (8, 88, 83×40) de
  `assets/vehicles.aseprite`, que ahora se importa como textura estática).
  `InteractableDetectors/ParkedCar` (área de 80×14 en el borde de la acera,
  `one_time_interaction`) abre `street_car`.
  - **Por qué se acerca Alice:** su reflejo en la ventanilla oscura. Mira que
    no haya nadie y se arregla el pelo: Alice nunca se mira en público, y la
    única vez que lo hace la "pillan". Retoma el espejo de casa y el miedo a
    ser vista. (Primero se probó un gato dibujado en el polvo, pero Alice
    hacía algo raro sin motivo; se descartó.)
  - El dueño aparece "de la nada" (`car_owner_appears`: `CarOwnerNPC`, col. 7,
    el oficinista del maletín, sin colisión, con un fundido). Se coloca
    respecto al sprite `Body` del coche (`CAR_OWNER_OFFSET`, junto a la puerta
    del conductor, en la acera), así que si se mueve el coche en el editor él
    lo sigue. Personaje `car_owner` = "Dueño". "¿Todo bien?". Alice se queda helada (`shocked`) y sale un **Rompecabezas de la
    Ansiedad** (`puzzles/street_car.tres`, 15 s): "Solo... me estaba...
    arreglando el pelo." (`explain`) o "Perdón, perdón." (`sorry`), con
    distractores "mirando", "coche", "nada", "robar".
  - Ninguna rama la juzga: el dueño se ríe con ella ("Tranquila. Yo también lo
    hago en todos los coches."; con `sorry`: "¿Perdón por qué?..."; con
    silencio: "Tranquila, mujer..."). "Bueno, me voy, que llego tarde." →
    `car_drives_away`: él se sube y el coche se va hacia la derecha (760 px
    en 3 s). Alice: "(se va casi corriendo) ...Quiero que me trague la
    tierra." / "Pero se rió conmigo. No de mí." (`nervous` → `relaxed`).
  - `GameManager.street_car_gone`: al volver a la calle ya no está.
  - Se quitó el pensamiento de paso `ShopWindowReflection` ("Mi reflejo en el
    escaparate..."): el momento del reflejo es el coche, y tener los dos cerca
    repetía la idea.
- **Coches aparcados de decorado** (`MiddleLayer/ParkedVehicles`, con
  y-sort): `Sprite2D` con una región de `assets/vehicles.aseprite`,
  `centered = false` y `offset = (-ancho/2, -alto)`, así el punto de apoyo es
  el centro del borde inferior (para ordenarse bien con Alice). Están sobre la
  calzada, que ya tiene colisión, así que no llevan cuerpo propio. No tapan
  ningún paso de cebra.

  | Nodo | Región | Dónde (borde inferior) |
  |---|---|---|
  | `BlueCar` (de perfil) | (6, 22, 85×42) | (697, 345): avenida de la torre, carril de abajo, a la derecha de la torre. Más abajo se metía en la valla de la plaza. |
  | `BrownVan` (desde atrás) | (110, 37, 36×59) | (875, 656): calle vertical derecha, carril derecho, entre los dos cruces |
  | `WhiteVan` (desde atrás) | (174, 29, 37×67) | (266, 631): calle vertical izquierda, carril derecho, entre los dos cruces |

  Las furgonetas se ven de espaldas: están aparcadas mirando calle arriba. Si
  hicieran falta en el otro carril, habría que dibujarlas de frente.
  - **Cada uno tiene un pensamiento** (`RemarkInteractable` en la acera, sin
    globito; la línea sale en la nube). Por la regla de coherencia: el coche
    negro responde, así que los demás coches también. No repiten lo del
    reflejo (eso es del coche negro) y cada uno dice algo de Alice:
    `BlueCarRemark` (697, 356, sobre la valla de la plaza; se alcanza desde la
    acera de abajo) "Nunca aprendí a conducir. Tampoco tuve a dónde ir.";
    `BrownVanRemark` (893, 626) "Una mudanza. Alguien empezando de cero... Qué
    valor."; `WhiteVanRemark` (290, 597) "Hay alguien dentro comiéndose un
    bocadillo. No miro. No miro."
- **Ojo con `StreetRoadColisions`:** es una capa de colisión y tiene que estar
  oculta (`visible = false`; las colisiones funcionan igual). Al editar el mapa
  quedó visible una vez y tapaba media calle con marrón.
- **Una pista no puede depender de otra.** El jugador puede verlas en
  cualquier orden, o ninguna, así que ningún texto debe nombrar una pista
  anterior (por ejemplo "como en la caja del repartidor").

### Tono de los diálogos
Todos son monólogos de Alice: los NPCs no hablan. Al escribir uno nuevo:
- **Poco texto y nada de explicar lo que ya se ve.** El jugador ya sabe que
  está perdida y sin teléfono. No hace falta repetir el objetivo (la comida de
  Wilson) en cada diálogo. Ya lo dicen `street_arrival`, el de
  gorra roja, la entrada del metro y el límite del mapa.
- **Mostrar, no decir.** El teléfono público termina en "Ni siquiera el mío" en
  vez de "estoy sola". La panadería cierra con "No. Es para Wilson." y nada más.
- **Variar el cierre.** Su timidez aparece de varias formas: el oficinista se
  echa atrás ("No. Mejor no."), la estudiante aparta la mirada, la rubia
  intenta hablarle pero apenas se le oye. No todos los NPCs terminan con Alice
  decidiendo no hablar.
- **Las acotaciones van en minúscula, entre paréntesis y sin punto**
  (`alice: (se acerca al escaparate)`). Si la acción es de Alice no se nombra. Si es
  de otro personaje, sí: `(la chica levanta la vista un instante; Alice aparta
  la mirada)`.
- **Las acotaciones no pueden contradecir lo que pasa en pantalla.** Los
  peatones siguen caminando mientras Alice les habla (ver
  `stops_when_talked_to`). Si un peatón se configura para frenarse, nada de
  "(la chica se aleja)".

---

## 11. La tienda de Leo (`scenes/leo_store_scene/scenes/leo_store.tscn` + `.gd`)
Es el interior al que se entra por `ShopDoor` en la calle. Acá pasa **la
primera conversación con Leo**, la escena "Escena Leo" del Twine
(`Documents/Twine/Stories/Escena Leo.html`), adaptada a las reglas del juego.

```
LeoStore (Node2D, y_sort)               leo_store.gd
├── InferiorLayer / MiddleLayer / SuperiorLayer   el tileado de la tienda
│   └── MiddleLayer/NPCS/Leo   StaticBody2D: AnimatedSprite2D (leo_npc.aseprite)
│                               + colisión en los pies
├── CounterCollision           StaticBody2D: bloque de las dos cajas y baranda
├── InteractableDetectors
│   ├── LeoCounter             NpcTalkArea "[Espacio] Hablar" (su burbuja va sobre Leo)
│   ├── TunaShelf              la góndola de arriba a la izquierda: ahí está el atún
│   ├── DrinksShelf, PantryShelf, CannedShelf, SnacksShelf, CleaningShelf
│   │                          las otras cinco góndolas: Alice busca y no encuentra
│   ├── FruitCrates            "[Espacio] Mirar", las cajas de fruta (secundario)
│   └── ExitToStreet           SceneTransitionArea a la calle
└── ThoughtTriggers/CrushThought   franja de suelo: pensamiento "Es muy lindo"
```

### El flujo (los 11 pasos del guion)
1. **Al entrar** (`_play_greeting`, tras 1 s de fundido): `leo_store_greeting`.
   Leo saluda con la animación `wave` durante todo el diálogo de entrada, y
   vuelve a `idle_side` justo cuando Alice se desvía a las góndolas (señales
   `leo_wave` / `leo_wave_end`). Cuando cruza hacia los pasillos de la izquierda
   pisa `CrushThought`, una franja de suelo vertical (12×190 en x≈572, de
   y 280 a 470), y sale la nube de pensamiento: "Ese es el cajero...", "...es muy lindo.",
   "¿Por qué pensé eso?". Si sube derecho por el pasillo del mostrador no la
   cruza. Sale una sola vez en todo el juego
   (`GameManager.leo_crush_thought_shown`), aunque Alice salga y vuelva.
2. **Buscar la lata.** Las seis góndolas dicen lo mismo, "[Espacio] Buscar",
   para que la del atún no se destaque. El atún está solo en `TunaShelf`, la
   de arriba a la izquierda, lejos de la puerta. En las otras cinco Alice
   busca y no encuentra (`leo_store_shelf_drinks`, `_pantry`, `_canned`,
   `_snacks`, `_cleaning`, conectadas desde `SEARCH_SHELVES`); con la lata ya
   encontrada todas dicen `leo_store_shelf_done`. En `TunaShelf`
   (`leo_store_tuna`) por fin la encuentra y agarra una sin mirar.
3. **El mostrador** cambia según el paso: sin lata, `leo_store_counter_early`
   ("Primero... la comida de Wilson"); con lata, `leo_store_checkout`; después
   de hablar, `leo_store_after`. Se elige en `_on_counter_interacted`, que
   corre antes de que el área arranque su timeline (igual que en la calle).
4. **`leo_store_checkout`** tiene las tres decisiones del Twine. Las dos
   primeras son **Rompecabezas de la Ansiedad** (ver `AnxietyPuzzle`, sección
   5); la tercera es un menú normal:
   - "¿Estás bien?" (`puzzles/leo_are_you_ok.tres`): "La verdad... no. Me
     perdí." → `truth` (+1), "N-no, estoy bien." → `lie` (0), "(...)" o
     tiempo agotado → `silence` (−1). Las tres ramas terminan en que Alice se
     perdió. Distractores: "Sí...", "metro", "Wilson".
   - El número (`puzzles/leo_number.tres`): "Oye, ¿me das tu número?" → `ask`
     (+1, iniciativa); "Bueno... gracias." → `leave`; silencio → Leo se lo da
     igual. En todos los casos Alice termina con el número (`leo_number`).
     Distractores: "teléfono", "atún", "adiós".
   - Tienen tres distractores cada uno; el de la estación, que es el
     tutorial, solo dos. (Hasta el 2026-10-23 los de Leo no tenían ninguno:
     se habían perdido al guardar desde el editor.)
   - Darle el suyo (menú): +2 si había pedido el de él, +1 si no; o no
     dárselo (0).
5. **La salida.** `ExitToStreet` está siempre bloqueada (`is_locked`).
   **Sin haber pagado** (`leo_talk_done` en falso, 2026-11-14, el usuario no
   quiere que se pueda salir sin la comida de Wilson): `_refuse_to_leave()`
   muestra en la nube una de `LEAVE_REFUSAL_LINES` ("No puedo irme ahora.",
   "Tengo que encontrar la comida de Wilson.", "Sé que estás nerviosa, Alice,
   pero tenemos que hacer esto."), al azar y nunca la misma que la anterior,
   y la hace retroceder 16 px hacia dentro (`LEAVE_REFUSAL_STEP`), como un
   borde del mapa. Antes se podía salir a la calle sin comprar.
   **Ya pagado:** al intentar salir, `blocked_interaction` dispara
   `leo_store_farewell` ("Oye, Alice", dos variantes) y al cerrarse se pasa a
   `scenes/demo_end/demo_end.tscn`. Leo solo nombra a Wilson si Alice se lo
   dijo (rama de la verdad o al pedirle el número, señal `leo_knows_wilson`);
   si no, dice "tu gato".
6. **La reflexión y `demo_end.tscn`**: al salir, `_leave_store` usa
   `FadeTransition.transition_with_interlude` (la misma pieza que la escalera
   al metro) para contar, con la pantalla en negro, cómo Alice sale a la calle.
   Hay dos versiones según si le dio su número (`REFLECTION_GAVE_NUMBER` /
   `REFLECTION_KEPT_NUMBER`) y un cierre común (`REFLECTION_END`, que termina
   con el salto de tiempo hasta la plaza, adonde lleva ahora; `demo_end` llega
   al final de la plaza, sección 15). Antes era
   una timeline de Dialogic (`leo_store_reflection`, borrada) con la caja de
   diálogo sobre negro. `demo_end.tscn` muestra, sobre la portada oscurecida
   (`ui/cover.aseprite` al 30 %), uno tras otro, "Continuará...", "Gracias por jugar" con la invitación a dejar un
   comentario, y dos opciones que se eligen con flechas y Espacio, como en la
   pantalla de idioma: **Empezar de nuevo** (`GameManager.reset()` +
   `Dialogic.VAR.reset()` y vuelta a la pantalla de idioma) y **Salir**
   (`AppExit.quit_game()`). Las opciones solo responden cuando ya
   aparecieron, para que un Espacio de más no cierre el juego.
   `GameManager.reset()` toma los valores iniciales de una copia nueva del
   script, así que una variable nueva de estado vuelve a cero sola (salvo las
   de `NOT_RESET`: la referencia a Wilson y `missing_prep_text`).

### Estado en `GameManager`
`leo_greeted`, `leo_has_tuna`, `leo_talk_done`, `leo_confidence` (la
"confidence" del Twine, guardada para escenas futuras),
`leo_alice_took_initiative`, `leo_gave_number`, `leo_knows_wilson` y el objeto `leo_number` en
`collected_items`. Se actualizan con señales de Dialogic (`leo_greeted`,
`leo_tuna_taken`, `leo_took_initiative`, `leo_number`, `leo_gave_number`,
`leo_talk_done` y `leo_confidence:<n>`). Si Alice sale a la calle antes de
hablar y vuelve, la escena sigue desde donde quedó y no repite el saludo.

### Decisiones al adaptar el Twine
- La prosa pasa a acotaciones: lo de Alice como `alice: (...)` y lo de los
  demás como narración sin nombre (`(Leo no se ríe. Solo asiente.)`). Lo que
  Alice piensa en el momento va en la nube de pensamiento (paso 1).
- El paso 4 es jugable: el mostrador no deja avanzar hasta tener la lata.
- Español neutro en Leo: el guion traía "boli", "pues", "vale". Se usa
  "bolígrafo" y tuteo, como el resto del juego.
- Tres arreglos de continuidad: Alice escribe su número en **una esquina
  arrancada** del ticket (en el Twine se lo daba entero y se quedaba sin el de
  Leo); "sobre todo los lunes" pasó a "antes del primer café" (el oficinista
  de la calle sugiere que es domingo); y Leo explica que **el metro de esa
  calle es el de la línea que termina en la terminal**, y que la otra línea
  pasa por la plaza (si no, no se entiende por qué Alice no vuelve por donde
  vino). Se quitó "no tenía otra cosa que hacer hasta averiguar cómo volver":
  Alice salió justamente a comprar la comida.

### Medidas y colisiones
- **Alice** arranca en (591, 504). La cámara baja hasta y=600 (antes 552)
  para que, en la puerta, Alice quede por encima de la caja de diálogo. **`ExitToStreet`** está en (593, 524) con
  32×24: más abajo el detector de Alice ya no llega, porque la colisión de la
  entrada la frena en y≈505.
- La cámara está limitada a 314–774 × 185–600.
- Leo está en (730, 466), detrás de la caja de abajo, y `LeoCounter` en
  (703, 450).
- **Los mostradores y la baranda no tienen colisión en el tileset** (las
  góndolas sí). Por eso existe `CounterCollision`: sin él Alice atravesaba la
  caja y quedaba encima de Leo. Si se pinta esa colisión en los tiles, se
  puede borrar.
- Las áreas de las góndolas cubren cada grupo de estantes con 6 px de margen
  arriba y abajo, así se pueden usar desde los dos pasillos. Sus carteles
  están subidos por encima del estante (offset ≈ −40): en el sitio por
  defecto tapaban el pensamiento que sale después de agarrar la lata.
- **Todas las áreas de esta escena tienen `[editable path]` en el `.tscn`.**
  Sin eso, al guardar la escena desde el editor Godot descarta los cambios de
  forma y de cartel de los hijos de cada instancia (ya pasó una vez con
  `LeoCounter` y `TunaShelf`). Si agregas otra área instanciada, márcala con
  "Hijos editables".
- Los carteles "[Espacio] Buscar" van centrados sobre su góndola (offset
  −7/7). Puestos encima del estante parecían de la góndola de arriba.

### Y-sort de los muebles
Góndolas, heladeras, frutas, freezers y la maceta están en
`AssetsLayerInferior`, que ahora tiene `y_sort_enabled` (antes no, y Alice se
dibujaba siempre encima). Cada tile tiene `y_sort_origin` apuntando a la base
de su mueble: el final de su columna de tiles menos 4 px, que queda por
encima del punto más cercano al que llega Alice desde abajo (p. ej. góndolas
de abajo: base 428, Alice frena en 435). Los mostradores
(`AssetsLayerSuperior`) usan la misma regla. Excepciones:
- Las dos alfombras de las cajas tienen origen −64: son planas y Alice
  siempre va encima.
- Lo que está contra las paredes laterales (las columnas de estantes, las
  rejillas y los cuadros de los costados) tiene origen −64, como las
  alfombras: Alice nunca puede quedar detrás, así que siempre va delante. Con
  origen 0 por tile, el estante de abajo le tapaba las piernas al pararse al
  lado. La excepción es la maceta de abajo a la izquierda, que comparte tiles
  con la de la puerta y se ordena por su base.
- El poste bajo la caja de abajo va por tile (origen 0).
Los valores se calcularon con un script en Godot que recorre las celdas de
cada capa. Si se pintan muebles nuevos, hay que darles su `y_sort_origin`.

### Sprite de Leo
`global/npcs/assets/leo_npc.aseprite`, 32×32, basado en la ilustración de
Leo: pelo castaño despeinado, ojos celestes, camisa naranja arremangada,
delantal con el carrito, pantalón gris azulado y zapatillas grises. Tags:
`idle_side` (mirando a la izquierda, hacia su mostrador; es su pose normal,
`LEO_IDLE` en `leo_store.gd`), `idle_front` (con parpadeo; respaldo si falta
`idle_side`) y `wave` (retocado a mano), que solo usa al saludar al entrar. Se importa como
`SpriteFrames`, igual que `pedestrian_blonde`.

---

## 12. Idiomas (español e inglés)

El juego se escribe en español y se puede jugar en español o en inglés. Todo
usa el sistema de traducción de Godot (`TranslationServer` + CSV importados),
y Dialogic usa el suyo encima del mismo sistema.

**Pantalla de idioma** (`scenes/language_select/`): es la escena principal.
Flechas para elegir, Espacio o Enter para confirmar, y pasa al apartamento con
`FadeTransition`. Viene marcado el último idioma usado. La escena tiene
`auto_translate_mode` desactivado: cada idioma se muestra con su propio nombre.

**`Localization`** (autoload, `autoload/Localization.gd`): guarda el idioma en
`user://settings.cfg` y lo aplica al arrancar, así que una escena lanzada sola
desde el editor también sale en el último idioma elegido.
`Localization.set_language("en")` cambia todo el juego.

**Los textos, en tres CSV** (`translations/`, columnas `keys,es,en`):

| Archivo | Qué tiene | Clave |
|---|---|---|
| `dialogic_timeline_translations.csv` | Todas las líneas y opciones de los `.dtl` | `Text/<id>/text`, `Choice/<id>/text` |
| `dialogic_character_translations.csv` | Nombres de los personajes (`.dch`) | `Character/<id>/name` |
| `game_text.csv` (solo `keys,en`) | Todo lo demás: pensamientos (`ThoughtTrigger`, `RemarkInteractable`, `AmbientThought`, `BoundaryArea`), `prompt_text`, textos de `Label`/`Button`, constantes de código (`LOST_LINES`, `STUMBLE_LINE`, el interludio de Leo...) | el propio texto en español |

- **Dialogic:** cada línea de un `.dtl` lleva al final un `#id:xx`. Ese id es
  la clave en el CSV: **no lo borres ni lo copies a otra línea** al editar.
  Si cambias el texto en español, el inglés sigue siendo el viejo hasta que
  lo actualices en el CSV.
- **`game_text.csv`** usa el texto en español como clave: si una línea no
  está en el CSV (o su columna `en` está vacía), se ve en español. Si cambias
  una línea en español en el inspector, su traducción se pierde (queda la
  vieja en el CSV como fila huérfana hasta la próxima actualización).
- **Qué textos encuentra el recolector:** en escenas, las propiedades
  `lines`, `first_line`, `thought_lines`, `thought_text`, `prompt_text`,
  `interlude_lines` (y `text` de `Label`/`Button`); las mismas en los `.tres`
  (p. ej. `global/remarks/ambient_npc_pool.tres`); en código, las constantes
  que parecen frases y cualquier literal escrito como `tr("...")`. Las
  constantes se recorren enteras: textos sueltos, `Array`,
  `PackedStringArray` y los **valores** de los `Dictionary`, también
  anidados (las claves son ids y no se recogen). Antes del 2026-11-17 solo
  miraba textos y listas de primer nivel, así que al actualizar el CSV
  **borraba unas 100 claves** que la plaza guarda en diccionarios (charlas y
  curiosidades de Lía, cabinas, pensamientos, guardia...). Comprobado con
  el arreglo, dentro del juego y en modo `--script`: el CSV sale con las
  mismas 309 claves y sin perder ningún `en`. Un texto
  nuevo con otro nombre de propiedad hay que añadirlo a
  `TranslationCollector.TEXT_PROPERTIES`.
- **Cómo se traduce en el juego:** `ThoughtBox.say()` pasa cada línea por
  `tr()`; los `Label` y `Button` se traducen solos (`auto_translate`), y por
  eso `prompt_text`, el interludio de `FadeTransition` y los textos fijos de
  las escenas no necesitan código. Una constante nueva de código que se
  muestre de otra forma necesita su `tr()`.
- **Puzzles:** tienen su propia versión por idioma (ver `AnxietyPuzzle`, §5).
- **Texto dibujado en el arte** (carteles, "MEOW!"): no se traduce.

**Flujo al escribir texto nuevo:**
1. Escríbelo en español, como siempre.
2. Diálogos: Dialogic → Ajustes → Traducción → **Update CSV files** (añade los
   `#id:` nuevos y las filas al CSV, sin tocar las traducciones que ya hay).
   **Cuidado:** si sale un aviso de que cambiaron los ajustes, elige
   "Keep old & Generate new": el botón OK de ese aviso, y el botón de borrar
   traducciones de esa pestaña, borran los CSV con todo el inglés.
3. Resto del texto: abre `global/localization/update_translations.gd` en el
   editor de scripts y pulsa **Ctrl+Shift+X** (Archivo → Ejecutar).
4. Rellena la columna `en` de las filas nuevas (Excel/Sheets/un editor de
   texto; guárdalo en UTF-8). Godot reimporta el CSV solo.

Desde la terminal, con el editor cerrado, todo de una vez:
`godot --headless --path . --script res://global/localization/update_translations_cli.gd`
(`TranslationCollector`, `global/localization/translation_collector.gd`).

Añadir un tercer idioma: una columna nueva en los CSV, su código en
`Localization.LANGUAGES` y en `TranslationCollector.LOCALES`, una opción en la
pantalla de idioma, y versiones de los puzzles.

### Español neutro (2026-11-15)
Todo el texto en español está en un español neutro de doblaje, sin marcas
fuertes de España ni de un solo país (revisión de Guion aprobada por el
usuario: `narrative/revision_espanol_neutro.md`). Al escribir texto nuevo:

| Se usa | Se evita |
|---|---|
| auto, estacionado | coche, carro, aparcado |
| lentes | gafas, anteojos |
| refrigerador | nevera, frigorífico |
| boleto (del metro); "ticket" solo para el recibo de la tienda | billete |
| teléfono | móvil, celular |
| paso peatonal | paso de cebra |
| folleto | volante, flyer |
| tomar (un tren), agarrar (con la mano) | coger |
| Bueno, Está bien, De acuerdo; coletilla "¿sí?" | vale, ¿vale? |
| ustedes | vosotros, os, vais |
| dice (un texto escrito) | pone |
| mostrar | enseñar (con ese sentido) |
| a lo mejor, quizá / de todos modos, aun así | igual (con esos sentidos) |
| cuando sea grande (Lía) | cuando sea mayor |
| seguro que + verbo | "seguro" sin "que" |
| "lindo" para personas, "bonito" para cosas | — |

Diminutivos de niña en Lía (poquito, despacito) sí; regionales en la
narración o en Alice (cachetes, chiquito), no. Al aplicarla se cambiaron solo
los textos en español: las líneas de las timelines conservan su `#id` (se
rehízo la columna `es` del CSV y el inglés de las cuatro que cambiaban de
sentido), y en `game_text.csv` cambiaron a la vez la clave y el texto en el
código o la escena. También se borraron dos claves que ya no usaba nada.

---

## 13. Sonido

Todo el audio está en `audio/` (`ambience/`, `music/`, `sfx/`), ya recortado, en
bucle y con el volumen igualado. De dónde sale cada archivo, y qué se le hizo,
está en `audio/CREDITS.md` (todo de Pixabay, sin atribución obligatoria).

**Tres buses** (`default_bus_layout.tres`, panel Audio del editor): `Music`
(−2 dB), `Ambience` (−8 dB: el ambiente es aire de fondo, nunca tapa la música) y `SFX`. Para subir o bajar un tipo de sonido en todo
el juego, se toca el bus, no cada archivo.

**`SoundManager`** (autoload, `autoload/SoundManager.gd`): sobrevive a los
cambios de escena, así que el sonido de una escena se funde con el de la
siguiente (1,5 s) en vez de cortarse. API: `set_music(stream, db)`,
`set_ambience(stream, db)` (null = silencio; si es el mismo stream sigue
sonando donde iba) y `play_sfx(stream_o_nombre, db, pitch)`.

**`SceneAudio`** (`global/scene_audio.gd`): un nodo por escena dice qué suena en
ella, con `ambience`/`music` y su volumen en el inspector. Hueco vacío =
silencio (lo anterior se apaga). Una escena sin `SceneAudio` deja sonar lo que
hubiera.

**Música propia** (ElevenLabs, 2026-11-11, ver `audio/CREDITS.md`): cada
momento es una **lista** (`audio/music/playlists/<nombre>.tres`,
`AudioStreamPlaylist`, orden aleatorio, en bucle, 2 s de fundido entre
pistas), no un archivo en bucle: así alterna las variantes. Las pistas están
igualadas a −21 LUFS (FFmpeg `loudnorm`) y el volumen de cada escena se ajusta en su
`SceneAudio`. Para añadir una variante, se mete el OGG en la lista. Si dos
escenas seguidas usan la misma lista (calle → plaza), la música sigue sin
cortarse.

| Escena | Ambiente | Música |
|---|---|---|
| Selección de idioma (menú) | — | `theme` (−6 dB) |
| Apartamento | `apartment` (salón, tráfico lejano; −2 dB) | `apartment` (−8 dB, debajo de los diálogos) |
| Andén | `metro_platform` (andén + gente) | — (falta la del metro) |
| Vagón | (su `TrainAmbience` propio, `train_ride`, que se apaga al dormirse) | — |
| Estación desconocida | `unknown_station` (andén vacío, apagado) | — |
| Calle | `street` | `street` (−12 dB, casi de fondo) |
| Plaza | `street` | `street` (−12 dB); `lia` (−10 dB) desde `lia_grabs_sleeve` hasta que Lía se va con su madre (`plaza.gd`, `LIA_MUSIC`) |
| Tienda de Leo | `leo_store` (nevera) | `leo_store` (−6 dB) |
| Fin de la demo | — | `theme` |

**Efectos y dónde se disparan:**
- **Tren:** `metro_stations.gd` hace sonar la llegada al llamar al tren y la
  campanita al abrir y cerrar las puertas (señales `doors_opened`/`doors_closed`
  de `metro_train`). `unknown_station.gd` hace sonar la salida al irse el tren: el sonido va pegado al tren (`AudioStreamPlayer2D` hijo de `MetroTrain`, se desplaza y se atenúa con él) y además se apaga en lo que tarda el tren en irse (`arrival_time * 1.5`), así que se disipa mientras se aleja.
- **Puertas** (`basic_door.gd`): `open_sound` (export) al abrirse. Vacío = puerta
  muda.
- **Campanita de la tienda:** al entrar (`leo_store.gd`, `_ready`).
- **Wilson:** mientras maúlla (animación `meowing`), un maullido cada
  `meow_interval` s (3). Suena desde donde está él (`AudioStreamPlayer2D`, se
  apaga a `meow_hearing_distance` px), así que se pierde al alejarse y no
  sigue en el interludio. Después de la despedida (`stay_home()`, la llama
  `outside_door.gd`) solo maúlla `meows_after_goodbye` veces (2). En los diálogos, `[signal arg="sfx:meow"]` antes de cada
  línea en que maúlla.
- **Desde Dialogic:** `[signal arg="sfx:<nombre>"]` con cualquier nombre de
  `SoundManager.SFX` (`meow`, `door_open`, `shop_bell`, `train_chime`).
- **Rompecabezas de la Ansiedad:** solo en los de verdad (no en el espejo), un
  latido que se acelera (×1 → ×1,4) y sube de volumen con la presión, y una
  respiración que entra al 60 % del tiempo (`BREATHING_FROM`) y no pasa de
  −24 dB. Antes entraba a la mitad y llegaba a −12 dB, y en YouTube
  comentaron que el jadeo era exagerado. Se apagan con el puzzle.
- **Pasos de Alice** (`player.gd`): en cada fotograma de `step_frames`
  (`[0, 3]`) de `walk_front/back/side` suena uno de los 4 `footstep_*.ogg`,
  nunca el mismo dos veces seguidas y con el tono un poco al azar (×0,92–1,08),
  a `footstep_volume_db` (−12). Solo con animaciones `walk_`, así que las de
  cinemática no suenan. Si un paso no cae justo cuando el pie toca el suelo,
  cambia `step_frames` en el inspector de Alice.
  Al girar caminando, la animación nueva sigue en el mismo fotograma y punto
  del ciclo (`_switch_walk_animation`) en vez de volver al 0, que es un
  fotograma de paso: si no, sonaba un paso de golpe y cortaba el anterior.
  Además, nunca suenan dos pasos a menos de 0,25 s y un paso no corta la
  cola del anterior (`max_polyphony = 2`).
- **Pantalla de idioma:** un pitido suave al mover la selección.
- **"Bajo el agua" en el Rompecabezas:** al empezar cualquier puzzle,
  `SoundManager.set_muffled(true)` baja el filtro de paso bajo de los buses
  `Music` y `Ambience` (20 kHz → 500 Hz) y los baja 6 dB en 0,6 s; al acabar
  vuelve todo. El latido y la respiración van por `SFX`, sin filtro.

Añadir un sonido: recórtalo/normalízalo, ponlo en `audio/`, apúntalo en
`CREDITS.md`, y si es un bucle activa **Loop** en su panel de importación.

**Bucles de música sin corte:** la música no se repite de punta a punta (se
notaba un corte a mitad de frase). Cada pista se analizó para encontrar dos
puntos donde suena lo mismo (mismo compás de la misma frase): el archivo
acaba en el punto final E, sus últimos 80 ms se funden con lo que suena justo
antes del punto S, y el importador vuelve a S al llegar al final (**Loop** +
`loop_offset` = S en segundos, en el panel de importación). La intro solo
suena la primera vez. Los puntos de cada pista están en `CREDITS.md`. Una
música nueva necesita lo mismo: si solo se activa Loop, vuelve al segundo 0.

---

**Arranque del tren visto desde el andén** (2026-11-17): el sonido de
salida (`audio/sfx/train_departure.ogg`) es del propio tren. `metro_train.gd`
tiene el export `departure_sound` (vacío por defecto) y
`departure_hearing_distance` (900 px). Si tiene sonido, `leave_station()` lo
reproduce en un `AudioStreamPlayer2D` hijo del tren (bus `SFX`): se mueve
con él y baja a −60 dB durante lo que tarda en irse (`arrival_time` × 1,5).
Lo usa `unknown_station.tscn`. En `metro_stations` va vacío, porque Alice
va dentro y la escena cambia enseguida. Antes, cada escena tenía su propia
copia de `_play_departure_sound()`.

## 14. Cosas pendientes / a vigilar

- **Feedback de jugadores para el Rompecabezas de la Ansiedad (pendiente, 4 nov 2026).**
  Viene de un comentario de @ryux0000 en un vídeo de YouTube:
  *"You should probably have those thoughts literally switch up/change in random intervals. Probably even add thoughts like 'can I go home', 'I gotta go', etc. In my opinion the panting is kinda exxagerated."*
  Plan acordado:
  - **Pensamientos que cambian solos.** Solo las palabras distractoras (`extra_words`); las de las respuestas se quedan quietas para que el puzzle siga siendo justo. Cada pocos segundos, una distractora se desvanece y reaparece como otro pensamiento de una lista común (*"go home"*, *"just leave"*, *"they're staring"*, *"say something"*, *"too late"*…). Con más presión, cambian más a menudo. La lista va en `game_text.csv` con su versión en español.
  - **Respiración más contenida.** Hoy `BREATHING_DB` sube hasta -12 dB y entra en la segunda mitad del tiempo (`pressure * 2.0 - 1.0`). Bajar el máximo a unos -20 dB y que entre solo en el último tercio. Si sigue sonando forzada, cambiar `audio/sfx/breathing_loop.ogg` por una respiración más corta.
  - **Para la comunidad:** cuando esté hecho, enseñarlo en un vídeo ("a viewer suggested this, so I added it") y contestar a @ryux0000.

- **Crash al cerrar el juego en macOS (Godot 4.7).** Cerrar el juego después de
  haber cargado cualquier escena con `TileMapDual` termina con
  `Program crashed with signal 11` dentro de `NSApplication terminate`
  (MoltenVK). Pasa al pulsar "[Espacio] Salir" en `demo_end`, pero también con
  Cmd+Q desde cualquier escena jugable. Comprobado aislando el nodo: un
  `TileMapDual` solo crashea al cerrar, y la escena sin ese nodo cierra limpio.
  Sigue pasando aunque se libere el nodo antes de salir, y no lo causan el
  shader fantasma ni las conexiones de sus *watchers* al `TileSet`. Es un fallo
  del addon (v5.0.2) o del motor, no del juego.
  **Rodeo actual: el autoload `AppExit`** (`autoload/AppExit.gd`). En macOS,
  todas las salidas terminan el proceso directamente (`OS.kill` del propio
  proceso), sin pasar por el cierre normal de Godot: "[Espacio] Salir" de
  `demo_end` llama a `AppExit.quit_game()`, y Cmd+Q o el botón de cerrar
  llegan como `NOTIFICATION_WM_CLOSE_REQUEST`, que `AppExit` atiende con
  `auto_accept_quit = false`. En otros sistemas cierra con `get_tree().quit()`.
  No hay partidas guardadas, así que no se pierde nada. **Para cerrar el juego
  desde código, usa siempre `AppExit.quit_game()`, nunca `get_tree().quit()`.**
  Si una versión nueva del addon o de Godot arregla el crash, este rodeo se
  puede quitar.

- **La salida de `unknown_station.tscn` es un placeholder deliberado.**
  `ExitToStreet`/`ExitToStreet2` apuntan a `apartment.tscn` porque la escena de
  la calle todavía no existe — no es un bug, es la decisión consciente de no
  dejar un `next_scene_path` vacío que no lleve a ningún sitio.
- **Al salir de la tienda de Leo, Alice aparece en el inicio de la calle**
  (177, 613) y no frente a la puerta. Además los `ThoughtTriggers` de la calle
  se vuelven a disparar, porque la escena se recarga desde cero. Para
  arreglarlo hace falta un punto de aparición, como `SpawnContainers` en
  `metro_train_interior.gd`, y guardar en `GameManager` qué pensamientos ya
  salieron.
- `metro_stations.tscn` es la escena activa del andén. La copia antigua con
  espacio fue eliminada para evitar rutas ambiguas.
- **Gente del andén:** con conversación (globito "..."), `ImportantMan` y
  `TwoYoungGuys`. De fondo (`AmbientThought`): `BenchSitter` (pool),
  `ReadingStander` ("Lee de pie, en pleno andén." / "Yo me mareo si leo en el
  metro."), `PhoneGirl` ("Habla por teléfono como si nadie la oyera.") y
  `ListeningGuy` ("Auriculares puestos. Así nadie te habla." / "Yo también
  llevo los míos."). Los tres últimos antes no respondían a nada.
- La escena reutilizable de escaleras vive en `global/stairs/` y conserva su
  UID original para no romper las instancias existentes.
- **`TrainAmbience`** no tiene sonido asignado; el código lo detecta y no falla.
- El `SpriteFrames` del trabajador y de `WalkingNPC` en general siguen usando
  arte placeholder en varias animaciones — revisa `has_animation()` antes de
  asumir que algo se ve como debería.
- `basic_door.gd::_is_player_body()` acepta cualquier `CharacterBody2D`, así que
  Wilson y los NPCs también abren puertas. Puede ser intencionado.
- **Toda la calle se bajó 12 filas (384 px)** para dejar sitio a más ciudad
  arriba sin coordenadas negativas. La zona jugable va ahora de y=384 a
  y=1152 (las coordenadas de esta sección y de "Límites del mapa" son
  anteriores: súmales 384). La franja y=0–384 está vacía; los tejados más
  altos (torre de vidrio y edificio alto) llegan hasta y=256.
- La cámara de Alice en la calle tiene `limit_top = 0` y
  `limit_bottom = 1152`. Antes del cambio, la torre de vidrio y el edificio alto subían hasta
  y=-128 y quedaban cortados; con la franja nueva ya se pueden mostrar.
- La franja de arriba ya tiene y-sort y colisiones: árboles grandes, macetas
  con árbol, columna verde, jardineras y cartel del café, carrito de comida,
  contenedores y columna bajo el muro de ladrillo, parquímetro, sillas del
  patio, parada de bus y el edificio amarillo de la esquina (colisión en todo
  su contorno). `BoundaryLeft`/`BoundaryRight` ahora miden 16×1152 y cubren
  todo el alto del mapa.
- **Después del prólogo existen** la calle (sección 10) y la tienda de Leo con
  su conversación completa (sección 11), que termina en "Continuará...". No
  existen todavía los encuentros con Clara/Rosa (Lía está en la sección 15), inventario, guardado,
  menús ni arte de retratos/cinemáticas. La "confianza" con Leo ya se guarda
  en `GameManager.leo_confidence`, pero nada la usa aún.
- **`fonts/m3x6.ttf` está modificada**: la original no traía tildes, ñ ni ü,
  y esas letras salían con la fuente de respaldo (más grandes y lisas). Se le
  agregaron á é í ó ú ñ ü y sus mayúsculas con `fonttools`, dibujadas en su
  misma grilla de píxeles (la tilde son dos píxeles en diagonal, una fila por
  encima de la letra). La usan los carteles "[Espacio]", los pensamientos y
  "Continuará...". Si se reemplaza el archivo por la versión original de
  Daniel Linssen, vuelven a romperse las tildes. `tiny.ttf` y Silkscreen
  siguen sin tildes, pero ya no se usan para textos en español. El prólogo en sí (apartamento → vagón →
  estación desconocida) es jugable de principio a fin.

---

## 15. La plaza: Lía (`plaza.tscn` + `plaza.gd`)

Adaptación del Twine "Escena Lia" (`Documents/Twine/Stories/Escena Lia.html`).
Por ayudar a Lía, Alice pierde el último tren: eso justifica que esté en la
plaza de noche (Clara). **Lía tiene su propio sprite** desde 2026-11-05
(`global/npcs/assets/lia.aseprite`: `idle_front/side/back` y
`walk_front/side/back`); es un `WalkingNPC` con `frames = lia.aseprite`. `_slide()`
reproduce el ciclo de caminar (`play_move()`) en los `WalkingNPC` y al final
los deja quietos mirando hacia donde iban. Su madre también tiene sprite
propio desde 2026-11-16 (`global/npcs/assets/lia_mom.aseprite`, `WalkingNPC`).

**Los movimientos de cutscene rodean obstáculos** (2026-11-17): `_slide()` y
`_walk_player()` ya no van en línea recta. Piden la ruta a `CutsceneNav`
(`global/cutscene_nav.gd`, un `NavigationRegion2D` en la raíz de la plaza),
que al arrancar hornea en segundo plano la zona caminable a partir de todas
las colisiones estáticas de la escena (tiles y `StaticBody2D`, capa 1) dentro
de `bounds`, con un margen de `agent_radius` 10 px. Con 6 px pasaban rozando
el borde de arriba de los setos, que solo chocan en su base. Mientras no está
lista, `route()` devuelve la línea recta. `_slide()` conserva la velocidad de
la línea recta, así que un rodeo tarda un poco más. Afecta a la madre, la
salida de la familia, Lía (curiosidades, palomas, Toby, ir junto a Alice),
Toby y Alice yendo al guardia. La madre camina a `MOTHER_WALK_SPEED`
(75 px/s) y la familia se va a `LEAVING_WALK_SPEED` (50 px/s). Antes
recorrían unos 400 px en 1,8 s y 3 s, y parecía que se deslizaban.
**Dos modos de ruta** (2026-11-17, corregido 2026-11-23): el césped no tiene
colisión (Alice puede pisarlo). `CutsceneNav` hornea dos mallas, cada una en
su propio mapa de navegación privado (ya no es un `NavigationRegion2D`, es un
`Node2D`):
- **Libre** (por defecto, `route(from, to)`): solo bloquean las colisiones.
  Es para los movimientos cortos: las curiosidades de Lía, ir junto a Alice,
  Toby, el guardia, el corredor.
- **Solo pavimento** (`route(from, to, true)`, y `_slide(..., true)` /
  `_path_length(..., true)` en la plaza): además evita el césped. Solo la
  usan quienes llegan o se van como transeúntes: la llegada de la madre y la
  salida de la familia. `avoid_layers` = `FloorLayer1` (el césped): cada celda
  pintada ahí entra como obstáculo (una franja por fila de celdas), salvo si
  también está pintada en `keep_layers` = `FloorLayer2`, el pavimento (parte
  de la plazoleta de la fuente tiene pavimento encima del césped). Si el
  origen o el destino están en césped no hay camino por pavimento hasta ahí,
  así que usa la libre.

Antes todo iba solo por pavimento y era un bug (vídeo del usuario,
2026-11-23): con Alice y Lía dentro del jardín del picnic, Lía salía del
jardín, daba la vuelta por la acera de fuera de la valla y el último tramo
la cruzaba (471 px en vez de 76). Probado: desde cualquier punto con línea
recta despejada las rutas a las 8 curiosidades miden lo mismo que la recta
(287 casos) y ningún tramo cruza colisiones estáticas. En el juego, Lía va
directa a cada una (también a la furgoneta de helados). La madre y la salida
de la familia siguen 100 % por pavimento.

**El sitio de Lía nunca cae dentro de una colisión:** algunos puntos de
curiosidad están sobre lo que enseñan (el del escaparate, dentro de la pared
del edificio), así que, llegando de lado, el sitio a `look_distance` caía en
la fachada. `_lia_explores()` y las palomas pasan el sitio por
`cutscene_nav.closest()`: el punto caminable más cercano. En el escaparate,
Lía queda en y=152, justo delante de la fachada.

**Aviso «Navigation region synchronization had N edge error(s)»:** ya salía
antes de los dos modos (la malla de solo pavimento da 64). Ahora sale también
para la malla libre (48). Viene de las colisiones de tiles de 8×8 que se tocan
borde con borde: el horneado deja aristas coincidentes. La peor zona es la
columna de `MiddleLayer/AddonsSuperior` en x≈1272–1280, y≈1030–1300 (el
borde derecho, abajo), más algunos remates de setos. No afecta a las rutas.
Probado sin éxito: `cell_size` 2 o 4, triangular en vez de partición
convexa, agrandar los obstáculos y excluir esa columna (quedan 34 y 18).

**Lía sigue el rastro de Alice** (2026-11-13, `WalkingNPC.follow_trail()`):
Alice va dejando un punto cada 3 px por donde pasa y Lía va al punto que queda
`LIA_FOLLOW_GAP` (24 px) atrás en ese camino, hasta `LIA_FOLLOW_SPEED`
(130 px/s), con `move_and_slide` contra el mapa (máscara 1; ella no es sólida,
así que nunca empuja a Alice). Solo pisa por donde pasó Alice: ya no atraviesa
paredes, farolas ni la calzada, y al girar Alice no salta al otro lado. Si se
queda atascada lejos más de 1,2 s, salta al rastro. Su colisión se reduce a
los pies (`LIA_FEET`, 10 × 6, en `_shrink_lia_body()`), como la de Alice.
`_lia_takes_sleeve()` / `_lia_lets_go_sleeve()` la enganchan y la sueltan
(cutscenes, Toby, palomas, curiosidad, fuente). El llanto que oye Alice al
llegar es `audio/sfx/lia_crying_loop.ogg` (bucle) en un `AudioStreamPlayer2D`
de Lía (−4 dB, se apaga a 360 px), solo en `ARRIVED`; empieza en un punto al
azar y suena más fuerte al acercarse. Bajo cada globo de "¡Mamá!" baja a
−16 dB y vuelve (`_duck_crying()`), y sigue durante el foco del metro. Se
apaga con fundido de 1 s al hablarle (su `TalkArea`) o, en la ruta del metro,
al terminar el minijuego (`_play_puzzle()`); también, por si acaso, al ir
Alice a ella, al correr ella hacia Alice y al agarrarle la manga.
La animación `cry` de `lia.aseprite` la usa `_lia_waits_crying()` al esperar
en la banca.

### Recorrido
**Textos: "Escena Lia v2"** (aprobada 2026-11-12; fuente
`narrative/twee/escena_lia_v2.twee`, de la sesión de Guion). Ids nuevos de
Dialogic `374`–`3ae` (contador 943); quitadas `302` y `31e`.

1. **Llegada** (`ARRIVED`). Nube: "Llegué. Solo falta bajar al metro y...",
   "...¿Alguien está llorando?". Lía (`MiddleLayer/NPCS/Lia`) llora
   junto a la banca con baranda que está encima de la entrada del metro, en la
   acera de abajo (1110, 1060), al mismo lado de la calle que Alice; su `Bark`
   (`SpeechBark`) dice "¡Mamá!" cada 4 s si Alice está a menos de 360 px.
   **Prisa de Alice** (`ARRIVAL_BEATS`, `_think_about_lia`): tras los dos
   pensamientos de llegada, tres más, una vez cada uno y al menos 4 s
   (`ARRIVAL_BEAT_GAP`) entre ellos: "Está sola. ¿Dónde están sus padres?"
   cuando Lía entra en pantalla; "Alguien la va a ayudar. Alguien que no
   tenga un tren que coger." a 160 px de Lía o 200 px del metro; "...Debería
   preguntarle qué le pasa. Pero el metro..." a 100 px de Lía o 130 px del
   metro. Cada entrada es `[frase, distancia a Lía, distancia al metro]`.
   **Pasos peatonales cerrados hasta conocer a Lía** (2026-11-06): el primer
   objetivo de Alice es el metro, que está de este lado de la calle. Los tres
   pasos (`MapBoundaries/Crosswalks/CrosswalkLeft`, `Middle`, `Right`, en
   x = 63, 638, 1216, y = 1016) son `BoundaryArea` como los bordes del mapa:
   Alice piensa "No me conviene alejarme. La entrada del metro debería estar
   por aquí cerca." y retrocede. El resto de la calle ya tiene colisión.
   Cada uno tiene su `CollisionShape2D` con `RectangleShape2D_crosswalk`
   (84 × 22) y "Hijos editables" activado (`[editable path=...]`): sin eso el
   editor descartó el tamaño al guardar y volvieron al área pequeña por
   defecto.
   `plaza.gd` los desactiva (`_open_crosswalks()`) con `lia_grabs_sleeve` y al
   cargar la plaza en cualquier etapa que no sea `ARRIVED`.
2. **Primera decisión** (2026-11-06: Lía ya no persigue a Alice nada más
   llegar al metro). Dos formas de llegar a ella:
   - **Hablarle antes del metro** (su `TalkArea`): `plaza_lia_meet` desde el
     principio. Descripción de la niña, Alice piensa "(tiene que ser rápido.
     El metro no la va a esperar.)" y salta a `approach` (*Rama_Acercarse*,
     +1, `lia_approached_first`) sin rompecabezas, porque ya eligió
     acercarse. Luego la **segunda decisión** (menú: calmada +2 / nerviosa +1
     / bloqueada −1).
   - **Ignorarla e ir al metro**: al entrar en `SubwayArea`,
     `_lia_at_the_metro()` bloquea a Alice y arranca
     `Dialogic.start("plaza_lia_meet", "metro")`. `[signal arg="focus_on_lia"]`
     lleva la cámara hacia Lía (`pan_camera_to`, 0,9 s). Desde el 2026-11-14
     encuadra a las dos (`_frame_alice_and_lia`: el punto medio, bajado lo
     justo para que los pies de Alice queden por encima de la caja de
     diálogo, que tapa el 27 % de abajo, `DIALOGUE_BOX_SHARE`); antes centraba
     a Lía y Alice quedaba debajo de la caja. "(La niña sigue
     llorando.)", "(Nadie se detiene...)", "(podría seguir caminando. Nadie la
     obliga a meterse. Pero no puede dejar de mirarla.)". Después el
     rompecabezas `plaza_lia` hace de las tres decisiones del Twine:
     - "ask" = *Rama_Acercarse*: `alice_goes_to_lia` (la cámara vuelve y
       Alice camina hasta 22 px de Lía) y salta a `approach`.
     - "leave" = *Rama_No_Acercarse_Pasa*: `alice_turns_away` (mira hacia la
       escalera), "da media vuelta" y `chase`: Lía corre hasta ella
       (`lia_comes_to_alice`) y le agarra la manga (−1,
       `lia_tried_to_leave`), luego `forced`.
     - callarse = *Rama_No_Acercarse_Espera*: Lía la ve, se levanta y corre
       hasta ella (`lia_comes_to_alice`), "¡Tú llevas rato mirándome!",
       luego `forced`.
     `lia_comes_to_alice` la pone en el primer sitio libre junto a Alice
     (`_free_spot_by_alice`: el lado de donde viene, el otro, debajo,
     encima; comprueba que sus pies no toquen nada sólido). Lía se desliza
     con la colisión apagada y antes podía quedar encima de la barandilla de
     la boca de metro.
     Cada señal de movimiento pausa Dialogic mientras dura. Al terminar, la
     cámara vuelve a Alice y se desbloquea.
   Todas terminan en `[signal arg="lia_grabs_sleeve"]` (`WITH_LIA`): Lía la
   sigue agarrada de la manga (Alice camina a ×0.75) y le va hablando en su
   `Bark` (ver "Burbujas de Lía" más abajo). Al empezar, nube
   (`SEARCH_START_LINES`): "Alguien en la plaza tiene que haberla visto." y
   "Solo hasta encontrar a su mamá. Después, el metro.". Si Alice vuelve al
   metro durante la búsqueda: sin pistas, "El tren todavía no ha pasado." /
   "Primero, su mamá." (`SUBWAY_WITH_LIA_LINES`); con 1 o 2,
   "Aquí no hay nadie con vestido rosa." / "Vamos, Lía. Por aquí no es."
   (`SUBWAY_SEARCHING_LINES`).
3. **La búsqueda** (`WITH_LIA`). Tres personas pueden ayudar, en el orden
   que el jugador quiera (o ninguno); con **2 pistas** (`LIA_CLUES_NEEDED`)
   Alice sabe que tiene que ir a la fuente (`KNOWS_FOUNTAIN`). En cada una,
   Lía sube la tensión:
   - **Heladero** (`IceCreamMan`, columna 22 de `npcs_sprite_sheet`, en la
     acera junto a su camión, `plaza_ice_cream`): un señor mayor y paciente.
     El camión es `ParkedVehicles/IceCreamVan`
     (`scenes/street_scenes/assets/ice_cream_van.aseprite`, textura fija,
     región 71×58 del lienzo de 100×100; la posición del nodo es la base de
     las ruedas), aparcado en el tramo despejado de la calle de abajo, junto
     al paso de cebra de la derecha. Alice tartamudea y Lía la
     interrumpe a gritos. Pista: la vio ir hacia la fuente hace unos veinte
     minutos. Si Alice no se acercó a Lía por su cuenta, después viene la
     charla de "¿Tú qué estabas comprando?" del Twine.
   - **Señora del perro** (`DogLady`, `plaza_dog_lady`): mujer joven que sale
     a correr con Toby (`MiddleLayer/NPCS/Toby`, sin "..." porque no habla).
     Desde 2026-11-03 los dos son `WalkingNPC` con sus propios sprites
     (`global/npcs/assets/sporty_girl.aseprite`: `idle_front`, `run_side`;
     `dog.aseprite`: `idle_side`, `run_side`; las columnas 23 y 24 de la hoja
     ya no se usan). Sus animaciones van en el export `frames` de cada
     `WalkingNPC` (ver más abajo) y `move_animation = "run"`. Ella va y vuelve por la acera
     de arriba, entre la valla y los edificios (`JoggingRoute/Point1`–`2`,
     y = 210, 70 px/s), y descansa 12–15 s en cada punta; se para y mira a
     Alice si se acerca a 44 px (`pause_near_player`), así se le puede
     hablar. Toby la sigue con `follow()` a 16 px a su derecha y 5 px más
     abajo; en las puntas mira hacia el siguiente tramo. Las palomas que
     estaban en esa acera (`Pigeons/TopSidewalk`) pasaron al paseo central de
     arriba (640, 300). **Colocación al hablar con ella** (2026-11-17,
     esquema del usuario; en todos sus timelines: el de la pista, `_extra`,
     `_idle` y `_after`, con o sin Lía): al empezar el timeline, Dialogic
     espera (`_runner_layout`, conectado a `interacted` →
     `timeline_started`) mientras todos caminan a su sitio por la ruta de
     `CutsceneNav`. Alice queda a 28 px a la izquierda de la corredora,
     mirando a la derecha; si venía por la derecha, la rodea por abajo.
     Lía (si está con ella) va abajo a la izquierda de Alice (−14, +12) y
     mira a la derecha. Toby va abajo a la derecha de la corredora
     (+14, +12) y mira a la izquierda. La corredora solo tiene `idle_front`
     y `run_side`, pero su `idle_front` está en 3/4 mirando a la derecha:
     durante la charla se voltea para mirar a Alice
     (`WalkingNPC.flip_front_idle`, una variable que la escena activa un
     rato y que hace que `face_direction()` voltee la pose de frente hacia
     la izquierda). Al terminar se apaga y ella vuelve a su orientación
     normal (decisión del usuario, 2026-11-17). En ese
     arreglo, `toby_comes` hace que Toby trote a olfatear las rodillas de
     Alice y vuelva a su sitio a los 1,4 s, y `lia_lets_go` solo le suelta la
     manga (Lía no se mueve). Al terminar (`_runner_talk_over`), Toby vuelve
     a seguir a su dueña, Lía vuelve a la manga si la llevaba y la corredora
     sigue corriendo cuando Alice se aleja (`pause_near_player`). Menú: preguntar igual (+1) o
     apartarse primero. Pista: iba preocupada, preguntando por una niña,
     hacia la fuente.
   - **Chico con auriculares** (`Teen`, columna 25 de `npcs_sprite_sheet`,
     sentado en la banca frontal del paseo de la derecha, raíz en (957, 502),
     `plaza_teen`, personaje `headphones_teen`): no la oye. Lía le tira de la
     manga ("¡Más fuerte!"). Menú: subir la voz (+1) o hacerle gestos. Pista:
     no vio a nadie, pero la fuente está al otro lado.
   Cada pista se manda con `[signal arg="lia_clue:<id>"]` y se guarda en
   `GameManager.lia_clues`. `plaza.gd` (`_refresh_helpers`) les cambia el
   `timeline_name` en cuanto cambia la etapa (`_set_stage()`, el único sitio
   donde se asigna `plaza_stage`) y al terminar cada diálogo. Antes solo lo
   hacía al terminar un diálogo: como la etapa pasa a `LIA_HOME` justo
   después de `plaza_lia_fountain`, el primer ayudante al que se hablaba
   tras entregar a Lía hablaba como si siguiera con Alice (2026-11-17).
   Reglas: la de la pista solo mientras se busca y no se les ha
   preguntado; en `KNOWS_FOUNTAIN`, al que nunca se le preguntó,
   `<timeline>_extra` (conversación opcional completa, ver abajo); si no,
   `<timeline>_idle` (una línea antes de Lía y otra después). Tras la
   primera pista sale "Mejor preguntarle a alguien más..." y tras la segunda
   "La fuente. Vamos a la fuente.".

   **Con 2 pistas (`KNOWS_FOUNTAIN`)** (2026-11-12, opción A del usuario):
   - Los ayudantes **que ya ayudaron** ofrecen una vez su despedida
     `plaza_<ayudante>_extra` (`plaza_ice_cream_extra`,
     `plaza_dog_lady_extra`, `plaza_teen_extra`), que termina con
     `[signal arg="lia_extra:<id>"]`; luego pasan a `_idle`.
   - El **que falta** ofrece su conversación completa normal, con una
     variante para "ya sabemos lo de la fuente": un bloque
     `if {GameManager.lia_knows_fountain}:` dentro de su timeline (getter de
     `GameManager`, verdadero en `KNOWS_FOUNTAIN`). Su `lia_clue` final ya no
     suma pista ni lanza pensamientos: `_add_clue` lo apunta en
     `GameManager.lia_extras` y pasa a `_idle`.
   - Variantes (textos de Guion): el heladero cambia "¡Hacia la fuente!"
     (`#id:328`, que pasa a un `else`) por dos líneas tras `#id:327`; la
     corredora añade dos tras `#id:343`; el chico dos tras `#id:35b` (sigue
     la burla de "superfuerte" si le subió la voz).
   La de la corredora reutiliza `toby_comes` / `lia_lets_go` /
   `lia_holds_on` (Toby se le sienta en el pie). El chico tiene además dos
   líneas al final si Alice le subió la voz (`[signal arg="lia_teen_loud"]`
   → `GameManager.lia_teen_loud`).

   **Burbujas de Lía** (2026-11-12): los textos están en
   `scenes/plaza_scene/scenes/lia_chatter.gd` (`LiaChatter`), en tres fases
   según las pistas: `EARLY` (0), `MIDDLE` (1) y `LATE` (2, camino a la
   fuente). Cada entrada es `[frase de Lía, respuesta de Alice]`. Lía dice
   una cada 20–30 s (`LIA_CHATTER_EVERY`), sin repetir hasta agotar la fase,
   y empieza de nuevo al cambiar de fase. Alice contesta **en voz alta**, en
   su propio `SpeechBark` (lo crea `plaza.gd` sobre su cabeza,
   `ALICE_BARK_OFFSET`), 1,4 s después; una respuesta `""` = se queda
   callada. Nada sale durante una conversación. Cada frase necesita su fila
   en `game_text.csv`. Seis pares por fase.
   **Burbujas que no se pisan** (2026-11-14): con Lía de la manga, la
   respuesta de Alice salía encima de la frase de Lía y no se leía ninguna.
   `SpeechBark` lleva una lista de las burbujas en pantalla (`_shown`, la más
   antigua primero) y la que salió después sube por encima de cualquier otra
   que tape (`_above_earlier_bubbles`, 4 px de separación). Vale para todas
   las burbujas del juego.

   **Lía señala a los ayudantes** (2026-11-14, playtest: la corredora se
   mueve y el chico no se ve): en `WITH_LIA`, con Lía de la manga, al pasar a
   menos de `HELPER_HINT_DISTANCE` (110 px) de un ayudante al que aún no le
   preguntaron, Lía dice sus burbujas y Alice contesta en la suya
   (`HELPER_HINTS`, mismo formato que las curiosidades, `_lia_then_alice`).
   Una vez por ayudante (`GameManager.lia_helper_hints`), nunca encima de
   otra burbuja ni de una conversación, y retrasa su charla
   (`_point_out_helpers`). El heladero está junto a su camión: antes de la
   primera pista, su aviso y la curiosidad `IceCreamVan` (versión `early`)
   hablan del mismo sitio, así que solo sale la primera que toque (cada una
   marca la otra como vista).

   **La fuente con una sola pista** (2026-11-14): llegar a la fuente en
   `WITH_LIA` con una pista no hacía nada y parecía un cuelgue. Ahora sale un
   pensamiento una vez por visita (se rearma al salir del área) y la escena
   no se dispara (`_fountain_too_early`): con una pista
   `FOUNTAIN_ONE_CLUE_LINES` ("No está aquí. Todavía no."...), sin pistas
   `FOUNTAIN_NO_CLUE_LINES` ("Una fuente... pero ni rastro de su mamá."...).

   **La entrada de la plaza** (`MapBoundaries/BoundaryEntry`, 2026-11-14):
   decía "Por ahí vine. Ahora, a buscar el metro." también con Lía. Ahora
   `plaza.gd` le cambia `thought_lines` según la etapa en su `interacted`
   (`ENTRY_LINES`): con Lía, "Por ahí vine yo." / "Su mamá se fue hacia la
   plaza, no por aquí."; después, "Por ahí no. La entrada del metro está
   aquí al lado.". La pista de Lía también cambió (`plaza_lia_meet`, ids
   293, 29d, 2a6, 2ba): su mamá se fue "hacia la plaza", al otro lado de la
   calle, no "por la entrada de la plaza", que está cerrada.

   **Cabinas de la plaza** (2026-11-14): las cuatro cabinas azules de la valla
   de abajo del parque (`InteractableDetectors/Payphones/Payphone1..4`,
   `InteractableArea` sin timeline, 18×34, en x 276/404/884/1012, y 858)
   responden igual y comparten la cuenta. Antes de Lía (`ARRIVED`) están
   apagadas (`_refresh_payphones`). Con Lía (`WITH_LIA`/`KNOWS_FOUNTAIN`), la
   primera vez Alice piensa "Una cabina. No me queda ni una moneda." y Lía
   contesta en burbujas (se sabe el número de su mamá... más o menos), con
   respuesta de Alice; las siguientes, Lía juega a llamar. Sin pista y sin
   caja. Después de que Lía se va, solo nube sobre el número de Leo, y otra
   las siguientes veces. Textos en `PAYPHONE_WITH_LIA` / `PAYPHONE_ALONE`;
   la cuenta por fase en `GameManager.plaza_payphone_visits`. Las dos
   cabinas de la calle (`street_payphone*`) no cambian: ahí Alice todavía no
   tiene el número de Leo.

   **Setos** (2026-11-14): los setos de la plaza (atlas `41–46 × 4–7` de
   `Addons`) solo tenían colisión en la fila de abajo y Alice podía cruzar
   por su mitad de arriba, como si caminara por dentro. Las filas 5 y 6
   tienen ahora colisión; la de arriba (4) sigue libre para que pueda
   quedarse detrás con las piernas tapadas.

   **Lía y las palomas** (2026-11-12, rediseñado el 2026-11-13; opcional,
   una sola vez, no da pista): empieza como una curiosidad y solo pasa a la
   caja si Alice se queda. Con Lía de la manga (`WITH_LIA` o
   `KNOWS_FOUNTAIN`), la primera vez que Alice se acerca a un grupo de
   palomas, el grupo avisa (`PigeonFlock.player_approached`) y `plaza.gd`
   (`_on_pigeons_approached`) lo pone en `calm` para que Alice no lo
   espante. No arranca si Lía ya está mirando otra curiosidad, durante el
   enfriamiento de 15 s (`CURIOSITY_COOLDOWN`), en una cutscene o durante
   una conversación. Lía suelta la manga, corre hasta 18 px del grupo y dice
   sus burbujas; Alice contesta en la suya (`LiaCuriosity`, entrada
   `"Pigeons"`; mismo formato que los puntos de curiosidad, con `lia_after`
   = lo que grita Lía si Alice sigue andando). Alice camina libre a
   velocidad normal. Cada frame (`_watch_alice_by_the_pigeons`):
   - **Se queda**: cuando ya acabaron las burbujas (no corta las de Lía),
     Alice sin moverse **y sin pulsar dirección** (empujar una pared no
     cuenta) a menos de `PIGEON_STAY_DISTANCE` (85 px) de Lía durante
     `PIGEON_STAY_TIME` (1 s desde el 2026-11-15; antes 2) → `_pigeons_up_close()`: se bloquea y suena
     `plaza_lia_pigeons`, que empieza con Alice ya parada a su lado (la
     línea «¡Mira! ¡Esa es más gorda!» pasó a ser globito); su
     `[signal arg="pigeons_fly"]` hace volar el grupo lejos de Lía
     (`fly_away_from`; si no, vuelan al terminar).
   - **Sigue andando**: a más de `PIGEON_LEAVE_DISTANCE` (110 px) de Lía,
     o empieza una conversación → `_lia_leaves_the_pigeons(true)`: Lía dice
     su `lia_after` y vuelve a la manga; el grupo deja `calm` y es un grupo
     normal (Alice puede espantarlo después).
   - **Nada de eso** en `PIGEON_WAIT` (8 s) tras las burbujas → Lía vuelve
     sola, sin frase.
   Las dos salidas ponen el enfriamiento de curiosidades y devuelven a Alice
   la velocidad de la manga. Cuenta como visto en ambos casos
   (`GameManager.lia_pigeons_seen` se pone al empezar). Los umbrales son
   amplios porque Alice nota el grupo a ~70 px de Lía. Textos de Guion
   (una sola versión para `early` y `late`: tres globitos de Lía, «Lía...»
   de Alice y «¡Espérame! ¡Adiós, paloma gorda!» al irse).
4. **La fuente** (`StoryAreas/FountainArea`, solo en `KNOWS_FOUNTAIN`):
   `plaza_lia_fountain`. Lía se pone al lado de Alice y viene la **tercera
   decisión** (esperar +2 / buscar a seguridad +1 / pánico −1 y final
   "agridulce"). `time_passes` funde a negro y deja el cielo más rojo;
   `lia_mom_arrives` trae a la madre desde `MotherStart` hasta el lado de
   Lía (es un `WalkingNPC` con su propio sprite,
   `global/npcs/assets/lia_mom.aseprite` en el export `frames`: camina con
   `walk_*` al deslizarse, mira a Lía al llegar y vuelve a caminar al irse); `lia_drawing_given` añade `dibujo_lia`; `lia_leaves` se las
   lleva a `FamilyExit` mientras siguen las líneas. Termina con el reloj de
   la fuente: Alice ya sabe que perdió el tren (`LIA_HOME`, camina a ×0.8,
   "ya no corre"). En la v2, Alice contesta "Entonces... seguiremos
   buscándola." en todas las rutas (antes solo si no se acercó primero), el
   dibujo es "para que te acuerdes de mí" en los dos finales y Alice lo
   guarda en el bolsillo de dentro. El agridulce ya no pesa como un fracaso:
   solo cambia que Alice no consigue despedirse.
5. **Bajada al andén** (`SubwayArea` en `LIA_HOME`, desde 2026-11-17,
   decisión del usuario): `_go_down_to_the_metro()` hace que Alice dé un
   paso hacia la boca y la escena funde a `plaza_metro.tscn` en
   `SpawnPoints/FromPlaza`. La etapa **sigue en `LIA_HOME`**: el contrato con
   `plaza_metro.gd` (Código 2) es que esa escena pone `MISSED_TRAIN` cuando
   se cierran las puertas del tren y, si Alice llega ya en `MISSED_TRAIN`,
   se salta la cutscene. Allí el tren se le va, oye a Clara cantar desde
   arriba y, al salir por la escalera, termina la demo. Si sube antes de que
   se cierren las puertas, vuelve a la plaza en `LIA_HOME` por
   `SpawnPoints/MetroExit` (1200, 1112), que queda fuera de `SubwayArea`
   (empieza en y = 1134): la boca no se dispara al aparecer y puede volver a
   bajar.
   **Antes era la reja**: `_miss_the_train()` arrancaba `plaza_missed_train`,
   caía la noche, Alice se ponía los auriculares y el interludio de
   *Transicion_Clara* (`NIGHT_LINES`) llevaba a `demo_end`. La función, ese
   timeline y `NIGHT_LINES` / `DEMO_END_SCENE` / `NIGHT_FALL_TIME` siguen en
   el código **sin uso**; se limpiarán cuando el final nuevo esté hecho.
Con cada pista nueva, al acabar el diálogo sale un pensamiento con el
siguiente sitio (`CLUE_*_LINES`).

**La etapa nunca retrocede** (2026-11-13): `_advance_to()` ignora una etapa
igual o anterior y `_add_clue()` solo cuenta pistas en `WITH_LIA`. Antes, el
ayudante que faltaba, consultado después de la fuente, volvía a poner
`KNOWS_FOUNTAIN` y el reencuentro se repetía. **Después de que Lía se va**
(`LIA_HOME`, `MISSED_TRAIN`), los tres ayudantes usan
`plaza_<ayudante>_after` (textos de Guion, con retratos de Alice), con dos
versiones según si Alice habló con ese ayudante con Lía
(`{GameManager.lia_met_ice_cream}`, `lia_met_dog_lady`, `lia_met_teen`:
dio pista o tuvo su conversación; `GameManager.lia_has_met(id)`).

**Toby y Lía, en fila** (2026-11-13): cuando Toby viene a Alice, se pone a
`TOBY_BESIDE_ALICE` (20 px) del lado contrario a la corredora y Lía, a jugar
con él, a `LIA_BESIDE_TOBY` (38 px) del mismo lado (`_away_from_jogger()`).
Corredora | Alice | Toby | Lía, sin taparse.

**Puntos de curiosidad** (2026-11-13): `CuriosityPoints/<Nombre>` en
plaza.tscn (`CuriosityPoint`, `global/curiosity_point.gd`: un `Marker2D`
`@tool` con `trigger_radius` 64 (antes 48; `GardenTables`, 72) y
`look_distance` 16, que dibuja ambos en el editor). Con Lía de la manga, la primera vez que Alice pasa a menos de
`trigger_radius` de uno, Lía suelta la manga, corre hasta él, dice sus frases
en su burbuja y Alice contesta en la suya (`LiaCuriosity`,
`scenes/plaza_scene/scenes/lia_curiosity.gd`, por nombre de nodo; frases en
`game_text.csv`). Cada punto tiene versión `early` (sin pistas) y `late`
(desde la primera); el camión la parte en `late_met` / `late_not_met` según
si ya hablaron con el heladero (`"helper"`). Opcional `lia_after`: una última
frase de Lía tras la respuesta de Alice. Alice puede esperar o seguir: si se aleja 90 px
(`CURIOSITY_LEAVE_DISTANCE`) o empieza una conversación, Lía vuelve corriendo
a la manga. Una vez por punto (`GameManager.lia_curiosities_seen`) y 15 s
entre uno y otro (`CURIOSITY_COOLDOWN`).
**Puntos que no se pierden** (2026-11-15, el usuario pasaba cerca y a veces
no saltaban). La causa: el punto solo se miraba mientras Alice estaba dentro
de su radio (48 px), y si en ese momento corrían los 15 s de espera o había
un pensamiento en pantalla (los pensamientos también son timelines de
Dialogic), se ignoraba sin recordarlo. Ahora los pensamientos no bloquean
(solo una conversación, una cutscene o la espera).
**Segunda vuelta** (2026-11-15, seguían perdiéndose). Comprobado pasando
andando sin parar junto al guitarrista: Lía corría, decía su primera frase y
Alice ya estaba a más de 90 px, así que Lía se volvía sin terminar y el punto
quedaba gastado para siempre (se marcaba como visto al empezar a correr).
Ahora:
- Al activarse, Lía avisa primero desde donde está, en su burbuja, con una
  de `CURIOSITY_CALL_LINES` ("¡Alice, mira!", "¡Espera, espera!", "¡Uy! ¿Qué
  es eso?", "¡Para! ¡Mira allá!"; al azar, nunca la misma que la anterior), y
  a los `CURIOSITY_CALL_TIME` (0,7 s) sale corriendo.
- El punto solo se marca como visto con su primera frase
  (`_mark_curiosity_seen`); si se corta antes, queda para la próxima vez.
- Desde esa primera frase, Lía dice todas las del punto aunque Alice siga
  andando: vuelve a la manga y sigue hablando en su burbuja, que la sigue, y
  Alice contesta en la suya (`_curiosity_talking`, `_curiosity_still_on`).
  Solo lo cortan una conversación o una cutscene. Su charla y los avisos de
  ayudantes esperan mientras tanto.
- Mientras Lía mira, Alice camina más despacio (`CURIOSITY_SPEED_SCALE`,
  ×0,6) y Lía se vuelve a 140 px (`CURIOSITY_LEAVE_DISTANCE`, antes 90).
- Varios pendientes en cola (`_pending_curiosities`): al acabar la espera
  salta el primero que siga a menos de `CURIOSITY_PENDING_REACH` (120 px).
- Radio 80 en todos los puntos (todos tienen suelo pisable a menos de 12 px,
  pero la acera pasa más lejos).
Probado andando sin parar junto al guitarrista y al picnic: se oyen el aviso,
las dos frases de Lía y la respuesta de Alice. Puntos (8): `PetShopWindow`, `CoffeeBoard`, `IceCreamVan`,
`Guitarist`, `Picnic`, `RedBike`, `GardenTables`, `AdColumn` (la columna de
anuncios verde junto al café, (580, 1100)). Textos de Guion. Las palomas empiezan igual que una curiosidad (no
coinciden con otra: comparten `_exploring`/enfriamiento) y son el único
momento que puede acabar en caja, si Alice se queda (ver arriba).

**Picnic** (2026-11-15): el mantel (`Addons`, atlas `47–54 × 0–6`, celdas
104–111 × 95–101) se dibujaba encima de Alice y Lía, porque cada fila se
ordenaba a su propia altura. Ahora todas sus baldosas tienen
`y_sort_origin = -(fila·8 + 8)`: el mantel entero se ordena en su borde de
arriba y quien se pare encima queda por delante.

**Arreglos del mapa** (2026-11-13):
- Edificio con fachada diagonal (acera del metro, abajo a la izquierda): sus
  tiles de esquina (`Buildings`, atlas 33–34 × 10–11) bloqueaban el cuadrado
  entero. Ahora (34,10) y (34,11) no tienen colisión y (33,11) tiene un
  triángulo que sigue la diagonal. **Ojo: esas celdas están volteadas en
  horizontal** (alternativa 4096), así que el polígono del tileset va en
  espejo. El tile (34,11) estaba además suelto en la celda (9,33), fuera del
  edificio, y bloqueaba 32 px de acera a la derecha; al quitarle la colisión
  al tile ya no bloquea (sigue dibujado; si es un tile perdido, que lo mire
  Arte).
- Fuente: toda ella se ordenaba en y = 603 (su base), así que Alice quedaba
  detrás en las esquinas de abajo y a los lados. Ahora (tileset de
  `WallsSuperior`, fuente 2, atlas 19–26 × 9–14) las filas de arriba (columna
  central y borde de atrás) se ordenan en el centro, y = 557; las del borde
  delantero, cada una en su base (571, 587, 603); los tiles diagonales de las
  esquinas de abajo, en 591.
- **Boca de metro de la plaza** (2026-11-17, rehecha 2026-11-24): son dos
  tramos de escalera apilados, cada uno de 4 filas de tiles (atlas 1–3 × 6–9,
  la variante con la escalera hacia la izquierda). El de arriba está en
  `Buildings` (filas 33–36, base en y = 1198) y el de abajo en `Buildings2`
  (filas 35–38, base en y = 1263). Funciona como la variante de la calle
  (`street_zone_1`, atlas 1–3 × 10–13), que tiene la misma configuración en
  el tileset de la plaza:
  - **Orden:** cada fila apunta a la base de su tramo (`y_sort_origin` 112,
    80, 48 y 16 de arriba abajo). Así los postes altos se dibujan delante de
    Alice y de Lía cuando están detrás de la boca, y detrás cuando están
    delante. Antes tenían origen 0, cada fila se ordenaba en su centro y
    Alice, detrás, pasaba por encima de los postes.
  - **Colisión** solo en la base: la fila 8 desde el pie de la baranda
    trasera (y = 1,9 del tile) y la fila 9 entera. Las filas altas (6–7,
    postes y caperuzas) no chocan.
  - `SubwayEntranceBody` (`StaticBody2D` en (1200, 1207,5), 94×23) ya no
    cubre toda la boca: solo tapa el hueco entre la base del tramo de arriba
    (1198) y la baranda trasera del de abajo (1217).
  - `SubwayArea` es de 140×142 para que Alice entre en ella al chocar por
    cualquier lado.
  - Probado: Alice para en y = 1145 por detrás y en 1266 por delante, y
    choca con la base por los lados (también en el hueco entre los tramos).
    Los postes tapan a Alice y a Lía por detrás y por los lados, y la
    silueta no salta tras un poste fino. `CutsceneNav` rodea la boca por el
    pasillo de la derecha sin cruzar colisiones. En LIA_HOME, entrar por
    arriba lleva a `plaza_metro.tscn`.
- **Fuente animada** (2026-11-15): ya no es de tiles. Es un objeto aparte,
  como el reloj y la taza del apartamento:
  `scenes/plaza_scene/scenes/animated_fountain.tscn` (`AnimatedSprite2D`,
  animación `flow` en bucle), instanciada en `MiddleLayer/AnimatedFountain`
  en (584, 592). El sprite sale de
  `scenes/street_scenes/assets/fountain_water.aseprite` (128×112, de Arte):
  la piedra (capa `fountain_base`, abajo del todo) más las capas del agua,
  de abajo arriba `top_ripple`, `basin_waves`, `lip`, `streams`, `foam` y
  `drops` (gotitas sueltas), en 16 fotogramas de 110 ms (etiqueta `flow`).
  La piedra se llamaba `ref_fountain` y estaba oculta; Arte la renombró y la
  hizo visible porque es parte del sprite. Su `.import` tiene el patrón de
  exclusión vacío: no le pongas uno que deje fuera `fountain_base`, o la
  fuente queda sin piedra. El origen del nodo está en y = 592 (el dibujo
  sube con `offset (0, -101)`, `centered` apagado). **Orden por franjas**
  (2026-11-17): con un solo punto de orden, quien estaba delante de una
  esquina de la base octogonal quedaba detrás de la fuente. Ahora la raíz
  lleva el script `StripSortedSprite` (`global/strip_sorted_sprite.gd`, con
  `y_sort_enabled`). Al arrancar parte el sprite en franjas verticales de
  16 px, cada una un `AnimatedSprite2D` hijo con su propio punto de orden
  (`strip_sort_y`, en px desde arriba del fotograma: el punto más alto del
  borde delantero dentro de la franja: 89.6, 96, 106, 112, 106, 96, 89.6,
  89.6). Las franjas siguen el fotograma de la raíz, que ya no se dibuja.
  Probado en las cuatro esquinas y los dos lados. Sirve para cualquier otro
  objeto animado ancho con frente diagonal o redondo. La colisión, que antes daban los
  tiles, es un `StaticBody2D` con un polígono que copia la de esos tiles. Se
  quitaron los 56 tiles de la fuente de `WallsSuperior` (celdas x 36–43,
  y 31–37); las entradas del tileset (atlas 19–26 × 8–14) siguen ahí sin
  usarse en la plaza.
- **Sonido de la fuente** (2026-11-15): `WaterSound`, un
  `AudioStreamPlayer2D` dentro de `animated_fountain.tscn`, en (64, −45)
  respecto a la raíz, que es el centro del agua; en el mundo, (648, 547).
  - Reproduce `audio/ambience/plaza_fountain_loop.ogg` en bucle por el bus
    `Ambience`. Viaja con la fuente. No usa autoplay: lleva el script
    `RandomStartSound2D` (`global/random_start_sound_2d.gd`), que lo arranca
    en un punto al azar del bucle, como el llanto de Lía. Sirve para
    cualquier otro sonido posicional en bucle (máquinas, otra fuente).
  - El agua es un acuario, borboteo suave, elegido por el usuario por ser más
    sutil que la primera fuente. Bucle de 50 s a −28 LUFS (ver
    `audio/CREDITS.md`).
  - `volume_db` +5, `max_distance` 300 px, `attenuation` 1.5,
    `panning_strength` 0.5.
  - Junto a la fuente queda unos 4 dB por debajo del ambiente de calle: se
    oye, pero discreto; no subirlo para igualar a la calle. Se apaga antes de llegar a los paseos. Suena en todas las
    etapas, también de noche.
  - El que "oye" es la cámara (centrada en Alice).

### Estado en `GameManager`
`plaza_stage` (`PlazaStage`: `ARRIVED`, `WITH_LIA`, `KNOWS_FOUNTAIN`,
`LIA_HOME`, `MISSED_TRAIN`), `lia_clues`, `lia_confidence`,
`lia_approached_first`, `lia_tried_to_leave`, `lia_outcome`
(`"feliz"`/`"agridulce"`), `lia_extras`, `lia_pigeons_seen`,
`lia_teen_loud` y `lia_curiosities_seen`. Señales: `lia_approached_first`, `lia_tried_to_leave`,
`lia_bittersweet`, `lia_confidence:<n>`, `lia_extra:<id>`, `lia_teen_loud`.
Las de la escena (`lia_grabs_sleeve`, `lia_clue:<id>`, `lia_lets_go`,
`lia_holds_on`, `toby_comes`, `pigeons_fly`, `focus_on_lia`,
`alice_goes_to_lia`, `alice_turns_away`, `lia_comes_to_alice`,
`time_passes`, `lia_mom_arrives`, `lia_drawing_given`, `lia_leaves`) las
atiende `plaza.gd`. `_restore_stage()` monta la escena según el paso, así que
se puede recargar en cualquier momento.

### Decisiones al adaptar el Twine
- La primera decisión es el rompecabezas (primer contacto); la segunda y la
  tercera, menús de Dialogic.
- *Rama_No_Acercarse_Pasa* es jugable de verdad: pasa si Alice camina al
  metro. Elegir "Tengo que irme" en el rompecabezas lleva al mismo texto.
- La madre lleva **vestido rosa** (el primer borrador decía abrigo rojo).
- El quiosco de *Rama_Buscar_Adulto* se cuenta en la narración; el señor de
  la radio es el personaje `plaza_old_man` ("Señor").
  **Guardia** (2026-11-15): un guardia de seguridad
  (`MiddleLayer/NPCS/PlazaGuard`, un `WalkingNPC` con el sprite del
  trabajador del metro, `metro_worker_npc.aseprite`, en `frames`; es otra
  persona) hace **una ronda** tranquila al suroeste de la fuente toda la tarde
  (`GuardRoute`, de (470, 680) a (600, 680), 20 px/s, paradas de 4–8 s, se
  para junto a Alice). Lejos del camino de la madre (este), del guitarista y
  de las palomas de la fuente. Lleva un `AmbientThought` con dos versiones
  (`_on_guard_thought`, que las cambia con `RemarkInteractable.set_lines()`
  y vuelve a la primera): con Lía, "Un guardia." / "Seguro que tiene cosas
  más importantes que hacer." (y `GameManager.plaza_guard_noticed` lo
  recuerda); cuando Lía ya se fue, "Sigue con su ronda." / "Como si fuera un
  día cualquiera.". En la rama, la narración #id:2e6 dice que Alice camina
  hacia él y, si se había fijado en él, Alice lo recuerda (#id:3d4,
  `if {GameManager.plaza_guard_noticed}`) antes del minijuego. Antes de esa
  narración, Lía pregunta "¿Me van a regañar?" (#id:3d5) y Alice la calma
  (#id:3d6).
  **Por qué no le preguntan desde el principio** (Guion, aprobado por el
  usuario): la primera vez que pasan cerca de él buscando (`WITH_LIA`, a
  `HELPER_HINT_DISTANCE`), Lía dice en su burbuja "¡A ese no! Si le
  contamos, mi mamá va a saber que me levanté de la banca." y después Alice
  piensa "...Y yo tendría que hablar con un guardia." / "Mejor le
  preguntamos a la gente." (`_lia_refuses_guard`, una vez por partida con
  `GameManager.lia_guard_refused`, nunca encima de otra burbuja, un
  pensamiento o una conversación). Es un personaje: la silueta no lo cuenta como
  algo que tapa a Alice.
  En la rama, `guard_comes` lo para donde esté (`WalkingNPC.stop_patrol()`)
  y Alice camina hasta él (`GUARD_TALK_DISTANCE`, 22 px) con Lía a su lado.
  `guard_leaves` lo devuelve a su ronda desde donde está
  (`start_patrol(true)`; mientras se aleja se le quita `pause_near_player`,
  que lo dejaba quieto junto a Alice) y Dialogic sigue a los 1,2 s.
  **Texto final** (Guion, aprobado por el usuario): el personaje es
  `plaza_guard` ("Guardia"/"Guard", `dialogic/characters/plaza_guard.dch`,
  sin retrato); `plaza_old_man` ya no se usa. Con el guardia ya al lado sale
  un **Rompecabezas de la Ansiedad** fácil, `plaza_guard`
  (`scenes/plaza_scene/puzzles/plaza_guard.tres` + `_en`, en
  `ANXIETY_PUZZLES` de `plaza.gd`): "Disculpe... / esta niña / se perdió.",
  2 distractores, 25 s, `hint_from_start`. Si lo arma (`ask`), Alice habla
  (#id:2e7) y `lia_confidence +1`; si calla o se le acaba el tiempo, Lía habla
  por las dos (#id:3ce) y Alice asiente (#id:3cf). Las dos ramas siguen en
  "¿Cómo te llamas?" (#id:3d0–3d3, 2e8) y después `guard_leaves`.
- El reloj está en la fuente y Alice **ya no corre** al metro (como en el
  Twine): sabe que lo perdió antes de llegar a la reja.

### Gotcha: ids de personaje que empiezan por "do"
Dialogic lee cualquier línea que empieza por `do` como un evento *Call*
(`do Autoload.metodo()`), así que `dog_lady: ...` se saltaba con
"Call event failed". Por eso la señora es `lady_with_dog`. No pongas ids de
personaje que empiecen por "do".

### Gente de fondo en la plaza (2026-11-05)
Solo `AmbientThought` (icono de pensamiento sobre Alice + una línea en la
nube, traducida en `game_text.csv`), sin "...":
- **`MiddleLayer/NPCS/DaytimeCrowd`** (`Node2D` con y-sort), los que se van
  al terminar la tarde:
  - `NewspaperReader` (columna 0), sentado en la banca frontal del paseo de la
    izquierda (332, 502), con el mismo truco que el chico de auriculares
    (`position (0, 20)`, `offset (0, -20)`);
  - `PigeonGrandma` (15), junto a las palomas de arriba de la fuente;
  - `Guitarist` (16), abajo de la fuente;
  - `CafeWoman` (21) y `CafeMan` (20), de pie junto a la mesa redonda del
    jardín de abajo a la izquierda;
  - `PicnicGirl` (18, con su perrito), al borde del mantel del picnic.
  `plaza.gd` (`_send_crowd_home()`) los desactiva cuando pasa el tiempo
  (`time_passes`, con la pantalla a negro) y al cargar la plaza en
  `LIA_HOME` o `MISSED_TRAIN`; también apaga su aviso sobre Alice.
- **Acera del metro** (2026-11-06, al sur de la calle, donde empieza Alice),
  también en `DaytimeCrowd`: `BenchReaderSouth` (columna 1, sentado leyendo
  en la banca de la derecha, raíz (792, 1190), `sort_lower = 11`) y
  `CoffeeWaiter` (columna 7, con maletín, en la puerta del café). Tres grupos
  de palomas más en `MiddleLayer/Pigeons`: `SouthBenches` (210, 1245),
  `ShopFront` (420, 1140) y `SubwaySidewalk` (900, 1250).
- **Paseantes** (`StrollerSidewalk` con `pedestrian_red_cap`, por la acera de
  abajo; `StrollerWalkway` con `pedestrian_blonde`, por el paseo de la
  izquierda hasta la plaza central): `WalkingNPC` con rutas en
  `StrollerRoutes`, `pause_near_player = 24`. `plaza.gd` les llama
  `start_patrol()` y siguen también de noche. Solo tienen ciclo de lado, así
  que sus rutas son horizontales.
- Las palomas del paseo de la izquierda (nodo `Pigeons/Node2D`) bajaron a
  y = 546 para que la paseante no las atraviese.

### Palomas (`PigeonFlock`, `global/npcs/scripts/pigeon_flock.gd`)
Pieza reutilizable: un `Node2D` con el script, puesto en una capa con y-sort,
crea 3–4 palomas (`count = 0`) repartidas alrededor (`spread`), con plumaje
al azar (`pigeons.aseprite`, importado como `SpriteFrames`: 9 colores con
`peck`, `stand`, `sit` y `rest`). Cada 1,5–4 s cada una cambia de pose o,
con probabilidad `walk_chance` (45 %), da un paseo corto a un punto al azar
a menos de `wander_radius` (12 px) de donde apareció, a `walk_speed`
(14 px/s), mirando hacia donde va, y al llegar se pone a picotear.
Nunca se superponen: al aparecer y al elegir adónde caminar guardan
`min_gap` (11 px) con las demás, contando dónde están y adónde van, y no
cruzan por encima de otra. Si no encuentra un sitio libre, en vez de caminar
cambia de pose. Si Alice
se acerca a menos de `scare_distance` (44 px) de cualquiera, sale volando
todo el grupo (emite `flew_away`): lejos de ella y hacia arriba, por encima
de todo, mirando hacia donde vuelan (el dibujo mira a la izquierda, así que
se voltea al volar a la derecha) y acelerando (`takeoff_speed` →
`max_speed`), y crecen un poco al despegar (`takeoff_scale` 1.3 en
`takeoff_grow_time` 0,35 s), como si se acercaran a la cámara. Cada paloma lleva un `VisibleOnScreenNotifier2D` y se borra
con `queue_free()` al salir de la pantalla; el grupo se borra con la última
(y como red de seguridad, a los 8 s). Vuelven al recargar la escena. **El sprite no tiene animación de vuelo:** se alternan el fotograma
de alas arriba de `peck` y el de `stand`. Si se dibuja una tag
`<color>_fly`, se usa sola. Tampoco hay sonido de aleteo: `takeoff_sound`
está vacío. En la plaza hay nueve grupos en `MiddleLayer/Pigeons`.
**Para que una escena monte algo con ellas** (2026-11-12): cada grupo se
apunta al grupo de Godot `pigeon_flock`. Emite `player_approached` una vez,
cuando Alice llega a `scare_distance + notice_margin` (28 px), justo antes de
espantarlas. Si la escena pone `calm = true` en ese momento (las señales
corren al instante), Alice ya no las espanta. `fly_away_from(punto)` las hace
volar lejos de ese punto, y `has_flown()` dice si ya se fueron. Lo usa el
momento de Lía con las palomas.
**Sonido** (2026-11-13, archivos de la sesión de Sonido): al despegar, un
aleteo por bandada (`takeoff_sound` = `audio/sfx/pigeon_takeoff.ogg`, −5 dB,
`takeoff_volume_db`). En el suelo, de vez en cuando (cada 5–11 s,
`coo_interval`), un arrullo al azar de `coo_sounds` (`pigeon_coo_1..3.ogg`,
−12 dB) desde la bandada, en un `AudioStreamPlayer2D` que se apaga con la
distancia y solo si Alice está a menos de 160 px (`coo_hearing_distance`).
Son los valores por defecto del script: todas las bandadas los tienen.
**Es `@tool`:** en el editor cada grupo dibuja una vista previa quieta (4
palomas, o `count` si no es 0), el rectángulo donde se reparten (`spread`,
amarillo) y, en rojo, más o menos hasta dónde puede llegar Alice antes de que
salgan volando (`scare_distance` contado desde el borde del grupo). Las
palomas de la vista previa no tienen *owner*, así que no se guardan en el
`.tscn`; en el juego se generan al azar como siempre.

## 16. El andén del metro de la plaza (`plaza_metro.tscn` + `.gd`)

**Estado (2026-11-17):** la sala la diseña el usuario desde cero en el
editor; la cutscene está programada con los textos de Guion
(`narrative/final_demo_metro.md`, aprobados por el usuario; en
`game_text.csv`). La canción de Clara la hará el usuario más adelante:
hasta entonces `ClaraVoice` no tiene audio y la escena va igual, en
silencio. Se llega desde la plaza en `LIA_HOME` (lo cablea `plaza.gd`). Se
puede ejecutar sola: la cutscene corre igual. El anochecer no ocurre en el
andén: lo cuenta el interludio final (`ENDING_LINES`).

**La cutscene** (`plaza_metro.gd`, todo sale de los `Marker2D` y nodos de
la escena, nunca de coordenadas fijas):
1. **Llega el tren mientras Alice baja.** Alice entra caminando sola desde
   la izquierda, escalera abajo (`SpawnPoints/FromPlaza` es un `SpawnPoint`
   con `walk_in` y `direction` derecha), y a la vez el tren empieza a llegar
   (`enter_in_station()`, con su sonido y `TRAIN_ARRIVING_LINES`). El jugador
   recupera el control en ~1 s, mucho antes de que se abran las puertas
   (~7 s): oye llegar el tren mientras baja y parece que llega a tiempo.
2. **Se le va, por poco.** Las puertas se abren y el tren la espera el tiempo
   que haga falta (no hay límite de tiempo: la escalera está cerrada, así
   que solo se puede ir hacia delante). Solo cuando Alice llega de verdad al
   borde del andén, a `DOORS_CLOSE_DISTANCE` (40 px) de
   `CutscenePoints/AliceSeesDoors`, se bloquea el control, se gira hacia el
   tren y las puertas se cierran delante de ella (`DOORS_CLOSING_LINES`). La
   cámara encuadra las puertas y vuelve. El tren se va con su sonido
   (`departure_sound` de `MetroTrain`, lo pone `leave_station()`) y
   `TRAIN_GONE_LINES`. El control vuelve justo tras «No, no, no...», con el
   tren ya arrancando (se va solo, con su sonido; la cámara regresa a Alice
   a la vez): `TRAIN_GONE_LINES` sale en la nube mientras ella ya camina. Si
   llega a `HearClaraZone` antes de que acabe esa nube, lo de Clara espera a
   que termine. El andén sigue en silencio hasta que vuelve a la escalera. No es un fallo: siempre lo
   pierde.
3. **Clara, al volver.** Clara no se oye enseguida: se oye cuando Alice,
   de vuelta, entra en `CutscenePoints/HearClaraZone` (un `Area2D` cerca del
   pie de la escalera). Antes de perder el tren esa zona no hace nada (Alice
   la cruza al entrar). Al entrar: `ClaraVoice` empieza con fundido (si
   tiene audio, suena sola 1,5 s antes de la nube), Alice se gira hacia la
   voz y sale `HEARS_CLARA_LINES`; luego se enciende `ExitToPlaza`.
4. **Fin de la demo.** La bajada es de ida: `ExitToPlaza` está apagada
   desde que entra hasta que oye a Clara, así que no puede volver a subir a
   media cutscene ni antes de oírla. Después, al cruzarla, `ExitToPlaza`
   (`walk_off_screen`, hacia la izquierda, sin `next_scene_path`) le quita el
   control y la hace caminar sola escalera arriba hasta salir del mapa, con
   la cámara quieta. Al emitir `walked_out`, `transition_with_interlude` con
   `ENDING_LINES` y luego `demo_end`, igual que el antiguo final de la
   plaza. `plaza_stage` llega como `LIA_HOME` y pasa a `MISSED_TRAIN`
   cuando se cierran las puertas; la escena no lo vuelve a mirar.

**Prisa (`HURRY_LINES`).** Mientras las puertas están abiertas y Alice aún
no ha llegado a `PassengersCue`, si se entretiene o vuelve atrás piensa en
la nube el siguiente pensamiento del banco, en orden y sin repetir; al
agotarlo no sale más. Su avance se mide por la distancia a `PassengersCue`
(el pasillo va recto hacia ahí desde la escalera). Sale uno si no se acerca
16 px en `HURRY_STALL_TIME` (8 s) o si está 160 px más lejos que lo más
cerca que llegó; nunca con otra nube o diálogo en pantalla y con al menos
`HURRY_MIN_GAP` (10 s) entre dos. Se apaga al cruzar `PassengersCue` o al
cerrarse las puertas. Medido: yendo directo, ninguno; quieta en la
escalera, uno a los 8 s de abrirse las puertas y luego uno cada 10 s; a
mitad del pasillo y volviendo, uno al retroceder ~250 px. Son 5
pensamientos de Guion aprobados por el usuario, de una línea cada uno.

**Pasajeros.** Bajan por las **puertas centrales** cuando se cumplen las
dos cosas: las puertas están abiertas y Alice sube hacia el andén (entra en
`CutscenePoints/PassengersCue`, arriba del paso de los torniquetes, el único
camino al andén). Cada `WalkingNPC` de `MiddleLayer/Passengers` con ruta en
`PassengerRoutes/<su nombre>` aparece con fundido en su puerta (primer
punto), se queda en el umbral y luego camina el resto de la ruta
(`walk_path`, sin colisión: nunca empuja ni bloquea a Alice) y se desvanece
al final. **Ritmo adaptativo:** el horario base (`start_delay` + fundido 0,4 s
+ `PASSENGER_DOOR_PAUSE` 0,9 s; el último sale a ~4 s) corre en un reloj
propio (`_alight_clock`). Cada fotograma se estima cuánto tarda Alice en
llegar a las puertas a su velocidad (por el hueco de las rejas si aún está
abajo) y se acelera el reloj (hasta ×4, y su caminata hasta ×2,5) para que
el último salga `PASSENGER_ETA_MARGIN` (0,4 s) antes de que ella llegue. Si
va despacio, el ritmo es el base. Si aun así llega con alguien dentro, todos
bajan en ese instante y las puertas se cierran: **Alice nunca espera ante
puertas abiertas.** Medido: a toda velocidad, ritmo ×1,26 y las puertas se
cierran justo al llegar; despacio, ritmo base, los tres bajan mientras ella
se acerca.
Todos pasan por el hueco central de la fila de rejas y por los torniquetes
de la derecha (los de la izquierda están cerrados):
- `MetroWorker` (0 s): puerta x 644 → puerta de servicio del extremo
  derecho del pasillo.
  Los que se van por la puerta de servicio (metadato de ruta `door_sound`)
  caminan hasta la propia puerta (último punto (1240, 550), pegado a ella,
  subiendo con `walk_back`) y se desvanecen ahí en 0,2 s con el sonido
  `door_open.ogg` posicional en la puerta (bus SFX, −8 dB; si llegan dos
  en menos de 0,8 s, suena una vez). La rubia acaba en x −40, fuera de
  cuadro, así que su fundido no se ve.
- `RedCap` (1,4 s): puerta x 536 → también a la puerta de servicio.
- `Blonde` (2,8 s): puerta x 760 → pasillo hacia la izquierda → sube la
  escalera por el carril de escalones y sale del mapa.
Las rutas se comprobaron contra la colisión cada 4 px. **Para añadir un
pasajero:** instancia `walking_npc.tscn` en `Passengers` con su `frames`
(necesita `walk_front`/`walk_back` para verse bien bajando) y crea en
`PassengerRoutes` un `Node2D` con el mismo nombre, sus `Marker2D` en orden
y, si hace falta, `start_delay`.
(El 2026-11-18 se probaron pasajeros dibujados tras las ventanas del tren y
se descartaron: parecían pegatinas encima del vagón.)

**`ClaraVoice`** (`AudioStreamPlayer2D`, bus Ambience, junto a la escalera):
el gancho para la voz de Clara. Su `stream` (en bucle) llegará con la canción; con voz, suena sola 1,5 s antes de la nube de Alice; al
ser posicional, se oye más fuerte al acercarse a la escalera. Muévelo a
donde quede la salida del andén. Sin `stream`, la cutscene sigue igual.

**Cómo se hizo:** a partir de `metro_stations.tscn`, con los mismos
TileSets, capas, tren, luces y ambiente. Del mapa solo queda la sala del
andén (suelo, vías y paredes con su colisión, todo lo que está por encima
de y = 360). Se quitaron el pasillo, el vestíbulo, los torniquetes, el
decorado (bancos, carteles), los NPCs y la lógica de aquella estación. Los
TileSets están copiados dentro de la escena: cambiarlos aquí no afecta a
`metro_stations.tscn`.

**Qué es cada nodo (dónde pintar):**

| Nodo | Qué es |
|---|---|
| `PlazaMetro` (raíz, `y_sort_enabled`) | Script `plaza_metro.gd`. |
| `InferiorLayer` | Suelo y vías (tiles de 32 px). Pinta aquí el suelo del andén. |
| `MiddleLayer` | Capa con orden por y. Tiene el mismo TileSet que la de `metro_stations`; hoy le quedan 20 tiles. Dentro van `AssetsLayerInferior`, para lo que se pisa o queda por debajo, y `AssetsLayerSuperior`, para objetos que tapan a Alice (bancos, columnas, carteles; tiles de 8 px). Las dos están vacías. |
| `MiddleLayer/NPCS` | Vacío, para la gente del andén. |
| `MiddleLayer/Player` | Alice. Los límites de la cámara están en `Player/Camera2D` (izquierda 152, arriba −38, derecha 1127, abajo 420): ajústalos al tamaño de la sala. |
| `MiddleLayer/MetroTrain` | El tren (`metro_train.tscn`). Fuera de pantalla a la derecha (2172, 129) hasta que la cutscene llame a `enter_in_station()`. Se para en `station_position_x` = 600. `next_scene_path` está vacío, para que no lleve al vagón. |
| `SuperiorLayer` | Capa por encima de todo (z 2). Vacía. |
| `SuperiorLayer/WallBorders` | Bordes de pared (TileMapDual). Su hija oculta `ColisonesDual` lleva las colisiones de las paredes. Del borde de abajo no queda nada: hay que cerrar la sala por abajo al diseñarla, o Alice puede salirse. |
| `SuperiorLayer/TileMapLayer` | Decorado alto (8 px). Vacío. |
| `LightsContainer` | Un `Node2D` simple (sin el script de parpadeo de `metro_stations`). Una `PointLight2D` por lámpara (`MetroAmbientalLight*`), `StairsLight` y `DarkFilter`. Ver **Iluminación** abajo. |
| `InteractableDetectors`, `ThoughtTriggers` | Vacíos, para lo que se pueda mirar y los pensamientos de suelo. |
| `SceneAudio` | Ambiente del andén (`metro_platform.ogg`), el mismo de la otra estación. |
| `SpawnPoints/FromPlaza` | `SpawnPoint` con `walk_in` (dirección derecha): Alice entra caminando desde la izquierda, escalera abajo, hasta este punto. Es el sitio por defecto si no se pide otro. |
| `CutscenePoints/TrainStop` | Donde se para el tren (600, 129): el mismo `station_position_x`. |
| `CutscenePoints/AliceSeesDoors` | En el borde del andén frente a las puertas (623, 300): cuando Alice llega a 40 px de aquí, se cierran (el tren espera hasta entonces). |
| `CutscenePoints/PassengersCue` | `Area2D` (90×24) arriba del paso de los torniquetes de la derecha, en (846, 448): cuando Alice la pisa con las puertas abiertas, empiezan a bajar los pasajeros. |
| `CutscenePoints/HearClaraZone` | `Area2D` (90×100) cerca del pie de la escalera, en (170, 595): tras perder el tren, al entrar Alice oye a Clara y se abre la salida. Antes no hace nada. Muévela si cambia la escalera. |
| `ClaraVoice` | La voz de Clara, posicional, encima del rellano de la escalera (24, 530), "desde arriba" (ver arriba). |
| `MiddleLayer/Passengers` | Pasajeros que bajan del tren (`WalkingNPC`, ocultos y sin colisión hasta que se abren las puertas): `MetroWorker` (trabajador con uniforme granate, `metro_worker_npc_b`), `Blonde` y `RedCap` (los peatones de la calle). |
| `PassengerRoutes/<nombre>` | La ruta de cada pasajero, con el **mismo nombre** que su nodo en `Passengers`: sus `Marker2D` en orden; el primero es la puerta por la que sale. Metadato opcional `start_delay` (segundos) para que no bajen todos a la vez. |
| `ExitToPlaza` | La salida por la escalera: un `ExitArea` sobre el rellano de arriba de la escalera (24, 564), con `walk_off_screen` hacia la izquierda y sin `next_scene_path`: Alice sale caminando del mapa y la escena hace el final con `walked_out`. Empieza con `monitoring = false` para no dispararse al llegar; la cutscene la enciende al oír a Clara. |

**Iluminación** (estándar del metro, ver «Iluminación estándar del metro»; variante «A′», elegida por el usuario el 2026-11-18; las luces de lámpara son instancias de `metro_lamp.tscn`): luz
pareja y legible, sin puntos quemados ni agujeros negros.
- **Relleno base:** lo da `DarkFilter` (`CanvasModulate`, azul pizarra
  0.6/0.65/0.74), no la suma de halos.
- **Lámparas:** cada lámpara pintada tiene su `PointLight2D` con la textura
  `global/lights/light_fluorescent.tres` (degradado radial de caída rápida),
  blanco verdoso (0.85/1/0.97), energía 0.45. Cada halo crece hasta casi
  tocar el de su lámpara más cercana, sin solaparse: radio visible ≈ 38 px
  por unidad de escala, escala x ≈ 0,45 × distancia a la vecina / 38. Así,
  las del pasillo, juntas, van a (2, 1.6); el pilar izquierdo
  (`MetroAmbientalLight3`) a (2.25, 1.8), y las tres de la pared de arriba
  (12, 13, 14), muy separadas, a ~(3.8, 2.2) con energía 0.4. Las luces de pilares y pasillo están 35 px por debajo de su
  lámpara para que el charco caiga en el suelo donde camina Alice; las
  lámparas (tiles) no se movieron.
- **`MiddleLayer/MetroTrain/TrainLight`:** luz cálida y alargada delante
  de las puertas, hija del tren solo en esta escena (no toca
  `metro_train.tscn`): llega y se va con él.
- **`LightsContainer/StairsLight`:** luz cálida suave en la escalera, por
  donde llega la voz de Clara.
- `global/lights/light_soft_wide.tres` es la versión ancha y suave (tren,
  escalera). Las dos texturas sirven para otras estaciones.
- Para añadir una lámpara: duplica una `MetroAmbientalLight*` y ponla bajo
  la nueva lámpara (+35 px en y si está en pared de pasillo o pilar).

**Colisión de la escalera** (TileSet interno de la escena, `stairs.aseprite`):
la franja diagonal del pasamanos (tiles (1,1), (2,1), (2,2) y (3,2)) está
puesta **a propósito** por el usuario (2026-11-18): se baja por el carril de
escalones de abajo, no por todo el ancho. No quitarla. Las rutas que suben o
bajan la escalera (la de `Blonde`) van por ese carril.

Todas las posiciones son provisionales: mueve los marcadores y la salida a
donde quede la escalera en el diseño.

**En la plaza:** `SpawnPoints/MetroExit` (1200, 1112), justo encima de la
boca de metro y fuera de `SubwayArea`. `plaza.gd` lo lee al arrancar
(`_place_at_spawn_point()`, que deja a Alice mirando hacia arriba).
**`ExitArea` tiene ahora `spawn_point`**, como `SceneTransitionArea`: es
el nombre del `Marker2D` bajo `SpawnPoints` en la escena siguiente.
