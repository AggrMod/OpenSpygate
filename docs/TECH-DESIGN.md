# Technical Design

> **Direction change, 2026-11-14.** OpenSpygate is now a modern-day, open-world city game (`docs/GDD.md`). For this document that means: the ground rules, code style, testing, saving and quality tiers stand. The espionage systems (suspicion, alert tiers, cover burn, tradecraft, missions) are gone from the layout; the planned systems are traffic, pedestrians, police response and the economy. Networking (section 4) is the design for stage 5, not for stage 1. The engine stays Godot 4.7 while the Unreal question is open (`docs/GDD.md`, section 6.1). The layout in section 2 is the target; what exists today is `autoload/`, `actors/player/`, `actors/vehicle/`, `audio/vehicle/`, `worlds/void/`, `worlds/city/` and `tests/auto/`.

Version 0.1, 2026-11-14. The standard all code is reviewed against. It is built from `docs/research/03-tech-and-netcode.md`; where they differ, this document wins.

Numbers marked *(start)* are starting values, to be measured and corrected as the stages run.

## 1. Ground rules

1. **Godot 4.7, GDScript, text files only.** Scenes are `.tscn`, resources are `.tres`. No binary scene or resource files, so every change can be read in a pull request.
2. **The host decides.** One process is the authority for everything that matters to the game. Clients send what the player wants to do; the host says what happened.
3. **Logic is separate from presentation.** Game rules live in plain scripts under `sim/` that need no scene tree, no rendering and no real clock. They are what the tests run.
4. **Deterministic where it is cheap.** Anything every device can compute from a seed and the host's clock is computed locally and never sent.
5. **Nothing depends on one machine.** No absolute paths, no installed-tool assumptions beyond the engine version.
6. **One engine version per stage.** Currently 4.7.2. Upgrades are their own pull request.

## 2. Project layout

The Godot project lives in `game/`. Asset sources (Blender files, scripts, review pictures) live in `assets/` at the repository root; only exported files are copied into `game/assets/`.

```
project.godot
autoload/
  game.gd          session state, world switching, save and load
  net.gd           transport, discovery, protocol gate, clock
  replication.gd   entity registry, spawn and despawn, snapshots
sim/               rules with no scene tree: testable without graphics
  crowd/           pedestrians from seed and time
  traffic/         lanes and vehicles from seed and time
  police/          police response
  economy/         money, prices, shops
actors/
  player/  npc/  vehicle/
worlds/<world>/    world.tres, chunks/, roads.tres, nav/
streaming/         chunk loading
ui/
assets/            see the art bible, section 7
tools/             build, check and review scripts
tests/
  unit/            sim tests, no graphics
  auto/            self-playing scenarios
  net/             multi-client scenarios
```

## 3. Code style

- Static typing everywhere: typed variables, parameters and return values. `class_name` for anything used from another file.
- Names: `snake_case` for files, functions and variables; `PascalCase` for classes; `ALL_CAPS` for constants; signals in past tense (`door_opened`).
- One class per file. A file over 400 lines is a sign it should be split.
- No magic numbers in rules: tunable values live in `.tres` resources under `sim/<system>/tuning/`.
- Comments say why, not what.
- Game rules never call `get_tree()`, never read `Time` directly, and never use unseeded randomness. They take a clock and a random source as arguments.
- Client code never changes authoritative state. If `multiplayer.is_server()` is false, a script may predict its own player's movement and nothing else.

## 4. Networking

### 4.1 Authority

| Mode | Use |
|---|---|
| Listen host | Home play. A PC runs the game and is the host. A tablet or phone never hosts |
| Headless server | More than four players, or internet play. Same code, no window |

Both are the same code path: the host is whoever `multiplayer.is_server()` is true for.

### 4.2 Transport

`net.gd` wraps a `NetTransport` interface so the wire can be swapped without touching the game.

| Transport | Status |
|---|---|
| ENet | First and default |
| Loopback with simulated lag and loss | Built with the first; used by every network test |
| Epic Online Services peer-to-peer, WebRTC | Later, behind the same interface |

- Default port 47800 *(start)*. Tests use their own ports and their own discovery tag, so a test can never join a real game.
- **Protocol gate:** a `PROTO` number is part of the discovery message and the handshake. Builds with different numbers never join each other. Any change to a message bumps it.
- **Discovery:** the host announces itself on the local network by UDP broadcast, plus a sweep of the local subnet for devices that drop broadcasts. Joining needs no typed address.

### 4.3 Time

- Simulation tick: 60 per second, fixed.
- The host owns `server_tick`. Clients estimate it from round-trip time and smooth their estimate.
- Snapshots from host to client: 20 per second to PCs, 15 to tablets *(start)*.
- Inputs from client to host: every tick, batched, with the last few repeated in each packet so a lost packet costs nothing.

### 4.4 Entities

- Every networked thing has a stable `entity_id` (unsigned 32-bit) given by the host. Nothing is addressed by node path.
- The entity registry in `replication.gd` maps `entity_id` to node on every device.
- Spawning and despawning are our own reliable messages: `spawn(entity_id, type_id, state)` and `despawn(entity_id)`. The engine's MultiplayerSpawner and MultiplayerSynchronizer are not used for game entities.

### 4.5 Messages

| Message | Direction | Delivery | Content |
|---|---|---|---|
| `hello` | client to host | reliable | protocol number, player name, quality tier |
| `world_snapshot` | host to client | reliable | world, seed, tick, all entities in range, persistent edits |
| `ready` | client to host | reliable | client has loaded and applied the snapshot |
| `input` | client to host | unreliable | tick, movement, look, held actions; last 3 repeated |
| `snapshot` | host to client | unreliable | tick, last input tick processed, packed states of entities in the client's cells |
| `spawn` / `despawn` | host to client | reliable | see 4.4 |
| `action_request` | client to host | reliable | "I want to do X to entity Y" |
| `action_result` | host to client | reliable | what happened |
| `event` | host to client | reliable | changes every player must see at once: time of day, police response, world state |

- Snapshots are one packed byte array per client per send: positions as 16-bit integers relative to the cell, angles as one byte.
- A client is added to the snapshot stream only after its `ready`.

### 4.6 Movement and smoothing

- **Your own player:** predicted on your device, corrected by the host. The client keeps its unacknowledged inputs and replays them when a correction arrives.
- **Everyone and everything else:** shown about 100 ms in the past, interpolated between two snapshots.
- **Actions** (open a door, get into a car, buy something) are never predicted. The client plays a short wind-up while it waits for `action_result`.
- **Looking back in time:** the host keeps one second of position history, so a collision or a sight check is judged from what that client was actually seeing.

### 4.7 Interest

Each world is a grid of 96 m cells *(start)*. A client receives entities in the 3 by 3 cells around its player, and mission-critical entities always. Far entities update at a lower rate.

### 4.8 Crowds and traffic

- Ambient pedestrians and vehicles are a pure function of `(world seed, agent id, server_tick)`: which path they are on and how far along. Every device computes them; nothing is sent.
- The function uses integer steps and path parameters, never physics, so PCs and tablets agree.
- An agent that a player disturbs (bumped, alerted, followed, spoken to) is **promoted**: the host takes it over as a normal entity until it calms down and rejoins its schedule.
- Police, and anyone a player is dealing with directly, are always host entities.
- The host sends a checksum of the ambient state every few seconds; a client that disagrees resynchronises.

### 4.9 Vehicles

Our own arcade car (ray casts for suspension, no engine vehicle body). The driver's device simulates its car and reports it; the host checks speed and position limits; everyone else sees it interpolated. Changing driver is an explicit hand-over.

## 5. Worlds, chunks and streaming

- Each world lives in `worlds/<world>/` with a `world.tres`: seed, grid, chunk list, road graph, spawn points, travel points.
- A chunk is a `.tscn` covering a 96 m square *(start)*: static meshes, collision, a navigation piece, markers. Chunks never reference each other.
- Clients load the chunks around their player with threaded loading and add a limited number of nodes per frame. The host loads collision and navigation for the chunks around every player.
- **The void rule:** where no chunk exists, nothing is drawn and nothing is loaded. The world's edge is void, not a wall. The void with the door is its own world; the city is the world the game starts in.
- Navigation is baked per chunk with a shared border so neighbours join. A test paths across every chunk border.
- One world is loaded at a time on a client. Travel between worlds: request, host checks, unload, load, `ready`, snapshot.

## 6. Saving

- The host writes the save. Clients keep only their own settings.
- Versioned JSON, one file per profile, plus one per world for its persistent state.
- World state is stored as **edits on top of the seed** (a car parked, a door opened), never as a copy of the world.
- Every save has a `version` field and a migration function per version.

## 7. Quality tiers

| Tier | Renderer | Target |
|---|---|---|
| High | Forward+ | Reference PC (GTX 1660 SUPER), 1080p, 60 frames per second |
| Medium | Forward+ with reduced settings, or Mobile | Weaker PCs |
| Low | Mobile, or Compatibility where needed | Tablets and phones, 30 frames per second |

- Tiers change texture size, level-of-detail distance, shadow and reflection quality, crowd density and draw distance. They never change game rules or what the host decides.
- Which renderer the Low tier uses is decided by a benchmark on real tablets, if and when tablets become a target.

### Budgets *(start)*

| | High | Low |
|---|---|---|
| Draw calls | 2,000 | 300 |
| Visible triangles | 3,000,000 | 300,000 |
| Skinned characters | 30 | 8 |
| Texture memory | 3 GB | 1 GB |

The benchmark scene fails the build when a budget is exceeded.

## 8. Testing

1. **Unit tests** for everything in `sim/`: no window, no scene tree, fixed seed, fake clock.
2. **Self-playing scenarios** (`tests/auto/`): the game plays a script and writes pictures and a result file. Run as `godot --path . -- --auto=<name> --out=<dir>`.
3. **Network scenarios** (`tests/net/`): one host and several scripted clients on one machine, through the loopback transport at 150 ms and 5% loss. They assert that positions converge, that a late joiner's world matches the host's, and that ambient crowd checksums agree.
4. **Performance:** a camera fly-through logging frame time, draw calls and memory against the budgets.
5. **Asset checks:** the measurements listed in the art bible, section 9.

Rules for tests:

- A test passes by writing a result file that says so. Process exit codes are not trusted: the engine can exit cleanly after a failure.
- Tests use their own ports and discovery tag.
- A bug fix comes with the test that would have caught it.
- Every pull request runs the unit tests, the network scenarios and the asset and licence checks.

## 9. Tools

- `tools/check` runs everything a pull request runs, locally, with one command.
- `tools/review` renders the review pictures the art bible asks for.
- Tools are scripts in the repository (GDScript, or Python 3 for Blender work). They take paths as arguments and write only where they are told.

## 10. What is deliberately left out for now

- Rollback netcode: only the player's own movement is predicted.
- Dedicated matchmaking, accounts, anti-cheat beyond the host's checks.
- More than one world loaded at once.
- Voice chat.

## 11. Open questions

- Whether the Compatibility renderer honours occlusion culling, and Mobile renderer speed on tablets (a tablet benchmark, when tablets become a target).
- Whether to adopt an existing prediction library or keep our own small one (decide in stage 5, the multiplayer foundation).
- The character skeleton and animation set (decided in stage 2, the person; the first block needs only the first-person player).
- Godot or Unreal: open, settled by the side-by-side comparison (`docs/GDD.md`, section 6.1).
