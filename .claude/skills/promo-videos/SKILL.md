---
name: promo-videos
description: Make promo videos for Take Up Space (TikTok/YouTube Shorts verticals, the "Alice's anxious thoughts" series, long horizontal YouTube devlogs) with the pipeline in press_kit/video_tools - record gameplay with Godot Movie Maker, render captions in the game font, generate ElevenLabs voices, compose with ffmpeg, make covers. Use when the user asks for a new video, a series episode, a hook, a cover/thumbnail, voices, music changes or re-edits of an existing video.
---

# Promo videos for Take Up Space

Everything lives in `press_kit/video_tools/` (gitignored, local only). Read `press_kit/video_tools/LEEME.md` first: it lists every tool and command. Finished videos go in `press_kit/tiktok/videoN_<slug>/` (vertical) or `press_kit/youtube_long/` (horizontal).

## Ground rules
- Talk to the user in Spanish. Videos, captions and voices are in English. Script and notes files in Spanish.
- **AI transparency:** the user wants full disclosure. ElevenLabs voices are "Violet - Cozy Voicemails" (Alice) and "Jeremy" (his own cloned voice). Every script file says which voices were used. Posting notes say: "AI-generated content" on TikTok, "altered or synthetic content" on YouTube.
- **TikTok uploads go from the phone app.** Web uploads got 0 views on this account. YouTube can be scheduled from the desktop.
- Music: Pixabay only (license compatible). Credit tracks in the description. Downloading a new track needs the user's OK.
- Never touch game code for a video. Temporary Godot scripts are copied to the repo root as `_xxx_tmp.gd` and deleted afterwards along with their `.uid`.

## What the Shorts metrics taught (Nov 2026)
- The cat Short lost half its viewers between seconds 4 and 7: slow walking and metro shots before the conflict.
- "This is what social anxiety looks like in my indie game" kept 42% and grew after the title change.
- Rules that follow:
  - Open on dialogue or the puzzle already on screen.
  - Reach the twist by second 3-5.
  - Titles follow "This is what [X] looks like in my indie game".
  - End with an on-screen question, plus a pinned comment with the same question (comments are low).

## Pipeline
1. **Plan the beats.** Pick dialogue or scenes. Read the `.dtl` (Spanish) and `translations/dialogic_timeline_translations.csv` (English). Propose hook, captions and end question to the user before recording.
2. **Record** with `record.gd` (Movie Maker, `--fixed-fps 30`, 1280x768). Add a `clip_<name>()`.
   - `_series(scene, pos, facing, center, timeline, lift)` reads a timeline and logs `PRESS <frame>`. That frame equals the PNG index, so it is the cut point.
   - Mute the Music bus (`_mute_music()`). The video lays one continuous music track.
   - Use `probe.gd` first to find a spot. Re-place Alice after load, because scenes move her to their spawn.
3. **Captions:**
   - `captions.gd` for vertical (1080x1920).
   - `captions_h.gd` for horizontal (renders 2560x1440).
   - Add a caption set and render it to `work/cap_*`.
4. **Voices** in ElevenLabs, through the user's Chrome (Claude in Chrome). The built-in browser cannot save downloads.
   - One line per generation: triple-click the text, type, `cmd+Return`, wait about 9 s. Batches of 4–5 lines; longer batches drop the connection.
   - Each generation makes 2 variants; credits are charged once.
   - Download from History: Manage → select one variant per line (with JS over the checkbox rows, scrolling the virtualized list) → download. Above ~20 items the zip arrives late, sometimes minutes later.
   - Zip files carry timestamps, not text. Name them by generation order (`name_vo.sh`; use bash arrays, since zsh arrays are 1-based).
   - Always verify with `check_voices.py` (Whisper `models/ggml-base.en.bin`).
   - Ask before spending credits. It is about 1 credit per character.
5. **Compose:**
   - Vertical: `compose_series.py` (`--voz`, `--cover`).
   - Horizontal: `compose_long.py` (`--preview`, `--finish-only`, `--finish-only --audio-only` for audio in about 25 s).
   - Long video output is 2560x1440: game recordings scale x2, the user's playthrough fits 1:1, and YouTube gives 1440p more bitrate.
   - Make a 720p copy under 30 MB to send to the phone.
6. **Covers:**
   - Vertical: keep key content within y 240–1680, the 3:4 profile crop. Append the cover as the last 4 frames (`*_cover.mp4`) so TikTok can pick it.
   - YouTube thumbnail: `thumb_text.gd` plus ffmpeg, 1280x720.
7. **Check frames** with contact sheets (`fps=1/10,tile`) before delivering. Write `<name>_script.md` with posting texts (TikTok + YouTube) in the video's folder.

## Pitfalls already paid for
- Movie Maker runs in game time. Count frames; never use `Time.get_ticks_msec`. Godot exit code 134 at quit is normal and the frames are saved.
- Setting `Camera2D.offset` or disabling smoothing in the apartment and metro jumps the view to the wrong room. Use the default camera; only small `lift` values are safe.
- Alice does not walk with `Input.action_press` in these recordings. For movement, cut from the user's playthrough (`press_kit/youtube_long/clips_jeremy/gameplay_full.mov`, `crop=2560:1440:190:236`) or ask for a new one.
- Recordings made without muting music carry the game music in `f.wav`. Re-record with `NO_MUSIC=1` (see `clip_layers`).
- `leo_store_checkout` event indices change when the timeline is edited. List them with `clip_events` before starting at an index.
- ffmpeg stalls forever with one graph holding the picture and about 70 audio inputs. Keep captions, audio and mux as separate passes (already done in `compose_long.py`). Pass `stdin=DEVNULL`.
- A music part longer than its track goes silent. Loop from the track's loop point (`aloop`), crossfade parts, even out levels (`MUSIC_DB`) and duck gently (`DUCK_*`).
- Non-integer downscales blur pixel art. Prefer x2 nearest-neighbour or 1:1 crops.
