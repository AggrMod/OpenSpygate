# AGENTS.md: start here

This file runs the project. Any person or AI agent arriving at this repository reads it first and then knows where the project stands, what to do next, what standard to meet, and how to review someone else's work. If this file and another document disagree, this file wins and the other document gets fixed.

## 1. What this is

OpenSpygate is an open-source, modern-day, open-world city game. You go on foot and in vehicles through a living fictional city, alone or with friends. It is meant to stand next to the big commercial open-world city games, and it is built in the open by a crowd of people and AI engineers.

Everything is given away under permissive licences: code under MIT, everything else under CC BY 4.0, credit "the OpenSpygate contributors". We do not try to stop anyone from copying us; we go fast and stay ahead. A closed studio is limited by headcount. We are limited only by how well contributions can be checked, so the framework below matters more than any single asset.

The name stays. It was chosen for an earlier plan, a Cold War espionage game; that plan is set aside (see `docs/archive/cold-war/`).

## 2. Current state

**Keep this section true.** Whoever changes the state of the project updates it in the same pull request.

| | |
|---|---|
| Stage | 0, direction: written down by the rewrite of 2026-11-14, apart from the open decisions below. Stage 1, "the first block", is open for work |
| Open for work | Stage 1 tasks and "open at any time" tasks in `docs/TASKS.md` |
| Playable build | `game/` is a Godot 4.7 project. `godot --path game` starts in the city: the edge of downtown Calder, a 2 x 2 block street grid (`worlds/city/`) with kerbs, pavements, crossings, street lamps, trees, working signals at the centre junction and a sky that follows the hour (T advances it). Every lot has a building from the procedural generator (`worlds/city/buildings/`, six styles, shopfronts, rooms behind the glass, windows lit at night). A saloon of our own design (built by a Blender script, `assets/shared/vehicle/sedan_a`, with an interior and working lamps) stands at the kerb: E gets in and out, and it drives on our own physics with an engine and gearbox model and synthesised engine, tyre, skid and wind sound (V changes the view). You walk in first person. `godot --path game -- --world=void` opens the void and the door; the door cannot be opened yet and there is no voice. Ten self-playing tests pass: `void_walk`, `drive`, `drive_audio`, `drive_top`, `drive_kerb`, `car_show`, `buildings`, `city_walk`, `city_drive`, `city_look` |
| Known to be unfinished | The first pass of stage 1 was merged on 2026-11-15 after review. It is not yet at the stage 1 quality bar. No person has listened to the car sounds (checked by measurement only). Upper facades are black at night away from the lamps. Shop interiors are thin close up. The saloon reads as a plain car of the 2010s and its tail lamps are flat. The stand-in driver's cabin code is unused now that the model has an interior. The road has no crown. 60 frames a second holds at 1280 x 720 on the reference PC (GTX 1660 SUPER); at 1920 x 1080 it dips to about 55 at dusk at the centre junction. Sign and street-name lettering uses Godot's built-in font. Follow-up tasks are in `docs/TASKS.md` |
| Written so far | This file, design document v0.2 (`docs/GDD.md`), production plan v0.2, task list. Art bible v0.1 (#1), technical design v0.1 (#2) and audio guide v0.1 (#3) carry a banner saying what the direction change means for them |
| Drafts awaiting review | Audio guide (#3). Licence notes (#6) reviewed and accepted as a first pass |
| Next gate | Stage 1: one downtown block you can walk and drive round, by day and night, with sound, at final quality. The project lead approves the look on the PC |
| Decided | The name OpenSpygate. A modern-day, open-world city game in a fictional present-day American river-port city. Permissive licences (MIT and CC BY 4.0). Our-own-assets rule. Realistic art direction. Host-decides multiplayer. The opening: void, door, voice; the door opens onto the city |
| Awaiting the project lead | The premise and story (nothing is written; see `docs/GDD.md`, section 4). The content rating (until it is set, nothing beyond teen-level is built). The engine: Godot 4.7 now, Unreal raised, to be settled by putting the same assets side by side. The city's name ("Calder" is a working title) |
| Set aside | The Cold War story proposal, the recruitment design and the Berlin reference pack, moved to `docs/archive/cold-war/`. Kept for the record; not the plan |
| Last updated | 2026-11-15 |

### Who runs it

| Role | Who | What they do |
|---|---|---|
| Project lead | @AggrMod | Sets the direction. Makes the open decisions above, and the two judgment calls: is the look right, is it fun |
| Project manager | Jim, an AI agent working through the project lead's account | Keeps this file and the task list true, writes and maintains the standards, opens and triages issues, reviews contributions against the standards, moves the stages forward |
| Area maintainers | Contributors invited after several good contributions | Review and merge in their area (code, art, audio, writing) |

## 3. How the game begins, and how we build it

The game opens in an empty black void. In it stands one door, detailed down to the grain of the wood, the wear on the brass and the light under the gap. A voice says that if you walk in, there is no turning back. The door opens onto the city.

That is also the build order. We started with nothing but the door and made it as real as we could. Now we build the city behind it, outward from one block, one finished piece at a time. Nothing unfinished is ever on screen: where the city has not been built yet, there is void, not a grey box.

## 4. Read in this order

1. This file.
2. `docs/GDD.md`: what the game is, and what is still undecided.
3. `docs/PRODUCTION-PLAN.md`: the stages and the gate for each.
4. `docs/TASKS.md`: what is open right now, and `team/README.md`: who is working on what, and how to register.
5. `CONTRIBUTING.md`: how to submit, and the licence rules.
6. The standard for your kind of work: `docs/ART-BIBLE.md`, `docs/TECH-DESIGN.md`, `docs/AUDIO-GUIDE.md`. Each starts with a banner saying what the direction change of 2026-11-14 means for it. If the standard you need does not exist yet, writing it is the task.
7. `docs/research/`: background and sources, when you need the reasoning. Written for the old plan; the parts on open-world city games, streaming, traffic and pipelines still apply.

## 5. Rules that never bend

1. **We make our own assets, always.** Every model, texture, sound and line is made by a contributor for this project, by script wherever possible so content scales. No downloaded asset packs, scans or stock. Nothing from any commercial game, no real brands or logos, no real living people. Fonts under the Open Font License and Godot's built-in font are the only exceptions.
2. **No placeholders on screen.** Unbuilt space is void. A contribution is a finished thing, however small.
3. **Realistic.** True-to-life dimensions, materials and light, true to how such places are really built: a kerb, a traffic signal or a shopfront is built the way real ones are. Check a real reference before designing; say what you could and could not confirm. Reference is studied, never copied. People are believable without chasing photographic faces.
4. **One stage at a time.** Work on the open stage or on "open at any time" tasks. A stage opens only when the previous gate has passed.
5. **The host decides.** Game rules run on the host. A client never decides what happened.
6. **Everything is checkable.** Code comes with a test: a self-playing test that writes `result.json` and pictures, or a test that runs without graphics. Assets come with their source, measurements and pictures. If it cannot be checked, it cannot be merged.
7. **State what you verified.** Say what you tested and what you did not. Never report something as working that you did not see work.
8. **Content.** The content rating is not decided; it is the project lead's call. Until it is, nothing beyond teen-level is built. Places, companies, products and people are fictional. See `docs/GDD.md`, section 5.

## 6. How to do a piece of work

1. Pick a task from `docs/TASKS.md` or the issue list and claim it on its issue.
2. Read the standard for that kind of work and the parts of the design it touches.
3. Look at what already exists and match it. Reuse before adding.
4. Build it in a branch, in small commits, each signed off (`git commit -s`).
5. Check it yourself against the review list in section 7, as if it were someone else's.
6. Open a pull request using the template. Include how to see it working, what you verified, and which tools you used.
7. If your work changes the state of the project, update section 2 of this file and tick the task in `docs/TASKS.md` in the same pull request.

## 7. How to review a contribution

Review against the written standard, not taste. Work through this list in order and stop at the first failure.

1. **Scope.** Does it match one claimed task in an open stage? Unrelated changes are split out.
2. **Origin.** Is it the contributor's own work, made for this project, with sign-off? Does anything look taken from a commercial game, a real brand or a real person? If in doubt, reject and ask for the source.
3. **Automatic checks.** All passing. Never merge over a failing check.
4. **Standard.** Compare against the standard for its type:
   - *Code:* test present and meaningful; rules on the host; no hidden dependence on one machine; readable.
   - *3D assets:* real-world dimensions; texel density, triangle budget and material values within the art bible's ranges; levels of detail and collision present; source file or generating script included; pictures attached.
   - *Audio:* format, loudness and origin as the audio guide says.
   - *Writing:* content rule in section 5 followed; every name invented and checked against real places, companies and people.
5. **In context.** Look at it in the game next to its neighbours, at eye level, by day and by night. An asset that passes numbers but looks wrong in place is not done.
6. **Honesty.** Does the description say what was verified? Reproduce the claim yourself.
7. **Decide.** Approve, or request changes naming the exact line of the standard that is not met. If the standard is silent or wrong, open a proposal to change the standard rather than arguing in the review.

Two judgments belong to the project lead and are made at the marked gates: whether the look is right (stage 1), and whether the game is fun (stage 4).

## 8. Before you stop

- Leave the repository in a state the next arrival can pick up from this file alone.
- Section 2 is true. `docs/TASKS.md` matches reality.
- Anything half-done is either finished, or removed and described in its issue.
- Decisions you made are written where the next person will read them: the design document, the standard, or the issue. Not only in a chat or a commit message.

## 9. When something is unclear

Prefer the rule in section 5, then the design document, then the production plan. If they do not answer it, make the smallest reasonable choice, write it down in the pull request, and flag it for the maintainers. Do not invent a new direction for the game in a pull request. In particular, do not write a premise, plot, characters or factions: that is the project lead's call.
