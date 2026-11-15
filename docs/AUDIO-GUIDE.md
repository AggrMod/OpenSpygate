# Audio Guide

> **Direction change, 2026-11-14.** OpenSpygate is now a modern-day, open-world city game set in a fictional present-day American river-port city (`docs/GDD.md`). For this document that means: measurement, loudness targets, formats, trimming, names, buses and the door specification (section 13) stand. The Berlin 1961-63 footstep surfaces (section 7.1) and ambience beds (section 8.1) are superseded and kept for the record; the city's lists are to be written for the first block (stage 1). The music states in section 10 were tied to the old design's six alert tiers, which no longer exist; they are set aside until police response is designed. Footsteps as a gameplay noise (section 7.4) is kept as a mechanism, not as a decided rule. The handler voice belongs to the old plan; whether there is one depends on the premise, which is not decided. The first new sounds are engine, tyre and wind, synthesised in code (in review).

> **Policy change, 2026-11-14.** The project now makes all of its own assets and accepts no third-party asset files (fonts excepted), and its licences are MIT for code and CC BY 4.0 for everything else. Where this document talks about using third-party sources or about CC BY-SA or GPL, it is out of date and is kept as background. `CONTRIBUTING.md` is the rule.

Version 0.1; numbers are starting values to be calibrated in stage 1, on the first block.

Written 2026-11-14 by Foley (audio standards). Reviewed by Jim (project manager) before merge. This guide is the standard that audio contributions are checked against, in the same way `docs/ART-BIBLE.md` is for visual assets. A reviewer should be able to pass or fail a sound from this document and its measurements alone.

## How to read the numbers

Every number carries one tag:

- **[S]** sourced. The source is named in section 14 and the value is what that source says. Where a source was read only through a search excerpt and not in full, the tag says so.
- **[C]** convention. A starting value chosen for this project. It is not from a standard. Stage 1 calibrates these on the door and the first block, measured on the reference PC (GTX 1660 SUPER, Ryzen 5 4600G, 1080p, per GDD section 6).

Every "must" below is checkable. Every measurement is taken by the method in section 2.

## 1. The sound in one paragraph

Realistic, true to the place and physically motivated. Doors creak because hinges are old. Footsteps differ by surface, and each step is a noise the city can hear. Music is original. Voices are close, dry and honest at the door, and radio-treated only when they come through a radio. Nothing is copied from a commercial game or a real recording of a real person. Every sound has a source, a licence and a ledger row.

## 2. Measurement

| Quantity | Meter and method |
|---|---|
| Integrated loudness (LUFS) | ITU-R BS.1770 K-weighted loudness with 400 ms gating, measured with a meter that follows EBU Tech 3341 so that tools agree [S: BS.1770 and Tech 3341 as cited in section 14; the standard was not re-read in this session] |
| True peak (dBTP) | Inter-sample peak by oversampling, per BS.1770 and EBU R 128 [S] |
| Sample peak (dBFS) | Highest sample value. Used only to check that true peak is not hiding in the data |
| Noise floor | A-weighted RMS over the quietest 1 s of the file, measured in the file's silent section [C] |

**Gating warning.** Integrated loudness averages over blocks of at least 400 ms. It is meaningless on sounds shorter than about 400 ms (door latch, footstep, UI click). Those are judged by **true peak** and by the peak of their envelope, and their loudness is not required to be measured. Every category below names which measure applies.

## 3. Targets

### 3.1 Platform reference

- **Whole mix, PC (lead platform):** the reference mix, played for a 10-minute gameplay recording, measures **-24 LUFS integrated, ±2 LU** [S for the console figure: IESD Mix Reference Levels v03.02, and ITU-R BS.2434 which gives -24 ±2 LKFS for consoles]. Applying the console figure to PC is a **[C]** convention. Stage 1 confirms it by ear on the reference PC.
- **Whole mix, tablets (second tier):** **-16 LUFS integrated, ±2 LU** [S: IESD mobile row; ITU-R BS.2434 gives -18 ±2 LKFS for portable devices, so the two differ and the tablet figure is a **[C]** choice within that spread]. Tablets use a bus trim (section 9), not separate files.
- **Ceiling, master bus:** **-1 dBTP** [S: EBU R 128 production limit as quoted in the EBU v5.0 summary, and IESD]. A limiter on the master holds it.

### 3.2 Per-category asset targets

These sit inside the whole-mix target. Each one is a **[C]** convention unless the tag says otherwise.

| Category | Measure | Target | True-peak ceiling | Tag |
|---|---|---|---|---|
| Music, per state, one layer set | Integrated over loop | -26 LUFS | -3 dBTP per stem, -1 dBTP on master | C (ceiling is S) |
| Voice, handler and door | Integrated over the line | -22 LUFS | -3 dBTP per file | C |
| Radio-treated voice | Integrated over the line | -24 LUFS | -3 dBTP | C |
| Ambience bed | Integrated over loop | -30 LUFS | -10 dBTP | C |
| Vehicle engine loop | Integrated over loop | -28 LUFS | -6 dBTP | C |
| Footsteps | True peak, by mode and surface (section 7) | Walk on asphalt -14 dBTP; surface and mode offsets in section 7 | Same as target | C |
| Door, hardware one-shots | True peak | -10 dBTP (handle), -12 dBTP (latch, flap) | -6 dBTP | C |
| Foley and impacts | True peak | -8 dBTP | -4 dBTP | C |
| Knock on the door | True peak | -8 dBTP | -4 dBTP | C |
| UI | True peak | -12 dBTP | -8 dBTP | C |

A file that exceeds its true-peak ceiling fails. A file more than 2 LU away from its integrated target fails, unless the file is a one-shot, in which case loudness is not checked.

Consistency across variations: the integrated (or peak) level of variations of one sound must lie within **±1.5 dB** of each other [C]. Pitch and volume randomisation at runtime is set by the engine, not baked in.

## 4. Formats

### 4.1 Source files (what contributors deliver)

- **Container:** WAV, uncompressed PCM. No MP3 or Ogg as a source [C].
- **Sample rate:** **48 kHz** [C]. Godot's import note says rates above 48 kHz give no audible benefit in games unless audio is slowed at runtime [S].
- **Bit depth:** **24-bit** [C]. The Godot note says 24-bit has no audible benefit for shipped games [S], so 24-bit is kept only as a source, never as a shipped format.
- **Channels:** mono for footsteps, foley, voice, door hardware and UI. Stereo for ambience, music, vehicles and any sound whose stereo image matters (stereo is never used as a way to fake width on a mono sound). No 5.1 [C].
- **Recording level:** peaks between -18 and -6 dBFS on a clean take [C]. Nothing clips.

### 4.2 Formats the engine ships

These follow Godot's own guidance [S: Godot 4.7 "Importing audio samples"].

| Use | Ship format | Setting | Why |
|---|---|---|---|
| Short, repeated SFX (footsteps, latch, UI, knock, flap) | WAV | Compress mode **Quite OK Audio (QOA)**, the default | Godot: consider WAV for short, repetitive sound effects. QOA saves space at little CPU cost [S] |
| Long SFX (vehicle, engine, long ambience one-shots) | Ogg Vorbis | Quality -q 5 to -q 6 (about 160 to 190 kbps stereo) [C] | Godot: Ogg Vorbis for longer sound effects. Smallest files [S] |
| Ambience beds | Ogg Vorbis | Stereo, -q 6 [C] | Long loops; Ogg is the usual music and speech format [S] |
| Music stems | Ogg Vorbis | Stereo, -q 7 [C] | Music and speech are Ogg in Godot's guidance [S] |
| Voice (handler, door) | Ogg Vorbis | Mono, 22.05 or 24 kHz, -q 4 [C] | Speech can be mono and reduced to about 22 kHz [S] |
| MP3 | Only on request for tablets with many simultaneous long streams | [C] | Godot says MP3 uses less CPU than Ogg and suits many long ambient sounds, mainly on mobile and web [S] |

Do not ship 8-bit. Godot advises against it because quality drops significantly [S].

Loop mode:

- **WAV:** set Loop Mode to Forward (or Ping-Pong for the rare effect that needs it). Loop Begin and Loop End are in samples from the file start; Loop End -1 means the end of the file [S].
- **Ogg:** enable Loop. Loop Offset is in seconds from the file start where looping restarts. The value 0 loops the whole file. Ogg and MP3 support only a loop start, not an end [S].

## 5. Trimming, fades, loop points, noise

- **Trim head:** cut to within **10 ms** of the first transient. For transient-critical sounds (latch, knock, footstep), keep **no more than 5 ms** of pre-roll [C].
- **Trim tail:** cut where the level falls below **-60 dBFS** after the last audible event, not earlier, so tails are not chopped [C].
- **Fades:** every file has a fade-in and fade-out of **at least 2 ms** to avoid clicks. Long tails (ambience, room tone, engine loops) use **10 to 20 ms** [C].
- **Noise floor:** the quietest 1 s of any clip measures **at or below -60 dBFS RMS, A-weighted** [C]. Room tone for the void is the one exception (section 13), and it has its own limit.
- **Clicks and hum:** no click above -40 dBFS in the first or last 5 ms [C]. No mains hum (50 or 60 Hz, depending on where it was recorded, and their harmonics) above -40 dB relative to the signal around it [C].
- **Loop points:** set on a zero crossing. Seam check: the loop plays through 3 times in the review, and no seam is audible; measured as a difference below **0.5 LU** in loudness across the seam window of 200 ms [C].
- **Loop crossfade:** SFX loops use **50 ms**; ambience and music loops use **1 to 2 s** equal-power overlap [C].
- **Ambience loop length:** **60 to 120 s** [C]. Music loop length is set per track by bar count at the track's tempo.

## 6. Names, folders and variations

### 6.1 Folder layout

Matches `docs/ART-BIBLE.md` section 7, with audio classes:

```
assets/<world>/<class>/<name>/
  source/    the .wav files as recorded or generated, plus the recording notes (README is not used: notes go in notes.txt)
  export/    the shipped .wav (SFX) and .ogg (everything else), one folder per sound
  review/    loudness report (CSV), true-peak report, spectrogram PNG, the in-game listening clip
```

- `<world>` is a city name or `shared`. Footsteps and door sounds are `shared` where they carry over; city-specific ambience is under the city.
- `<class>` for audio is one of `sfx`, `foley`, `amb`, `music`, `vo`. `sfx` is gameplay effects, `foley` is body and surface sounds, `amb` is ambience, `music` is music, `vo` is voice.

Example: `assets/shared/foley/footstep_cobble_walk/`, `assets/<world>/amb/amb_downtown_day/`, `assets/shared/vo/door_voice/`.

### 6.2 File names

- Lowercase, underscores, no spaces, no accents. Same rule as the art bible (section 7).
- Pattern: `<class>_<name>_<nn>.<ext>`. `nn` is a two-digit variation number from `01`, with no gaps.
- Examples: `footstep_cobble_walk_01.wav`, `door_latch_02.ogg`, `vo_handler_briefing_01.ogg`.

### 6.3 Variations

- Minimum **4** variations for any sound that repeats in play. Footsteps need 4 per surface per mode; 6 for the three most-walked surfaces of the city, set when its surface list is written [C].
- Variations must differ in content, not only in level. Two files that match after pitch and volume shift count as one.
- Variation sets are named by the sound, not the take: never `footstep_final2.wav`.

## 7. Footsteps

### 7.1 Surfaces (Berlin 1961-63)

*Superseded on 2026-11-14 and kept for the record. The city's surface list is to be written for the first block.*

The surface list is the set the engine can tag. Each surface has a loudness offset that the **gameplay** table (section 7.4) also uses.

| # | Surface | Where in Berlin 1961-63 | Offset, dB [C] |
|---|---|---|---|
| 1 | Cobblestone (Kopfsteinpflaster) | Old tenement courtyards, older streets | +3 |
| 2 | Asphalt | Main roads, the boulevard | 0 |
| 3 | Paving slabs (concrete) | Pavements of the housing estates | +1 |
| 4 | Wet paving or puddle | Any paved surface after rain (a state, not a material) | +1 |
| 5 | Sandstone steps | Tenement stairs, church steps | +2 |
| 6 | Wood floor (boards, parquet) | Flats, safehouses | +1 |
| 7 | Terrazzo or tiled stairwell | Tenement stairwells, public buildings | +2 |
| 8 | Linoleum | Offices, flats, the checkpoint hut | -1 |
| 9 | Carpet or runner | Hotel, embassy, the better flats | -6 |
| 10 | Metal grate and catwalk | Rail yards, the wall's watchtowers | +4 |
| 11 | Gravel and cinder (Schotter) | Rail yards, edges of the wall zone | +2 |
| 12 | Sand | The strip beside the wall (the death strip) | -4 |
| 13 | Grass and earth | Parks, waste ground | -5 |

Tram rails and the wall's concrete barrier are not footstep surfaces; they belong to vehicle and impact sounds.

### 7.2 Sets and modes

Each surface has three modes. Each mode has its own variations.

| Mode | Variations per surface | Level relative to walk | Hearing radius, metres, on hard surface [C] |
|---|---|---|---|
| Walk | 4 (6 for cobble, asphalt, paving) | 0 dB | 12 |
| Run | 4 (6 for cobble, asphalt, paving) | +6 dB | 24 |
| Sneak | 4 (6 for cobble, asphalt, paving) | -8 dB, softer high end | 4 |

The sneak set is not a quieter walk. It has a softer attack and less heel, so it sounds different, not only lower.

Count: 13 surfaces × 3 modes × 4 variations = 156 files, plus 2 extra variations on each of the 3 most-walked surfaces in each mode = **174 files**. This is above the research budget of 150 to 200 for all SFX (`docs/research/04-art-and-content-pipeline.md` section 8.2), which must be raised to cover footsteps alone. That is a finding for Jim to schedule.

### 7.3 Triggering

- Footsteps play from animation markers on walk, run and sneak clips.
- Runtime pitch variation **±3%** and volume variation **±1.5 dB** [C]. These are set in the engine, not baked.
- Maximum 2 footstep voices at once per character. A sound that clips the limit is dropped, not queued.

### 7.4 Footsteps are a gameplay value

Guards hear footsteps. The loudness of a step is therefore not only an audio decision, it is part of the game's rules.

- The noise value for a step is `base(mode) + offset(surface)` in dB, taken from one data table. The same table sets the audio level in the engine **and** the hearing radius used by guards and watchers.
- Hearing radius, metres, is `base_radius(mode) × 10^(offset/20)`, rounded to the nearest metre, with `base_radius` from section 7.2. For example, run on grate (+6 + 4 = +10 dB): 24 × 10^(10/20) ≈ 76 m. That figure is a starting value and is calibrated if footstep noise becomes a rule (C).
- The table lives in the data layer named by the technical design (`docs/TECH-DESIGN.md`). This guide sets the values; the code reads them. If the two ever disagree, the table wins and this guide is corrected.
- A reviewer checks that the audio file's measured level for each surface matches its offset within **±1 dB** [C].

## 8. Ambience beds

### 8.1 Berlin 1961-63 beds

*Superseded on 2026-11-14 and kept for the record. The city's beds are to be written district by district, starting with downtown.*

Five districts, each with a day and a night bed, plus three interior beds. The first district to launch is the checkpoint zone (GDD v0.1 numbering; that section no longer exists).

| Bed | Day content | Night content |
|---|---|---|
| Checkpoint zone | Wind on wire, distant road, guard boots on gravel, a radio through a hut window | Generator hum, searchlight motor, wind, a dog far off |
| Tenement quarter | Courtyard voices, a child, laundry poles, a radio through an open window | Pipe knock, a tram far off, a door closing, one neighbour's radio |
| Eastern boulevard | Trams, traffic, a crowd of pedestrians | Fewer trams, distant traffic, a bus engine idle |
| Rail yards | Shunting, bell, horns, wind through cables | Shunting, a signal relay, wind |
| Western shopping street | Shoppers, shop bells, cafe chatter, a cinema queue | Late bar voices, a shutter rattling, a car passing |
| Safehouse (interior) | Room tone, a kettle, a clock | Room tone only, a heater tick |
| Tenement stairwell (interior) | Footstep echo, a distant wireless | Pipe, a distant door |
| Café (interior) | Cups, low voices | Low voices, one radio |

Each bed: stereo, Ogg, 60 to 120 s loop, integrated -30 LUFS, true peak -10 dBTP [C]. Ambience uses the period's real sounds (trams, dogs, radios of the time) recorded or licensed under section 11. No real place names on signs in recordings.

### 8.2 Rules

- Beds never carry a melody or a recognisable song.
- The day and night beds of one district share their room tone so the change is a cross-fade, not a cut.
- A bed must sit under the voice and the footsteps in the reference mix. A reviewer listens with a handler line playing; if the bed masks the line, the bed fails.

## 9. Buses

| Bus | Holds | Notes |
|---|---|---|
| Master | Everything | Limiter, true-peak ceiling -1 dBTP [S]. Platform trim: PC 0 dB, tablet +8 dB [C] |
| Voice | The door voice, dialogue, barks | Dialogue priority. Music ducks under it |
| Radio (effect) | Only radio-treated voice | Band-pass and hiss live here, not on the voice bus |
| Music | Adaptive music stems | Ducks by **4 dB** while voice plays, with a 0.3 s attack and 1.0 s release [C] |
| SFX | Parent of the buses below | Gameplay and world sound |
| SFX / Footsteps | Footsteps | Carries the surface offsets from section 7 |
| SFX / Doors and props | Door hardware, latches, flaps | |
| SFX / Street | Signals, crossings, shop doors, street machinery | |
| SFX / Vehicles | Engines, brakes, horns | |
| SFX / Impacts | Foley, falls, scuffles | |
| UI | Menus and interface | Never ducked |
| Ambience | All beds | Ducked 3 dB during voice [C] |

Every bus has a gain and a limiter at the top. Nothing plays directly to Master.

## 10. Adaptive music

### 10.1 Layers

| Layer | Content | Starts |
|---|---|---|
| 1. Bass and pad | Sustained low and mid tones | Always |
| 2. Percussion | Brushes, a tick, a light pulse | Tier 1 |
| 3. Motif | Original melodic line on a period-flavoured instrument (cello, zither-like string, or a bowed lute); no melody copied from any existing film or game | Tier 2 |
| 4. Stinger | Short hits at events and entries | Tier 4 and 5, and on events |

### 10.2 States mapped to the six alert tiers

*Set aside on 2026-11-14: the alert tiers belonged to the old design. Kept for the record until police response is designed.*

The tiers were defined in `docs/GDD.md` v0.1, section 6, which no longer exists. Music followed them one to one.

| Tier (GDD v0.1, section 6) | Music state | Layers | Entry into the state |
|---|---|---|---|
| 0 Normal | `explore` | 1 | Default |
| 1 Extra watchers on cameras | `watch` | 1 + 2 | Next bar |
| 2 Private areas lock | `tense` | 1 + 2 + 3 | Next bar |
| 3 Plain-clothes counter-agents | `hunt` | 1 + 2 + 3, bass pulse on | Next bar |
| 4 Checkpoints on district exits | `lockdown` | 1 to 3, stinger layer on entries | Next bar |
| 5 Lockdown and manhunt | `manhunt` | 1 to 4 | Immediate cut with a stinger |

Off-tier states (not alert tiers):

- `safehouse`: lounge version of layer 1, no percussion.
- `stealth_success`: a short stinger over `explore`, 4 s, then back to `explore`.
- `capture`: no layers for 2 s, then a scene cue. Captures are non-lethal scenes (GDD v0.1, section 4), so the state is never a combat cue.

Note: the research document lists the states `explore, suspicion, pursuit, combat, stealth_success, safehouse` (`docs/research/04-art-and-content-pipeline.md` section 6.4). This guide replaces it with the tier-matched set above, because the GDD's tiers are the authority. `combat` is dropped because takedowns are non-lethal.

### 10.3 Transitions

- **Tier up:** wait for the next bar, then cross-fade over **0.5 s** [C]. The stinger jump at tier 5 is immediate with a **0.2 s** fade [C].
- **Tier down:** wait for the end of a 4-bar phrase, then fade over **2 s** [C].
- **Loud event:** immediate cut with a 0.2 s fade. A loud event is anything the GDD names as a jump.
- All tracks share one tempo per city [C]. The tempo is set per track and stated in its notes.

## 11. Sources and licences

### 11.1 Allowed

Per `CONTRIBUTING.md`, third-party audio must be CC0, CC BY, CC BY-SA, MIT, BSD, Apache-2.0 or OFL, with one row in `assets/LICENSES.csv` per file.

- **Our own recordings and generated files.** Contributed under CC BY-SA 4.0, per CONTRIBUTING.md.
- **Freesound.org,** filtered to CC0, CC BY or CC BY-SA. Each file logs its ID and author. CC BY needs credit. Non-commercial (NC) files are excluded, because a game that sells is commercial (research section 6.1 [V-2nd]).
- **OpenGameArt audio** under the same licence filter.
- **Kenney audio packs,** CC0, where the specific pack is confirmed on its own page.

### 11.2 Not accepted

- **Sonniss GDC bundles.** `CONTRIBUTING.md` lists them as not accepted (no redistribution), even though research section 6.1 recommends them. This guide follows CONTRIBUTING.md.
- **Any NC or ND licence.**
- **Any sound ripped from a commercial game,** or from a fan site that rips games.
- **Any recording of a real person without a signed release,** or any voice cloned from a real person. See section 12.
- **Any sound that imitates a famous film or game theme.**

### 11.3 Ledger row

Each third-party file gets one row in `assets/LICENSES.csv`: path, source URL, author, licence, date fetched, SHA-256.

## 12. Voice

### 12.1 The two voices

- **The handler.** The briefing voice. Speaks the operation briefings and debriefs. Voiced by a generated or recorded voice, one consistent character, in American English. Belongs to the old plan; whether the game has a handler depends on the premise.
- **The voice at the door.** The line in the void: a voice says that if you walk in, there is no turning back (`AGENTS.md` section 3, `docs/GDD.md` section 9). It is the first voice the player hears, and it sets the tone for the whole game. Its wording is to be decided in the writing pass; this guide sets how it is delivered, not what it says.

The two voices are one character or two; the choice is open and is recorded as a decision in the audio pull request.

### 12.2 Recording or generating

Two routes. Pick one per line and record which in the ledger.

1. **Generated offline with Kokoro-82M.** Kokoro-82M is Apache-2.0 on its official model card [S: research section 6.3, from the model card as quoted there; not re-read in this session]. Its phonemizer dependency espeak-ng is GPLv3, so the voice is **baked offline** and only the resulting WAV or Ogg ships. No GPL code goes in the repository or the build. Each voicepack used is checked for its licence in the same way.
2. **Recorded by a human actor.** Only with a signed release, a recording log, and the actor's own voice. No cloning.

Piper voices are allowed only when the voice's own model card permits commercial use. Piper's engine is GPL-3 (research section 6.3), so ship only baked audio, never the engine.

### 12.3 Radio treatment

Used on the radio effect bus only (section 9).

- Band-pass **300 Hz to 3.4 kHz** [C: telephone-band convention, applied as a radio approximation].
- Compression **4:1**, threshold **-18 dBFS**, attack 10 ms, release 150 ms [C].
- Hiss at **-50 dBFS** under the voice, one crackle every ~10 s [C].
- Level matched so radio voice is **-24 LUFS integrated** (section 3.2).

The door voice is **not** radio-treated. It is dry and close, with a faint room reflection of **-20 dB** relative to the direct sound [C]. The voice speaks when the player is close, and it should sound as if it is next to the player.

### 12.4 No impersonation

- No real person's voice, cloned, imitated or sampled.
- No voice in the game is presented as a real person or a real service.
- The handler and the door voice are fictional characters with fictional names.

## 13. Door specification

The door is the first asset built (`docs/GDD.md` section 9, `docs/ART-BIBLE.md` section 11). Its sound is built to the same standard: every sound has a reason, and every one is measured. The door sounds are recorded or generated to the rules above, then checked in the game at the door, in the void.

| Sound | File(s) | Duration | Variations | Level | What it must be |
|---|---|---|---|---|---|
| Brass lever handle, press and release | `door_handle_press_01..03.wav` | 0.4 to 0.8 s | 3 | True peak -10 dBTP | A brass lever sprung and worn: a small metallic click at the end of travel, a soft clunk of the spindle. The sound changes with how hard the hand pushes |
| Latch | `door_latch_01..03.wav` | 0.15 to 0.3 s | 3 | True peak -12 dBTP | A mortise latch throwing back: a short, dry click with a faint metal ring. Not a modern spring-latch snap |
| Hinge creak, swing | `door_hinge_swing_slow_01..02.wav`, `_med_01..02.wav`, `_fast_01..02.wav` | 2 to 5 s | 2 per speed | True peak -12 dBTP | An old iron hinge with dry pivot. Speed sets the pitch and the rhythm of the creak. Recorded on a real old hinge or a real old door, not synthesised |
| Letter-slot flap, lift | `door_flap_lift_01..02.wav` | 0.4 s | 2 | True peak -12 dBTP | Iron flap on hinge, a hollow metal lift and a small rattle at the top |
| Letter-slot flap, drop | `door_flap_drop_01..02.wav` | 0.3 s | 2 | True peak -12 dBTP | The flap falls back; a hollow tap and a short ring |
| Knock | `door_knock_01..03.wav` | 0.6 to 1.0 s (three knocks) | 3 | True peak -8 dBTP | Knuckle on painted wood: three knocks, the middle one slightly harder. Not a drum sample |
| Bell push | `door_bell_press_01.wav`, `door_bell_ring_01.wav` | 0.1 s press, 1.5 to 2.5 s ring | 1 each | True peak -10 dBTP | A period bell push with a real bell behind the frame: a short, sharp ring that decays and stops. Not an electronic doorbell |
| Void room tone | `door_void_tone_01.ogg` | 60 s loop | 1 | Integrated -48 LUFS, true peak -20 dBTP | Near silence. The sound of nothing in particular: a faint, even air tone. No hum above -40 dB relative (50 or 60 Hz and harmonics), no tonal peaks, no clock |
| Voice line at the door | `vo_door_01.ogg` | 5 to 8 s | 1 (plus a 1-variation alt) | Integrated -22 LUFS, true peak -3 dBTP | Close and dry, faint room reflection at -20 dB (section 12.3). Speaks when the player comes close, once |
| Warm light under the door | No sound | n/a | n/a | n/a | The light is visual. Its sound is the room tone, not a hum |

Rules for the door set:

- Every hardware sound is recorded at **0.5 m** from the source, on a real object where possible, in a room with a measured noise floor at or below -60 dBFS.
- Every sound has a one-line reason in `source/notes.txt`: which part makes it, and why it sounds that way. "Looks right" is not a reason.
- The **moving-part pivots** of the handle and the flap are the same objects as in the art bible (section 11), so the sound and the animation line up. The door's opening task checks the sync by ear.
- The handle is the most-used sound on the door. The reviewer listens to the press at arm's length (0.5 m) and at 3 m in the void.

## 14. Sources

Accessed 2026-11-14.

1. Godot Engine 4.7 docs, "Importing audio samples": https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_audio_samples.html. Read in full. Source for sections 4.2, 4.1 (the 24-bit and 48 kHz notes), and the loop settings in section 4.2.
2. EBU R 128, "Loudness normalisation and permitted maximum level of audio signals". Source for the true-peak production limit of -1 dBTP and the Tech 3341 meter method. v5.0 PDF: https://tech-qual.ebu.ch/files/live/sites/tech/files/shared/r/r128v5_0.pdf; background: https://en.wikipedia.org/wiki/EBU_R_128. The PDF could not be read as text in this session. The -1 dBTP figure is taken from the EBU v5.0 text as quoted in a search excerpt. The -23 LUFS broadcast target is not used in this guide because it is a broadcast figure.
3. IESD Mix Reference Levels v03.02 (game audio reference levels, including console -24 LUFS ±2 and mobile -16 LUFS ±2 with a -1 dBTP ceiling): https://www.audiogang.org/wp-content/uploads/2015/04/IESD-Mix-Ref-Levels-v03.02.pdf. The PDF could not be read as text in this session; the figures are from a search excerpt of the document and must be checked against the PDF before the stage 1 calibration.
4. ITU-R BS.2434 (2018), game loudness: consoles -24 ±2 LKFS, portable -18 ±2 LKFS: https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BS.2434-2018-PDF-E.pdf. Figures from a search excerpt.
5. Meta developer documentation, audio loudness meter (-16 LUFS Quest, -18 LUFS PCVR): https://developers.meta.com/horizon/documentation/unreal/audio-loudness-meter-overview/. Cross-check only.
6. ITU-R BS.1770 (loudness and true-peak method). Cited as the meter standard in section 2. Not re-read in this session.
7. `docs/research/04-art-and-content-pipeline.md` section 6 (sources and licences for audio, Kokoro-82M and Piper, adaptive music in Godot 4.3). Used for the licence screen and the voice routes. Its Sonniss recommendation is overruled by `CONTRIBUTING.md`.
8. `CONTRIBUTING.md` and `AGENTS.md` (licence and originality rules), `docs/GDD.md` (tiers, footsteps, non-lethal rule, Berlin districts), `docs/ART-BIBLE.md` (folder layout, door specification).

## 15. Review checklist

Work through in order and stop at the first failure (`AGENTS.md` section 7).

1. **Scope.** The sound belongs to the claimed task and to the open stage.
2. **Origin.** Own work or an allowed licence (section 11). Ledger row present for every third-party file. Not from a commercial game, a real person, or a Sonniss or NC source. Generated voices name the model and voicepack, and the GPL engine is not in the build.
3. **Automatic checks.** Format, sample rate, bit depth, channels, file names and folder layout (section 6) pass.
4. **Loudness.** Integrated and true-peak values in the review report are within section 3. True peak is at or below the ceiling. Variations are within ±1.5 dB of each other.
5. **Trim and fades.** Head and tail trimmed (section 5). Fades present. No clicks in the first or last 5 ms. Noise floor at or below -60 dBFS.
6. **Loops.** Seam check passes (3 plays, no audible seam, loudness across the seam within 0.5 LU). Loop points on zero crossings. Loop mode set per section 4.2.
7. **Footsteps.** Surface offsets match the table within ±1 dB. Mode sets match section 7.2. The gameplay noise value comes from the shared table, not a copy.
8. **Music.** Layer and tier mapping matches section 10.2. Transitions match section 10.3.
9. **Voice.** No real person. Radio treatment only on the radio bus. Door voice dry, with the reflection in section 12.3.
10. **In context.** Listened to in the game next to its neighbours, at the distance it will be heard from (door sounds at 0.5 m and 3 m; footsteps at 3 m, 10 m and 20 m; ambience with a voice playing). An asset that passes the numbers but masks the handler, or sounds wrong in place, fails.
11. **Honesty.** The description says what was measured, with which meter, and what was not measured. A claim of "sounds right" without a listening note fails.
12. **Decide.** Approve, or request changes naming the exact line of this guide that is not met. If the guide is silent or wrong, open a proposal to change it instead of arguing in the review.

## 16. Open items

- Calibrate every **[C]** number on the door and the first block (stage 1), on the reference PC.
- Read the IESD and EBU PDFs as text, and replace the search-excerpt figures with quotes from the documents.
- Decide the PC platform reference (-24 LUFS mix is a convention for PC).
- Confirm the footstep and SFX budget in `docs/research/04-art-and-content-pipeline.md` section 8.2, which does not cover the 174 footstep files this guide needs.
- Confirm the Kokoro-82M model card and voicepack licences before the first voice is baked.
- Write the door's voice line. This guide does not set its wording.
