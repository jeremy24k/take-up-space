# CLAUDE.md

**Take Up Space** is a 2D pixel-art narrative game made in **Godot 4.7** (Forward+) with GDScript. Alice leaves her apartment to buy food for her cat Wilson, takes the metro, falls asleep, and wakes up at an unknown terminal station. Only the prologue exists so far.

**[DOCS.md](DOCS.md) is the full project reference and is written in Spanish.** Read it before changing a system. It covers each reusable piece, the metro-train cutscene state machine, and the unknown-station flow in detail. This file is the short version. When you change a system, update DOCS.md in Spanish.

## Language
- Code, comments, and identifiers are in **English**.
- Everything the player sees is written in **Spanish**: Dialogic timelines, prompt labels, and thought bubbles. It is translated to **English** through CSV files in `translations/` (DOCS.md §12):
  - Dialogue lines carry a `#id:xx` suffix in the `.dtl`: that is their translation key. Keep it when editing a line and never copy it to another line.
  - Other text (thoughts, remarks, prompts, labels, code constants) is keyed by its Spanish text in `game_text.csv`. `ThoughtBox.say()` runs `tr()`; Labels translate themselves. New player-facing text shown any other way needs `tr()`.
  - After adding text, update the CSVs (Dialogic's "Update CSV files" + `global/localization/update_translations.gd`, or `update_translations_cli.gd` headless with the editor closed) and fill the `en` column.
  - Anxiety puzzles have a `*_en.tres` per puzzle, linked in its `translations`; answer keys must match.

## Commands
There is no test suite, linter, or build script. The editor binary is `/Applications/Godot.app/Contents/MacOS/Godot`; `godot` is not on PATH.

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import              # reimport + surface parse/load errors (an "ObjectDB instances leaked" warning at exit is normal)
$GODOT --headless --path . --check-only --script res://path/to/file.gd   # parse-check one script
$GODOT --path .                                  # run the game (main scene = language screen)
$GODOT --path . res://scenes/prologue_scene/scenes/unknown_station.tscn  # run one scene directly
```

`.tscn`, `.tres`, `.dch`, and `project.godot` are usually edited in the Godot editor. Hand edits are fine if you keep the format and UIDs intact.

## Layout
```
autoload/          GameManager (quest state), FadeTransition (scene changes),
                   ThoughtBox (Alice's thoughts in the "thought" Dialogic style),
                   Localization (chosen language, saved in user://settings.cfg),
                   SoundManager (music/ambience cross-fades, one-shot sounds)
audio/             Ambience, music and sfx (.ogg), plus CREDITS.md
translations/      Translation CSVs (Dialogic timelines/characters + game_text)
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
  dialogic_additions/TakeUpSpace/   Ours: Dialogic extension (custom portrait animations)
```

Scene flow: `language_select` (main scene) → `apartment` → (stairs, needs wallet/headphones/shoes) → `metro_stations` → (train door) → `metro_train_interior` → `unknown_station` → `ExitToStreet`/`ExitToStreet2`. The exits point back to `apartment.tscn` **on purpose** as a placeholder until the street scene exists.

## Architecture essentials
- **Scene changes always go through `FadeTransition.transition_to_scene(path)`**, either directly or via `SceneTransitionArea` (you interact to use it) or `ExitArea` (it fires when you walk in). Never call `get_tree().change_scene_to_file()` directly.
- **`GameManager`** holds state that survives between scenes: `quest_step` 0–4, `collected_items`, `missing_prep_items`, `prep_items_unlocked`, `target_door_id`, `has_phone`, and a `wilson` ref. It moves forward on Dialogic `[signal arg="..."]` events (`step_1`–`step_4`, `prep_items_unlocked`, `no_phone`).
- **`InteractableArea`** (`global/interactable_area.gd`) is the base for everything interactive. It is an `Area2D` on layer/mask 4. The player's `InteractionDetector` finds it when you press `ui_accept`. Its exports are `timeline_name` (starts that Dialogic timeline), `prompt_text`, and `one_time_interaction`, and it emits `interacted`. To specialize it, write `extends "res://global/interactable_area.gd"` and override `update_label_text()`, `interact()`, or `_collect_item()`. Simple ambient interactables are plain instances with only `timeline_name` set and no script. **Anyone Alice can talk to uses `NpcTalkArea`** (`global/npcs/scenes/npc_talk_area.tscn`) instead: it carries the "..." bubble (`InteractionHint` child); place it over the NPC's head by moving that child in the editor (Editable Children). Code can move it at runtime with `set_hint_position()`. Things that look interactive but have little to say (ambient NPCs, locked doors, a second vending machine) use **`RemarkInteractable`** (`global/remark_interactable.tscn`): Space shows a single line, written in the scene, in the thought cloud (`ThoughtBox`); it never stops Alice and closes by itself, on Space, or when she walks off. Look-alike objects share a `group_id`, so only the first one Alice tries in any scene plays the full `first_timeline`. If one object of a type responds, all look-alikes must respond; benches, bins, plants and the like never do. **Background people use `AmbientThought`** (`global/npcs/scenes/ambient_thought.tscn`), a `RemarkInteractable` with nothing over the NPC: within reach, a small lavender thought-cloud icon shows over Alice's head (`ThoughtBox.set_notice`, `ThoughtNotice`, drawn in screen space so scene tints don't affect it) and Space shows one line in the cloud. Keep their lines to 1–2 short ones. The "..." bubble always means "this person will answer".
- **Player cutscene API:** use `lock_control()` / `unlock_control()`, `play_animation(name, fallback)`, `play_animation_backwards(...)`, `face_direction(dir)`, `wait_animation_loops(count)` (move on at the end of a loop), and `pan_camera_to(world_point, time)` / `reset_camera(time)` to show something (the glass tower, the arriving train). Don't touch the `AnimatedSprite2D` from outside. The player locks and unlocks itself around every Dialogic timeline, but a `lock_control()` lock stays in place after a dialogue ends.
- **Alice's sprite is layered** (`player/alice.aseprite`, imported split by layer into `player/alice_layers/`): the body `AnimatedSprite2D` plus child layers for backpack, shoes and headphones (neck/head). Code drives only the body; layers mirror it. What shows follows `GameManager.collected_items` and `headphones_on_head` (`[signal arg="headphones_on"]`/`"headphones_off"`).
- **Every character has a `CharacterShadow`** (`global/character_shadow.tscn`) as a child of its sprite, already in the player, `base_npc`, `walking_npc` and Wilson templates: it draws behind the sprite and places itself at the feet from the sprite's offset. Set `small = true` for cats.
- **Sound** (DOCS.md §13): audio lives in `audio/{ambience,music,sfx}` (sources in `audio/CREDITS.md`), on the `Music`/`Ambience`/`SFX` buses. Each scene has a `SceneAudio` node (`global/scene_audio.gd`) with its ambience and music; the `SoundManager` autoload cross-fades between scenes and plays one-shots (`SoundManager.play_sfx(stream_or_name)`, or `[signal arg="sfx:<name>"]` from a timeline). Loops need **Loop** on in their import settings.
- **Animation names** are built from a prefix and a direction: `idle_`/`walk_` + `front`/`back`/`side`. `side` uses `flip_h`. `Player` and `WalkingNPC` use the same scheme. Code guards with `has_animation()` because several sprites are still placeholders.

## Two visual languages
Both go through Dialogic, with two Styles in `dialogic/styles/` (`thought` inherits `dialogue`):
- **Bottom box** (`dialogue`, the default style): everything from a `.dtl` (conversations and monologues). It stops Alice and waits for Space. Portraits only appear here.
- **Top cloud** (`thought`): Alice's thoughts, always through **`ThoughtBox.say(lines)`** (autoload). Used by `ThoughtTrigger` (floor), `BoundaryArea` (map edges) and `RemarkInteractable` (inert objects). It sets `[style name="Thought"]` inside the timeline (setting it from code before `Dialogic.start()` does not stick), uses Dialogic's native auto-advance only for that timeline, and never stops Alice. Never draw thought text yourself. Its juice (bubbles from Alice's head, enter/exit tweens on the textbox `Sizer`, thinning cloud) is reset by `ThoughtBox` because both styles share one layout. See DOCS.md §3 and §6.

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
- **`hide()` does not disable a node.** Also set `process_mode`, and disable collision shapes and `monitoring` with `set_deferred`. Visibility is inherited from the parent. For an area Alice uses with Space, also turn off `monitorable`: her `InteractionDetector` still finds a hidden, non-monitoring area (that let her skip the train nap through the hidden exit).
- **Commit `.uid` files** alongside their `.gd`/`.dtl`/`.dch`. If they're missing you get "invalid UID" warnings. Don't regenerate UIDs for existing resources, because scenes reference them by UID (for example the main scene and the stairs scene).
- Pixel art: nearest texture filter, 1280×768 viewport, `canvas_items` stretch with integer scaling.
