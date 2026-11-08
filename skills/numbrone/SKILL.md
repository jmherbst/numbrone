---
name: numbrone
description: Set up a "chief of staff" workflow on herdr. One HQ agent routes requests to a manager agent per project, and managers run workers in git worktrees and herdr tabs, all in parallel. Use when the user asks to set up numbrone, a chief of staff or multi-project agent workflow on herdr, or to add a project to an existing HQ.
---

# numbrone setup

You are setting up a workflow where:

- the **chief of staff** (an agent in the HQ directory) takes the user's requests, works out
  which project each belongs to, and delegates;
- each project has a **manager** agent in its own herdr workspace (`hq/<project>`);
- managers answer small things themselves and spawn **workers** for code changes. Each worker
  gets its own git worktree, its own tab in the project's workspace, and its own branch;
- workers report to their manager, and managers report to the chief.

All the mechanics live in one script, `scripts/hq` in this skill's directory. Run it with no
arguments to see its commands. Do the steps below in order. Keep the user informed in short lines.

## 1. Check prerequisites

Run these checks and fix or report anything missing before continuing:

```bash
test "${HERDR_ENV:-}" = 1 && echo "inside herdr"   # must be inside a herdr pane
herdr status                                       # server must be running
command -v git jq
herdr integration status | grep -E '^claude:'      # or the agent the user wants to use
```

- Not inside herdr: tell the user to install herdr (`curl -fsSL https://herdr.dev/install.sh | sh`),
  run `herdr`, start their agent in a pane, and run this skill again. Then stop.
- `jq` missing: suggest `brew install jq` or `apt install jq`.
- Integration not installed: offer `herdr integration install claude` (or their agent's kind).
  Ask before running it, because it writes to the agent's config.

## 2. Create the HQ directory

Ask where HQ should live (default `~/hq`). Then run:

```bash
bash <this skill's directory>/scripts/hq init <hq-dir>
```

This creates `bin/hq`, `roles/`, `tasks/`, `projects/`, `worktrees/`, `hq.conf`,
`projects.json`, and `CLAUDE.md` (the chief's instructions, with an `AGENTS.md` symlink for other
agents). Running it again upgrades the script and the role files, and leaves the user's edits to
`CLAUDE.md`, `hq.conf`, and `projects.json` alone. From here on, use `<hq-dir>/bin/hq`.

## 3. Choose the projects

Ask the user which local projects HQ should manage. Accept either a list of paths or a parent
folder. For a parent folder, list the git repos in it and let the user choose:

```bash
find <folder> -maxdepth 3 -name .git -prune | sed 's|/.git$||'
```

Give each project a short name: lowercase, dashes, at most 28 characters, starting with a letter
(usually the folder name). Each project must be a git repository.

## 4. Build context for each project

For each project, read enough to route requests to it accurately: README, CLAUDE.md/AGENTS.md,
package manifests (package.json, pyproject.toml, Cargo.toml, go.mod, ...), the top-level layout,
and `git log --oneline -20`. With more than three projects, use one parallel subagent per project.

Write `<hq-dir>/projects/<name>/context.md` in this shape:

```markdown
# <name>
<one paragraph: what this project is and who it is for>

## Stack
## Layout          <!-- the directories that matter -->
## Commands        <!-- install, dev, test, lint, build -->
## Conventions     <!-- branching, commit style, anything a contributor must know -->
## Route here      <!-- kinds of requests that belong to this project, plus keywords -->
## Not here        <!-- things that sound related but belong to another project -->
```

Then register the project with a one-line summary the chief can route on:

```bash
<hq-dir>/bin/hq add <name> <path> "<one-line summary>"
```

Show the user the list (`hq projects`) and ask whether the summaries are right.

## 5. Agent settings

Open `<hq-dir>/hq.conf` and confirm two settings with the user:

- `AGENT_KIND`: which agent runs managers and workers (default `claude`).
- `AGENT_ARGS`: workers stop at every permission prompt and show as `blocked` in herdr. If
  the user wants fewer interruptions, for Claude Code they can set
  `AGENT_ARGS="--permission-mode acceptEdits"`. This is their choice; don't pick it for them.

## 6. Start the managers

```bash
<hq-dir>/bin/hq up
```

This creates one herdr workspace per project (`hq/<name>`, in the background) and starts
`mgr-<name>` in it. Check `hq projects`: every manager should show `idle` or `done`.

## 7. Hand over

Tell the user how to start their chief of staff:

> In herdr, open a pane (or a workspace) in `<hq-dir>` and start your agent there
> (`cd <hq-dir> && claude`). It reads `CLAUDE.md`, runs `hq chief`, and from then on you
> give it requests in plain language, such as "add rate limiting to the api". It routes each one,
> delegates it, and reports back as managers make progress.

If this session is already running in `<hq-dir>`, offer to become the chief now: run
`<hq-dir>/bin/hq chief` and follow `<hq-dir>/CLAUDE.md`.

## Adding a project later

Do steps 3 and 4 for the new project, then run `hq up <name>`.
