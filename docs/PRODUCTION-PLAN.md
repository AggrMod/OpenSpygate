# OpenSpygate: Production Plan

Version 0.2, 2026-11-14. Companion to `GDD.md`. Replaces version 0.1, which planned a Cold War game starting in Berlin; that plan is in the git history.

## How this is run

- **Stages with gates.** A stage ends when its gate is passed, not on a date. Quality decides.
- **One finished piece at a time.** The city grows outward from one block. Each piece is finished to the standard before the next is started. Where nothing is built, there is void.
- **Pipelines before volume.** Buildings, streets, props and vehicles come from scripts and generators, so each new block and district reuses the machinery. Stage 6 turns them into tools that grow the city.
- **No placeholder art.** Every build uses real, if few, assets.
- **Everything tested.** Each system has a self-playing test that writes `result.json` and pictures. Rules that run on the host are tested without graphics. Multiplayer tests run a host and several clients on one PC with simulated lag and packet loss.
- **Review gates.** Every asset gets a turntable picture and an in-game street-level picture, by day and by night, checked next to its neighbours before it goes in. The project lead approves the look and judges the fun at the marked gates.
- **Our own assets.** Every asset is made by the project's contributors and released under permissive licences. No downloaded asset packs. Fonts under the Open Font License are the one exception and are logged in `assets/LICENSES.csv`.
- **Open contribution.** Work is split into small tasks with written standards and automatic checks, so many people can build in parallel. See `TASKS.md` and `CONTRIBUTING.md`.

## Stages

| # | Stage | What gets built | Gate |
|---|---|---|---|
| 0 | Direction | The direction written down: design document, this plan, the task list, `AGENTS.md`. Done by the rewrite of 2026-11-14, apart from the open decisions (premise, content rating, engine, the city's name) | Done. The open decisions are tracked in `GDD.md`, section 14, and do not hold up stage 1 |
| 1 | The first block | One downtown block you can walk and drive round, by day and night, with sound, at final quality: street, kerbs, pavements, signals, street furniture, buildings from the generator, the saloon car, a time-of-day sky and street lighting, engine, tyre, wind and city sound. Plus the foundations it needs: automatic checks on every pull request, a frame-rate and memory benchmark on the block | **The project lead approves the look on the PC.** If not, it is reworked until it is right. Holds 60 fps on the reference PC *(start)* |
| 2 | The person | A third-person character of our own on one shared skeleton, with walking, running and turning animation, and getting in and out of cars properly (door opens, the character sits, the door closes) | The character walks the block and gets in and out of the car without visible popping or sliding, checked in self-playing test pictures and by the project lead |
| 3 | The living street | Traffic on lanes that obeys the signals and gives way, pedestrians on the pavements who cross at signals, parked cars | A 10-minute self-playing run on the block with no collisions between traffic, no pedestrian walking through a car or wall, and frame rate held on the reference PC |
| 4 | Find the fun | Four blocks, and a small set of things to do on them. What those things are is found here, by building and playing | **The project lead judges whether it is fun.** If not, the set changes until it is |
| 5 | Multiplayer foundation | Host-decides networking skeleton, a lag and packet-loss simulator, a multi-client test harness, friends in one city | A host and two clients stay in agreement at 150 ms lag and 5% loss, on foot and driving, in a self-playing network test |
| 6 | The district pipeline | Tools that grow the city block by block: the street plan as data, the building generator driven by it, rule-based street dressing, chunk streaming, navigation and traffic lanes from the same data | A generated block is indistinguishable in quality from the hand-finished first block, and a new block can be added from data alone |
| Later | The city | More districts (the bluffs, riverfront and port, rail yards and industry, midtown, suburbs, the flood plain), more vehicles, interiors, the story once the premise is decided | Each district passes the same gates as stages 1 and 6 |

Numbers marked *(start)* are starting values, measured and corrected when the stage runs.

## Biggest risks

| Risk | What guards against it |
|---|---|
| The look disappoints | Stage 1 gate: one block at final quality, approved by the project lead, before any volume of city is made |
| Realistic detail is too heavy for the hardware | Measured on the first block; levels of detail and texture tiers on every asset; budgets enforced by the benchmark |
| Realistic assets vary in quality between contributors | Measurable standards in the art bible, sources and scripts required, in-context review by day and night |
| Generated buildings and streets look repetitive | Hand-designed street plan, hand-built landmarks, per-district building mix, review of whole blocks, not single buildings |
| The game isn't fun | Stage 4 gate before the city is grown |
| The engine question stays open too long | Settled by a side-by-side comparison of the same assets; assets kept engine-neutral where cheap |
| Netcode instability | Only your own movement is predicted; everything else is confirmed by the host; lag simulator in every multiplayer test |
| Scope drift | A stage's gate must pass before the next stage starts |
| Something real or copied slips in | Review step 2 (origin) in `AGENTS.md`; every name checked against real brands and places |

## What happens next

Stage 1 is open. Its first pass was merged on 2026-11-15: a 2 x 2 block street grid with a time-of-day sky, a procedural building generator, a reworked car body, and engine, tyre and wind sound. It is not at the gate yet. The follow-ups and the rest of the stage 1 tasks are in `TASKS.md`.
