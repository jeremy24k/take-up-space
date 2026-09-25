# CLAUDE.md

**Take Up Space** is a 2D pixel-art narrative game made in **Godot 4.7** (Forward+) with GDScript. Alice leaves her apartment to buy food for her cat Wilson, takes the metro, falls asleep, and wakes up at an unknown terminal station. Only the prologue exists so far.

**[DOCS.md](DOCS.md) is the full project reference and is written in Spanish.** Read it before changing a system. It covers each reusable piece, the metro-train cutscene state machine, and the unknown-station flow in detail. This file is the short version. When you change a system, update DOCS.md in Spanish.

## Language
- Code, comments, and identifiers are in **English**.
- Everything the player sees is in **Spanish**: Dialogic timelines, prompt labels, and thought bubbles.

## Commands
There is no test suite, linter, or build script. The editor binary is `/Applications/Godot.app/Contents/MacOS/Godot`; `godot` is not on PATH.

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import              # reimport + surface parse/load errors (an "ObjectDB instances leaked" warning at exit is normal)
$GODOT --headless --path . --check-only --script res://path/to/file.gd   # parse-check one script
$GODOT --path .                                  # run the game (main scene = apartment)
$GODOT --path . res://scenes/prologue_scene/scenes/unknown_station.tscn  # run one scene directly
```

`.tscn`, `.tres`, `.dch`, and `project.godot` are usually edited in the Godot editor. Hand edits are fine if you keep the format and UIDs intact.

## Layout
```
autoload/          GameManager (quest state), FadeTransition (scene changes)
player/            Alice: class_name Player, group "player"
global/            Reusable pieces: InteractableArea and its subclasses, ExitArea,
                   ThoughtTrigger, stairs/, npcs/ (BaseNPC sprite-sheet column, WalkingNPC)
scenes/prologue_scene/
  scenes/          Playable scenes + their scripts (apartment, metro_stations,
                   metro_train_interior, unknown_station, ...)
  wilson/          The cat (NavigationAgent2D follower; NOT a WalkingNPC)
  worker/          Metro worker = WalkingNPC instance
dialogic/          characters/*.dch (alice, metro_worker, wilson), timeline/{apartment,metro}/*.dtl
addons/            Third-party: dialogic, AsepriteWizard, TileMapDual. Do not modify.
```

Scene flow: `apartment` → (stairs, needs wallet/headphones/shoes) → `metro_stations` → (train door) → `metro_train_interior` → `unknown_station` → `ExitToStreet`/`ExitToStreet2`. The exits point back to `apartment.tscn` **on purpose** as a placeholder until the street scene exists.

## Architecture essentials
- **Scene changes always go through `FadeTransition.transition_to_scene(path)`**, either directly or via `SceneTransitionArea` (you interact to use it) or `ExitArea` (it fires when you walk in). Never call `get_tree().change_scene_to_file()` directly.
- **`GameManager`** holds state that survives between scenes: `quest_step` 0–4, `collected_items`, `missing_prep_items`, `prep_items_unlocked`, `target_door_id`, `has_phone`, and a `wilson` ref. It moves forward on Dialogic `[signal arg="..."]` events (`step_1`–`step_4`, `prep_items_unlocked`, `no_phone`).
- **`InteractableArea`** (`global/interactable_area.gd`) is the base for everything interactive. It is an `Area2D` on layer/mask 4. The player's `InteractionDetector` finds it when you press `ui_accept`. Its exports are `timeline_name` (starts that Dialogic timeline), `prompt_text`, and `one_time_interaction`, and it emits `interacted`. To specialize it, write `extends "res://global/interactable_area.gd"` and override `update_label_text()`, `interact()`, or `_collect_item()`. Simple ambient interactables are plain instances with only `timeline_name` set and no script.
- **Player cutscene API:** use `lock_control()` / `unlock_control()`, `play_animation(name, fallback)`, `play_animation_backwards(...)`, and `face_direction(dir)`. Don't touch the `AnimatedSprite2D` from outside. The player locks and unlocks itself around every Dialogic timeline, but a `lock_control()` lock stays in place after a dialogue ends.
- **Animation names** are built from a prefix and a direction: `idle_`/`walk_` + `front`/`back`/`side`. `side` uses `flip_h`. `Player` and `WalkingNPC` use the same scheme. Code guards with `has_animation()` because several sprites are still placeholders.

## Dialogic gotchas
- Write each line as `character_id: text`, using the `.dch` id (`alice`, `metro_worker`, `wilson`). Actions look like `alice: (suspira)`. If the colon is missing, the whole line shows as narration. If the name is unknown, Dialogic creates a temporary character.
- **Dialogic picks the timeline identifier, not you.** It uses the bare filename and adds the folder prefix only when names collide (e.g. `metro/ticket_store` vs `unknown_station_worker`). Always check `dtl_directory` in `project.godot` before calling `Dialogic.start("...")`.
- `Dialogic.signal_event` and `Dialogic.timeline_ended` are **global**. Connect with `CONNECT_ONE_SHOT` or filter on the argument or timeline, or other dialogues will fire your callback. See `_wait_for_signal()` in `metro_train_interior.gd`.

## Conventions
- **No `AnimationPlayer`.** Do everything timed with `Tween` and `await`.
- Every script uses section headers:
  ```gdscript
  # =========================
  # Section name
  # =========================
  ```
- **Scenes decide what happens; pieces only emit signals.** Reusable pieces emit signals and never walk the tree with `get_parent().get_parent()`. The owning scene script wires them up. For example, the worker's trigger-on-proximity behavior is connected in `unknown_station.gd`, not in `InteractableArea`.
- **`hide()` does not disable a node.** Also set `process_mode`, and disable collision shapes and `monitoring` with `set_deferred`. Visibility is inherited from the parent.
- **Commit `.uid` files** alongside their `.gd`/`.dtl`/`.dch`. If they're missing you get "invalid UID" warnings. Don't regenerate UIDs for existing resources, because scenes reference them by UID (for example the main scene and the stairs scene).
- Pixel art: nearest texture filter, 1280×768 viewport, `canvas_items` stretch with integer scaling.
