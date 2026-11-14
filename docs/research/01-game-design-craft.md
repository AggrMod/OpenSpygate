# 01 — Game Design Craft Research for *Spycraft International*

*Research date: 2026-11-14. Design research only, no code. Every lesson below is used as craft knowledge; nothing (names, characters, maps, art, missions, feature names) is to be copied from any game cited.*

## How to read the sourcing

Every claim carries one of three tags:

| Tag | Meaning |
|---|---|
| **[Read]** | I fetched and read the source page itself. |
| **[Search]** | Only a search-engine summary or snippet of the source was available. The claim matches several summaries, but I did not read the full page. |
| **[Unverified]** | General craft knowledge with no source checked in this session. Treat it as informed opinion. |

Thinly sourced areas are said to be thin. Some fetches failed: the Game Developer article on Hitman (2016) AI, the PC Gamer "MGS5 failure spectrum" article, and Chris Hecker's own design page (site down). Claims tied to those sources are snippet-level only.

**Name check.** *Spycraft: The Great Game* (Activision, 1996) is an existing espionage adventure game [Unverified, from memory]. "Spycraft International" is not the same name, but it is close. Run a trademark or store search before committing to the title publicly.

---

## 1. How open-world city games are structured

### 1.1 Core loop

The open-world city genre stacks three loops [Unverified]:

- **Moment-to-moment loop (seconds):** move, drive, interact, fight or evade. If this layer is not fun with no mission at all, the game is not fun. The genre's own origin story shows it: the first GTA (prototype *Race'n'Chase*) was close to being shelved after ~30 months until a pathfinding bug made police ram the player. The chase became the game [Search: [Engadget, original design docs](https://www.engadget.com/2011/03/22/race-n-chase-original-gta-design-docs-posted/); [Prima Games](https://primagames.com/gaming/racenchase-gta-dma-design-feature)]. Sources disagree on whether the behaviour was a pure accident or a deliberate pick, but they agree the emergent chase was the "find the fun" moment.
- **Activity loop (minutes):** take a job, travel, execute, escape, get paid, unlock.
- **Progression loop (hours):** money, gear, reputation, and new districts or contacts unlock more varied activities.

The genre's signature is that **the systemic layer (police, crowds, traffic) creates stories between scripted missions**. Scripted missions alone feel like a linear game with a long commute [Unverified].

### 1.2 Mission structure

These patterns are common across the genre [Unverified]:

- **Story missions from contacts or quest-givers.** Each contact is a thematic strand that unlocks the next. Usually two or three strands run in parallel, so the player always has a choice.
- **Mission anatomy:** briefing, travel (often with dialogue to make travel meaningful), set piece, escape (hands the player back to the systemic heat layer), payoff.
- **Repeatable side activities** that reuse the same systems: races, deliveries, rampages, collectibles. These are cheap content because they recombine existing systems with new parameters.
- **Common failures:** instant-fail conditions, long restarts with no mid-mission checkpoints, and "follow the car" or "tail the guy" missions (see 3.1).

### 1.3 World activity systems

A city feels alive when things happen without the player [Unverified]:

- ambient scripted vignettes, such as an argument or a mugging
- random encounters
- schedules (shops open and close, night versus day crowds)
- systemic reactions (police respond to crime the player didn't commit)

Hitman's IO Interactive frames this as designing **"believable everyday life"**, not just a good mission. After Sapienza, reviews praised the atmosphere more than the assassination, and that changed the studio's level-design goal [Read: [Game Developer — Hitman social cues](https://gamedeveloper.com/design/mapping-out-the-subtle-social-cues-throughout-i-hitman-i-s-level-design)].

### 1.4 Traffic and pedestrian simulation (design level)

This area is thinly sourced. The key craft idea is **level of detail for AI**:

- Hitman's crowd tech runs cheap crowd agents that are **promoted to full NPCs on demand** when the player interacts with them. Per-level crowd limits feed back into level design [Search: [Intel / IOI Hitman 2 slides (PDF)](https://www.intel.com/content/dam/develop/external/us/en/documents/06-create-a-scalable-and-destructible-world-in-hitman2-807276.pdf); [GDC Vault — Crowds in Hitman (Fauerby)](https://gdcvault.com/play/1015315/Crowds-in-Hitman)]. Absolution-era reporting cites up to ~500 characters on screen and talks of "1,200 character crowds" [Search: [MCV](https://www.mcvuk.com/development/gdc-hitman-dev-to-showcase-crowd-technology)].
- The general pattern [Unverified]:
  - Spawn pedestrians and cars in a ring around the player, just outside view, and despawn them behind.
  - Simulate far agents as data only.
  - Traffic follows lane graphs with simple rules: follow, stop at lights, give way, panic.
  - Pedestrians run cheap steering plus a small reaction set: flee, gawk, call police, ignore.
- For a spy game, **pedestrians matter far more than cars**. Crowds are the stealth medium. Traffic is scenery plus an escape tool.

### 1.5 "Wanted level" escalation and tuning

This area is thinly sourced on hard tuning numbers. No GDC talk on wanted-level tuning was found.

- **Shape:** a small number of discrete, readable tiers (classic GTA used 5–6 stars). Each tier adds a qualitatively new response, not just more of the same [Unverified].
- **Escape rules:**
  - Break line of sight, after which a search zone shrinks or decays over time.
  - Or use a "reset" service (paint shop, safehouse).
  - Escape must stay possible but cost something at every tier [Unverified].
- **High tiers as a toy.** Ubisoft developers describe the top tier of Star Wars Outlaws' wanted system as "very difficult" but say "it becomes a toy" that players deliberately push [Search: [TechRadar](https://www.techradar.com/gaming/consoles-pc/the-star-wars-outlaws-wanted-system-is-very-difficult-at-the-highest-level-it-becomes-a-toy-says-developer); [GamesRadar](https://gamesradar.com/games/open-world/you-can-mess-with-star-wars-outlaws-gta-style-wanted-system-to-make-the-ultimate-open-world-playground-type-of-self-imposed-challenge)].
- **Telemetry to watch while tuning** [Unverified]: time to first response, time between tiers, average chase length, escape rate per tier.

The best-documented escalation design is not from a city game. It is Klei's *Invisible, Inc.* alarm, covered in 2.3 and the basis of the heat proposal in section 6.

### 1.6 Map design: landmarks, districts, density versus size

- **Kevin Lynch's *The Image of the City* (1960)** gives five elements people use to mentally map cities: paths, edges, districts, nodes and landmarks. He recommends clustering or sequencing landmarks for reinforcement, and giving nodes distinctive spatial form [Search: [Wikipedia](https://en.wikipedia.org/wiki/The_Image_of_the_City)].
- **A study applying Lynch to open-world games** found only 2 of the 5 elements clearly confirmed. Paths matter less because games lack street names, and games need extra categories such as NPCs. Treat Lynch as a starting vocabulary, not a law [Search: [Wellesley poster (PDF)](https://cs.wellesley.edu/~pmwh/mvmap/posters/open_world_elements/IOOW_Poster.pdf)].
- **Public versus private spaces** (Mette Podenphant Andersen, IO Interactive, GDC 2019) [Read: [Game Developer](https://gamedeveloper.com/design/mapping-out-the-subtle-social-cues-throughout-i-hitman-i-s-level-design)]. This is the most useful map framework for a spy game. Levels are built from:

  | Space type | Subtype | Example and purpose |
  |---|---|---|
  | Public (open without disguise) | Basic | Town square: rest and orientation |
  | Public | Purpose | Alley: nudges actions without danger |
  | Public | Rule | Church: social norms enforced by "social enforcers", a safe place to learn rules |
  | Private (strict rules on behaviour and access) | Basic | Trespass alleys: low-pressure stealth and breathers |
  | Private | Professional | Kitchens: the space itself tells you how to blend in as staff |
  | Private | Personal | Rare; reveals the target. "It should feel special." |

  IOI also found "you can keep the player engaged without introducing trespassing". Large public areas with good social cues carry play by themselves.
- **Density beats size** [Unverified, strongly held in the genre]. One dense, legible district with many interior and social spaces beats a big empty grid. Every block should hold something to do, see or use.

### 1.7 Onboarding

- **Teach through space, not text.** Public "rule spaces" teach social norms safely before the player enters private spaces where breaking them matters [Read: Andersen, above].
- **Single-player as a practice ground before multiplayer.** Chris Hecker saw a solo mode for *SpyParty* as the way to teach new players. It lets them "make mistakes against the computer" without an audience [Read: [Game Developer — Hecker on SpyParty single-player](https://gamedeveloper.com/design/ai-hiding-among-ai-chris-hecker-on-i-spyparty-s-i-devious-single-player)].
- **Missing practice spaces hurt.** A critic notes that *Payday 2* had no practice space for stealth, so players learned detection rules by failing live heists [Search: [Game-Wisdom — Payday 2 and stealth](https://game-wisdom.com/?p=8278)].

---

## 2. Stealth and social-stealth design craft

### 2.1 Detection models

These come from Game Maker's Toolkit, *School of Stealth* [Search: Part 1 transcript on [Amara](https://amara.org/videos/4SwBdOk0E4LH/en/3100597); Part 3 "How do Stealth Games Deal with Detection?", 2020]:

- **Vision cones** are the standard. Splinter Cell *Blacklist* layers a narrow primary cone with a wider peripheral box.
- **Fuzzy detection.** An awareness meter fills rather than triggering instantly. It fills slower at distance, in peripheral vision, in low light, and when the player is crouched or still. GMTK argues instant detection on cone contact "wouldn't feel very fair".
- **Binary detection** works only if perception is perfectly readable. *Mark of the Ninja* shows its cones on screen and pairs them with near-instant detection.
- **On-screen indicators** mirror the guard's internal meter so the player can read the AI's state.
- **Decay** [Unverified, standard practice]: the meter falls when the player leaves sight. That gives a forgiveness window to recover from mistakes.

### 2.2 Social stealth: disguises and crowd blending

- **Disguise as social role.** In Hitman, taking a uniform unlocks the areas tied to that role. Stealth becomes *performing a role convincingly* [Read: Andersen, above].
- **Per-NPC disguise checks.** Hitman (2016) runs a "Disguise service" that checks whether 47's outfit looks suspicious to nearby characters. It sits inside a broader system that also supports loud play [Search, snippet only; full article fetch failed: [Game Developer — The AI of Hitman (2016)](https://gamedeveloper.com/design/the-ai-of-hitman-2016-)]. Hitman's well-known "enforcer" pattern also matters [Unverified, from memory]: only certain NPCs, such as the head chef or senior guards, see through certain disguises. That turns one disguise into a puzzle of who to avoid.
- **Crowd blending in multiplayer.** In Assassin's Creed *Brotherhood*'s Wanted mode, each player hunts one target and is hunted by another, inside crowds that act as cover. The "Advanced Wanted" variant adds more NPCs to make targets harder to pick out [Search: [Wikipedia](https://en.wikipedia.org/wiki/Assassin%27s_Creed:_Brotherhood); [GameSpot impressions](https://www.gamespot.com/articles/assassins-creed-brotherhood-multiplayer-impressions/1100-6265687/)].
  - **Conflict noted:** popular memory says crowd NPCs shared the player models. One preview says there were six distinct player characters, randomly assigned. Whether crowds reused those models is unverified.
- **Behaviour is the tell, not appearance.** SpyParty's whole game is that the spy looks like any partygoer and gives itself away only through behaviour [Read: Hecker, above]. This is the deepest form of social stealth, covered in 3.5.

### 2.3 AI alert states

- **The standard state ladder** [Unverified, genre convention]:
  - unaware
  - suspicious or investigating ("what was that?")
  - searching (goes to the last known position)
  - combat or alarm
  - a cooled-down but heightened state that never fully returns to unaware
- **Soft-fail state.** *Invisible, Inc.*'s searching state gives the player a chance to re-hide before being caught [Search: [Game Developer — the problems of modern stealth design and how Invisible Inc. solves them](https://www.gamedeveloper.com/design/lesson-the-problems-of-modern-stealth-design-and-how-invisible-inc-solves-them)].
- **Global escalation: Klei's alarm** [Read: [Game Developer — alarm systems in Invisible, Inc. (James Lantz)](https://gamedeveloper.com/design/game-design-deep-dive-alarm-systems-in-klei-s-i-invisible-inc-i-)].
  - **First version:** 20–30 levels, rising one per turn, with *random* consequences. Playtesters couldn't tell when the next level would matter, and randomness clashed with a planning game.
  - **Redesign:** **6 levels, each split into 5 sub-ticks that do nothing.** Only full-level transitions have effects. Those effects are fixed and previewed by tooltip (for example, level 2 raises all firewalls by one; level 3 sends another patrol in).
  - **Triggers:** the alarm rises **every turn** (the most important trigger) and on certain actions (killing guards, bodies found).
  - **Naming:** renaming "ALARM" to an in-world label was called "small but effective".
  - **Goal:** "tension rather than difficulty". Because the clock adds pressure, each starting situation could be made *easier*.
  - **Honest caveat:** the system "feels unfair to many players" who expect classic stealth patience. Better framing would have helped.
- **Long-term adaptation.** *Metal Gear Solid V*'s enemy-preparedness system makes soldiers adapt to habits over many missions. Repeated headshots lead to helmets, repeated night ops lead to night-vision goggles, and gas attacks lead to gas masks [Search: [Metal Gear Wiki — Revenge System](https://metalgear.fandom.com/wiki/Revenge_System_(enemy_preparedness)); fan-wiki-level, design intent not stated by the developer].
  - This pushes players to vary their tactics and makes the world feel like it remembers.
- **Last-chance window.** MGSV's slow-motion window on detection gives one chance to neutralise the spotter before the alarm, with a score bonus for turning it off [Search: same; [GameSpot — Ground Zeroes "making failure fun"](https://www.gamespot.com/articles/how-metal-gear-solid-5-ground-zeroes-revitalises-stealth-by-making-failure-fun/1100-6418681)].

### 2.4 Fail-forward design

Thinly sourced; mostly commentary.

- **Getting caught should feel like an avoidable mistake.** That needs clear readouts of what enemies perceive and tools to recover. Defensive designs with few options collapse into trial and error [Search: [Game Developer — reactive vs active stealth](https://www.gamedeveloper.com/design/reactive-vs-active-stealth-in-game-design)].
- **Fail-forward ladder** [Unverified, synthesis]: spotted, then suspicion (talk your way out or leave), then local alert (hide or change disguise), then district lockdown (escape), then capture (interrogation or escape sequence; the mission continues in a worse state). Mission failure should be rare, and a mission should almost never restart from scratch.
- **Payday 2's stealth tools** (limited body bags, the pager system, randomised mission parts) give some recovery and replay variety. One critic argues spotting is still mostly "a wasted pager" rather than improvisation [Search: [Game-Wisdom](https://game-wisdom.com/?p=8278)].
- **Hitman** mostly uses fast save/retry rather than true fail-forward. That works for a single-player puzzle box but **not in persistent multiplayer** [Search].

### 2.5 What makes infiltration levels replayable

- **Many entry routes and many kill or objective methods** within one dense space; the Hitman model [Unverified, widely documented].
- **Randomised parts.** *Payday 2* varies safe, guard and objective placement [Search].
- **Systemic pressure instead of fixed scripts:** the alarm clock (Invisible Inc.) and adaptive enemies (MGSV) [Read/Search, above].
- **Mastery challenges and score modifiers,** such as MGSV's bonus for disabling its last-chance mechanic [Search].
- **Daily challenge seeds.** Hecker suggests a Spelunky-style daily challenge with a shared random setup [Read: Hecker].

---

## 3. Espionage-specific mechanics: what worked and what was tedious

### 3.1 Tailing and following

- **Widely disliked in its common form.** Critics call tailing "pace-killers", "reverse escort missions" and slow and linear. Black Flag and GTA are the usual examples. The **instant-fail** for being too close or too far is the main complaint [Search: [GamingBolt — objective types to stop using](https://gamingbolt.com/10-objective-types-games-need-to-stop-using/4)].
- **The fix:** *Judgment*'s tailing missions were praised for being "more forgiving" with **mid-sequence checkpoints**. The problem was insta-fail, not the mission type [Search, blog-level source].
- **Tailing as PvP works.** The original *Watch Dogs* (2014) "online tailing" mode had an invader follow a real player within a radius, unspotted, until a meter filled [Search: [Watch Dogs Wiki](https://watchdogs.fandom.com/wiki/Online_Hacking); [Prima Games](https://primagames.com/eguides/watch-dogs-eguide/online-missions/_online-tailing)].
  - Following a *human* who may turn around is tense. Following a scripted NPC on rails is not.

### 3.2 Surveillance and hacking

- **Hack anywhere, not hacking minigames.** Watch Dogs 2's "Invasion of Privacy" scenes were designed so the player could "affect and control the outcome of these scenes by hacking at any point". Surveillance becomes an input to the world, not a cutscene [Search: [Game Developer — design deep dive (Dragert)](https://gamedeveloper.com/design/game-design-deep-dive-i-watch-dogs-2-i-s-invasion-of-privacy-missions)].
- **Minigames that become separate games are a trap.** Obsidian's lead designer on *Alpha Protocol*: "We had these mini-games that were clearly not fun, nobody liked them." They grew into "several minutes of 'this is a whole new game in and of itself'". The team wanted them cut, the publisher kept them, and they were salvaged only by making them shorter [Read: [Game Developer — Alpha Protocol cuts](https://gamedeveloper.com/design/-i-alpha-protocol-i-devs-share-how-cutting-features-helped-refocus-development)].
- **Lesson** [Unverified, synthesis]: surveillance should be quick verbs (tap a camera, plant a bug, read a phone) whose *results* drive play. Avoid long abstract puzzles.

### 3.3 Gadgets

- **Use gadgets as systemic verbs that interact with the AI model**, such as a distraction noise, a camera loop or a disguise kit. Avoid one-off key items [Unverified].
- **Let the world adapt to gadget overuse.** MGSV's gas masks appear after repeated gas use [Search, above]. This counters dominant strategies without nerfing the tool.

### 3.4 Dialogue and social engineering

- **Alpha Protocol** is the cautionary and inspiring case. Reviewers consistently praised its consequence-heavy, branching dialogue and choices as its "biggest strength". Its shooting and stealth were widely panned, and many missions "devolve into mindless shooting" [Search: [Hardcore Gaming 101](https://www.hardcoregaming101.net/alpha-protocol/); [RPGFan](https://www.rpgfan.com/review/alpha-protocol/)].
  - The specifics of its timed "stance" dialogue are **unverified** in this research. No source on it was read.
  - The developers also cut parkour, chase sequences, environmental interaction and longer minigames after a "coming to Jesus" meeting, and said cutting "revitalized a lot of the team" [Read: Game Developer, above].
- **Lesson:** a spy game can lean on talk and choices if the core movement and stealth verbs are solid. Weak core verbs drag the whole game down regardless of writing [Unverified, synthesis].
- **Systemic dialogue.** A Hangar 13 GDC 2017 talk covers *Mafia III*'s system-driven dialogue [Search, not read: [Game Developer video](https://gamedeveloper.com/design/video-designing-i-mafia-iii-i-s-system-driven-dialogue)]. That model suits a small team: barks assembled from state, not hand-written scenes.

### 3.5 Asymmetric and deception multiplayer

- **SpyParty (Chris Hecker)** [Read: [Game Developer](https://gamedeveloper.com/design/ai-hiding-among-ai-chris-hecker-on-i-spyparty-s-i-devious-single-player); Search: [Game Informer interview](https://gameinformer.com/b/features/archive/2011/06/08/chris-hecker-spy-party-interview)]:
  - **Perception versus deception.** One spy hides among AI partygoers while doing missions. The sniper watches and gets one shot.
  - **Attention is the resource.** Because the sniper can spend 100% of their attention watching, the spy's tells can be very subtle.
  - **Asymmetric in roles, symmetric in pressure.** Everyone is both chasing and being chased. Hecker notes fully asymmetric games are "really hard to balance".
  - **AI should be fallible, not stupid.** An AI watcher needs "a model that can be wrong". It should tunnel on suspects like humans do and be **explainable** after the match, through a post-game log of why it fired.
  - **Depth first, accessibility later.**
- **Spies vs Mercs** (Splinter Cell *Pandora Tomorrow* / *Chaos Theory*, then *Blacklist*) [Search: [bit-tech retrospective](https://bit-tech.net/reviews/gaming/pc/ten-years-on-chaos-theory/2/); [GameRevolution review](https://www.gamerevolution.com/review/36141-splinter-cell-chaos-theory-review)]:
  - 2v2, with third-person agile spies with gadgets against first-person armed mercs.
  - Maps looked merc-favoured on paper but were "full of little holes and avenues" for spies.
  - Slower and more thoughtful than normal online play.
  - Still remembered as rare and beloved.
  - No developer postmortem was found on how it was balanced.
- **Watch Dogs (2014) invasions** [Search: Watch Dogs Wiki, Prima, SegmentNext]:
  - The invader drops into another player's single-player world, disguised as an ordinary NPC. **The invader sees their own character; the victim sees a random civilian.**
  - The victim is alerted once hacking starts and must find the invader in the crowd before a progress meter fills.
  - Reviewers compared it to Souls-style invasions.
  - **An accidental tell:** a single-player ability stopped working during invasions, so players learned "my ability broke, so I'm being invaded". **Hidden-player state must never leak through UI or mechanic side effects.**
  - **Conflict noted:** sources disagree on whether Watch Dogs 2 kept the invasion mode or reworked it. Its heat-triggered "Bounty Hunter" mode, where 2–4 players are sent after a high-heat player, is better documented [Search: [Wikipedia — Watch Dogs 2](https://en.wikipedia.org/wiki/Watch_Dogs_2); [GamesRadar](https://www.gamesradar.com/watch-dogs-2s-bounty-hunter-mode-will-send-online-players-to-kill-you)].
- **Assassin's Creed multiplayer:** the hunter-and-hunted chain inside crowds (see 2.2).

### 3.6 Agent recruitment

**Not researched in this pass.** No sources were checked, so everything here is [Unverified]:

- Recruiting NPC assets is a strong fantasy: find a person with a need, build leverage, run them as a source.
- It risks becoming menu management.
- A plausible small-scope form: recruited NPCs become **map-layer services**, such as a doorman who lets you in, a cabbie for extraction, or a clerk who leaks a schedule. They are not squad members with full AI.
- Look at XCOM-style agent rosters and Watch Dogs: Legion's "recruit anyone" before designing this. Legion's reception reportedly praised the idea but called the generated characters shallow, which is unverified here.

### 3.7 Fun versus tedious summary

| Usually fun | Usually tedious |
|---|---|
| Hiding among a crowd from a *human* hunter | Tailing an NPC with instant-fail distance rules |
| Short hacks that change the world state | Multi-minute minigames that are "a whole new game" |
| Disguises that open areas, with specific NPCs who see through them | Disguises that are all-or-nothing and never fail |
| A readable escalation clock with known consequences | Random or opaque escalation |
| Getting spotted turning into a scramble or escape | Getting spotted equals restart |
| AI that can be fooled and explains its suspicion | AI that is omniscient or visibly dumb |

---

## 4. Multiplayer design for open worlds

### 4.1 Co-op versus PvP versus asymmetric

- **Co-op** is the safest fit for a small game: no balance arms race, works with friends, no stranger griefing [Unverified].
- **Free-roam PvP** in a shared city historically breeds griefing (4.4).
- **Asymmetric spy versus spy** is the genre's most distinctive form: SpyParty, Spies vs Mercs, Watch Dogs invasions, AC Wanted. It is also the hardest to balance, in Hecker's words. The well-loved examples are **small and bounded** (1v1, 2v2, or a short round) [Search/Read, above].
- **Opt-in invasions and contracts, triggered by state.** Watch Dogs 2's Bounty Hunter mode was triggered by high police heat [Search]. That ties PvP to a choice the victim made, which feels fairer than random ganking.

### 4.2 Session sizes

Thinly sourced. Session sizes are **unverified** in this research. The genre examples above cluster at 1v1 to 4v4, and that range suits both small servers and a hobby budget [Unverified]:

| Mode | Suggested size |
|---|---|
| Co-op story or ops | 1–4 players |
| Asymmetric deception rounds | 1v1 to 2v2 |
| Opt-in bounty or hunter interactions | 1v1 to 1v3 |

### 4.3 Making a world feel alive with few players

- **AI does the populating; players are the spice.** A crowd of 100+ cheap AI with a few humans hidden among them is *more* tense than a crowd of humans. It is also what makes deception modes work at all: SpyParty and Watch Dogs invasions [Read/Search].
- **Asynchronous presence.** Death Stranding's system has players leave structures (roads, bridges, shelters) and items in each other's worlds without ever sharing a session. Analysts call shared structures the element that most "populates the barren environs" [Search: [Shacknews — Director's Cut](https://shacknews.com/article/125784/a-big-goal-of-death-stranding-directors-cut-was-improving-the-asynchronous-multiplayer); [MP1st](https://mp1st.com/news/death-stranding-multiplayer-to-offer-asynchronous-gameplay-no-player-will-ever-cross-paths)].
  - Spy translations: dead drops, chalk marks, safehouses, and intel left by other players.
- **Daily or shared seeds** let everyone face the same scenario and compare results [Read: Hecker].
- **Persistent world state driven by all players** [Unverified]. For example, a district's security posture rises because many players hit it this week. This is MGSV-style adaptation applied to the whole server.

### 4.4 Griefing prevention

These lessons come from GTA Online [Search: [MP1st — Bad Sport](https://mp1st.com/features/gta-online-dear-rockstar-fix-get-rid-bad-sport-system); [GTABOOM — passive mode](https://www.gtaboom.com/GTA_Online%27s_Passive_System_Might_Need_Tweaks); press-level sources]:

- **Sorting players into "bad sport" lobbies** separated griefers but also punished victims who defended themselves, and it was later dropped.
- **Passive or opt-out modes** got exploited by griefers toggling them, which forced long cooldowns. They also never covered every harm, such as cargo destruction.
- **The most lucrative activities required public lobbies,** which pushed players into harm's way. *Incentives create griefing.*
- **Design takeaway** [Unverified, synthesis]:
  - Make PvP **structurally opt-in**: separate modes, or contracts consented to through gameplay state.
  - Never put the best rewards behind exposure to strangers.
  - Do not ship open free-roam PvP at all at this scale.
  - Friends-only co-op sessions remove most griefing by construction.

---

## 5. Production craft for a tiny team

### 5.1 Find the fun first

- **GTA found its fun in an emergent chase** after ~30 months, almost too late [Search, above]. Prototype the systemic toy *before* building content.
- **A common anecdotal pattern:** open-world projects fail by building outward (levels, content, features) before confirming the core is fun. A standard piece of advice is to make one core verb excellent, such as just walking through the world, before adding content [Search: devlog- and blog-level sources, weak]. Marketing-blog "postmortems" found in search were excluded as unverifiable.

### 5.2 Vertical slice, milestones and playtesting

Thinly sourced; [Unverified] craft practice:

1. **Toy prototype:** greybox, no art. Is the moment-to-moment verb fun?
2. **System prototype:** two or three interacting systems (detection, crowd, heat) in one block. Can players make stories?
3. **Vertical slice:** one district, one mission chain, final-quality look in a small area, the full loop from briefing to heat to escape to payoff.
4. **Content production:** only now add more missions or districts by recombining proven systems.

- **Playtest by watching, not asking.** Klei's alarm redesign came straight from watching players misread a 20-level meter [Read: Lantz].
- **Fix forward or cut.** Alpha Protocol's minigames were not saved by iteration. They were cut down [Read].

### 5.3 Why ambitious indie open-world projects fail

- **Tech before game.** Introversion's *Subversion* had "a highly impressive but questionably important procedural city generator". After about 6 years of part-time development, its developer wrote "we had lost our way" and that it needed "a total rethink from top to bottom". It was shelved in 2011. Its tech was reused for the much more focused *Prison Architect* [Search: [MCV](https://www.mcvuk.com/subversion-dropped-after-six-years-development/); [PC Gamer](https://www.pcgamer.com/introversions-chris-delay-on-shifting-from-subversion-to-prison-architect-i-wanted-to-build-alcatraz); [Destructoid](https://destructoid.com/introversion-shelves-subversion-announces-new-project)]. **This is the single most relevant warning for this project:** a procedural espionage city that never became a game.
- **Feature creep and underestimated polish** [Search, weak sources].
- **Technical debt.** The *Against the Storm* team at GDC 2024: "Every hastily written line of code and patchwork solution you do today is extra work you have to do tomorrow" [Search: [secondary report](https://jikguard.com/news/how-the-small-team-behind-against-the-storm-kept-scope-in-check)].

### 5.4 Small teams that shipped open worlds, and what they cut

- **Kenshi** (Lo-Fi Games; Chris Hunt, roughly 12 years, mostly solo early on) [Search: [PC Games Insider](https://www.pcgamesinsider.biz/indie-interview/68200/surviving-steam-greenlight-and-decade-of-development-with-lo-fi-games-chris-hunt/); [Wikipedia](https://en.wikipedia.org/wiki/Kenshi_(video_game)); cut list from a fan-forum transcription, treat with care]:
  - **Cut:** wall breaking, climbing, controller support, mounts, egg hatching and taming, and a mission system ("removed due to complications").
  - **Kept:** a systemic sandbox where stories emerge.
  - **Asset limits** forced careful reuse of creatures and models.
  - **Early-access revenue** let Hunt go full-time.
- **Shadows of Doubt** (ColePowered; a tiny team, roughly 7 years) [Search: [DevBlog #21 — How Voxels Saved the Project](https://colepowered.itch.io/shadows/devlog/133150/shadows-of-doubt-devblog-21-how-voxels-saved-the-project); [PC Gamer review](https://pcgamer.com/games/sim/shadows-of-doubt-review)]:
  - A fully simulated procedural city where every room is enterable. It is the closest existing proof that a tiny team *can* ship a systemic city stealth or detective game.
  - **The enabling cut was art style:** going voxel was "perhaps the biggest decision in actually making this ambitious project actually somewhat do-able with a small team and small budget".
  - **Reviews flagged repetition.** Generated cases started to feel alike. Procedural breadth does not replace authored variety.

---

## 6. Recommendations for *Spycraft International*

These are recommendations, built on the sources above. All feature names below are original placeholders.

### 6.1 Proposed core loop

**Minute to minute: "Blend, observe, act, slip away".** Walk a dense district as a civilian. Read the crowd and the security. Take one decisive covert action (photograph, plant, swap, lift, meet). Get out before suspicion turns into pursuit.

**Operation loop (10–20 minutes):**

1. **Brief.** A handler gives a goal with several possible approaches.
2. **Recon.** Observe, tag people and cameras, learn schedules.
3. **Prep.** Pick a cover outfit, gadgets, and an exfil route; optionally call in an asset.
4. **Execute.** Social stealth inside public and private spaces.
5. **Exfil.** Shake any heat through crowds, transit or a safehouse.
6. **Debrief.** Pay, reputation, and a readable log of what gave you away.

**Campaign loop:** new contacts, districts, gadgets and cover identities. The city's security adapts to your habits.

### 6.2 "Exposure" system (replaces a wanted level)

The system has three separate layers, so mistakes have proportional consequences.

1. **Local suspicion (per NPC, seconds).**
   - A fuzzy meter fills based on distance, cone or periphery, lighting, the player's *behaviour* (running, loitering in private spaces, carrying contraband) and the *disguise versus space* rule.
   - It decays when you break contact.
   - Specific "sharp-eyed" NPC roles see through specific covers.
   - Every suspicious NPC shows a readable indicator.
   - Basis: GMTK fuzzy detection; Hitman disguise and enforcer pattern.
2. **Operation exposure (per operation, minutes): 6 named tiers.**
   - Based directly on Lantz's lessons: few readable tiers, quiet sub-ticks, **fixed and previewed consequences per tier**, a slow time-based rise as the main driver, plus spikes from loud events.
   - Use an in-fiction label (for example "Station Alert", placeholder).
   - Example tiers:

     | Tier | Effect |
     |---|---|
     | 0 | Normal |
     | 1 | Extra camera watchers |
     | 2 | Doors to private spaces lock and need better covers |
     | 3 | Plainclothes counter-agents enter the crowd |
     | 4 | Checkpoints on district exits |
     | 5 | Lockdown and active manhunt |
   - **Fail-forward at the top:** capture leads to an interrogation or escape sequence, not a mission restart.
   - **Show a "time to next tier" preview** and frame the clock in the fiction. Lantz warns a time-based alarm "feels unfair to many players" without that framing.
3. **Cover burn and city memory (persistent, days).**
   - **Burned covers:** a cover identity seen doing something illegal becomes "burned" in that district for a while. The player must switch identities, which creates a fun resource to manage.
   - **City adaptation:** at the district level, the city adapts to repeated tactics in the MGSV pattern. Lots of rooftop entries bring more rooftop watchers. Lots of tranquilizer use brings guards in protective gear. This pushes variety without forcing it.

### 6.3 The 7 mechanics to prototype first, in order

1. **Crowd blend and suspicion meter.** One plaza, about 100 cheap crowd agents, with promotion to full NPC when close. This is the whole game's medium.
2. **Disguise versus space rules.** Two or three public and private space types (Andersen's taxonomy) and three covers, with one "sharp-eyed" role per cover.
3. **Exposure tiers.** The 6-tier operation clock with fixed consequences and a visible preview.
4. **Shake the tail (escape).** Break line of sight, blend, change outfit, take transit. The search zone decays. This must be fun on its own.
5. **One quick surveillance verb.** Photograph or bug, with results that change the world (a schedule revealed, a door code learned). Under 10 seconds, no puzzle minigame.
6. **AI suspicion that can be wrong, and explains itself.** Watchers tunnel on the wrong person sometimes. The post-operation log shows "what gave you away" (Hecker's principle).
7. **A 1v1 "hidden agent" test.** One player hides among AI civilians doing small tasks; the other watches and has one challenge or arrest. It runs on the same crowd tech, and the hidden player's own view must differ from the other player's view. It is the cheapest test of whether multiplayer is fun.

**Stretch, if those work:** a forgiving tail mission against an NPC (checkpoints, recoverable "lost them" states, no instant fail), and recruitable assets as map services.

### 6.4 Multiplayer recommendation

- **Ship order:**
  1. Solo, which doubles as practice for multiplayer.
  2. **2–4 player co-op operations** in a private session.
  3. **Opt-in asymmetric rounds** (1v1 or 2v2 hide-and-hunt in a crowd).
- **Asynchronous touches** to make the city feel inhabited: dead drops and intel left for friends, shared daily operation seeds.
- **Hidden-player rule:** no UI or mechanic side effect may reveal that a hidden human is present.

### 6.5 What NOT to attempt

- **Procedural city generation as the foundation.** That is the *Subversion* trap. Hand-build **one dense district** first. Add procedural dressing (crowd schedules, randomised guard and objective placement) only after the loop is fun.
- **A big map.** One district of a few blocks, rich in public and private spaces, beats a city of empty streets.
- **Full vehicle traffic simulation.** Use a few scripted lanes, taxis or transit as escape tools, and parked props. Driving physics and traffic AI are a separate game's worth of work.
- **Open free-roam PvP with strangers.** GTA Online's history shows lobby filters and passive modes only shift griefing around.
- **Hacking or lockpicking minigames** longer than a few seconds (the Alpha Protocol lesson).
- **Instant-fail tailing or detection.** Every failure should hand the player a worse but playable situation.
- **Large hand-written dialogue trees.** Use systemic barks and short choice moments. Get the stealth verbs right before the writing.
- **Feature names, characters or setups from any cited game.** Mechanics above are described generically on purpose.

---

## Source list (canonical URLs)

**Read in full**
- Game Developer — Hitman social cues / level design (Andersen, GDC 2019): https://gamedeveloper.com/design/mapping-out-the-subtle-social-cues-throughout-i-hitman-i-s-level-design
- Game Developer — Alarm systems in Invisible, Inc. (Lantz): https://gamedeveloper.com/design/game-design-deep-dive-alarm-systems-in-klei-s-i-invisible-inc-i-
- Game Developer — Hecker on SpyParty single-player AI: https://gamedeveloper.com/design/ai-hiding-among-ai-chris-hecker-on-i-spyparty-s-i-devious-single-player
- Game Developer — Alpha Protocol devs on cutting features: https://gamedeveloper.com/design/-i-alpha-protocol-i-devs-share-how-cutting-features-helped-refocus-development

**Search summary only (not fully read)**
- GDC Vault — Crowds in Hitman: https://gdcvault.com/play/1015315/Crowds-in-Hitman
- Intel / IOI Hitman 2 slides: https://www.intel.com/content/dam/develop/external/us/en/documents/06-create-a-scalable-and-destructible-world-in-hitman2-807276.pdf
- Game Developer — The AI of Hitman (2016) (fetch failed): https://gamedeveloper.com/design/the-ai-of-hitman-2016-
- GMTK School of Stealth (Amara transcript): https://amara.org/videos/4SwBdOk0E4LH/en/3100597
- Game Developer — Invisible Inc. and modern stealth problems: https://www.gamedeveloper.com/design/lesson-the-problems-of-modern-stealth-design-and-how-invisible-inc-solves-them
- Game Developer — Reactive vs active stealth: https://www.gamedeveloper.com/design/reactive-vs-active-stealth-in-game-design
- Game-Wisdom — Payday 2 and stealth: https://game-wisdom.com/?p=8278
- Metal Gear Wiki — enemy preparedness: https://metalgear.fandom.com/wiki/Revenge_System_(enemy_preparedness)
- GameSpot — Ground Zeroes making failure fun: https://www.gamespot.com/articles/how-metal-gear-solid-5-ground-zeroes-revitalises-stealth-by-making-failure-fun/1100-6418681
- Watch Dogs Wiki — Online Hacking: https://watchdogs.fandom.com/wiki/Online_Hacking
- Prima — Watch Dogs online tailing: https://primagames.com/eguides/watch-dogs-eguide/online-missions/_online-tailing
- Game Developer — Watch Dogs 2 Invasion of Privacy deep dive: https://gamedeveloper.com/design/game-design-deep-dive-i-watch-dogs-2-i-s-invasion-of-privacy-missions
- Wikipedia — Watch Dogs 2: https://en.wikipedia.org/wiki/Watch_Dogs_2
- GamesRadar — Watch Dogs 2 Bounty Hunter: https://www.gamesradar.com/watch-dogs-2s-bounty-hunter-mode-will-send-online-players-to-kill-you
- Wikipedia — Assassin's Creed: Brotherhood: https://en.wikipedia.org/wiki/Assassin%27s_Creed:_Brotherhood
- GameSpot — AC Brotherhood multiplayer impressions: https://www.gamespot.com/articles/assassins-creed-brotherhood-multiplayer-impressions/1100-6265687/
- bit-tech — Ten Years On: Chaos Theory: https://bit-tech.net/reviews/gaming/pc/ten-years-on-chaos-theory/2/
- GameRevolution — Chaos Theory review: https://www.gamerevolution.com/review/36141-splinter-cell-chaos-theory-review
- Game Informer — Hecker SpyParty interview: https://gameinformer.com/b/features/archive/2011/06/08/chris-hecker-spy-party-interview
- Hardcore Gaming 101 — Alpha Protocol: https://www.hardcoregaming101.net/alpha-protocol/
- RPGFan — Alpha Protocol review: https://www.rpgfan.com/review/alpha-protocol/
- Game Developer — Mafia III system-driven dialogue (video): https://gamedeveloper.com/design/video-designing-i-mafia-iii-i-s-system-driven-dialogue
- GamingBolt — objective types to stop using: https://gamingbolt.com/10-objective-types-games-need-to-stop-using/4
- TechRadar — Star Wars Outlaws wanted system: https://www.techradar.com/gaming/consoles-pc/the-star-wars-outlaws-wanted-system-is-very-difficult-at-the-highest-level-it-becomes-a-toy-says-developer
- Wikipedia — The Image of the City: https://en.wikipedia.org/wiki/The_Image_of_the_City
- Wellesley — open-world elements poster: https://cs.wellesley.edu/~pmwh/mvmap/posters/open_world_elements/IOOW_Poster.pdf
- Engadget — Race'n'Chase design docs: https://www.engadget.com/2011/03/22/race-n-chase-original-gta-design-docs-posted/
- Prima Games — Race'n'Chase to GTA: https://primagames.com/gaming/racenchase-gta-dma-design-feature
- MP1st — GTA Online Bad Sport: https://mp1st.com/features/gta-online-dear-rockstar-fix-get-rid-bad-sport-system
- GTABOOM — passive mode: https://www.gtaboom.com/GTA_Online%27s_Passive_System_Might_Need_Tweaks
- Shacknews — Death Stranding DC async multiplayer: https://shacknews.com/article/125784/a-big-goal-of-death-stranding-directors-cut-was-improving-the-asynchronous-multiplayer
- MP1st — Death Stranding asynchronous: https://mp1st.com/news/death-stranding-multiplayer-to-offer-asynchronous-gameplay-no-player-will-ever-cross-paths
- MCV — Subversion dropped: https://www.mcvuk.com/subversion-dropped-after-six-years-development/
- PC Gamer — Subversion to Prison Architect: https://www.pcgamer.com/introversions-chris-delay-on-shifting-from-subversion-to-prison-architect-i-wanted-to-build-alcatraz
- Destructoid — Introversion shelves Subversion: https://destructoid.com/introversion-shelves-subversion-announces-new-project
- Against the Storm scope (secondary report of GDC 2024): https://jikguard.com/news/how-the-small-team-behind-against-the-storm-kept-scope-in-check
- PC Games Insider — Kenshi / Chris Hunt: https://www.pcgamesinsider.biz/indie-interview/68200/surviving-steam-greenlight-and-decade-of-development-with-lo-fi-games-chris-hunt/
- Wikipedia — Kenshi: https://en.wikipedia.org/wiki/Kenshi_(video_game)
- ColePowered DevBlog #21 — Voxels: https://colepowered.itch.io/shadows/devlog/133150/shadows-of-doubt-devblog-21-how-voxels-saved-the-project
- PC Gamer — Shadows of Doubt review: https://pcgamer.com/games/sim/shadows-of-doubt-review

**Deliberately excluded:** GTA VI police-AI "reports" (the game's systems are not publicly documented; these are leak or fan sites), AI-generated tutorial and summary-farm pages, and a tool vendor's "postmortem" blog posts that could not be verified.

**Not researched (gaps for a later pass):** agent recruitment mechanics; concrete wanted-level tuning numbers; traffic simulation implementation; netcode and session architecture; Journey-style anonymous co-op.
