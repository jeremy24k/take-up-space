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
`quest_step >= 4` **y** `GameManager.mirror_practice_done`. Si va sin
ensayar, `alice_cant_leave_yet` dice "Todavía no. Primero el espejo." El
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
en "Cosas pendientes".

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
pantalla en negro antes de cargar la escena; Espacio salta la línea actual. La
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
| `pickable_item.gd` | Objeto recogible; se borra si ya está en `GameManager`. La mochila solo muestra "[Recoger]" cuando ya están los otros tres objetos; antes muestra "[Espacio]" |
| `lamp_interactable.gd` | Sincroniza un `PointLight2D` con `Dialogic.VAR.lamp_is_on` |
| `seat_interactable.gd` | Sienta a Alice y emite `player_sat_down` |
| `train_door_area.gd` | Secuencia de subir al tren |
| `scene_transition_area.gd` | Cambia de escena; se puede bloquear |

### `SceneTransitionArea`
Cambia de escena cuando el jugador **interactúa** (hereda de `InteractableArea`,
necesita `[Espacio]`).

```gdscript
@export_file target_scene_path
var is_locked                    # si está bloqueada emite blocked_interaction
signal blocked_interaction       # ...para que la escena reaccione (diálogo, pensamiento)
signal transition_started
```

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
Uso: instanciar `boundary_area.tscn`, darle un `RectangleShape2D` propio a su
`CollisionShape2D` y fijar `thought_lines` (o `timeline_name`) y
`push_direction`. En la calle usan las líneas "Mejor no me alejo más." / "No
conozco esta zona. Primero, la comida de Wilson." (antes era el timeline
`street_boundary`, que se borró).

**Sin acotaciones en la nube.** "(se detiene y mira hacia atrás)", "(mira las
vidrieras)" o "(mira a su alrededor)" funcionan en la caja de abajo, que es
una escena, pero en la nube se leen como si Alice pensara la acotación. Lo que
va en la nube es solo lo que piensa.

### `NpcTalkArea` (`global/npcs/scenes/npc_talk_area.tscn`)
`InteractableArea` para **cualquier personaje con el que Alice puede hablar**.
Es una escena heredada de `interactable_area.tscn` que ya trae el globito "..."
(`InteractionHint`), así ningún NPC que habla se queda sin él y no hay que
colocarlo a mano.

- `hint_position`: dónde flota el globito, relativo al área. Casi siempre el
  área está corrida respecto del NPC (está donde se para Alice para hablar),
  así que se ajusta por instancia para que quede 2 px sobre la cabeza.
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
- Ojo con los `BaseNPC`: su sprite está centrado en el nodo (no en los pies),
  así que la cabeza queda unos 15 px más arriba del origen, no 30.

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
- Aparece con un pop, flota 1 px, y se apaga con un fundido. Al pulsar Espacio
  se apaga y suben las burbujas de verdad hacia la nube.
- **Nunca mientras se prepara o se muestra un pensamiento** (`_refresh_notice`
  mira `_starting` e `is_showing()`, y se vuelve a evaluar al empezar y al
  terminar cada `say()`). Al pulsar Espacio con una nube en pantalla, entre el
  pensamiento viejo y el nuevo hay ~0,2 s sin timeline (suben las burbujas), y
  el área volvía a pedir el aviso: la nubecita asomaba un instante. Además
  espera 0,12 s (`SHOW_DELAY`) antes de aparecer, para no parpadear nunca.

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
- **El reloj espera** a la primera tecla o clic del jugador, y abajo hay una
  línea fija con los controles ("Flechas: elegir · Espacio: decir · (...):
  callarse"). En el tercer playtest el tiempo se acababa antes de entender
  cómo se jugaba.
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
- **Frase que no lleva a ningún lado:** además de temblar en rojo y
  reacomodarse, la pista de arriba muestra "No... así no." durante 1,2 s. Sin
  eso, el reinicio parecía un fallo.
- **Ninguna palabra tiene el foco al abrir.** La primera flecha enfoca una; hasta
  entonces Espacio no dice nada. Antes el foco caía en una palabra al azar y
  el Espacio de cerrar el diálogo anterior la decía sin querer.
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
que esté en pantalla, en vez de reemplazarla.
- Antes dibujaba un globo de texto sobre la cabeza de Alice, en una
  `CanvasLayer` propia. Se quitó para que el juego tenga solo dos lenguajes:
  abajo conversación, arriba mente.

### `LightsContainer`
Parpadeo aleatorio de luces + `fade_out_lights(duración)` y `turn_off_lights()`.

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
```

**`pause_near_player`** (px, 0 = nunca): si Alice se acerca a esa distancia
mientras camina, el NPC pausa su tween, la mira, y sigue cuando ella se aleja
`PAUSE_HYSTERESIS` (12 px) más. Lo usan los dos peatones y el gato de la calle
(20 px), para que haya tiempo de apretar Espacio.

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

Si en ese momento hay un diálogo abierto, `metro_is_entering_station`
espera a que termine en vez de cortarlo.

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
  en los pies:** cada instancia sube el `Sprite2D` 16 px y usa una colisión de
  pies de 14×8. Así se ordenan bien con bancos y faroles. `base_npc.tscn` no se
  tocó, para no mover a los NPCs del metro.
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
- **Peatones:** instancias de `walking_npc.tscn` con su `InteractableArea` como hija,
  para que el diálogo se mueva con ellos. `street_zone_1.gd` los pasea de ida
  y vuelta por los `Marker2D` de `PedestrianRoutes/<NombreDelPeatón>`, con una
  pausa en cada extremo, en la que los gira de frente.
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
  desliza hasta la torre (`camera.offset`, 0,9 s), se queda 1,4 s y vuelve
  (0,7 s). Mientras tanto, en la nube: "Qué edificio más raro... todo de
  cristal.". Si después escucha "la torre de cristal", ya sabe cuál es.
- **Recordatorio si se pierde** (`_tick_lost_reminder` en `street_zone_1.gd`).
  Si pasan 150 s caminando (sin contar diálogos ni cutscenes) sin encontrar una
  pista nueva (`GameManager.clue_added` reinicia el reloj) y sin acercarse a
  menos de 220 px de la tienda, sale en la nube: "Quizá alguien por aquí sepa
  dónde hay un minimercado..." y, la segunda vez, "Podría fijarme mejor en los
  carteles. O en lo que dice la gente.". Si ya oyó a la chica del teléfono,
  apunta a la torre: "Un minimercado detrás de la torre de cristal, cruzando
  la avenida... Tiene que estar cerca.". Como máximo 2 recordatorios, y ninguno después de entrar a la
  tienda de Leo.
- **`ThoughtTriggers`:** pensamientos espontáneos que se disparan una sola vez
  al pasar: `FirstCrossing`, `Houses` y `ShoppingBlock`.
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
  - Puertas de tiendas sin contenido, "Aquí no venden comida para gatos.":
    `PizzaDoor`, `VinylDoor`, `CafeDoor` (junto al inicio) y `CafeDoorNorth`
    (junto a Leo).
  - Casas y edificios, "No es mi casa.": `HouseDoorGreen`/`Grey`,
    `HouseDoorNorth1`–`3`, `BuildingDoorNorthwest`, `BuildingDoorWest`.
    `ATMBuildingDoor` dice "Cerrado.".
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
| `PetsShopDoor` | Puerta de la tienda PETS, arriba de la panadería | Falsa: "Cerrado por reformas." | `street_pets_closed` |
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
  3. **La anciana** es la **única** que dice "justo detrás de la torre de
     cristal", y es la única vez en la calle que Alice le pregunta algo a
     alguien: la respuesta clara es el premio por atreverse a hablar. (No es
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
  de ambiente (`OfficeMan`, `Student`, `HeadphonesGuy` y los peatones
  `PedestrianA`/`PedestrianB`, más `NewspaperReader`, `VinylBrowser` y
  `BenchSitter`) son `AmbientThought`: sin globito; cerca de ellos aparecen
  las burbujitas sobre Alice y Espacio muestra una línea en la nube (su mejor
  momento de los diálogos viejos, recortado a 1 o 2 líneas). Sus `.dtl` (`street_office_man`, `street_student`,
  `street_headphones_guy`, `street_pedestrian_cap`,
  `street_pedestrian_blonde`) se borraron. El gato es la excepción: conserva
  su diálogo (Wilson).
- **Los que caminan se detienen cuando Alice se acerca**
  (`WalkingNPC.pause_near_player`, 20 px en los dos peatones y el gato). Se
  paran, la miran y siguen cuando ella se aleja 12 px más.
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
5. **La salida.** Al terminar la charla, `ExitToStreet` queda bloqueada
   (`is_locked`). Al intentar salir, `blocked_interaction` dispara
   `leo_store_farewell` ("Oye, Alice", dos variantes) y al cerrarse se pasa a
   `scenes/demo_end/demo_end.tscn`. Leo solo nombra a Wilson si Alice se lo
   dijo (rama de la verdad o al pedirle el número, señal `leo_knows_wilson`);
   si no, dice "tu gato".
6. **La reflexión y `demo_end.tscn`**: al salir, `_leave_store` usa
   `FadeTransition.transition_with_interlude` (la misma pieza que la escalera
   al metro) para contar, con la pantalla en negro, cómo Alice sale a la calle.
   Hay dos versiones según si le dio su número (`REFLECTION_GAVE_NUMBER` /
   `REFLECTION_KEPT_NUMBER`) y un cierre común (`REFLECTION_END`). Antes era
   una timeline de Dialogic (`leo_store_reflection`, borrada) con la caja de
   diálogo sobre negro. `demo_end.tscn` solo muestra "Continuará..." y
   "[Espacio] Salir", que cierra el juego (la salida se habilita cuando
   termina de aparecer el título, para que un Espacio de más no lo cierre).

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

## 12. Cosas pendientes / a vigilar

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
  existen todavía los encuentros con Lía/Clara/Rosa, inventario, guardado,
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
