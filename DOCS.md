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
| `wilson` | Referencia al gato |

Escucha `Dialogic.signal_event` y avanza `quest_step` con las señales
`step_1`…`step_4`.

### `FadeTransition`
`CanvasLayer` en la capa 100 con un `ColorRect` negro encima de todo.

```gdscript
await FadeTransition.fade_out(1.0)
await FadeTransition.fade_in(1.0)
await FadeTransition.transition_to_scene("res://ruta.tscn")
```

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

1. `lock_control()` y lanza `timeline_name`, si tiene uno.
2. Al terminar el diálogo, la hace caminar `push_distance` px en `push_direction`
   (UP/DOWN/LEFT/RIGHT, siempre **hacia dentro** del mapa) con un `Tween`.
3. La deja mirando hacia dentro y le devuelve el control. El empujón tiene que
   sacar su cuerpo del área para que vuelva a dispararse la próxima vez.

Se repite cada vez que vuelve al borde, salvo que `one_time_interaction` esté
activo. Emite `interacted` al empezar y `pushed_back` al terminar, por si la
escena quiere cambiar el `timeline_name` (por ejemplo, otro texto la segunda vez).
Uso: instanciar `boundary_area.tscn`, darle un `RectangleShape2D` propio a su
`CollisionShape2D` y fijar `timeline_name` y `push_direction`. En la calle, el
timeline genérico es `street_boundary`.

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
  Los bordes se cierran con una viñeta pixelada (`anxiety_vignette.gdshader`).
- **Desde Dialogic:** la timeline emite `[signal arg="anxiety_puzzle:<id>"]`
  y después ramifica con `if {anxiety_result} == "<clave>":`. La escena
  (p. ej. `leo_store.gd::_play_anxiety_puzzle`) pone `Dialogic.paused =
  true` dentro del handler de la señal: Dialogic no pasa al siguiente evento
  hasta que vuelve a `false` (`DialogicGameHandler.handle_event` hace
  `await dialogic_resumed`). Instancia el puzzle, hace `await
  puzzle.run(data)`, guarda el resultado con
  `Dialogic.VAR.set_variable("anxiety_result", ...)` y reanuda.
  `anxiety_result` está declarada en las variables de Dialogic
  (`project.godot`).
- Es una `CanvasLayer` en la capa 2: por encima de la caja de Dialogic (capa
  1, así el clic no lo atrapa su capa de input) y por debajo del fundido.
- **Cuándo usarlo** (regla de diseño): la primera interacción importante con
  cada personaje, las confesiones (pedir un número, admitir que no sabe su
  dirección) y la respuesta siguiente a un error social (si en un menú
  normal eligió mentir o callarse). El resto son menús normales, para no
  gastar la mecánica.

### `ThoughtTrigger`
Burbuja de pensamiento sobre la cabeza de Alice. Se puede **esperar**:

```gdscript
await thought_trigger.show_thought(player)
```

Con `monitoring = false` se dispara solo desde código; si no, al entrar en el área.
Un pensamiento nuevo cancela el anterior (contador `active_sequence_id` compartido).

**La burbuja se dibuja en pantalla, no en el mundo.** Es una `CanvasLayer`
(capa 1) llamada `ThoughtBubble`, hija de Alice, con el `Label` dentro. Cada
frame se coloca sobre su cabeza con `get_global_transform_with_canvas()` y se
mantiene dentro de los bordes de la pantalla (margen de 8 px). Así:
- **El zoom ×3 de la cámara no multiplica la fuente.** Antes, en el mundo, el
  tamaño solo podía subir de 3 en 3 px de pantalla (6 → 18 px, 8 → 24 px) y
  cualquier fuente un poco mayor quedaba enorme. Ahora `font_size` y
  `outline_size` del `Label` de `thought_trigger.tscn` están **en píxeles de
  pantalla**. Fuente elegida: `m3x6.ttf` a 48 (×3), borde oscuro de 6,
  `line_spacing = -6` y `max_width = 420`. Es más legible que `tiny.ttf` y
  tiene minúsculas; Silkscreen se descartó porque es toda en mayúsculas y
  parecía que Alice gritaba.
- Para que una fuente pixel se vea nítida, usa un múltiplo entero de su tamaño
  nativo: `tiny.ttf` 6 (12, 18, 24…), `m3x6.ttf` 16 (32, 48…), Silkscreen 8
  (16, 24…).
- Ninguna capa del mapa la tapa y no se corta contra el borde. Antes en la
  estación desconocida el "(mira a su alrededor)" salía como "nira a su
  alrededor)".
- `max_width` (exportado, en px de pantalla) es el ancho de ajuste del texto.

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

**Comunicación diálogo → juego:** el evento `[signal arg="lo_que_sea"]` llega a
`Dialogic.signal_event`. `GameManager`, `pickable_item`, `lamp_interactable` y
`wilson` están escuchando.

> **⚠️ `Dialogic.timeline_ended` es global**, no por diálogo. Conéctate siempre
> con `CONNECT_ONE_SHOT` o comprobando cuál terminó, o cualquier diálogo
> disparará tu callback.

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

`metro_train_interior.tscn` se usa **dos veces sin recargarse**: el mismo nodo se
transforma en sitio, así Alice nunca se mueve del asiento.

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
        │
_depart_train()      metro_train.leave_station() (sin await, corre de fondo)
                      → pausa de `wait_time_for_phone_missing` (1s) para que se
                        sienta la desorientación
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
                               Él apenas levanta la vista ("¿Qué?"); ella se
                               avergüenza y se va — "irse" es simplemente que el
                               jugador recupera el control cuando el diálogo
                               termina (Player ya hace lock/unlock solo con
                               Dialogic.timeline_started/ended)
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

### Interactuables ambientales (`InteractableDetectors`)
Mismo patrón que la estación de salida (`TicketStore`/`ImportantMan` en
`metro_stations.tscn`): instancias sueltas de `interactable_area.tscn` con
`timeline_name`, sin script propio. Cada uno es una línea o dos de Alice sola,
tono bajo, nada de escena — actualmente: `SittingGirl`,
`ListeningGuy`, `Tracks`, `StationMap`, `Bench`, `VendingMachine`. Se han ido
añadiendo y descartando por lotes; si faltan o sobran, es a propósito.

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
dentro, todas con el timeline `street_boundary`: `BoundaryLeft`, `BoundaryRight`,
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
- **`ThoughtTriggers`:** pensamientos espontáneos que se disparan una sola vez
  al pasar: `Arrival` en el punto de inicio de Alice, `FirstCrossing`,
  `Houses` y `ShoppingBlock`. `ShoppingBlock` está en la vereda, junto a la
  panadería, y cierra el desvío: "(mira las vidrieras) Una panadería,
  discos... Nada para gatos.". Antes decía "Esto es una zona de tiendas. Por
  aquí tiene que haber algo.", y en los dos playtests hizo creer que la tienda
  estaba en esa manzana. El olor a pan quedó solo en el diálogo de la puerta
  (`BakeryDoor`), así no se repite.
- **`InteractableDetectors`:** además de los diálogos de los NPCs fijos, objetos
  clave para la historia (`Shop`, `BakeryDoor`, `ATM`, `Payphone`,
  `SubwayEntrance`, `GlassTower`), cada uno con su `street_*.dtl`.
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
    esconde mientras haya cualquier diálogo en pantalla.
  - Se pone como hijo del NPC, en (0, -38) sobre los pies. En la calle lo
    tienen los 8 NPCs que hablan: oficinista, estudiante, chico de
    auriculares, chica del teléfono, repartidor, abuela y los dos peatones.
  - Sirve para que se distingan de la gente que es decorado. Un NPC nuevo con
    diálogo tiene que llevarlo; uno de ambiente, no.

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
| `VendingMachines` | Máquinas entre la panadería y los vinilos | Falsa, con humor | `street_vending` |
| `BusStopGrandma` | Abuela (`BusStopGrandmaNPC`, col. 15), en la manzana de arriba a la derecha (se movió desde la parada; el nombre quedó) | A medias: lleva latas de comida para gatos | `street_grandma` |
| `BusStopMap` | Mapa de rutas de la parada | A medias: "Hay tiendas pasando la torre." | `street_bus_stop` |
| `PhoneGirl` | Chica del teléfono (ya existía) | Buena e incompleta: oye "el almacén ese, el de la torre" | `street_phone_girl` |
| `Delivery` | Repartidor (`DeliveryNPC`, col. 14), vereda este de la manzana central | Buena: caja de "Almacén" con frutas | `street_delivery` |
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
  | `GlassTower` | `overheard_store` | `street_glass_tower_clue`: "El de la torre", decía. (mira a su alrededor) Aquí no hay ningún almacén... ¿Cruzando la calle, quizás? |

- **Por qué existe la reacción de la torre:** en el playtest, la jugadora
  escuchó "el de la torre", llegó a la base de la torre y se quedó sin saber
  qué hacer. La tienda de Leo está detrás de la torre, al otro lado de la
  calle, y desde la base no se ve. La pista sigue siendo sutil ("el de la
  torre"): no dice dónde. Es la torre la que empuja un poco, sin dar la
  respuesta. Se probó decir "detrás de la torre" en la pista, pero era
  demasiado obvio.
- **Una pista no puede depender de otra.** El jugador puede verlas en
  cualquier orden, o ninguna, así que ningún texto debe nombrar una pista
  anterior (por ejemplo "como en la caja del repartidor").

### Tono de los diálogos
Todos son monólogos de Alice: los NPCs no hablan. Al escribir uno nuevo:
- **Poco texto y nada de explicar lo que ya se ve.** El jugador ya sabe que
  está perdida y sin teléfono. No hace falta repetir el objetivo (la comida de
  Wilson) en cada diálogo. Ya lo dicen `Arrival`, el de
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
│                               + colisión en los pies + InteractionHint
├── CounterCollision           StaticBody2D: bloque de las dos cajas y baranda
├── InteractableDetectors
│   ├── LeoCounter             "[Espacio] Hablar", delante de la caja de arriba
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
   y 280 a 470), y sale el globo: "Ese es el cajero...", "...es muy lindo.",
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
     perdió.
   - El número (`puzzles/leo_number.tres`): "Oye, ¿me das tu número?" → `ask`
     (+1, iniciativa); "Bueno... gracias." → `leave`; silencio → Leo se lo da
     igual. En todos los casos Alice termina con el número (`leo_number`).
   - Darle el suyo (menú): +2 si había pedido el de él, +1 si no; o no
     dárselo (0).
5. **La salida.** Al terminar la charla, `ExitToStreet` queda bloqueada
   (`is_locked`). Al intentar salir, `blocked_interaction` dispara
   `leo_store_farewell` ("Oye, Alice", dos variantes) y al cerrarse se pasa a
   `scenes/demo_end/demo_end.tscn`.
6. **`demo_end.tscn`**: pantalla negra con `leo_store_reflection` (dos
   variantes según si le dio su número) y después "Continuará...", porque la
   escena de Lía todavía no existe.

### Estado en `GameManager`
`leo_greeted`, `leo_has_tuna`, `leo_talk_done`, `leo_confidence` (la
"confidence" del Twine, guardada para escenas futuras),
`leo_alice_took_initiative`, `leo_gave_number` y el objeto `leo_number` en
`collected_items`. Se actualizan con señales de Dialogic (`leo_greeted`,
`leo_tuna_taken`, `leo_took_initiative`, `leo_number`, `leo_gave_number`,
`leo_talk_done` y `leo_confidence:<n>`). Si Alice sale a la calle antes de
hablar y vuelve, la escena sigue desde donde quedó y no repite el saludo.

### Decisiones al adaptar el Twine
- La prosa pasa a acotaciones: lo de Alice como `alice: (...)` y lo de los
  demás como narración sin nombre (`(Leo no se ríe. Solo asiente.)`). Lo que
  Alice piensa en el momento va en globo de pensamiento (paso 1).
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
- **Alice** arranca en (591, 504). **`ExitToStreet`** está en (593, 524) con
  32×24: más abajo el detector de Alice ya no llega, porque la colisión de la
  entrada la frena en y≈505.
- La cámara está limitada a 314–774 × 185–552.
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
