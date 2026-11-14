# AGENTS.md: start here

This file runs the project. Any person or AI agent arriving at this repository reads it first and then knows where the project stands, what to do next, what standard to meet, and how to review someone else's work. If this file and another document disagree, this file wins and the other document gets fixed.

## 1. What this is

OpenSpygate (Open Spygate International) is an open-source, open-world, multiplayer espionage game, built by an open crowd of people and AI engineers. The game is the first product; the thing being built alongside it is a decentralised, collaborative game studio that anyone can join. Everything is given away under permissive licences. We do not try to stop anyone from copying us; we go fast and stay ahead. The ambition is a level of realistic detail that closed studios cannot reach, because they are limited by headcount and we are not. We are limited only by how well contributions can be checked. So the framework below matters more than any single asset.

## 2. Current state

**Keep this section true.** Whoever changes the state of the project updates it in the same pull request.

| | |
|---|---|
| Stage | 0, pre-production |
| Open for work | Stage 0 tasks and "open at any time" tasks in `docs/TASKS.md` |
| Playable build | `game/` is a Godot 4.7 project that starts in the void and lets you walk (self-playing test `void_walk` passes). The door is in it: baked from its procedural materials at 2048 px and exported by `source/bake_door.py`. It cannot be opened yet and there is no voice |
| Written so far | Design document, production plan, art bible v0.1 (#1) and technical design v0.1 (#2), both open for comment |
| Drafts awaiting review | Audio guide (#3), recruitment design (#4), Berlin reference pack (#7). Licence notes (#6) reviewed and accepted as a first pass |
| Being built now | The Door, brought forward ahead of stage 1 so there is something to see. Geometry pass done (`assets/shared/hero/door_tenement_a`, clay pictures in `review/`); materials, textures, the void scene and the voice are not done |
| Next gate | Stage 0: design direction agreed. Then the project lead's approval of the door |
| After that | Stage 1 (foundations), then stage 3: the first corner behind the door |
| Decided | The name OpenSpygate, permissive licences (MIT and CC BY 4.0), our-own-assets rule, realistic art direction, Berlin 1961-63 as the first world, host-decides multiplayer. Engine: Godot 4.7, to be confirmed by putting the finished door on screen (the same asset can be compared in another engine) |
| Direction (2026-11-14) | The project lead has set the target: a modern-day, open-source competitor to the big open-world city games. The Cold War story in `docs/STORY.md` and the period setting in `docs/GDD.md` are set aside and those documents are out of date until rewritten. The first modern pieces exist: a saloon car of our own design that can be entered and driven (`drive` test passes), on a first stretch of lit road in the void |
| Awaiting the project lead | The story in `docs/STORY.md`, including its change to which year each city is set in |
| Not decided | Names of the fictional services, recruitment design (draft in review) |
| Last updated | 2026-11-14 |

### Who runs it

| Role | Who | What they do |
|---|---|---|
| Project lead | @AggrMod | Sets the direction. Makes the two judgment calls: is the look right, is it fun |
| Project manager | Jim, an AI agent working through the project lead's account | Keeps this file and the task list true, writes and maintains the standards, opens and triages issues, reviews contributions against the standards, moves the stages forward |
| Area maintainers | Contributors invited after several good contributions | Review and merge in their area (code, art, audio, writing) |

## 3. How the game begins, and how we build it

The game opens in an empty black void. In it stands one door, detailed down to the grain of the wood, the wear on the brass and the light under the gap. A voice says that if you walk in, there is no turning back.

That is also the build order. We start with nothing but the door and make it as real as we can. Then we build what is behind it, and work outward from there, one finished thing at a time. Nothing unfinished is ever on screen: where the world has not been built yet, there is void, not a grey box.

## 4. Read in this order

1. This file.
2. `docs/GDD.md`: what the game is, and `docs/STORY.md`: the story it tells (a proposal awaiting the project lead).
3. `docs/PRODUCTION-PLAN.md`: the stages and the gate for each.
4. `docs/TASKS.md`: what is open right now, and `team/README.md`: who is working on what, and how to register.
5. `CONTRIBUTING.md`: how to submit, and the licence rules.
6. The standard for your kind of work, once written: `docs/ART-BIBLE.md`, `docs/TECH-DESIGN.md`, `docs/AUDIO-GUIDE.md`. If the standard you need does not exist yet, writing it is the task.
7. `docs/research/`: background and sources, when you need the reasoning.

## 5. Rules that never bend

1. **We make our own assets, always.** Every model, texture, sound and line is made by a contributor for this project. No downloaded asset packs or libraries, nothing from any commercial game, no real brands or logos, no real living people. Fonts under the Open Font License are the one exception.
2. **No placeholders on screen.** Unbuilt space is void. A contribution is a finished thing, however small.
3. **Realistic and true to history.** True-to-life dimensions, materials and light, and true to the real place and year: a Berlin door is built the way Berlin doors were built. Check a real reference before designing; say what you could and could not confirm. People are believable without chasing photographic faces.
4. **One stage at a time.** Work on the open stage or on "open at any time" tasks. A stage opens only when the previous gate has passed.
5. **The host decides.** Game rules run on the host. A client never decides what happened.
6. **Everything is checkable.** Code comes with a test that runs without graphics. Assets come with their source, measurements and pictures. If it cannot be checked, it cannot be merged.
7. **State what you verified.** Say what you tested and what you did not. Never report something as working that you did not see work.
8. **Content rules.** Teen-level thriller; non-lethal takedowns; fictional agencies; real atrocities appear only in the history codex. See `docs/GDD.md`, section 4.

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
   - *3D assets:* real-world dimensions; texel density, triangle budget and material values within the art bible's ranges; levels of detail and collision present; source file included; pictures attached.
   - *Audio:* format, loudness and licence as the audio guide says.
   - *Writing and missions:* content rules followed; facts in codex entries sourced.
5. **In context.** Look at it in the game next to its neighbours, at eye level, in the lighting it will be seen in. An asset that passes numbers but looks wrong in place is not done.
6. **Honesty.** Does the description say what was verified? Reproduce the claim yourself.
7. **Decide.** Approve, or request changes naming the exact line of the standard that is not met. If the standard is silent or wrong, open a proposal to change the standard rather than arguing in the review.

Two judgments belong to the project lead and are made at the marked gates: whether the look is right, and whether the core game is fun.

## 8. Before you stop

- Leave the repository in a state the next arrival can pick up from this file alone.
- Section 2 is true. `docs/TASKS.md` matches reality.
- Anything half-done is either finished, or removed and described in its issue.
- Decisions you made are written where the next person will read them: the design document, the standard, or the issue. Not only in a chat or a commit message.

## 9. When something is unclear

Prefer the rule in section 5, then the design document, then the production plan. If they do not answer it, make the smallest reasonable choice, write it down in the pull request, and flag it for the maintainers. Do not invent a new direction for the game in a pull request.
