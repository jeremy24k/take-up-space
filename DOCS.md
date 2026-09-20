# testing_dual — Referencia del proyecto

Juego 2D pixel art en **Godot 4.7**. Alice sale de su apartamento a comprar
comida para su gato Wilson, coge el metro y se queda dormida.

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
| `prep_items_unlocked` | Alice ya miró la mochila |
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
| `pickable_item.gd` | Objeto recogible; se borra si ya está en `GameManager` |
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

### `ThoughtTrigger`
Burbuja de pensamiento sobre la cabeza de Alice. Se puede **esperar**:

```gdscript
await thought_trigger.show_thought(player)
```

Con `monitoring = false` se dispara solo desde código; si no, al entrar en el área.
Un pensamiento nuevo cancela el anterior (contador `active_sequence_id` compartido).

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

---

## 6. Diálogos (Dialogic)

- Personajes en `dialogic/characters/*.dch`, diálogos en `dialogic/timeline/**/*.dtl`
- Se lanzan con `Dialogic.start("identificador")`

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
                      → pausa de 1.5s para que se sienta la desorientación
                      → Dialogic.start("unknown_station_lost_phone")
                        (incluye [signal arg="no_phone"] → GameManager.has_phone = false)
        │
[jugador libre — puede hablar con el trabajador y/o los interactuables ambientales]
        │
_on_worker_area_entered()     el InteractableArea del trabajador se dispara SOLO
                              (al entrar en rango, sin `[Espacio]`) — ver nota abajo
        │
_ask_worker_for_help()        Dialogic.start("unknown_station_worker_dismissive")
                               él nunca reacciona; ella se rinde y se va —
                               "irse" es simplemente que el jugador recupera el
                               control cuando el diálogo termina (Player ya
                               hace lock/unlock solo con Dialogic.timeline_started/ended)
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
tono bajo, nada de escena — actualmente: `SittingBoy`, `SittingGirl`,
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

## 10. Cosas pendientes / a vigilar

- **La salida de `unknown_station.tscn` es un placeholder deliberado.**
  `ExitToStreet`/`ExitToStreet2` apuntan a `apartment.tscn` porque la escena de
  la calle todavía no existe — no es un bug, es la decisión consciente de no
  dejar un `next_scene_path` vacío que no lleve a ningún sitio.
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
- **Nada más allá del prólogo existe todavía:** ni la calle, ni los encuentros
  con Leo/Lía/Clara/Rosa, ni inventario, sistema de confianza, guardado, menús
  o arte de retratos/cinemáticas. El prólogo en sí (apartamento → vagón →
  estación desconocida) es jugable de principio a fin.
