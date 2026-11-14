# Spycraft International: Production Plan

Version 0.1, 2026-11-14. Companion to `GDD.md`.

## How this is run

- **Stages with gates.** A stage ends when its gate is passed, not on a date. Quality decides.
- **Pipelines before content.** Buildings, streets, props, people and vehicles come from generators, so each new district and city reuses the machinery.
- **No placeholder art.** The first playable build already uses real, if few, assets.
- **Everything tested.** Each system has a self-playing test that writes pictures and result files. Rules run on the host and are tested without graphics. Multiplayer tests run a host and several clients on this PC with simulated lag and packet loss.
- **Review gates.** Every asset gets a turntable picture and an in-game street-level picture, checked next to its neighbours before it goes in. The project lead approves the look at the marked gates.
- **Licence ledger.** Every outside file is logged in `assets/LICENSES.csv` with source, licence and checksum. Only CC0 and similarly open licences are allowed.
- **Open contribution.** Work is split into small tasks with written standards and automatic checks, so many people can build in parallel. See `TASKS.md` and `CONTRIBUTING.md`.

## Stages

| # | Stage | What gets built | Gate |
|---|---|---|---|
| 0 | Pre-production | Research (done), design document (done), this plan (done), art bible, technical design | The project lead has read the design and agrees with the direction |
| 1 | Foundations | Godot project, git with automatic checks on every pull request, host-decides networking skeleton with lag simulator, test harness, quality tiers, benchmark scene | Two clients and a host stay in agreement at 150 ms lag and 5% loss; benchmark numbers recorded on the PC and a tablet |
| 2 | The Door | An empty black void, one door at the highest realistic detail we can reach (wood grain, worn brass, light under the gap), the voice, and walking up to it and through. Sets the detail standard, the material and lighting setup, and the asset checks | **The project lead approves the door.** If not, it is reworked until it is right |
| 3 | Through the door: find the fun | The first Berlin street corner built outward from behind the door, to the door's standard: 2 buildings, about 10 props, 1 car, 1 person, wet cobbles, night lighting. On it: player movement and camera, a crowd, suspicion meters, 3 covers and the spaces they fit, the six alert tiers, shaking pursuit, one photograph/bug action, the debrief log | A 10-minute operation on one block is fun to replay, by the project lead's judgment, and holds frame rate on the reference PC |
| 4 | Character pipeline | Scripted modular people on one skeleton, period wardrobe, faces, animation library, crowd levels of detail | 40+ distinct pedestrians pass the review gate; the first is approved by the project lead before the rest are made |
| 5 | City pipeline | Facade kit (50 to 70 pieces), building generator, road-map-driven streets, navigation, minimap, rule-based street dressing, chunk streaming | A generated block is indistinguishable in quality from the first corner |
| 6 | Berlin, district 1 | The checkpoint district, about 600 m square: 120 to 250 buildings, 3 landmarks, 4 to 6 interiors, day and night | Walk the whole district at 60 fps on the PC and 30 on a tablet with no visible repetition problems |
| 7 | Tradecraft and missions | Dead drops, signal sites, brush passes, detection routes, sources, exfiltration, the bridge swap; mission scripting; the first chain of 6 to 8 operations | The chain is playable start to finish solo |
| 8 | Co-op | 2 to 4 players in free roam and operations, late join, saved drops and marks | A full operation completed by a PC and two tablets together |
| 9 | Vehicles and traffic | Car generator (8 to 10 period types), arcade handling, lane traffic, trams, chases, vehicle tailing | A car chase across the district works in multiplayer without visible disagreement between devices |
| 10 | Sound, voice, interface | Adaptive music, ambience, footsteps, voiced briefings, dossier menus, map, gadget wheel, credits and licences screen | Full pass with no missing sounds or unfinished screens |
| 11 | Berlin complete | Districts 2 to 5, the wiretap-tunnel and sector-crossing operations, hidden-agent rounds, two-service free roam | Berlin is a finished game on its own |
| 12 | World 2 onward | Lisbon, then Moscow, Istanbul, Vienna, Havana. Each needs a new facade kit, landmarks, palette, wardrobe, ambience, music and missions; about 60% of everything else is reused | Per world, the same gates as stages 6, 7 and 11 |

## Biggest risks

| Risk | What guards against it |
|---|---|
| The look disappoints | Stage 2 gate (the door) before any volume of art is made |
| Realistic detail is too heavy for the hardware | Measured on the door and the first corner; levels of detail and texture tiers on every asset; budgets enforced automatically |
| Realistic assets vary in quality between contributors | Measurable standards in the art bible (dimensions, texel density, material ranges), source files required, in-context review |
| The core isn't fun | Stage 3 gate before the city is built |
| Tablet speed | Benchmark in stage 1; quality tiers; budgets enforced by an automatic fly-through test |
| Netcode instability | Only your own movement is predicted; everything else is confirmed by the host; lag simulator in every multiplayer test |
| A generated city feels repetitive | Hand-designed street plan, landmarks, per-district building mix, hand-placed story spots |
| Scope drift | A stage's gate must pass before the next stage starts |

## What happens next

Stage 0 finishes with two short documents: the art bible (real-world scale, material and texture standards, lighting setup, the specification for the door) and the technical design (network messages, entity model, chunk format, test harness). Then stage 1 starts.
