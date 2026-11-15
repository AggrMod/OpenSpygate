# Contributing

Thank you for wanting to build this. The aim is that anyone can pick up a task, finish it to a written standard, and have it merged without waiting on one person's taste.

## How to pick up work

1. Read [AGENTS.md](AGENTS.md), then [docs/GDD.md](docs/GDD.md) and the stage you want to help with in [docs/PRODUCTION-PLAN.md](docs/PRODUCTION-PLAN.md).
2. Find a task in [docs/TASKS.md](docs/TASKS.md) or in the issue list. Tasks marked `good first task` need no knowledge of the rest of the project.
3. Comment on the issue to claim it. A claim lapses after 14 days without a draft pull request, so nothing stays blocked.
4. Open a draft pull request early. Small pull requests are reviewed faster than large ones.
5. If you want to build something that is not on the list, open a proposal issue first, so effort is not wasted on work that cannot be merged.

Work only on the stage that is open, plus anything marked "open at any time". A stage opens when the gate of the one before it has passed. That order is what keeps a large project from becoming a pile of parts that do not fit.

## What "done" means

- **Code:** has a test that runs without graphics, passes the existing tests, follows the style in the technical design, and keeps game rules on the host side.
- **Art:** realistic and built to be looked at closely. Follows the art bible (real-world scale, material and texture standards, triangle and level-of-detail budgets, naming), comes with its source (the .blend file or the script that makes it), and includes a turntable picture and an in-game eye-level picture next to existing assets.
- **Audio:** comes with its source and licence, at the loudness and format the audio guide names.
- **Missions and writing:** follow the content rules in the design document.
- **Everything:** passes the automatic checks on the pull request.

No placeholder art. Unbuilt space in the game is void. A grey box is not a contribution; a finished small thing is.

## Originality and licences (strict)

This is the rule that protects the whole project.

- **Nothing from commercial games.** No ripped or extracted models, textures, sounds, maps, names, characters or missions. No "fan remakes" of them either.
- **No real brands or logos.** Cars, products and shops have invented makes.
- **No real living people** as characters, and no real agencies as playable factions.
- **We make our own assets.** Every model, texture, material, animation, sound, piece of music and line of writing is made by a contributor for this project. Downloaded asset packs, scanned-texture libraries, stock sounds and animation libraries are not accepted, however free their licence. This is what makes the whole library ours to give away.
- **Your work** is contributed under the project licences: MIT for code, CC BY 4.0 for everything else. Anyone may use it for anything.
- **Reference is fine, copying is not.** Study photographs and real objects for dimensions and character; do not trace them, project them onto a model, or sample them into a texture.
- **The one exception is fonts,** accepted under the SIL Open Font License with a row in `assets/LICENSES.csv`, until the project has its own.
- **Code libraries** may be used under MIT, BSD, Apache-2.0 or similar permissive licences. No copyleft code, so the project can run on any engine.
- **Tool-assisted and AI-assisted work** is welcome if you say which tool was used in the pull request, you have checked the result yourself, and the tool's terms allow the output to be released under our licences. A generative tool is a tool, like a brush; what it produces for you counts as your own work if those terms give you the rights to it.

## Sign-off

Every commit must carry a sign-off line (`git commit -s`). By signing off you state, under the [Developer Certificate of Origin](https://developercertificate.org), that you wrote the contribution or have the right to submit it under the project licences.

## Review

- The automatic checks run first. Fix those before asking for review.
- A maintainer for that area (code, art, audio, missions) checks the contribution against the written standard. Reviews are about the standard, not personal taste; if a standard is missing or wrong, propose a change to the standard.
- Two decisions belong to the project lead: the overall look, and whether the core game is fun. The look is settled at the stage 1 gate and the fun at stage 4, so later work has a fixed target.

## Maintainers

People who land several good contributions in an area are invited to become maintainers of that area, with merge rights there. The more maintainers, the more the project can take in.

## Conduct

Be decent to each other. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
