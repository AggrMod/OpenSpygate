# OpenSpygate: Game Design Document

Version 0.2, 2026-11-14. Rewritten for the direction the project lead set on 2026-11-14: a modern-day, open-world city game. Version 0.1 described a Cold War espionage game; it is in the git history, and the story proposal that went with it is in `docs/archive/cold-war/`. The research reports in `docs/research/` were written for the old plan; where this document and a report disagree, this document wins (section 13).

This document says what is decided and what is not. Where something is the project lead's call and still open, it says so. Do not fill the gaps in a pull request.

## 1. The game in one paragraph

An open-source, modern-day, open-world city game. You go on foot and in vehicles through a living fictional city, alone or with friends. The city runs by itself: traffic, people on the pavements, police who respond, shops and money. It is meant to stand next to the big commercial open-world city games, and to be built in the open by a crowd of people and AI engineers, every asset made by us.

Everything in it is original: no names, characters, maps, vehicles, missions, interface or art from any existing game, and no real brands or real living people.

## 2. Pillars

1. **A city that feels real at street level.** Kerbs, drains, signals, shopfronts, wet asphalt at night, built to true dimensions and materials. The city is judged at eye level, not from the air.
2. **Driving that feels good.** Weight, grip, sound and camera tuned until simply driving round the block is a pleasure.
3. **A systemic world, not scripted set pieces.** Traffic, pedestrians, police response and an economy make things happen without a script. The stories come from systems meeting.
4. **Every asset made by us, by script wherever possible.** Buildings, streets, props and vehicles come from generators and scripts kept in the repository, so content scales with contributors and anyone can rebuild it.
5. **Built to be modded and extended.** Text files, documented formats and small parts, so anyone can add a vehicle, a building style or a district.

## 3. The city

The city is fictional: a present-day American river-port city. Its working name is **Calder**. The name is a working title; settling it is a task (`docs/TASKS.md`). No real city is copied: real places are studied for how they are built, never reproduced.

Planned districts, built outward one finished piece at a time:

| District | What it is |
|---|---|
| Downtown | The first to be built. Street grid, towers and older commercial blocks, signals on every corner |
| The bluffs | High ground above the river: older houses and streets that climb |
| Riverfront and port | Quays, cranes, warehouses, the river itself |
| Rail yards and industry | Tracks, sheds, works, freight |
| Midtown strip | A commercial road: shops, car lots, filling stations, signs |
| Suburbs | Houses, yards, cul-de-sacs, wide arterial roads |
| The flood plain | Across the bridge: flat, low land on the far bank |

The order after downtown is not fixed. A district is added only when the one before it meets the standard, and the edge of what is built is void.

How the city is made:

- **A hand-designed street plan** with generated buildings and street dressing on it, and hand-built landmarks.
- **Generators, not hand-placed copies.** A building generator, a street and road-network builder, rule-based street furniture. Each is a script in the repository that anyone can run.
- **True to how such places are really built.** American street widths, kerb heights, lane widths, signal layouts and building types, each taken from a stated real reference.

## 4. Premise and story

**Not decided.** The premise and story are the project lead's call and are open. There is no plot, no set of characters and no factions yet, and none should be written into the game or the documents until the project lead decides.

What is decided is how the game begins (section 9). The Cold War story proposal is kept in `docs/archive/cold-war/` for the record; it is not the plan.

## 5. Content rules

- **The content rating is not decided.** It is the project lead's call. Until it is set, nothing beyond teen-level content is built: no graphic gore, no sexual content, no realistic depiction of drug use.
- Fictional city, companies, products and people. No real brands, logos, trademarks or real living people, on signs, vehicles, radio or anywhere else.
- Nothing from any commercial game: no names, places, vehicles, characters, missions or interface.
- Names on signs, plates, shops and streets are invented and checked against real organisations and brands before they go in.

## 6. Platforms and players

| | Decision |
|---|---|
| Lead platform | Windows and Linux PCs. Reference machine: GTX 1660 SUPER, Ryzen 5 4600G, 1080p at 60 fps. A PC hosts. |
| Second tier | Android tablets and phones may join at a lighter quality tier later. Not a target for stage 1. |
| Engine | Godot 4.7, with our own systems on top. See section 6.1. |
| Session size | Solo first. Friends join later (stage 5); the session size is set by measurement then. |
| Internet play | Home network first; internet play is decided in stage 5. |

### 6.1 Engine

We build on Godot 4.7 (Forward+ renderer, Jolt physics, GDScript), with our own systems on top: our own car physics, streaming, traffic and networking. The reasons:

- It runs on modest hardware, so contributors do not need an expensive PC.
- Its scenes, resources and scripts are text files, so every change can be reviewed in the open.
- It is under the MIT licence, so nothing limits what we and others do with the game.

The project lead has raised Unreal. The question is open. It will be settled by putting the same assets side by side in both engines and looking at them, not by argument. Until then, work goes into Godot, and assets are kept engine-neutral where that is cheap: Blender sources and scripts, glTF exports, real-world units.

## 7. What you do

The things to do in the city are found in stage 4 ("find the fun") on four blocks and judged by the project lead. Until then, this section lists only what the systems are, not the activities built on them.

**Second to second:** walk, run, get into a car, drive, park, get out.

**The systems that make the city run:**

| System | What it does | Stage |
|---|---|---|
| Time of day and weather | Sun, sky and street lighting through the day and night; rain later | 1 |
| Driving | Our own raycast-suspension car with a gearbox, tyre grip and sound | 1 |
| The person | Third-person character, animation, getting in and out of cars | 2 |
| Traffic | Cars on lanes, obeying signals, giving way, parking | 3 |
| Pedestrians | People on the pavements, crossing at signals, reacting | 3 |
| Police response | Officers who respond to what happens in the street | 4 or later |
| Economy | Money, buying and selling, shops | 4 or later |

## 8. Vehicles and travel

- Original vehicles only, of invented makes, with no badges from real makers and no shapes copied from real models. Proportions and dimensions are true to their class.
- Our own driving model: four suspension rays, load-limited tyre grip, a gearbox, on a plain rigid body.
- The first is a saloon (`assets/shared/vehicle/sedan_a`). More body styles are open tasks.
- Traffic follows lanes from the road network, built from the same data as the streets.

## 9. How the game begins

The game opens in an empty black void with one door, detailed down to the grain and the wear on the handle, and a voice saying that if you walk in, there is no turning back. The door opens onto the city.

The door was the first asset built and the standard for everything after it. The void-and-door scene exists; the door cannot be opened yet and the voice is not recorded. The voice line and the opening animation are open tasks.

## 10. Multiplayer

Built in this order, each on the one before:

1. **Solo.** Also the practice ground.
2. **Friends in one city,** a private session, from stage 5.

Rules: the host PC decides what really happened. No open play with strangers until the project lead decides otherwise. What modes come after that depends on the premise.

## 11. Look and sound

- **Style:** realistic. True-to-life dimensions, physically based materials (asphalt, concrete, glass, painted steel, brick), real light and shadow, by day and by night. Realistic, not uncanny: the aim is a city that looks solid and believable, not photographic human faces.
- **Level of detail:** higher than a closed studio can afford across a whole city, because every asset is its own small task with an owner, and generators carry the volume.
- **Gate:** the first downtown block, approved by the project lead on the PC, before anything else is built to that standard (stage 1).
- **Characters:** one shared skeleton, realistic proportions, modular bodies, heads and present-day clothing. Faces are believable and slightly simplified.
- **Sound:** engines, tyres and wind from our own synthesis; footsteps by surface; city ambience by district and time of day; radio stations with original idents and music only.
- **Interface:** our own design. Nothing taken from any commercial game.

## 12. Modding and extending

- Everything is text where the engine allows: scenes, resources, scripts, data.
- Generators take parameters, so a new building style or vehicle body is a new set of parameters or a new script, not a new pipeline.
- Formats are written down in `docs/TECH-DESIGN.md` as they are made.

## 13. Where this departs from the research

| Report said | This document says | Why |
|---|---|---|
| An espionage game in real cities of the twentieth century | A present-day open-world city game in one fictional American city | The project lead's direction of 2026-11-14 |
| No vehicle traffic simulation | Traffic is a core system, stage 3 | Driving and a living street are pillars |
| Avoid procedural city generation | Generated buildings and dressing on a hand-designed street plan, with hand-built landmarks | The failure case was generating the city itself with no game. Here one block is finished first, and the fun is found on four blocks before the city grows |
| Low-poly toon style | Realistic assets with physically based materials | The project lead's direction. The report's warning stands as a risk: realism is held to measurable standards in the art bible and checked in context |
| Tablets as an equal target | PC leads; tablets later, if at all | Raises the visual ceiling |
| Third-party CC0 assets | Every asset made by us | The project's own rule (`CONTRIBUTING.md`) |

## 14. Open questions

| Question | Who decides |
|---|---|
| The premise and story | Project lead |
| The content rating | Project lead |
| Godot or Unreal, settled by the side-by-side comparison | Project lead |
| The city's name ("Calder" is a working title) | Project lead, from a proposal |
| The order of districts after downtown | Project lead, from the production plan |
| Session size and internet play | Stage 5 |
| A trademark search for the name OpenSpygate (a quick web search found no game or mark with that name) | Project manager |
