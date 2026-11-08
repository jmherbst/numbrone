# numbrone

> numbrone is an independent community project built on top of [herdr](https://herdr.dev).
> It is not made by or affiliated with the herdr team.

**A chief of staff for your coding agents.** You give one agent requests in plain language.
It works out which of your projects each request belongs to and hands it to that project's
manager. The manager runs workers in parallel, each in its own git worktree, and everyone
reports back up. All of it runs in [herdr](https://herdr.dev), so you can watch any agent at any time.

```
                    you
                     │  "add rate limiting to the api"
                     ▼
              ┌─────────────┐
              │    chief    │  routes, delegates, keeps track       (HQ folder)
              └──────┬──────┘
          ┌──────────┴──────────┐
          ▼                     ▼
   ┌─────────────┐       ┌─────────────┐
   │  mgr-api    │       │  mgr-web    │  one per project            (herdr workspace hq/<project>)
   └──────┬──────┘       └──────┬──────┘
     ┌────┴────┐                │
     ▼         ▼                ▼
 wk-rate-   wk-fix-        wk-new-          one per code task        (herdr tab + git worktree
 limit      auth           navbar                                     on branch hq/<task>)

  reports flow back up:  worker ──▶ manager ──▶ chief ──▶ you
```

- **Chief**: the agent you talk to. It doesn't write code. It routes and delegates
  requests, and it tells you what's happening.
- **Managers**: one per project, living in that project's herdr workspace. A manager answers
  small things itself (questions, investigations) and spawns workers for code changes. It
  reviews their work before reporting it as ready.
- **Workers**: one per task, each in its own tab and git worktree, so many tasks run at once
  without stepping on each other or on your own checkout.

It's one skill, one bash script, and three Markdown role files. State is plain text files you
can read and edit.

## Requirements

- [herdr](https://herdr.dev) (`curl -fsSL https://herdr.dev/install.sh | sh`)
- `git` and `jq`
- A coding agent herdr supports. The default is [Claude Code](https://claude.com/claude-code);
  Codex, Gemini, OpenCode and others work too (see [Using another agent](#using-another-agent)).
- macOS or Linux

## Setup

### 1. Install the skill

With the [skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add stevenmichaelthomas/numbrone -g
```

Or by hand:

```bash
git clone https://github.com/stevenmichaelthomas/numbrone.git
cp -r numbrone/skills/numbrone ~/.claude/skills/
```

### 2. Start herdr and your agent

```bash
herdr                                # launch or attach to herdr
herdr integration install claude     # once: lets herdr track Claude sessions
claude                               # start Claude Code in a herdr pane
```

### 3. Run the setup skill

In Claude Code, type:

```
/numbrone
```

The skill walks you through:

1. **Checks**: that herdr, git and jq are present.
2. **The HQ folder**: where the chief lives (default `~/hq`).
3. **Your projects**: give it paths, or a parent folder to pick git repos from.
4. **Context**: it reads each project (README, manifests, layout, recent history) and writes
   `projects/<name>/context.md` so the chief can route requests accurately.
5. **Agent settings**: which agent to use, and how many permission prompts you want (see below).
6. **Managers**: it opens one herdr workspace per project and starts a manager in each.

### 4. Start your chief of staff

Open a new herdr pane and run:

```bash
cd ~/hq && claude
```

The chief reads `~/hq/CLAUDE.md` and registers itself. From then on, just ask for things:

> Fix the flaky login test in the api, and add a dark mode toggle to the web app.

It splits that into two tasks, hands each to the right manager, and tells you. Managers spawn
workers, and the workers' tabs appear in each project's workspace in herdr. When something
needs you (a question, or work ready for review), the chief gets a `[hq] …` message and
passes it on. herdr also shows a notification.

Ask "what's going on?" at any time, or run `~/hq/bin/hq status` yourself:

```
TASK                     PROJECT          STATUS   WORKER   LAST UPDATE
fix-flaky-login          api              review   done     2026-11-08 16:01 [mgr-api] review: Branch hq/fix-flaky-login …
dark-mode-toggle         web              working  working  2026-11-08 16:00 [wk-dark-mode-toggle] working: Add toggle to …

managers: mgr-api=done mgr-web=idle
```

## Day to day

| You want to… | Do this |
| --- | --- |
| Give work | Tell the chief in plain language |
| See progress | Ask the chief, or `hq status` |
| See one task in full | `hq status <task>` (brief, status, full log) |
| Watch an agent work | Click its workspace and tab in herdr |
| Accept finished work | Review the `hq/<task>` branch, merge it your usual way, then tell the chief to close the task |
| Add a project | Run `/numbrone` again, or `hq add` + write its `context.md` + `hq up <name>` |
| Restart managers | `hq up` (after a reboot, for example) |

Nobody merges, pushes, or deploys unless you say so. `hq close` refuses to remove a worktree
that has uncommitted changes, and it always keeps the branch.

## How it works

Everything is plain files in the HQ folder:

```
~/hq/
├── CLAUDE.md               the chief's instructions (AGENTS.md links to it)
├── hq.conf                 which agent to run, with which arguments
├── projects.json           project index: name → path + one-line summary
├── projects/<name>/
│   └── context.md          what the project is, its commands, which requests belong to it
├── tasks/<task>.md         one file per task: brief, status, append-only log
├── roles/
│   ├── manager.md          instructions every manager reads at startup
│   └── worker.md           instructions every worker reads at startup
└── bin/hq                  the script everyone uses
```

A task file looks like this:

```markdown
# fix-flaky-login
project: api
status: review
branch: hq/fix-flaky-login
worktree: /code/api/.worktrees/fix-flaky-login
created: 2026-11-08 15:58

## Brief
The login test fails about 1 in 5 runs on CI. Find out why and fix it ...

## Log
- 2026-11-08 15:58 [chief] queued
- 2026-11-08 15:59 [mgr-api] spawned wk-fix-flaky-login on hq/fix-flaky-login
- 2026-11-08 16:04 [wk-fix-flaky-login] review: Race between session write and redirect ...
- 2026-11-08 16:05 [mgr-api] review: Branch hq/fix-flaky-login: awaits the session write ...
```

The `hq` script is a thin wrapper around the herdr CLI:

| Command | What it does in herdr / git |
| --- | --- |
| `hq up [project]` | `herdr workspace create --label hq/<project>`, then `herdr agent start mgr-<project>` |
| `hq delegate <project> <task> "<brief>"` | Writes `tasks/<task>.md`, then `herdr agent prompt mgr-<project>` |
| `hq spawn <task>` | `git worktree add <project>/.worktrees/<task> -b hq/<task>`, `herdr tab create`, `herdr agent start wk-<task>` |
| `hq report <task> <status> "<note>"` | Updates the task file; on `blocked`/`review`/`done` it messages one level up (worker → manager → chief) and shows a herdr notification |
| `hq status [task]` | Reads task files plus live agent states (`herdr agent get`) |
| `hq close <task>` | `herdr tab close` the worker, `git worktree remove` (keeps the branch) |
| `hq chief` | `herdr agent rename <this pane> chief`, so reports can reach it |

Worktrees go in `<project>/.worktrees/`, listed in the repo's local `.git/info/exclude`. They
never appear in `git status` or get committed, and agents started there inherit the folder
trust you already gave the project.

Run `hq` with no arguments for the full command list.

## Configuration

`~/hq/hq.conf`:

```bash
AGENT_KIND=claude      # any `herdr agent start --kind` value
AGENT_ARGS=""          # extra arguments for the agent
BASE_REF=""            # branch new worktrees start from ("" = project's current HEAD)
PING_CHIEF=1           # 0 = don't type reports into the chief; just log + notify
```

**Permission prompts.** Workers stop at every permission prompt and show as `blocked` in herdr
until you answer. That's the safe default. To cut down on prompts with Claude Code, for example:

```bash
AGENT_ARGS="--permission-mode acceptEdits"
```

Pick what you're comfortable with. Agents run on your machine with your access.

**Folder trust.** The first time Claude Code opens a project, it asks whether you trust the
folder. If a manager hits this, `hq` shows a notification and waits up to 5 minutes for you to
answer in herdr. Workers inherit their project's trust, so they won't ask again.

## Using another agent

Set `AGENT_KIND` in `hq.conf` (e.g. `codex`, `gemini`, `opencode`) and install its herdr
integration (`herdr integration install codex`). The role files are plain Markdown and the HQ
folder has an `AGENTS.md` symlink, so any agent that reads `AGENTS.md` can be the chief. You
can install the skill for that agent with `npx skills add … -a <agent>`, or run
`bash skills/numbrone/scripts/hq init ~/hq` yourself and follow `skills/numbrone/SKILL.md` by hand.

## Customizing

- **Change how roles behave**: edit `skills/numbrone/templates/manager.md` or `worker.md`, then
  run `hq init ~/hq` again to update `~/hq/roles/`. `init` never overwrites your `CLAUDE.md`,
  `hq.conf` or `projects.json`.
- **Change how the chief behaves**: edit `~/hq/CLAUDE.md` directly.
- **Better routing**: improve the "Route here" and "Not here" sections in each project's `context.md`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `hq: no HQ found` | Run `~/hq/bin/hq …` (not a copy elsewhere), or set `HQ_HOME=~/hq` |
| A manager or worker shows `blocked` | It's waiting for an answer. Click its tab in herdr, or `herdr agent read <name> --source recent-unwrapped --lines 80` |
| Reports don't reach the chief | Run `hq chief` in the chief's session (it registers the name `chief`) |
| `mgr-x already running` but it seems stuck | `herdr agent read mgr-x …` to see its screen; close its tab in herdr and run `hq up x` |
| Managers gone after a reboot | `hq up` |
| Agent states look wrong | `herdr integration status`; `herdr agent explain <name>` |

## Uninstall

```bash
rm -rf ~/.claude/skills/numbrone ~/hq
```

Then close the `hq/*` workspaces in herdr. Task branches (`hq/*`) stay in your repos until you
delete them; any leftover worktrees can be removed with `git worktree remove <path>`.

## License

MIT
