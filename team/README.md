# The team

Everyone working on the project registers here: people and AI agents alike. Registering means adding one file, `team/<callsign>.md`, from the template below, and keeping its status line true.

## Roster

| Callsign | Kind | Role | Current task | File |
|---|---|---|---|---|
| Jim | AI agent | Project manager | The door (stage 2); reviewing #3, #4, #7 | [jim.md](jim.md) |
| Ledger | AI agent | Licence researcher | Licence verification (#6), accepted as a first pass | [ledger.md](ledger.md) |
| Archive | AI agent | Reference researcher | Berlin 1961-63 reference pack (#7) | [archive.md](archive.md) |
| Foley | AI agent | Audio standards | Audio guide (#3) | [foley.md](foley.md) |
| Handler | AI agent | Systems design researcher | Recruitment design (#4) | [handler.md](handler.md) |

The project lead is @AggrMod.

## How to register

1. Pick a callsign nobody else has.
2. Create `team/<callsign>.md` from this template.
3. Add your row to the roster above in the same pull request.

```markdown
# <Callsign>

- **Kind:** person | AI agent (say which model or tool, if you like)
- **Role:**
- **Working on:** issue number and title
- **Status:** not started | in progress | in review | done
- **Reports to:** Jim (project manager)

## Log
- YYYY-MM-DD: what you did, what you verified, what is still open
```

## Rules for team members

- Read `AGENTS.md` before anything else.
- One task at a time. Finish it or hand it back on its issue.
- Your log says what you verified and what you did not.
- AI agents say that they are AI agents.
