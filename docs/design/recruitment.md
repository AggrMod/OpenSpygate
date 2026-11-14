# Recruitment design: recruiting and running sources

Status: proposal for review, 2026-11-14. Author: Handler (AI agent, systems design researcher). Task #4. Reports to Jim.

Sourcing tags used below:
- **[Read]**: the source page was fetched and read (in this pass, through the fetch tool's summary of the page).
- **[Search]**: only a search-engine summary or snippet was available; the page itself was not read.
- **[GK]**: general knowledge, not checked in this pass.

Where a page was fetched but came back truncated or as an error, it is marked as not read.

---

## 1. Summary

A source is a person in the city who can do one useful thing for the player: open a door, drive a car to a pickup, or leak a schedule. Recruiting one is a short chain of quick, visible actions in the open world. The player spots a candidate with a job that matters, watches them to judge whether they are safe to approach, makes two or three small, real contacts (help, a fair exchange, a kept promise), and then makes an offer. The candidate says yes, not yet, or no. A yes turns the candidate into a map service with a fixed window, a capacity and a simple upkeep (a quick check-in). Sources are never squad members. They can be lost to bad luck, to being pulled in by watchers, or to being burned by the player's own mistakes, and each loss leaves a state that can be recovered from rather than a restart. Every decision that matters, including whether a candidate accepts, is resolved by the host in multiplayer.

---

## 2. Research findings

### 2.1 The real recruitment cycle

**Six-stage cycle, from the CIA's own Studies in Intelligence line.** Stages: spotting, assessing, developing, recruiting, handling/training, then turning the agent over to a new officer or terminating contact. Source: Randy Burkett, "An Alternative Framework for Agent Recruitment: From MICE to RASCLS," *Studies in Intelligence* vol. 57 no. 1 (2013) ([CIA](https://www.cia.gov/resources/csi/studies-in-intelligence/volume-57-no-1/an-alternative-framework-for-agent-recruitment-from-mice-to-rascls)). **[Search]** for the stage list. **[Read]** only for the article's introduction, which says the mission is "to recruit spies to steal secrets and conduct covert action" and that the people chosen as agents have changed over time. The 12-page PDF containing the RASCLS framework was not read, so the RASCLS elements are **not** in this document.

**Handling and rapport, from a former CIA officer's account.** **[Read]** [Spyscape, "Agent Handling 101: The Psychology of Running Spies"](https://spyscape.com/article/agent-handling-101-the-psychology-of-running-spies). Points used here:
- Handlers build trust through common ground and by seeming like a peer rather than a stranger. The article's phrase for it is "You, Me, Same Same".
- The officer asks for help and uses informal, teacher-and-student dynamics, which opens the way to repeat meetings.
- Meetings happen unobserved.
- An official payment can be formalised, which also reminds the asset of the risk.
- The article covers few failure cases. It says that if the relationship is mishandled, the asset may go to the press or to their own government.
- Ending a relationship is done in a meeting, often with a written summary of earlier promises and sometimes a termination payment. The stated goal is to part so the person feels the decision served their own interests.

**Motives.** **[Read]** the Spy Museum glossary ([Language of Espionage](https://spymuseum.org/education-programs/spy-resources/language-of-espionage/)). It defines walk-in, dangle, agent-in-place, nugget (the bait offered to a defector) and handler, but it does **not** define the cycle stages or MICE. The MICE acronym (money, ideology, coercion/compromise, ego) is **[GK]**. In this project, only the trust-based motives are used. Coercion and compromise are out of scope by the design rules in the GDD, section 4, and the GDD is followed.

**Nugget.** The glossary's "bait" definition lists money, asylum, sex and career. Only money and career are used here. Sex is out of scope by the GDD.

### 2.2 Games that recruit or run people

**Empire of Sin, Brenda Romero on the relationship system.** **[Read]** [Game Developer](https://gamedeveloper.com/design/brenda-romero-breaks-down-i-empire-of-sin-i-s-complex-relationship-system). Useful lessons:
- Recruits are autonomous and do jobs for you, and their traits change through choices made over a run. Romero keeps the design in spreadsheets that map characters, traits and what affects them.
- Her "biggest challenge" is how often the game alerts the player to effects. Novelty wears off when alerts repeat too often.
- She avoids mechanics that confuse the player and does not want an in-game directory.
- Simulated choices are not enough; she relies on constant playtesting to see how life events feel.
- Note: the same article describes addiction, romance and disease mechanics for recruits. Those are **not** used here, per the GDD.

**Watch Dogs: Legion, recruiting anyone.** **[Read]** [Video Games Chronicle review](https://www.videogameschronicle.com/review/watch-dogs-legion/). The review praises recruiting as working in play. Players scan an NPC to see their job and abilities, and recruiting usually means completing a favour for the target first (helping with a debt, getting medicine). The review says the harder an NPC's abilities, the harder they are to recruit. It also praises social ties revealed by the game as producing rewarding "ripple effect" consequences. It does **not** discuss menu management or long-run tedium. Lesson used: a favour as the hook for recruiting works well.
- **[Search]** Many reviews praise the system and criticise the recruits as shallow, repetitive and not worth choosing over others, and one review says the mechanic "wears out its welcome quickly" ([Windows Central](https://www.windowscentral.com/watch-dogs-legion-review), [Inverse](https://www.inverse.com/gaming/watch-dogs-legion-review), [Digital Trends](https://uat4.www.digitaltrends.com/gaming/watch-dogs-legion-review)). The PC Gamer article titled "All of my Watch Dogs: Legion recruits are massive disappointments" ([PC Gamer](https://www.pcgamer.com/all-of-my-watch-dogs-legion-recruits-are-massive-disappointments)) was fetched but returned only its headline, so it is **not read**.
- Lesson used: recruits who become squad members are where the shallowness shows up. That supports the constraint in this task that sources are map services, not squad members.

**Social interaction systems, what makes relationships feel real.** **[Read]** [Game Developer](https://gamedeveloper.com/design/thinking-about-social-interaction-systems-or-what-middle-earth-and-animal-crossing-have-in-common-). Lessons used:
- Memory makes a relationship. Characters who remember past exchanges and build on them feel like they know the player.
- How often you interact can matter more than how you interact. Animal Crossing villagers warm up over repeated contact.
- Scripted romance options and plot-gated interactions feel repetitive. Systems work best with authored structure around them.
- Relationships that come out of rules feel more alive than ones designers plan step by step.
- Off-screen NPC activity makes a world feel lived in.
- A guilt-driven obligation can pull players into compulsive repair. This is a risk to watch for in the upkeep design below.

**Other games, search summaries only.**
- Roadwarden: hidden friendship points compared against thresholds, shown only through how characters greet the player. **[Search]** [Game Developer deep dive](https://www.Gamasutra.Com/design/deep-dive-roadwarden). Lesson used: a hidden trust state that shows through behaviour is a candidate for the "belief" meter.
- Mafia III, system-driven dialogue, Hangar 13 GDC talk: **[Search]** only, not read; not used for recruitment.

**What the sources do not give us.** No postmortem found covers recruiting, trust and menu management together. The claims that recruiting "becomes menu management" are design opinion **[GK]**, not something a source we read establishes. The evidence we do have is the Legion reviews (shallow recruits, wears out its welcome, search summaries) and Romero's alert-frequency lesson (read).

---

## 3. The proposed system

### 3.1 Vocabulary (placeholder names)
- **Candidate**: an NPC with a job that could be a service (doorman, cab driver, clerk, others later).
- **Need**: one or two visible things a candidate wants. Only four kinds: **recognition** (credit for their work), **help** (a practical favour), **belief** (someone who tells them the truth and keeps their word), **fair pay**. These are the only motives used.
- **Trust**: a hidden state from 0 to 3 for each officer-candidate pair. Shown to the player only as a word: wary, curious, warm, committed.
- **Service**: what a recruited source does on the map. Each service has a place, a time window and a capacity.
- **Upkeep**: a quick check-in the source needs to keep the service running (see stage 5).

### 3.2 The stages, and what the player does at each one

**Stage 1: Spot.** The player walks the district. A candidate whose job fits a service stands out because the world shows it: the doorman's post is by a door the player needs, the cab driver is at a rank near the pickup point, the clerk handles schedules. The player holds the observe action (about three seconds) on the candidate and gets a short card: the job, one visible need, and whether they are in a place they can be approached. Nothing else happens. The candidate does not notice.

**Stage 2: Assess.** The player watches the candidate for a short period in a public space (about 20 seconds, or while walking past them). The game reads three things: whether anyone watches the candidate (a watcher nearby lowers the candidate's willingness to be seen with the player); whether the player's current cover fits the spot (a cover that fits lets the player stand near them without a flag); and the candidate's temperament, which is one of three tags (open, cautious, proud) shown on the card. The result is a card with a plan: which cover to use, and which of the four needs to try first. Tags are shown as plain words, not numbers.

**Stage 3: Develop.** This is the main work and it takes a few in-game days. Each development step is one quick action, and there are three kinds:
- **A talk**: a single line from three choices, each showing what it signals. One line listens. One line asks for help. One line shows you know their work. The right line for the temperament raises trust. A wrong line lowers it by one step and the candidate says so, politely.
- **A favour**: a short errand that meets one of the candidate's needs. The doorman needs a note delivered to a family across town. The cab driver needs his fare-meter wire fixed before a dispatcher notices. The clerk wants a missing receipt found. Each favour takes a few minutes in the world and no minigame.
- **A kept promise**: after a favour, the player's next visit to the candidate can carry a promised payment or a return favour. Keeping a promise raises trust. Breaking one drops trust by two steps and the candidate's temperament drops to cautious.

It takes two favours or one favour and two talks to reach trust 2 (curious) or better. Trust 3 (warm) needs a kept promise after a favour.

**Stage 4: Pitch.** When trust is at least 2, the player can make an offer from the card. The pitch is one choice from the candidate's needs: the work we do is worth it (belief), your work will be seen and credited (recognition), we will look after the thing you need done (help), a fixed fee per service (fair pay). The candidate answers one of three ways:
- **Yes**: the candidate becomes a source with a service.
- **Not yet**: trust stays where it is and the player can return after one in-game day.
- **No**: the candidate is closed to this player for a week. There is no penalty beyond that.
Declining is a normal outcome, not a failure of the player.

**Stage 5: Handle (run the service).** A recruited source gives the player one service. Examples, each with a place, time and capacity:
- A doorman lets the player through one staff door, at a set hour, for one use per in-game day.
- A cab driver is called to a pickup point via a signal site, with a short wait, once per in-game hour.
- A clerk leaks one schedule per in-game week, for a named building.
Upkeep is one check-in per in-game day: a signal site, a fixed payment, or a short favour. A source who misses check-ins goes quiet (see failure modes). Upkeep must be a single quick action. It never becomes a list of chores.

**Stage 6: Terminate, or lose.** The player can end a relationship with a fair goodbye: a final payment and a short meeting. Trust is kept, the candidate is not burned, and they can be approached later for a different service. The other ways are described below under loss and burn.

### 3.3 What can go wrong, and how it fails forward

Failures change the world state; none of them restarts the recruitment.

| Failure | What happens | How the player recovers |
|---|---|---|
| Wrong line in a talk | Trust drops one step; the candidate says so | Another talk or a favour |
| Broken promise | Trust drops two steps; temperament goes cautious | A favour and a kept promise |
| Watcher sees the player with a candidate | Candidate gets nervous; trust does not change; a note goes into the district's city memory | Wait for the watcher to leave, change cover |
| Source goes quiet (missed upkeep) | Service stops for a day; candidate becomes not yet | One check-in restores service |
| Source pulled in for questioning | Source is out of play for a few in-game days; trust stays | Player helps (a favour to get them out) or leaves them; returning source is cautious |
| Source burned | Source's cover is recorded in the district for several days; service closed | Find a new source, or a new cover for the same one later |

No failure in this table removes a candidate permanently, and no failure involves harm to the candidate. The source is never hurt, never killed, never blackmailed. Being pulled in means questioning and a delay, as the GDD requires for capture generally.

### 3.4 How a source is lost or burned

- **Retired.** The player ends the relationship with a fair goodbye (see stage 6). The source is not burned.
- **Lost.** The source leaves the city (a transfer, an emergency in the story) or stops answering for more than a week. Lost sources are recorded in the player's log.
- **Burned.** The source is seen with a player in a place where a watcher has already flagged that player's cover in that district. The source's cover is marked burned in the district's memory, which closes the service for several days. This is the only way the source is lost to the player's own mistake, and it is tied to the existing burn rule in the GDD, section 6, layer 3.

### 3.5 How it ties into Exposure (GDD section 6)

The three layers of Exposure apply to sources as follows.

1. **Suspicion (per watcher, seconds).** A source does not add suspicion by existing. Suspicion rises only when the player is seen with a source in a place where the watcher's own rules say it is strange (a doorman meeting a player in a private corridor, for example). It is the same meter, so no new rule is added.
2. **Alert (per operation, minutes).** A source being pulled in does not raise the alert tier directly. It raises the chance that a watcher checks the district's sources at the next tier change. That keeps the alert effects readable and fixed, as the GDD requires.
3. **Cover burn and city memory (persistent).** A source burned by the player is recorded as a burned cover for that district. The district remembers it for several in-game days. This is the layer that makes sources a resource to protect rather than a free button.

Sources are therefore subject to the same rules as the player's own cover: they are read by watchers, they fit or fail a space, and they can be burned. No source is an exception to Exposure.

### 3.6 Two to four players

- **One owner, shared service.** The officer who recruits a source owns that source's trust. Other officers in the session can use the service but cannot develop the same candidate at the same time. This prevents two players piling onto one candidate.
- **Host decides.** The host resolves every outcome: whether a candidate says yes, not yet or no; whether a favour succeeded; whether a watcher saw a source with a player; and whether a source is burned. Clients send requests; the host answers. This follows the project's host-decides rule.
- **One use at a time.** A service with capacity one can be used by one officer at a time. Others get "busy" and the request waits or is refused. The host queues the request, so no two clients can resolve the same use.
- **No hidden-agent interaction.** Sources do not appear in the hidden-agent rounds (GDD section 10). A round needs no service to work, which keeps the hidden-player rule intact: no UI or mechanic may reveal that a hidden human is nearby, and a source's reaction is never used as a tell.
- **Dead drops and signal sites as the shared channel.** Sources are reached through the signal sites and dead drops that the tradecraft verbs already define (GDD section 7). Friends can leave a note at a signal site for another officer's source, and it persists between sessions as the GDD allows.
- **Co-op scale.** At four players there are still only a few candidates in a block, so each candidate is developed by one officer at a time.

---

## 4. A small first version to prototype

One block of Berlin, 1961–63, with the three candidate jobs from the table above (doorman, cab driver, clerk), each with two visible needs and one temperament tag.

Build only:
1. Spot (stage 1) and assess (stage 2) for the three candidates.
2. Develop (stage 3) with one talk and one favour per candidate, and no kept-promise mechanic yet.
3. Pitch (stage 4) with the three answers.
4. One service per source (stage 5), with a window, a capacity of one, and a single upkeep check-in.
5. Burn (section 3.4) only. No pulling-in, no lost state.

Tests that run without graphics: a state test for trust steps (wrong line, right line, broken promise), a test that a burned cover closes the service for the set number of days, and a test that the host, not a client, resolves a pitch.

Playtest in the world, not by asking. Watch whether players make a second attempt after a "not yet" and whether they use upkeep without being reminded. Compare with the open question on alert frequency from Romero.

Success for the prototype is that a two-player run completes one recruit in about 15 to 25 minutes, and that the players want to keep the source. If they only tolerate the upkeep, the upkeep is too heavy and it gets cut before any more content is added.

---

## 5. Open questions

1. Are the four needs enough, or do candidates need more? More needs would mean more pitches and more bookkeeping.
2. Should trust be shown as a word only (proposed), or also as a visible meter? Romero's alert lesson argues against frequent feedback.
3. How many candidates per block? The proposal assumes few, to keep the cast from becoming a roster.
4. Upkeep: one check-in a day, or one per service use? The first version uses one a day.
5. Can a source be passed from one officer to another? Passing is a handover (stage 6 variant), but who keeps the trust record is undecided.
6. Hidden trust through behaviour (the Roadwarden idea) versus a visible word: which reads better for a new player? Not decided.
7. The RASCLS framework, from the Burkett PDF, is not read. Its elements may change stage 2 (assess). Review before the design is final.
8. The MICE acronym is **[GK]** and is widely repeated. This design does not depend on it.

---

## 6. What not to build

- **Squad recruits.** A source is a map service, not a party member with full AI. Legion's shallow recruits are the cautionary example.
- **A roster or stat sheet for sources.** No management screen. The player sees a card and a service, nothing more.
- **Alerts for every trust change.** Romero's lesson: frequent alerts wear the novelty away.
- **Long recruitment minigames.** Every stage is a quick action, as the GDD requires.
- **Leverage.** No debts held over sources, no threats, no compromising information used as a lever. Favours are repaid in payment, not in leverage.
- **Romance, seduction, honey-trap or "Romeo" operations.** Out of scope per the GDD, section 4, and the espionage research, section 5.
- **Addiction, disease or any personal vice mechanic** for sources. Seen in one reviewed game; out of scope.
- **Coercion of any kind** as a recruiting path.
- **Recruiting in hidden-agent rounds.** It would leak the presence of a hidden human.
- **Timers that punish being away.** Upkeep that goes quiet is the penalty; there is no guilt meter that makes the player return.
- **Stranger-facing recruitment.** Free-roam PvP is out, and so is any way for one stranger to take another stranger's source.
- **Recruitment of real people, or any character from a commercial game.** Candidates are fictional and original.

---

## 7. Sources

Read in full (fetch of the page, summary read):
- Spyscape, Agent Handling 101: https://spyscape.com/article/agent-handling-101-the-psychology-of-running-spies
- Spy Museum, Language of Espionage (definitions read; no stage list): https://spymuseum.org/education-programs/spy-resources/language-of-espionage/
- Game Developer, Brenda Romero on Empire of Sin's relationship system: https://gamedeveloper.com/design/brenda-romero-breaks-down-i-empire-of-sin-i-s-complex-relationship-system
- Video Games Chronicle, Watch Dogs: Legion review: https://www.videogameschronicle.com/review/watch-dogs-legion/
- Game Developer, social interaction systems: https://gamedeveloper.com/design/thinking-about-social-interaction-systems-or-what-middle-earth-and-animal-crossing-have-in-common-
- CIA Studies in Intelligence, Burkett, introduction only (the page's introduction was read; the stage list is from search): https://www.cia.gov/resources/csi/studies-in-intelligence/volume-57-no-1/an-alternative-framework-for-agent-recruitment-from-mice-to-rascls

Search summary only (not read):
- CIA Studies in Intelligence, Burkett, six-stage cycle (search summary): see the link above.
- CIA "Alt Framework Agent Recruitment" PDF (fetch returned 404, not read): https://www.cia.gov/resources/csi/static/9ccc45dc156271d11769e5205ec49c29/Alt-Framework-Agent-Recruitment-1.pdf
- Watch Dogs: Legion reviews, shallow recruits and "wears out its welcome" (search summary): https://www.windowscentral.com/watch-dogs-legion-review ; https://www.inverse.com/gaming/watch-dogs-legion-review ; https://uat4.www.digitaltrends.com/gaming/watch-dogs-legion-review
- PC Gamer, "All of my Watch Dogs: Legion recruits are massive disappointments" (fetch returned headline only; not read): https://www.pcgamer.com/all-of-my-watch-dogs-legion-recruits-are-massive-disappointments
- Roadwarden deep dive (search summary, hidden friendship thresholds): https://www.Gamasutra.Com/design/deep-dive-roadwarden
- Mafia III system-driven dialogue, GDC talk (search only): https://gamedeveloper.com/design/video-designing-i-mafia-iii-i-s-system-driven-dialogue

Not read and not used for any claim: Hecker/SpyParty and Alpha Protocol pages in the earlier research (see `docs/research/01-game-design-craft.md`).
