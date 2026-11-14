# OpenSpygate

**Open Spygate International.** An open-source, open-world, multiplayer espionage game, built in the open by anyone who wants to help: people and AI engineers alike.

Everything in it is made by the project's own contributors and given away under permissive licences. Use it, copy it, build on it, sell what you make with it. We are not trying to stop anyone from doing anything; we intend to stay ahead by building faster.

You play a field officer for a fictional intelligence service in the great spy cities of the twentieth century, each in the era that made it famous: divided Berlin, wartime Lisbon, watched Moscow, crossroads Istanbul, neutral Vienna, sunlit Havana. The crowd is your cover. The verbs are real tradecraft: dead drops, signal marks, brush passes, shaking a tail, cover identities, recruiting sources, getting someone out.

**Status: pre-production.** There is nothing to play yet. The research, the design document and the production plan are written, and the first build stage is open for work.

## How it begins

The game opens in an empty black void with a single door, detailed down to the grain of the wood, and a voice saying that if you walk in, there is no turning back. That is also how we build it: the door first, then what is behind it, then outward, one finished and realistic thing at a time. Where the world is not built yet there is void, never a placeholder.

**People and AI agents: read [AGENTS.md](AGENTS.md) first.** It says where the project stands, what to do next, the standard to meet, and how to review.

## Why open

A studio can only put so many people on a game. A public repository has no such limit, as long as contributions can be checked without waiting on one person. So this project is organised around that:

- **Small, self-contained tasks.** A building, a prop, a car, a pedestrian outfit, a mission, a sound, a translation. See [docs/TASKS.md](docs/TASKS.md).
- **Written standards.** The art bible and technical design say exactly what "done" means for each kind of contribution.
- **Automatic checks.** Every pull request runs tests, a licence check and performance budgets. A contribution that passes and matches the standard gets merged.
- **Everything is our own.** Every model, texture, sound and line is made by contributors for this project. Nothing from any commercial game, and no downloaded asset packs.

## Read first

| Document | What it is |
|---|---|
| [AGENTS.md](AGENTS.md) | Start here: current state, rules, workflow, review standard |
| [docs/GDD.md](docs/GDD.md) | The game design: pillars, loops, the Exposure system, the worlds |
| [docs/PRODUCTION-PLAN.md](docs/PRODUCTION-PLAN.md) | The build stages and the quality gate for each |
| [docs/TASKS.md](docs/TASKS.md) | What is open to pick up right now |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute, and the rules on licences and originality |
| [docs/research/](docs/research/) | The research behind the design |

## Technology

- Engine: [Godot 4.7](https://godotengine.org) (GDScript, text scene files). Game systems are our own code on top.
- Art: realistic 3D assets with physically based materials, made in Blender, with source files kept in the repository.
- Platforms: Windows and Linux PCs lead; Android tablets and phones join the same sessions at a lighter quality tier.
- Multiplayer: the host decides what really happened; 1 to 6 players per city at first.

## Licence

- Code: [MIT](LICENSE).
- Art, audio, writing and design documents: [CC BY 4.0](LICENSE-ASSETS.md). Credit "the OpenSpygate contributors" and do what you like.
- Fonts are the only third-party files accepted, under the SIL Open Font License, and are listed in `assets/LICENSES.csv`.
