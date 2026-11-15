# Open tasks

The master list. Read `AGENTS.md` first. Each line becomes an issue on the repository; claim it there. Stages and gates are explained in [PRODUCTION-PLAN.md](PRODUCTION-PLAN.md).

Every task is small, checkable and has a definition of done. "Done" always includes the general rules: your own work, made by script where possible, real-world dimensions, a self-playing test or review pictures (by day and by night where it is outdoors), and a pull request that says what you verified and what you did not.

Legend: **[first]** good first task · **[code]** · **[art]** · **[audio]** · **[writing]** · **[research]** · **[lead]** needs the project lead's decision before or at the end of the work · **[in review]** being built now, do not start it

## Decisions for the project lead

These are open. A contributor can prepare a proposal; the project lead decides.

- [ ] **The premise** [lead] What the player is and why they are in the city. *Done when:* the project lead has written or approved it and it is in `docs/GDD.md`, section 4. Nobody writes a plot, characters or factions before then.
- [ ] **The content rating** [lead] *Done when:* the project lead has set it and `docs/GDD.md`, section 5 and `AGENTS.md`, rule 8 say it. Until then, nothing beyond teen-level.
- [ ] **The engine comparison** [lead] [code] [art] Put the same assets (the door, the saloon, the first block) in Godot and in Unreal, under the same light, and capture the same views. *Done when:* the pictures and frame-rate figures from the reference PC are side by side in one pull request, with the files needed to reproduce them, and the project lead has decided.
- [ ] **The city's name** [lead] [writing] [research] "Calder" is a working title. Propose up to five names. *Done when:* each name has been checked against real US cities and towns, real companies and trademarks, and names in commercial games, with what was searched and what was found; and the project lead has chosen one.

## Stage 1: the first block (open now)

One downtown block you can walk and drive round, by day and night, with sound, at final quality.

### Merged as a first pass (2026-11-15)

In the main branch, reviewed, with passing tests. None is at the stage 1 quality bar yet: the follow-ups below say what is left.

- [x] **Street grid** [code] [art] A 2 x 2 block grid with pavements, street furniture, signals and a time-of-day sky (T advances the time). `game/worlds/city/`.
- [x] **Building generator** [code] [art] Procedural downtown buildings from parameters. `game/worlds/city/buildings/`.
- [x] **Saloon body rework** [art] The car body of `assets/shared/vehicle/sedan_a`, rebuilt with an interior and lamps.
- [x] **Driving sound and gearbox** [audio] [code] Engine, tyre and wind sound, synthesised, with a gearbox model. `game/actors/vehicle/`, `tools/audio/`.

### Follow-ups from the first pass

- [ ] **Listen to the car** [audio] [first] Nobody has heard the car sounds: they were checked by measurement only. *Done when:* a person has driven for five minutes with sound on and written up what is wrong with the engine, tyres, skid, wind and doors, as issues.
- [ ] **Engine loops drift out of phase** [audio] [code] Held at one engine speed for about a minute, two crossfaded engine layers begin to cancel. *Done when:* `drive_audio` holds an engine speed for three minutes and the overtone levels stay within 3 dB.
- [ ] **Facades at night** [art] [code] Above the shopfronts, walls are black at night away from a street lamp. *Done when:* the `city_look` night pictures show the wall surfaces readable up to the cornice, without flattening the picture.
- [ ] **Shop interiors close up** [art] The rooms behind shop glass are thin at one metre: one cut-out, nothing in the first metre. *Done when:* three shop kinds hold up in a close-up at 1 m by day and at night.
- [ ] **Saloon: rear end and tail lamps** [art] The rear is boxy and the tail, brake and reversing lamps are flat faces. *Done when:* they are built as a lens over elements like the headlamps, and the rear three-quarter picture no longer reads as a box.
- [ ] **Calipers that steer with the wheel** [code] [art] The brake calipers are fixed to the body and touch the rim beyond 3 cm of travel. *Done when:* each caliper rides a per-wheel pivot that steers and moves with the suspension but does not spin.
- [ ] **Body roll in corners** [code] At 60 km/h the outside wheels compress 18 cm and the tyre passes through the wing. *Done when:* a 60 km/h corner in `drive` keeps every tyre inside its arch.
- [ ] **Remove the stand-in cabin** [code] `vehicle_cabin.gd` built a driver's cabin in code before the model had an interior. It now stands aside. *Done when:* the driver's view is fitted to the real interior (eye point, a turning steering wheel, a rev counter) and the stand-in code is gone.
- [ ] **Road crown and drainage** [code] [art] The carriageway is flat; puddles come from noise. *Done when:* the road has a crown and gutters that fall to the drains, and puddles sit in real low points.
- [ ] **Frame rate at 1920 x 1080** [code] About 55 frames a second at dusk at the centre junction on the reference PC. *Done when:* `city_look` at 1920 x 1080 holds 60 in every view.

### Open

- [ ] **Automatic checks** [code] The pull-request workflow: run every self-playing test and fail on any `result.json` without `"pass": true`; check for machine paths and personal names in committed files. *Done when:* a pull request with a deliberately failing test is shown failing, and one without is shown passing.
- [ ] **Block benchmark** [code] A self-playing camera run round the block that logs frame time, draw calls, triangles and memory, and fails when a budget in `docs/TECH-DESIGN.md` is broken. *Done when:* it runs, writes its figures to `result.json`, and a deliberately broken budget makes it fail.
- [ ] **Street tree generator** [art] [code] A script that makes street trees of believable shapes in pavement tree pits, with seeded variety and levels of detail. *Done when:* ten seeds in one picture look like ten different trees of the same planting, and a picture at eye level on the block holds up at 2 m.
- [ ] **Bus shelter** [art] A bus shelter of our own design: steel frame, glass panels, bench, a blank timetable frame. *Done when:* real-world dimensions stated with the reference, review pictures by day and night, and it stands on the pavement in the block.
- [ ] **Tyre skid marks** [code] [art] Marks on the road where tyres slide, fading over time, with a limit on how many exist. *Done when:* a self-playing test brakes hard and turns, and the pictures show marks that follow the wheels and fade.
- [ ] **Rain** [code] [art] Falling rain, wet surfaces that darken and reflect, puddles. *Done when:* a self-playing test captures the same views dry and wet, by day and night, and the frame-rate cost is stated.
- [ ] **The door's opening animation** [code] [art] The leaf swings on its hinges when the player opens it, the handle turns first, and the city is seen through the doorway. *Done when:* a self-playing test walks up, opens the door and captures the swing in three pictures; the pivots match the art bible's door specification.
- [ ] **Licence-plate design** [art] [writing] [lead] A fictional plate for the city's state: layout, colours, lettering in Godot's built-in font or an Open Font License font, a fictional state name or motto checked against real ones. *Done when:* it is on the saloon in review pictures and the check is written in the pull request. The fictional state name is a world-naming decision: the project lead approves it. Uses the working city name until the name is settled.
- [ ] **Street names** [writing] [research] A list of street names for downtown, in the way American downtowns are really named (numbered streets, trees, people's surnames that are common, not famous). *Done when:* about forty names, each checked against real famous streets and commercial games, written into a data file the street signs can read.
- [ ] **Street sign design** [art] Street-name signs and the common regulatory signs (stop, one way, no parking) of our own drawing, in the proportions real ones use. *Done when:* real dimensions stated, pictures on the block by day and night.

## Open at any time

These do not depend on a stage and are needed in volume. Each follows the art bible or the audio guide.

- **A second vehicle body style** [art] [code] A hatchback, pickup, van or taxi of an invented make, built by a Blender script like `assets/shared/vehicle/sedan_a/source/build_car.py`, on the same driving model. *Done when:* it can be entered and driven in the `drive` test, with dimensions true to its class and review pictures from the front three-quarter, side and rear.
- **Street props** [art] [first] Fire hydrant, parking meter, newspaper box, mailbox, litter bin, bollard, utility pole, manhole cover, storm drain. *Done when:* each has its real-world dimensions stated, its script or source, and pictures in place.
- **Shopfront pieces** [art] Windows, doors, awnings and sign boards for downtown shopfronts, with invented shop names. *Done when:* the building generator can use them and the names are checked against real brands.
- **Radio idents** [audio] [writing] Short station idents for fictional radio stations, all original: words, music and voice. *Done when:* each ident has its script, its source (synthesis or recording with a signed release), and meets the audio guide's loudness. No real station names or call signs.
- **The voice line at the door** [writing] [audio] [lead] The line spoken at the door: if you walk in, there is no turning back. *Done when:* the wording is approved by the project lead and the recording meets the audio guide's door specification (`docs/AUDIO-GUIDE.md`, section 13).
- **Sound effects made by you** [audio] [first] Footsteps on named surfaces, car doors, signals, city ambience. *Done when:* each meets the audio guide's format and loudness, with its source.
- **Ground materials** [art] Asphalt patches, concrete pavement slabs, painted road markings, manhole and drain covers, made procedurally. *Done when:* pictures at eye level on the block by day and night, with the texel density from the art bible.
- **Reference notes** [research] [first] Written notes on how a part of an American downtown is really built (kerb and gutter, signal poles, crosswalk markings, street lighting), with sources. Links and measurements only; nothing copied into the game. *Done when:* each figure has a source, and what could not be confirmed is said.
- **Translations** [writing] Interface text, once it exists.

## Later stages

Stages 2 to 6 are described in the production plan. Their task lists are written when the stage before them is under way, so they reflect what was learned.
