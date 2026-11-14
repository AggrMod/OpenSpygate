# 03 — Technology & Netcode Research: Spycraft International

*Prepared 2026-11-14. Original open-world, multiplayer, third-person espionage game, built by one AI developer for a hobbyist.*

**Evidence labels used in this report**

- **[LOCAL]** I checked it on this PC with read-only commands.
- **[WEB]** I read it online. A URL is given, and the full list is in §9.
- **[JUDGEMENT]** This is my engineering opinion or recollection, and I did not verify it during this session.

---

## 0. TL;DR recommendation

**Build on Godot 4.7.2, using GDScript and text-only `.tscn` and `.gd` files.**

- The server is authoritative. The PC is the host, either as a listen host or as a headless server process.
- Wi-Fi discovery and the test harness should be copied from our earlier Godot tablet project. Its trust model should not be copied (see §2.1).
- Start on the **GL Compatibility** renderer, because that is what already runs on the test tablets. In week 1, benchmark the **Mobile** renderer on the real tablets.
- Each city is its own world of streamed chunks.
- Crowds and traffic run deterministically on every client from a shared seed and the server clock. Only the NPCs that players disturb get replicated.
- For friends over the internet, use **Tailscale** first, then **noray** or **EOS** if needed.
- Unreal 5.8 and a web stack both lose here. The reasons are disk space, Android support, and iteration speed for a developer who never clicks in an editor (see §1).

---

## 1. PC facts found locally [LOCAL]

| Item | Finding |
|---|---|
| GPU | **NVIDIA GTX 1660 SUPER** (6 GB GDDR6 per the card spec). WMI reports 4 GB because its 32-bit `AdapterRAM` field under-reports, so ignore that figure. Driver 32.0.16.1088. The CPU also has AMD Radeon integrated graphics. |
| CPU / RAM | AMD Ryzen 5 4600G (6 cores, 12 threads), 31.4 GB RAM |
| **C: free** | **21.4 GB free** (454.5 GB used). This is nearly full. |
| **D: free** | **112.8 GB free** (6.3 GB used). This is the drive to use for the project, caches and exports. |
| E: | Reports 0 GB free and 0 GB used. It is probably empty media or an unmounted drive, not a full disk. |
| Godot | `godot.exe` / `godot_console.exe` were installed by WinGet (on C:). `--version` → **4.7.2.stable.official.ed1daf0bf** |
| Godot export templates | `%APPDATA%\Godot\export_templates\4.7.2.stable\` holds the **full set**: android_debug/release.apk plus android_source.zip (Gradle builds), Windows, Linux (x86_64/arm64 and others), web (threads, nothreads and dlink variants), macOS and iOS. |
| Android toolchain (Godot) | Editor settings point at JDK `C:\Program Files\Microsoft\jdk-21.0.8.9-hotspot\` and SDK `the user-profile Android SDK folder`. `adb` is available from the scrcpy WinGet package. `ANDROID_HOME` is not set. |
| Unreal | `C:\Program Files\Epic Games\UE_5.8`, Build.version **5.8.4** (CL 58902052). It takes **29.9 GB of C:**. `Engine\Platforms\Android` exists but `Engine\Binaries\Android` does not, so Android target support **appears not to be installed**. Adding it would be another multi-GB download onto C:. |
| Blender | WSL: **Blender 4.2.3 LTS** at `~/.local/bin/blender` |

### What our earlier Godot tablet project proves works on this hardware [LOCAL]

our earlier Godot tablet project is at a private repository, and its last commit is "Build 13".

- **Engine and renderer.** It uses Godot 4.7 with the `gl_compatibility` renderer on both desktop and mobile (`renderer/rendering_method.mobile="gl_compatibility"`). It also enables ETC2/ASTC texture import and runs physics at 60 ticks per second.
- **Android export.** It exports an **arm64-v8a-only** signed APK of **46.9 MB**. Gradle builds are off. The export requests internet, network-state, wifi-state and `change_wifi_multicast_state` permissions. Its landscape orientation is 6.
- **Networking (`scripts/net/net.gd`).**
  - Peers talk over **ENetMultiplayerPeer**.
  - Each game finds the others through UDP beacons on port 47777. Every beacon goes to the 255.255.255.255 broadcast address, to a rolling unicast sweep of the /24 subnet (because "some tablets drop broadcasts"), and to 127.0.0.1 for same-PC testing.
  - Whichever game has built more (the "fuller world") hosts. Ties go to the lower random id.
  - `create_server(GAME_PORT, 6)` allows at most 6 peers.
  - A `PROTO` constant is baked into the beacon's magic string, so builds with different protocols never join each other.
  - The world comes from a shared seed. A joiner receives only the edits (`_world.rpc_id`).
  - Each player's own state goes out as `@rpc("any_peer","unreliable_ordered")` at **15 Hz**. Edits, blocks and mod events go out as reliable `any_peer` RPCs.
  - It uses **no MultiplayerSynchronizer or MultiplayerSpawner** at all.
- **Tests.** Self-playing scripts (`tests/auto_*.gd`) run with `godot --path . -- --auto=<name> --role=host|guest --out=<dir>`. They use separate test ports (47787/47788 and 47991 bound to 127.0.0.1), so a test can never join the real tablets. The network tests run two real game processes on one PC.

**Lesson:** the pieces to reuse are LAN discovery, the protocol-version gate, the shared-seed world, the host/guest test harness, the Compatibility-renderer APK pipeline, and the Android permissions. the earlier project's netcode is **client-trusted peer-to-peer co-op**: any peer may assert its own state and edits. That model is wrong for an espionage game. Detection, "who saw whom", stolen documents and PvP all need one authority (see §2).

---

## 2. Engine comparison for this project and this hardware

| Criterion | **Godot 4.7.2** | **Unreal 5.8.4** | **Web (three.js / Babylon)** |
|---|---|---|---|
| Open-world streaming | Nothing built in. You write chunk streaming yourself with `ResourceLoader.load_threaded_request` (see §4). Visibility ranges/HLOD are built in. [WEB] | World Partition, HLOD, PCG, and 5.8 terrain and vegetation tools are excellent. [WEB] | All manual. A three.js showcase author explicitly avoided infinite tiled worlds and dynamic culling. [WEB] |
| Third-person controller | `CharacterBody3D` plus a SpringArm camera. our earlier Godot tablet project already has `player.gd` and `cam_rig.gd`. [LOCAL] | Template plus CharacterMovementComponent, with built-in networked prediction. This is UE's strongest point. | Write it yourself, or use Rapier or cannon-es. |
| Vehicles | `VehicleBody3D` (raycast wheels). Jolt has been the default 3D physics for new projects since 4.6. Forum reports show sync issues; see §2.6. [WEB] | Chaos Vehicles plus Mover/replication. Mature but heavy. | Rapier's vehicle controller. |
| Crowds | MultiMesh plus your own simulation, or a handful of skinned NPCs near the player. | Mass Entity and City Sample–class tech. It is far too heavy for a 1660 SUPER plus tablets. | InstancedMesh; okay. |
| Navigation | NavigationServer3D. Chunks merge on exactly matching edge vertices or within an edge-connection margin. An official nav-chunks demo exists. [WEB] | Recast, with World Partition nav streaming. Excellent. | recast-navigation-js; workable. |
| Android export | **Proven on this PC**: a 46.9 MB arm64 APK, templates installed. [LOCAL] | Android binaries appear not installed. The SDK/NDK setup is heavy. Empty-project APKs historically run about 40–150 MB. Mid-range tablets are a poor fit for UE5 visuals. [LOCAL]/[WEB] | It runs in Chrome. WebGPU needs Vulkan-capable devices, and three.js's WebGPU path is still maturing (r182 regressions). [WEB] |
| Build size / disk | The editor is about 100 MB and the project cache is small. It fits easily on D:. | 29.9 GB already on a C: drive with 21.4 GB free. The DDC/shader cache and intermediate files add **tens of GB per project**. [LOCAL]/[JUDGEMENT] | Tiny. |
| Code-driven iteration (no editor clicks) | **Best.** `.tscn`/`.tres`/`.gd` are plain text, `--headless --script` and `--export-release` work from the command line, and edit-run takes seconds. our earlier Godot tablet project was built this way. [LOCAL] | Poor for an AI developer. Blueprints and `.uasset` files are binary. C++ rebuilds and shader compiles take minutes on a 4600G, and many workflows assume editor clicks. | Good (text plus hot reload), but you must build an engine first. |
| Headless/automated testing | `--headless` and dedicated-server export, with GdUnit4 and GUT available. Several runs fit on one PC (our earlier Godot tablet project does it already). [WEB]/[LOCAL] | Gauntlet and `-nullrhi` dedicated servers exist, but they are heavy to run on this machine. | Playwright plus Node; good. |
| Networking out of the box | ENet, WebSocket and WebRTC peers. RPCs plus MultiplayerSynchronizer/Spawner. **No built-in prediction or lag compensation.** netfox fills that gap. [WEB] | Best in class: replication graph, Iris, and prediction for characters. | None. You write your own (WebSocket/WebRTC, Colyseus and so on). |
| Fit for "one AI dev + hobbyist + tablets" | **High** | Low | Medium–low |

**Recommendation: Godot 4.7.2.** Unreal would deliver its quality only on the PC. It cannot share a game with mid-range tablets at acceptable cost, it fights the disk situation, and binary assets block a text-only workflow. A web stack would mean building an engine, and it has no proven open-world path. Godot already has a working tablet pipeline on this PC.

**Settings for the new project [JUDGEMENT]:**

- Create the project on **D:** (the data drive). Keep it off the nearly full system drive.
- Use Jolt physics, the default for new 4.6+ projects. [WEB]
- Turn on physics interpolation. 3D interpolation exists since 4.4: move objects only in `_physics_process`, and call `reset_physics_interpolation()` after teleports. [WEB]

### 2.1 Authority model

| Model | Pros | Cons | Verdict |
|---|---|---|---|
| Dedicated authoritative server (`--headless`, or a dedicated-server export with the `dedicated_server` feature tag [WEB]) | One truth, cheat-resistant. It can run on the PC alongside a PC client. | Needs a machine running. | **Use for sessions of 4 or more players, and for internet play.** |
| **Listen server on the PC** (the host is also a player) | Simplest. One process. | The host has zero latency, which is unfair for PvP. If the host quits, the session ends. | **The default for home play.** Bias host election so the PC always wins, which flips the earlier project's "fullest world" rule, and so a tablet never hosts. |
| Peer-to-peer, client-trusted (our earlier Godot tablet project) | No host load. | Any peer can lie, and peers disagree about detection. | **Reject** for espionage. |
| Relay (Steam, EOS, noray relay, TURN) | Gets through NAT. | It is only a transport; one peer must still be the authority. | Transport layer only (see §3). |

**Write all code as server-authoritative from day one.** In Godot, the listen-host and dedicated-server cases are the same code path, since `multiplayer.is_server()` is true for both.

### 2.2 Prediction, reconciliation and interpolation

- **Own character (the local player):** client-side prediction with server reconciliation. Each client sends an input frame stamped with a tick number. The server simulates it and returns `(tick, position, velocity, state)`. The client replays its unacknowledged inputs. **netfox** (MIT) provides exactly this through `RollbackSynchronizer`, plus network time/ticks and `netfox.noray` for NAT. [WEB] Decide early between adopting netfox and writing a small custom version (about 400 lines).
  - [JUDGEMENT] For a third-person stealth game, a light custom version is enough: predict movement only, and keep actions such as "take photo" and "pick lock" server-confirmed.
- **Remote players and NPCs:** snapshot interpolation. Render them about 100 ms in the past, between two buffered snapshots. Extrapolate for at most one snapshot when packets drop.
- **Lag compensation:** keep a short history (about 1 second) of other players' positions on the server. When someone shoots or takes a photo, or a guard runs a line-of-sight check that involves a player, rewind to that client's view time.
- **Tick rates [JUDGEMENT]:**
  - Physics at **60 Hz** (as in our earlier Godot tablet project).
  - Network snapshots at **20 Hz** to the PC and **15 Hz** to tablets, which matches the earlier project's proven 15 Hz.
  - Client input sent at 30–60 Hz, batched.
  - Distant entities updated at 2–5 Hz (see interest management below).

### 2.3 Interest management

- MultiplayerSynchronizer sends to **all peers by default**. Per-peer control exists through `set_visibility_for` and `add_visibility_filter`, re-evaluated per idle frame, per physics frame or manually. Godot has **no hierarchical or spatial interest management**, and filter cost grows as synchronizers × peers. [WEB]
- **Plan [JUDGEMENT]:**
  - Divide each city into a grid of 64–128 m cells. Each peer subscribes to the 3×3 or 5×5 cells around it.
  - The server sends one custom **batched snapshot per peer per tick** as a single unreliable RPC carrying a `PackedByteArray`.
  - Use MultiplayerSynchronizer only for a few low-rate, reliable properties, or not at all, as our earlier Godot tablet project already does.
  - Godot RPCs encode Variants, so quantise positions to int16 per cell and angles to a byte.

### 2.4 MultiplayerSpawner pitfalls (why to prefer explicit spawn RPCs) [WEB]

Forum threads report these problems:

- A custom `spawn_function` fails for late joiners after the spawner has already spawned something (seen in 4.5.1).
- Clients log `get_node: Node not found` when they join mid-game, because a synchronizer updates a node that has not yet spawned on the late joiner.
- The spawner only replicates children of its spawn path.
- Authority set at spawn time can be wrong for late joiners.
- Synchronizers are delta-based, so a late joiner misses any value that has not changed since.

**Mitigation:**

1. Send each new peer a full `world_snapshot` RPC, as the earlier project's `_world.rpc_id` already does.
2. Wait for that peer's "loaded" acknowledgement.
3. Only then add the peer to the replication set.
4. Spawn entities through your own `spawn(entity_id, type, state)` RPC, keyed by a stable `entity_id` rather than a node path.

### 2.5 Crowds and traffic: deterministic local simulation vs replication

- **Ambient pedestrians and traffic are simulated deterministically on every client.** The inputs are the world seed, the server's shared clock (`server_time`) and the road/sidewalk graph. Each agent's state is a pure function of `(seed, agent_id, t)`: which spline it is on and where along it. Nothing goes over the network. This extends the earlier project's shared-seed idea. [JUDGEMENT]
- **Any agent a player disturbs is "promoted"** to a server-owned entity. That covers being bumped, alerted, hit, pickpocketed or tailed. A promoted agent is replicated like any other entity until it calms down and returns to the deterministic schedule.
- Mission-critical NPCs are always server entities and always replicated: guards, targets, informants and witnesses.
- Floating-point determinism across x86 and ARM is not guaranteed. Keep the deterministic layer coarse: positions on a spline parameter, and integer schedule steps. Never run it through physics.

### 2.6 Vehicles and physics sync

- **Do not combine netfox rollback with `VehicleBody3D`.** Jolt is not deterministic, and Godot cannot re-simulate a single body in isolation.
- Forum reports describe cars drifting out of sync, and clients fighting the host when both simulate the same body. The advice that works is to **freeze or disable physics on non-authority peers** and apply received transforms and velocities with interpolation. [WEB]
- **Plan:**
  - The **driver's client owns the car's simulation** (client authority over its own vehicle). The server validates speed and teleport limits.
  - Everyone else sees the car through snapshot interpolation.
  - Better still, write a **custom arcade raycast car** on a `CharacterBody3D` or kinematic body, where you control every equation. That suits a stealth game, where handling matters less than chases.
  - Make the ownership handoff explicit when a driver changes, and reset interpolation at that moment.
- Passengers are parented to the car's seat node locally. They only replicate "in car X, seat N".

### 2.7 Late join, protocol and player count

- Late join works as in §2.4: snapshot, then acknowledgement, then streaming. Keep the `PROTO` gate.
- **Player-count guidance [JUDGEMENT]:**
  - **Target 2–6 players per city.** Godot ENet handles that easily, and the tablet's upload bandwidth and CPU are the real limits.
  - 8–12 players are feasible with a headless server on the PC and good interest management.
  - Beyond 16, Godot's Variant RPC path and GDScript server logic need profiling, and probably C# or a GDExtension.

---

## 3. Internet play without paying for servers

| Option | How | Android? | Catches |
|---|---|---|---|
| **LAN discovery** (as our earlier Godot tablet project) | UDP broadcast, /24 sweep and loopback; `change_wifi_multicast_state` permission | Yes [LOCAL] | Some routers and tablets drop broadcasts, which the sweep works around. Guest Wi-Fi with client isolation blocks it. |
| **Tailscale** | Friends join your tailnet, then connect by the PC's 100.x IP using plain ENet. | Yes (app) | Free Personal plan: **6 users, unlimited devices, non-commercial only** (April 2026 change). Each friend must install the app and be invited. [WEB] |
| **noray** (netfox.noray) | Players register with a noray server. It does NAT punch-through and falls back to relaying UDP. [WEB] | Yes (pure GDScript plus UDP) | **You must host noray on a public machine.** The public community instance gives no guarantees. Punch-through fails on some routers, and an issue reports that forced-relay behaviour is odd. [WEB] |
| **Epic Online Services P2P** (EOSG / GD-EOS plugins expose a `MultiplayerPeer`) | NAT punch-through with **automatic relay fallback**. EOS services are free. [WEB] | Yes (EOSG supports Android) | Needs an Epic dev account and product setup. GDExtension builds must match the Godot version. The relay is not meant for a dedicated server. Players log in with an Epic or device ID. |
| **Steam networking** (GodotSteam MultiplayerPeer; Steam Datagram Relay) | Valve relay plus NAT traversal, with lobbies and friends lists. [WEB] | **No.** It excludes the tablets. | You must be a Steamworks partner. Valve's docs say open-source GameNetworkingSockets cannot reach the relay. The Steam Direct fee and test-AppID terms were **not verified**. [WEB] |
| **WebRTC + Cloudflare TURN** | `WebRTCMultiplayerPeer`; Cloudflare STUN is free, and **TURN gives 1,000 GB/month free, then $0.05/GB**. [WEB] | Yes | Needs your own signalling server. [JUDGEMENT] Native desktop and Android builds need the `webrtc-native` GDExtension; not re-verified this session. |
| **playit.gg** | A UDP tunnel to the PC's ENet port. | Clients need nothing. | Free-tier tunnel count is disputed (1 vs 4+4). It adds a hop of latency. Verify on playit.gg. [WEB] |
| Port forwarding | Open the router to the PC's ENet port. | Clients need nothing. | Fails under carrier-grade NAT. Exposes the PC. |

**Order of adoption [JUDGEMENT]:**

1. LAN discovery, already proven.
2. **Tailscale** for a few friends, with zero code.
3. Only if strangers or no-install play matter: EOS P2P, which works on Android and has a free relay, or a self-hosted noray on a free-tier VM.

Keep the transport behind a `NetTransport` interface so ENet, EOS and WebRTC can be swapped.

---

## 4. Open-world tech at small scale

- **Chunk streaming.**
  - Cut each city into a grid of 128 m chunks. Each chunk is a `.tscn` holding baked static meshes, collision, occluders, a navmesh piece and spawn points.
  - Load chunks around each local player with `ResourceLoader.load_threaded_request(path)`, then poll `load_threaded_get_status`. Call `load_threaded_get` only once the status is LOADED, because it **blocks like `load()`** otherwise. [WEB]
  - Add chunks to the tree on the main thread, a few nodes per frame. [JUDGEMENT]
  - The server (headless) loads the chunks around *all* players, plus collision-only versions of mission areas.
- **LOD and HLOD.**
  - Godot generates automatic mesh LODs on import.
  - **Visibility ranges** (`visibility_range_begin`/`end` plus Visibility Parent) give HLOD: one merged block mesh replaces many building meshes in the distance, which cuts draw calls. Fades are alpha or dithered only. [WEB]
  - Bake per-block HLOD proxies in Blender 4.2 (WSL) with a script.
- **Occlusion.**
  - `OccluderInstance3D` culls on the CPU (Embree). It **helps the Mobile renderer most**, because Mobile has no depth prepass.
  - Only opaque `MeshInstance3D`s are baked; MultiMeshes are excluded. Moving occluders is costly, so toggle their visibility instead. [WEB]
  - **Whether the Compatibility renderer honours occlusion culling was not confirmed in the docs I read.** Test it in week 1.
  - In any case, city blocks give natural occlusion. Design streets with bends and T-junctions.
- **Renderer choice.**
  - Mobile is the default on mobile platforms but requires Vulkan, D3D12 or Metal. Compatibility suits low-end and older devices and lacks decals and particle trails. Neither supports SDFGI, VoxelGI or volumetric fog. [WEB]
  - our earlier Godot tablet project ships on Compatibility. [LOCAL]
  - **Decision:** keep Compatibility until a week-1 A/B benchmark on the actual tablets shows Mobile is stable and faster.
  - Use LightmapGI baked on the PC in either case. Compatibility can *render* lightmaps, but baking needs RenderingDevice hardware, which the 1660 SUPER has. [WEB]
- **Impostors.** Use octahedral or billboard impostors for distant pedestrians, cars and trees. Bake the impostor atlases with Blender scripts.
- **MultiMesh crowds.**
  - The far crowd is a `MultiMeshInstance3D` of low-poly people animated with vertex-animation textures, with per-instance custom data (phase, outfit).
  - The near crowd (around 8–15 m) is real skinned `Node3D` NPCs, swapped in and out of a pool.
- **Navigation for streamed worlds.**
  - Bake one navmesh per chunk with a shared baking AABB and border size so edges line up. Set the map's `edge_connection_margin`. Avoid overlapping regions.
  - Forum reports say a vertex supports only one automatic edge connection where four chunks meet, so test chunk corners. [WEB]
  - Pedestrians mostly follow sidewalk graphs, not the navmesh. Only promoted NPCs and guards path on the navmesh.
- **Traffic on road graphs.**
  - Roads are directed lane splines with junction nodes. Cars are `(lane_id, s, speed)`, driven by simple car-following (IDM-style) and junction reservations.
  - Render cars through a MultiMesh far away and as real nodes near the player.
- **Performance budgets [JUDGEMENT; validate with profiler]:**

  | Target | FPS | Draw calls | Visible tris | Skinned NPCs | Far crowd instances | Cars active | Texture memory |
  |---|---|---|---|---|---|---|---|
  | GTX 1660 SUPER, 1080p | 60 | ≤ 2,000 | ≤ 3 M | 30 | 1,000 | 60 | ≤ 3 GB |
  | Mid-range Android tablet | 30 (60 for UI) | ≤ 300 | ≤ 300 k | 8 | 200 | 20 | ≤ 1 GB (ASTC/ETC2) |

  Use `RenderingServer` monitors in an autoplay perf test (our earlier Godot tablet project already has `auto_mapperf.gd`). Fail the build when a budget is exceeded.

---

## 5. Multiple worlds (separate city maps)

- **Structure:**
  - An autoload `Game` holds the systems shared across all cities: net, inventory, save, missions, factions and audio.
  - `res://worlds/<city>/` holds `world.tres`, which records the seed, grid, chunk list, road graph, spawn points and the travel points out of the city, plus that city's `chunks/`.
  - A `WorldRoot` node loads one city at a time on a client.
- **Server:**
  - **Version 1:** one city per session. The party travels together; when a player triggers travel, everyone votes or the host decides.
  - **Version 2:** the server runs several cities **in one process under separate roots**, each using its own Jolt physics space (a `World3D`/viewport per city, or offset coordinates), with interest management per city. A peer is subscribed only to its own city. Alternatively, run one headless server process per city on separate ports and hand the peer off to the other process (simpler isolation).
- **Travel flow:**
  1. The client asks to travel.
  2. The server validates the request (mission state, whether the player is being chased).
  3. The server removes the peer from city A's replication set.
  4. The client loads city B with a loading screen, while threaded loading continues.
  5. The client sends "ready".
  6. The server sends city B's snapshot and spawns the player at the arrival point.
- **Save data:** a versioned JSON (or `ConfigFile`) per profile, written by the server/host. It holds the persistent player state (gear, cash, reputation, unlocked cities) and a per-city persistent world state (opened safes, alert levels, destroyed props). Treat these as **edits on top of the seed**, exactly as our earlier Godot tablet project does. Clients keep only their local settings.

---

## 6. Test strategy

1. **Unit and logic tests:** GdUnit4 or GUT, run with `godot --headless --path <proj> -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --run-tests`. It produces JUnit/HTML reports. [WEB]
2. **Headless false passes:** a forum write-up documents headless Godot **exiting 0 even when things failed**. A blog test on 4.7.2 found simulated clicks reach `_input` but never press a `Button` under `--headless`. [WEB]
   - The harness must **write and check its own result files** (the earlier project's `--out=<dir>` pattern), never rely on the process exit code.
   - Run UI tests windowed.
3. **Simulation tests:** deterministic server-only runs (`--headless --auto=<scenario> --seed=N`) that tick the world for N simulated minutes. They assert invariants: no NPC is stuck, traffic flows, every guard's alert level stays bounded, and the navmesh is connected across chunk borders.
4. **Bot players:** each scripted bot is a normal client process fed an input script (waypoints, actions). Put them behind the same input-frame API that prediction uses, so a bot exercises the netcode.
5. **Multi-client tests on one PC:** one headless server plus N clients on 127.0.0.1, using test ports and a test magic string (the earlier project's isolation trick). Inject a **simulated latency and loss** layer in `NetTransport`: delay queues and drop percentages, so 150 ms and 5% loss can be tested locally.
   - Asserts: positions converge, and the late-joiner snapshot matches the server's.
   - Also check a CRC of the deterministic crowd and traffic state at the same `server_time` on every client.
6. **Performance tests:** an autoplay camera fly-through of each city logs FPS, draw calls and memory against the §4 budgets. Run it on the PC and through `adb` on one tablet, using the `adb` already available.
7. **Visual check:** screenshot steps in autoplay scripts, compared against the previous build (the earlier project's `--out` screenshots).

---

## 7. Recommended architecture sketch

```
spycraft-international/   (Godot 4.7.2 project, text-only)
├─ project.godot                 Jolt, physics interp ON, 60 Hz, gl_compatibility (A/B Mobile in week 1)
├─ autoload/
│  ├─ Game.gd                    session state, world switching, save/load
│  ├─ Net.gd                     NetTransport (ENet | EOS | WebRTC), LAN discovery (from our earlier Godot tablet project),
│  │                             PROTO gate, PC-biased host election, clock sync (server_time)
│  └─ Replication.gd             entity registry (entity_id → node), spawn/despawn RPCs,
│                                per-peer cell subscriptions, batched snapshots (PackedByteArray)
├─ sim/                          pure-logic, no nodes where possible (unit-testable headless)
│  ├─ crowd_sim.gd               f(seed, agent_id, t) → sidewalk spline pose; promotion rules
│  ├─ traffic_sim.gd             lane graph, IDM following, junction reservations
│  ├─ stealth/                   vision cones, noise, suspicion meters, disguises (SERVER ONLY)
│  └─ missions/                  data-driven objectives (.tres)
├─ actors/
│  ├─ player/                    CharacterBody3D + predicted movement + cam rig
│  ├─ npc/                       pooled skinned NPC; far = MultiMesh crowd layer
│  └─ vehicle/                   custom arcade raycast car; driver-owned, others interpolate
├─ worlds/<city>/                world.tres, chunks/*.tscn, nav/, roads.tres, hlod/
├─ streaming/ChunkStreamer.gd    threaded loading, add-per-frame budget, HLOD/visibility ranges
├─ tests/                        auto_*.gd scenarios (+ --role, --out), GdUnit4 suites
└─ tools/                        Blender (WSL) scripts: city kit, HLOD/impostor bake, VAT bake
```

**Data flow:**

- Clients send input frames to the server at 30–60 Hz.
- The server runs the authoritative simulation at 60 Hz.
- Each peer receives, at 15–20 Hz, a snapshot of the entities in its cells together with ack'd input ticks. The client reconciles its own player and interpolates everyone else.
- Crowds and traffic run locally from `(seed, server_time)`. Only promoted agents travel as entities.

---

## 8. Top 8 technical risks and mitigations

| # | Risk | Mitigation |
|---|---|---|
| 1 | **Tablet performance**: an open city exceeds what a mid-range tablet can render or simulate on Compatibility. | A week-1 vertical-slice benchmark (one city block with crowd and traffic) on the real tablets, A/B testing Compatibility against Mobile. Hard budgets from §4 enforced by an autoplay perf test. Per-platform quality tiers, with shorter visibility ranges on tablets. |
| 2 | **Disk space on C:** (21.4 GB free). The `.godot` import cache, exports and Blender caches fill it and crash tools. | Put the project, exports and Blender work on **D:** (112.8 GB free). Leave Unreal untouched and don't install its Android components. Monitor free space in the build script. |
| 3 | **Netcode complexity**: prediction and reconciliation bugs cause rubber-banding. | Predict only the local player's movement; everything else is server-confirmed. Adopt netfox or a small, tested custom version. A latency and loss simulator in `NetTransport`. Multi-client convergence tests (§6). |
| 4 | **MultiplayerSpawner/Synchronizer late-join and path bugs.** [WEB] | Avoid them for game entities. Use an entity registry with explicit spawn RPCs, a snapshot, then an acknowledgement before replication. |
| 5 | **Vehicle physics desync** (Jolt is not deterministic; authority fights). [WEB] | The driver owns the car, other peers freeze it and interpolate, and handoffs are explicit. Prefer a custom kinematic arcade car. |
| 6 | **Streaming hitches and navmesh seams** at chunk borders. [WEB] | Threaded loads with a per-frame add budget. Baked chunk navmesh with a shared border and edge margin. A headless test that paths across every chunk corner. Pre-warm shaders behind the loading screen. |
| 7 | **Internet play**: NAT, carrier-grade NAT and friends' setups break connections. Steam would exclude the tablets. [WEB] | Tailscale first (6 free users). EOS P2P with a relay as the code path. Keep a transport abstraction so the game never depends on one provider. |
| 8 | **Determinism drift in crowds and traffic** across x86 and ARM floats, and between builds. | Integer or fixed-step schedules, spline parameters, and the PROTO and content hash in the beacon. A periodic server CRC and resync. Promote any agent that touches physics to a replicated entity. |

Also watch:

- Headless tests passing falsely: assert from result files, not exit codes.
- GDExtension plugins (EOS, WebRTC, GodotSteam) lagging behind Godot releases: pin the engine version per milestone.
- The Godot 4.7 migration guide notes breaking changes, so read it before any upgrade.

---

## 9. Sources

**Verified locally** (read-only commands on this PC): drive free space, GPU/CPU/RAM, Godot `--version`, the export-templates folder, Godot editor Android/JDK paths, UE `Build.version`, UE folder size and Android binaries, WSL `blender --version`, and the earlier project's `project.godot`, `export_presets.cfg`, `scripts/net/net.gd`, `tests/auto_mapnet.gd`, export folder and git log.

**Read online:**

- Godot 4.7 release page — https://godotengine.org/releases/4.7/
- Godot 4.7 release coverage — https://www.phoronix.com/news/godot-4.7-released ; https://www.gamingonlinux.com/2026/06/godot-engine-4-7-is-out-bringing-a-new-asset-store-hdr-support-steam-frame-support/
- Godot 4.6 release (Jolt default, D3D12 default on Windows) — https://godotengine.org/releases/4.6/ ; https://gamefromscratch.com/godot-4-6-released/
- MultiplayerSynchronizer class docs — https://docs.godotengine.org/en/4.3/classes/class_multiplayersynchronizer.html
- Rivet, Godot multiplayer vs Unity — https://rivet.dev/blog/godot-multiplayer-compared-to-unity/
- Forum: synchronizer visibility — https://forum.godotengine.org/t/difficulties-with-multiplayersynchronizer-visibility/52577
- netfox — https://github.com/foxssake/netfox ; https://foxssake.github.io/netfox
- noray guide — https://foxssake.github.io/netfox/netfox.noray/guides/noray
- netfox issue #174 (forced relay) — https://github.com/foxssake/netfox/issues/174
- Spawner late-join threads —
  - https://forum.godotengine.org/t/does-multiplayersynchronizer-and-multiplayerspawner-support-late-joining/47461
  - https://forum.godotengine.org/t/multiplayerspawner-errors-when-joining-in-progress-game/129301
  - https://forum.godotengine.org/t/node-not-found-multiplayersynchronizer-on-client-late-joining/137234
  - https://forum.godotengine.org/t/how-to-set-correct-authority-on-object-spawned-in-scene-for-a-late-joining-player/100359
- Vehicle and RigidBody sync threads —
  - https://forum.godotengine.org/t/multiplayer-synchronization-of-passenger/132332
  - https://forum.godotengine.org/t/how-do-i-sync-rigidbody3d-properly-in-multiplayer/129584
  - https://forum.godotengine.org/t/jolt-physics-causing-floaty-springy-joints/142182
- Physics interpolation (4.4+) — https://docs.godotengine.org/en/4.4/tutorials/physics/interpolation/using_physics_interpolation.html
- Dedicated server export — https://docs.godotengine.org/en/4.4/tutorials/export/exporting_for_dedicated_servers.html
- Renderers overview — https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Occlusion culling — https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html
- Visibility ranges (HLOD) — https://docs.godotengine.org/en/4.7/tutorials/3d/visibility_ranges.html
- Optimizing 3D — https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html
- Background loading — https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html
- Connecting navmeshes — https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_connecting_navmesh.html
- Forum: nav chunk connections — https://forum.godotengine.org/t/nav-chunks-some-chunk-connections-are-one-way-only/80241
- GdUnit4 — https://github.com/MikeSchulze/gdUnit4
- Headless input in GUT/GdUnit4 (tested on 4.7.2) — https://ziva.sh/blogs/godot-gut-gdunit4-simulate-input
- Headless exit-0 failures — https://forum.godotengine.org/t/things-that-exit-0-in-godot-4-headless-even-though-they-failed-measured-reproducible/145990
- Tailscale pricing v4 (April 2026) — https://tailscale.com/blog/pricing-v4
- Cloudflare Realtime/TURN pricing — https://developers.cloudflare.com/calls/pricing/ ; https://developers.cloudflare.com/realtime/turn/faq/index.md
- playit.gg alternatives and limits (third-party, conflicting) — https://pinggy.io/blog/best_playit_gg_alternatives/ ; https://dev.to/instatunnel/ngrok-vs-playitgg-bypassing-cgnat-for-gaming-and-real-time-udp-traffic-in-2026-60b
- Steam Datagram Relay — https://partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay ; https://partner.steamgames.com/doc/features/multiplayer/networking
- Steam Multiplayer Peer (asset listing) — https://godotengine.org/asset-library/asset/2258
- EOS for Godot (EOSG) — https://3ddelano.github.io/epic-online-services-godot ; GD-EOS — https://github.com/Daylily-Zeleen/GD-EOS
- EOS relay notes — https://edgegap.com/blog/can-epic-online-services-eos-relays-allow-for-dedicated-server-or-authoritative-server
- Unreal 5.8 release — https://www.unrealengine.com/news/unreal-engine-5-8-is-now-available ; https://tomlooman.com/unreal-engine-5-8-performance-highlights/
- Unreal 5.8 coverage — https://www.pcgamer.com/software/unreal-engine-5-8-launches-with-improved-terrain-and-vegetation-tools-a-lumen-lite-option-for-faster-global-illumination-and-for-the-times-we-now-live-in-an-open-standard-plugin-for-llm-systems/
- UE Android binary size — https://dev.epicgames.com/documentation/ja-jp/unreal-engine/reducing-android-binary-size-in-unreal-engine-projects ; https://forums.unrealengine.com/t/what-is-the-minimum-size-of-the-unreal-engine-based-mobile-application/461166
- three.js WebGPU r182 regression — https://discourse.threejs.org/t/webgpu-significant-performance-drop-and-shadow-quality-regression-in-r182-vs-webgl-r170/89322
- three.js WebGPU showcase — https://discourse.threejs.org/t/pockit-game-corp-a-webgpu-showcase/87891

**Not verified this session:**

- Whether Compatibility supports occlusion culling.
- The `webrtc-native` requirement on native platforms.
- The Steam Direct fee and AppID 480 rules.
- The playit.gg free-tier tunnel count.
- All performance budgets, which are estimates to validate on the hardware.
