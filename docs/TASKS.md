# Open tasks

The master list. Read `AGENTS.md` first. Each line becomes an issue on the repository; claim it there. Stages and gates are explained in [PRODUCTION-PLAN.md](PRODUCTION-PLAN.md).

Legend: **[first]** good first task · **[code]** · **[art]** · **[audio]** · **[writing]** · **[research]**

## Stage 0: pre-production (open now)

- [ ] **Art bible** [art] Real-world scale, material and texture standards (texel density, physically based value ranges), triangle and level-of-detail budgets, lighting setup, naming, and the full specification for the door.
- [ ] **Technical design** [code] Network messages, entity model, chunk format, save format, test harness, code style.
- [ ] **Audio guide** [audio] Formats, loudness, surface list for footsteps, music states and layers.
- [ ] **Recruitment design** [research] How spotting, developing and pitching a source should play. The research did not cover it.
- [ ] **Names** [writing] The fictional services, handler characters and vehicle makes. Must be invented and checked against real organisations and brands.
- [ ] **Licence verification** [research] [first] Confirm the terms of each source the art report marks unverified, with a link to the official text.
- [ ] **Berlin 1961-63 reference pack** [research] [first] Public-domain or openly licensed photographs of streets, shopfronts, vehicles, clothing and signage, each with source and licence. Reference only; nothing is copied into the game.

## Stage 1: foundations (opens when stage 0's gate passes)

- [ ] **Project skeleton** [code] Godot project, folder layout, quality tiers, export presets for Windows, Linux and Android.
- [ ] **Automatic checks** [code] The pull-request workflow: tests without graphics, licence-ledger check, naming check.
- [ ] **Transport layer** [code] One interface over ENet with a built-in lag and packet-loss simulator.
- [ ] **Entity registry and snapshots** [code] Stable entity IDs, spawn and despawn messages, batched per-player snapshots, late join.
- [ ] **Predicted player movement** [code] Own movement predicted and corrected by the host; other players smoothed.
- [ ] **Local network discovery** [code] Find a host on the same Wi-Fi without typing an address.
- [ ] **Multi-client test harness** [code] One host and several scripted clients on one machine, asserting they agree.
- [ ] **Benchmark scene** [code] A fly-through that logs frame rate, draw calls and memory, and fails when a budget is broken.

## Stage 2: The Door (opens after stage 1)

An empty black void, one door, a voice. The door is the first asset and the detail standard for everything after it.

- [ ] **The door** [art] Period door, frame and threshold at the highest realistic detail we can reach: wood grain, paint wear, brass handle and lock, hinges, keyhole.
- [ ] **Material and lighting setup** [code] [art] Physically based materials, the void, the light under the door, reflections.
- [ ] **The voice** [audio] [writing] The line spoken at the door, and its recording.
- [ ] **Walk up and through** [code] Player movement and camera in the void; opening the door.
- [ ] **Asset checks** [code] Automatic checks of dimensions, texel density, triangle count and material values against the art bible.

## Stage 3: through the door (opens after stage 2)

The first Berlin street corner, built outward from behind the door to the door's standard.

- [ ] **Two tenement buildings** [art]
- [ ] **Ten street props** [art] Lamppost, bench, bin, kiosk, phone booth, mailbox, advertising column, barrier, sign, tree.
- [ ] **One period sedan** [art] Invented make, no badges.
- [ ] **One pedestrian in overcoat and hat** [art]
- [ ] **Wet cobbles and sodium-lamp night lighting** [art]
- [ ] **Core play on the corner** [code] Crowd, suspicion, covers, alert tiers, escape, one photograph/bug action, debrief log.

## Open at any time

These do not depend on a stage and are needed in volume. Each has, or will have, a spec in the art bible or audio guide.

- **Street props** [art] [first] Period street furniture for each city.
- **Interior props** [art] [first] Typewriters, radios, filing cabinets, desks, lamps, telephones.
- **Period clothing pieces** [art] Coats, suits, uniforms (invented insignia), hats, bags.
- **Period vehicles** [art] Invented makes only.
- **Facade pieces** [art] Windows, doors, shopfronts, cornices, roofs, per city.
- **Sound effects recorded by you** [audio] [first] Footsteps on named surfaces, doors, switches, engines, ambience.
- **History codex entries** [writing] [first] Short, sourced, respectful notes on real places, techniques and gadgets.
- **Translations** [writing] Interface text, once it exists.
- **City research packs** [research] The same reference pack as Berlin, for Lisbon 1941, Moscow 1985, Istanbul 1943, Vienna in the 1950s and Havana 1962.

## Later stages

Stages 4 to 12 are described in the production plan. Their task lists are written when the stage before them is under way, so they reflect what was learned.
