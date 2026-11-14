# OpenSpygate: Game Design Document

Version 0.1, 2026-11-14. Built from the four research reports in `docs/research/`. Where this document and a report disagree, this document wins; the reason is given in section 12.

## 1. The game in one paragraph

An open-world, third-person, multiplayer espionage game. You are a field officer for a fictional intelligence service, working the great spy cities of the twentieth century, each in the era that made it famous. You walk, drive and ride through a living city, run sources, service dead drops, shake surveillance, slip into embassies under cover, and get out before the city closes around you. Friends join your city as fellow officers, or as the opposition.

Everything in it is original: no names, characters, maps, missions or art from any existing game.

## 2. Pillars

1. **The crowd is your cover.** Cities are dense with people, and blending into them is the main skill. Behaviour gives you away, not a glowing marker.
2. **Real tradecraft, made playable.** Dead drops, signal sites, brush passes, surveillance-detection routes, cover identities and exfiltrations are the verbs. Each is a quick action whose result changes the world, never a long minigame.
3. **Getting caught is the start of a scene.** Suspicion leads to a scramble, a chase, a capture and a prisoner swap. Missions almost never restart.
4. **An open city, not a mission menu.** Between operations the city is yours: drive it, learn it, scout it, recruit in it, find its secrets. Systems (crowds, police, counter-intelligence, traffic) make stories without a script.
5. **Each world is a different game mood.** Divided Berlin, glamorous Lisbon, paranoid Moscow, mercantile Istanbul, neutral Vienna, sunlit Havana.

## 3. Platforms and players

| | Decision |
|---|---|
| Lead platform | Windows and Linux PCs. Reference machine: GTX 1660 SUPER, Ryzen 5 4600G, 1080p at 60 fps. A PC hosts. |
| Second tier | Android tablets and phones join the same sessions at a lower quality tier (30 fps target). |
| Engine | Godot 4.7.2. Game systems are our own code on top. |
| Session size | 1 to 6 players per city at first; 8 to 12 later with a headless server. |
| Internet play | Home Wi-Fi discovery first, Tailscale for friends, Epic Online Services P2P later if needed. |

## 4. Tone and content rules

- Spy-thriller tone, about the level of a teen-rated adventure film. Tension, chases, fistfights, tranquilizer darts, arrests.
- Takedowns are non-lethal. Being caught leads to interrogation-room scenes and prisoner swaps, not death.
- Recruiting sources works on trust: belief, recognition, help, fair payment. No seduction or blackmail mechanics.
- Real cities and real techniques; fictional agencies, people and plots. No real living people as characters.
- Real atrocities and victims appear only in a respectful in-game history codex, never as missions.
- Cities are set in a stylized past (1940s to 1980s), away from current conflicts.

## 5. Core loops

**Second to second:** walk, drive, watch, blend, take one covert action, slip away.

**An operation (10 to 20 minutes):**

1. **Brief.** A handler gives a goal with several possible approaches.
2. **Recon.** Watch the place, tag people and cameras, learn schedules.
3. **Prep.** Choose a cover, gadgets and an exit route; call in a recruited source if you have one.
4. **Execute.** Social stealth through public and private spaces.
5. **Exfil.** Shake any pursuit through crowds, transit, vehicles or a safe house.
6. **Debrief.** Pay, reputation, and a plain log of what gave you away.

**Free roam (between operations):** scout future targets, spot and develop sources, service drops, find signal sites and history-codex entries, buy and stash vehicles, set up safe houses, take small street jobs (courier runs, counter-surveillance for another officer, photo assignments).

**Campaign:** new contacts, districts, gadgets, covers and cities. The city's security adapts to your habits.

## 6. The Exposure system (in place of a wanted level)

Three layers, so a mistake costs in proportion to its size.

1. **Suspicion (per person, seconds).** A meter over each watcher fills with distance, line of sight, light, your behaviour (running, loitering where you don't belong, carrying contraband) and whether your cover fits the space. It drains when you break contact. Certain "sharp-eyed" roles see through certain covers. Watchers can be wrong and fix on the wrong person.
2. **Alert (per operation, minutes).** Six named tiers with fixed effects the player can read ahead of time, a visible countdown to the next tier, and jumps for loud events.

   | Tier | Effect |
   |---|---|
   | 0 | Normal |
   | 1 | Extra watchers on cameras |
   | 2 | Private areas lock; better covers needed |
   | 3 | Plain-clothes counter-agents enter the crowd |
   | 4 | Checkpoints on district exits |
   | 5 | Lockdown and manhunt |

   At tier 5, capture leads to an escape or a prisoner swap, not a restart.
3. **Cover burn and city memory (persistent).** A cover seen doing something illegal is burned in that district for a while. Districts adapt to repeated tactics: many rooftop entries bring rooftop watchers.

## 7. Tradecraft verbs

| Verb | How it plays |
|---|---|
| Dead drop | Hide an item in a world prop. Another player or a source collects it. Anyone watching the spot can find it. |
| Signal site | Leave or read a chalk mark, tape strip or window object. A wrong mark aborts the meeting. |
| Brush pass | Two people cross in a crowd inside a short window, out of a watcher's sight. |
| Surveillance-detection route | Walk or drive a route with choke points; the game flags faces and cars you've seen twice. |
| Cover and legend | A cover opens some spaces and conversations and closes others. |
| Photograph / bug / tap | Under ten seconds each; the result reveals a schedule, a code or a conversation. |
| Recruit a source | Spot, assess, develop over several meetings, then pitch. Sources become services on the map: a doorman, a cab driver, a clerk. |
| Exfiltration | A multi-stage escort with signals, a fallback, and a nerve meter at the checkpoint. |
| Numbers station | A radio broadcast at a set hour, decoded with a one-time pad, gives a secret objective. |
| Prisoner swap | Captured players are exchanged at a bridge in a staged event. |

## 8. Worlds

Real city names, each at its famous moment. Landmarks are original designs inspired by the place, not copies.

| Order | World | Mood and signature play |
|---|---|---|
| 1 | Berlin, 1961-63 | Divided city, two halves, the bridge swap, the wiretap tunnel, sector crossings. Exercises every core system. |
| 2 | Lisbon and Estoril, 1941 | Casino social stealth, harbour, exit visas for refugees, running an invented spy network. |
| 3 | Moscow, 1985 | Hard mode. Watched everywhere; ends in a border exfiltration. |
| 4 | Istanbul, 1943 | The information market: hotels, bazaar, ferries, servant-cover embassy job. |
| 5 | Vienna, 1950s | The neutral social hub: coffeehouses, sewers, no takedowns allowed. |
| 6 | Havana, 1962 | Recon, numbers stations, a comic mission. |

Bench: Bern/Geneva, Tangier, Washington suburbs, a fictional Harbour City, Beirut 1962.

Each world is built district by district. A district is about 600 m square and dense: every block has something to do, watch or use. Berlin launches with one district and grows to five (checkpoint zone, tenement quarter, eastern boulevard, rail yards, western shopping street).

## 9. Vehicles and travel

Vehicles are in the game, as a later production stage and not in the first playable.

- Original period cars, vans, taxis, trams, motorcycles and boats, with invented makes and no badges.
- Arcade handling on our own raycast car. The driver's device simulates the car; others see it smoothed.
- Traffic follows lanes from the road map, run identically on every device from a shared seed.
- Cars matter for tailing, surveillance-detection routes, chases and exfiltration. Pedestrian crowds stay the heart of the stealth.
- Travel between worlds goes through an airport or station scene in each city.

## 10. Multiplayer

Built in this order, each on the one before:

1. **Solo.** Also the practice ground.
2. **Co-op, 2 to 4 friends,** private session, in free roam and on operations.
3. **Hidden-agent rounds,** 1v1 or 2v2, opt-in: one side hides in the crowd doing small tasks, the other hunts with a single arrest.
4. **Two-service free roam** in Berlin: friends split between the two halves of the city.

Rules: the host PC decides what really happened. No open play with strangers. Nothing in the interface may reveal that a hidden human is nearby. Dead drops and marks left by friends persist between sessions.

## 11. Look and sound

- **Style:** realistic. True-to-life dimensions, physically based materials (wood grain, worn brass, wet stone, chipped paint), real light and shadow, fog and a colour grade per city. Realistic, not uncanny: the aim is a world that looks solid and believable, not photographic human faces.
- **Level of detail:** higher than a closed studio can afford across a whole world, because every asset is its own small task with an owner. Each asset is built to be looked at closely.
- **The opening:** the game starts in an empty black void with one door, detailed down to the grain and the wear on the handle, and a voice saying that if you walk in, there is no turning back. That door is also the first asset built and the standard for everything after it. The world is then built outward from behind it. Where nothing is built yet there is void, never a placeholder.
- **Hardware:** the PC tier carries the full detail. Tablets get the same assets at lower levels of detail and texture size. How far the reference graphics card can be pushed is measured on the door and the first room, not assumed.
- **Gate:** the door in the void, approved by the project lead, before anything else is built to that standard.
- **Characters:** one shared skeleton, realistic proportions, modular bodies, heads and period clothing with real fabric materials. Faces are believable and slightly simplified to stay clear of the uncanny valley.
- **Sound:** period-flavoured adaptive music that layers up with the alert tier, footsteps by surface (noise is a gameplay value), voiced handler briefings generated offline with an openly licensed voice model and given a radio treatment.
- **Interface:** dossier folders, typewriter text, rubber stamps, map-room maps, analog-tech readouts.

## 12. Where this departs from the research

| Report said | This document says | Why |
|---|---|---|
| No vehicle traffic simulation | Vehicles and lane traffic, as a later stage | The game we set out to make is an open-world city game. Lane-following traffic is modest work once the road map exists. |
| One district only | One district first, then grow by districts and cities | Production is long and staged; pipelines make later districts cheap. |
| Avoid procedural city generation | Generated buildings and dressing on a hand-designed street plan with hand-built landmarks | The failure case was generating the city itself with no game. Here the game loop is proven in one block first. |
| Youngest age rating, no takedowns in places | Teen-level thriller with non-lethal takedowns | It is an open-world action game that should still be playable in a family home. |
| Tablets as an equal target | PC leads, tablets are a second tier | Raises the visual ceiling. |
| Low-poly toon style, because scripted modelling cannot make realism look good | Realistic assets with physically based materials | The project lead's direction. An open crowd of artists and agents, each owning one asset, can reach detail that one scripted pipeline cannot. The report's warning still stands as a risk: realism has to be held to measurable standards in the art bible and checked in context. |

## 13. Open questions for later passes

- Names for the fictional services, handlers and car makes (a writing pass).
- Recruitment design: the research did not cover it.
- Whether the Compatibility renderer does occlusion culling; Mobile renderer speed on the tablets.
- Font licence texts, before any font is used. Fonts are the only third-party files accepted; every other asset is made by the project's contributors.
- A proper trademark search for the name OpenSpygate (a quick web search found no game or mark with that name).
