# Créditos de audio

Todos los sonidos vienen de [Pixabay](https://pixabay.com/) (licencia de
contenido de Pixabay: uso comercial permitido, sin atribución obligatoria). Se
recortaron, se hicieron bucles y se igualó su volumen; el original está en la
columna "Origen" (autor-título-id de Pixabay).

| Archivo | Origen | Cambios |
|---|---|---|
| ambience/apartment.ogg | freesound_community — room-tone-int-living-room_poa_horns_trafic_kitchen-noises_m-18976 | 1:35–4:35 (sin el bocinazo de 1:27), bucle |
| ambience/metro_platform.ogg | vadim_makes_sound — muffled-subway-platform-ambience-546581 + freesound_community — crowd-ambience-27970 | mezcla de los dos, bucle de 57 s |
| ambience/train_ride.ogg | freesound_community — train-ride-inside-the-car-17382 | 0:20–2:20, bucle |
| ambience/unknown_station.ogg | vadim_makes_sound — muffled-subway-platform-ambience-546581 | solo el andén, sin gente; bucle de 54 s, bajo |
| ambience/street.ogg | km007 — city-ambience-9271 | bucle |
| ambience/leo_store.ogg | freesound_community — apartment-kitchen-ambience-19263 | 0:02–1:19 (nevera), bucle |
| sfx/meow.ogg | dragon-studio — cute-cat-meow-472372 | sin el silencio inicial, volumen |
| sfx/train_arrival.ogg | arunangshubanerjee — metro-train-arrival-at-platform-mind-the-gap-announcement-332673 | 0:03–0:14.5, sin el anuncio |
| sfx/train_departure.ogg | spinopel — a-subway-train-leaving-a-station-456315 | 0:05.5–0:24, fundido |
| sfx/train_chime.ogg | freesound_community — subway-station-chime-100558 | volumen |
| sfx/door_open.ogg | freesound_community — door-open-46756 | sin el silencio inicial |
| sfx/shop_bell.ogg | universfield — clear-bell-chime-487898 | volumen |
| sfx/ui_move.ogg | mr_berrydev — single-keypad-beep-433456 | volumen |
| sfx/heartbeat_loop.ogg | universfield — rapid-heartbeat-151928 | 7 latidos exactos, bucle |
| sfx/breathing_loop.ogg | lexieva — heavy-girl-breathing-149496 | bucle |
| sfx/footstep_1..4.ogg | freesound_community — pasos-steps-40285 (Pixabay) | 4 pasos sueltos (los de volumen más parejo), recortados, mismo volumen |

## Música

Toda la música es propia, creada con ElevenLabs Music (2026-11-11). Se pasó de
WAV a OGG con FFmpeg (Vorbis q5, 48 kHz), se quitó el silencio de las puntas,
se igualó el volumen a −21 LUFS (`loudnorm` en dos pasadas, lineal, pico
−2 dBTP; la música anterior estaba en ~−21 LUFS) y se le puso un fundido de
entrada de 0,3 s y de salida de 3 s. No son bucles: cada momento tiene una lista
(`audio/music/playlists/*.tres`, `AudioStreamPlaylist` en orden aleatorio,
con fundido de 2 s entre pistas).

| Lista | Pistas (archivo ← original de ElevenLabs) |
|---|---|
| theme (menú, fin de la demo) | theme_quiet_little_smile ← Quiet_Little_Smile; theme_smiling_to_myself ← Smiling_to_Myself |
| apartment | apartment_dusk_loop_a ← Dusk_Apartment_Loop; apartment_dusk_loop_b ← Dusk_Apartment_Loop (1) |
| street (calle y plaza) | street_first_steps_a–d ← First_Steps_Outside, (1), (2), (3) |
| leo_store | leo_nervous_little_heart ← Nervous_Little_Heart; leo_butterfly_timing ← Butterfly_Timing |
| lia (plaza, mientras Lía va con Alice) | lia_pocketful_of_wonder ← Pocketful_Of_Wonder; lia_little_wanderer ← Little_Wanderer |
