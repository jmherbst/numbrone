# numbrone

> numbrone is an independent community project built on top of [herdr](https://herdr.dev).
> It is not made by or affiliated with the herdr team.

**A chief of staff for your coding agents.** You give one agent requests in plain language.
It works out which of your projects each request belongs to and hands it to that project's
manager. The manager runs workers in parallel, each in its own git worktree, and everyone
reports back up. All of it runs in [herdr](https://herdr.dev), so you can watch any agent at any time.

```
            you, or sources the chief watches (Linear, GitHub issues, ...)
                        │  "add rate limiting to the api"
                        ▼
                 ┌─────────────┐
                 │    chief    │   routes, delegates, keeps track       ~/.numbrone
                 └──────┬──────┘
           ┌────────────┴─────────────┐
           ▼                          ▼
   ┌───────────────┐          ┌───────────────┐   ◀── sources each manager watches
   │  manager-api  │          │  manager-web  │       (Sentry, Datadog, ...)
   └───────┬───────┘          └───────┬───────┘   one per project: herdr workspace numbrone/<project>
      ┌────┴─────────┐                │
      ▼              ▼                ▼
 worker-rate-   worker-fix-     worker-new-       one per code task: herdr tab and git worktree
 limit          login           navbar                               on branch numbrone/<task>

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
2. **The numbrone home**: the folder where the chief lives (default `~/.numbrone`).
3. **Your projects**: give it paths, or a parent folder to pick git repositories from.
4. **Context**: it reads each project (README, manifests, layout, recent history) and writes
   `projects/<name>/context.md` so the chief can route requests accurately.
5. **Inputs** (optional): sources the chief or a manager should watch, such as Linear tickets
   or Sentry errors (see [Inputs](#inputs-you-or-anything-else)).
6. **Knowledge** (optional): a few questions about your goals and standards, to give the chief a head start.
7. **Agent settings**: which agent to use, and how many permission prompts you want (see below).
8. **Managers**: it opens one herdr workspace per project and starts a manager in each.

### 4. Start your chief of staff

Open a new herdr pane and run:

```bash
cd ~/.numbrone && claude
```

The chief reads `~/.numbrone/CLAUDE.md` and registers itself. From then on, just ask for things:

> Fix the flaky login test in the API, and add a dark mode toggle to the web application.

It splits that into two tasks, hands each to the right manager, and tells you. Managers spawn
workers, and the workers' tabs appear in each project's workspace in herdr. When something
needs you (a question, or work ready for review), the chief gets a `[numbrone] …` message and
passes it on. herdr also shows a notification.

Ask "what's going on?" at any time, or run `numbrone status` yourself. To use the
`numbrone` command from your own shell, add it to your PATH:

```bash
export PATH="$HOME/.numbrone/bin:$PATH"   # in ~/.zshrc or ~/.bashrc
```

The status looks like this:

```
TASK                     PROJECT          STATUS   WORKER   LAST UPDATE
fix-flaky-login          api              review   done     2026-11-08 16:01 [manager-api] review: Branch numbrone/fix-flaky-login …
dark-mode-toggle         web              working  working  2026-11-08 16:00 [worker-dark-mode-toggle] working: Add toggle to …

managers: manager-api=done manager-web=idle
```

## Inputs: you, or anything else

Work doesn't have to come from you. At each level, an agent can run a loop that watches a
source and turns new items into tasks:

- **The chief** watches sources that span projects, such as a Linear team, GitHub issues across
  an org, or a shared inbox. It routes each new item to the right project, just like a request from you.
- **A manager** watches sources its project owns, such as that service's Sentry errors, its
  Datadog monitors, or its CI failures. It triages each item and either handles it, spawns a
  worker, or asks the chief (and so you) when it needs a decision.

Sources are listed under a **Watch** heading: in `~/.numbrone/CLAUDE.md` for the chief, and in
`projects/<name>/context.md` for a manager. One line per source:

```markdown
## Watch
- Linear: new issues in team ENG labelled "agent", every 15 minutes
- Sentry: new unresolved issues in project "api", every 30 minutes
```

Agents start these loops when they launch (in Claude Code, with `/loop`), so watches come back
after a restart. You can also add one just by asking, for example "have the api manager keep an eye on
Sentry". The manager adds it to its `context.md` itself.

Agents read sources with whatever tools they have: MCP connectors (Linear, Sentry, Datadog, ...)
or CLIs such as `gh`. Connect those in your agent first. The item's ID goes in the task brief,
so the same ticket or error is never picked up twice.

## Teaching the chief

Not every conversation with the chief needs to be a task. You can also just give it context:

> For context: we're prioritizing enterprise customers this quarter, so anything touching SSO
> or audit logs comes first. And we decided last month to stop supporting IE.

The chief files it rather than delegating it, and confirms in one line where it went:

- **Context about your world** (goals, customers, people, past decisions, your standards) goes in
  `~/.numbrone/knowledge/`, one Markdown file per topic, with an `index.md` it reads at the start
  of every session.
- **Context about one project** goes in that project's `context.md`, and the chief passes it to
  that project's manager.
- **How you want the chief itself to work** goes under **Learned** (see below).

The more it knows, the better its work gets. It routes ambiguous requests correctly, writes briefs
that carry the "why" (managers only see the brief), and judges finished work against your goals
and standards before it reaches you. Paste documents, explain history, or correct a wrong assumption.
It keeps the files organized and up to date, and asks when it's missing something it needs.

## A chief that learns from you

The chief is meant to act like an extension of you: opinionated and quick to decide. It
recommends one option instead of listing five, makes routine calls itself, and only brings you
real decisions, with its recommendation attached. It also gives feedback, for example when a
request is vague or the same problem keeps happening.

It gets better by taking your feedback. Whenever you correct it or tell it how you like things
done, it adds one line to the **Learned** section of `~/.numbrone/CLAUDE.md`, which every future
session reads first. Early on (until it has about ten lessons), it asks you a short question
after each finished task to calibrate faster. You can edit **Learned** yourself at any time.

## Work log

Everything that happens is written to `~/.numbrone/log/<date>.md`, one Markdown file per day.
The script appends every event as it happens: queued, spawned, each report, closed. The chief
adds an outcome note when a task finishes: what was delivered, how much rework or blocking it
took, and a one-line lesson.

```markdown
# Work log 2026-11-08

- 15:59 [chief] add-name: queued
- 16:00 [manager-demo] add-name: spawned worker-add-name on numbrone/add-name
- 16:00 [worker-add-name] add-name: review: greet.sh takes an optional name ...
- 16:01 [manager-demo] add-name: review: Branch numbrone/add-name (c880b98) ...
- 16:02 [chief] add-name (demo): optional name argument, one pass, no rework. Lesson: briefs
  for this repository should say which branch to base on, since two tasks touched greet.sh.
```

Entries are only ever appended, so the log is an audit trail you can trust. It's also how the
setup gets better over time. Ask the chief for a retro and it reads the log, tells you where work
stalled or was redone, and proposes changes to its own instructions, the role files, or a
project's context. It only makes them once you agree.

## Day to day

| You want to… | Do this |
| --- | --- |
| Give work | Tell the chief in plain language |
| See progress | Ask the chief, or `numbrone status` |
| See one task in full | `numbrone status <task>` (brief, status, full log) |
| Watch an agent work | Click its workspace and tab in herdr |
| Accept finished work | Review the `numbrone/<task>` branch, merge it your usual way, then tell the chief to close the task |
| Add a project | Run `/numbrone` again, or `numbrone add` + write its `context.md` + `numbrone up <name>` |
| Restart managers | `numbrone up` (after a reboot, for example) |
| Review how things went | Ask the chief for a retro ("how did this week go?") |

Nobody merges, pushes, or deploys unless you say so. `numbrone close` refuses to remove a worktree
that has uncommitted changes, and it always keeps the branch.

## How it works

Everything is plain files in the numbrone home folder:

```
~/.numbrone/
├── CLAUDE.md               the chief's instructions (AGENTS.md links to it)
├── settings.sh           which agent to run, with which arguments
├── projects.json           project index: name → path + one-line summary
├── projects/<name>/
│   └── context.md          what the project is, its commands, which requests belong to it
├── tasks/<task>.md         one file per task: brief, status, append-only log
├── log/<date>.md           the daily work log (see below)
├── knowledge/              what the chief knows about your world, by topic (index.md lists them)
├── roles/
│   ├── manager.md          instructions every manager reads at startup
│   └── worker.md           instructions every worker reads at startup
└── bin/numbrone            the script everyone uses
```

A task file looks like this:

```markdown
# fix-flaky-login
project: api
status: review
branch: numbrone/fix-flaky-login
worktree: /code/api/.numbrone/worktrees/fix-flaky-login
created: 2026-11-08 15:58

## Brief
The login test fails about 1 in 5 runs on CI. Find out why and fix it ...

## Log
- 2026-11-08 15:58 [chief] queued
- 2026-11-08 15:59 [manager-api] spawned worker-fix-flaky-login on numbrone/fix-flaky-login
- 2026-11-08 16:04 [worker-fix-flaky-login] review: Race between session write and redirect ...
- 2026-11-08 16:05 [manager-api] review: Branch numbrone/fix-flaky-login: awaits the session write ...
```

The `numbrone` script is a thin wrapper around the herdr CLI:

| Command | What it does in herdr / git |
| --- | --- |
| `numbrone up [project]` | `herdr workspace create --label numbrone/<project>`, then `herdr agent start manager-<project>` |
| `numbrone delegate <project> <task> "<brief>"` | Writes `tasks/<task>.md`, then `herdr agent prompt manager-<project>` |
| `numbrone spawn <task>` | `git worktree add <project>/.numbrone/worktrees/<task> -b numbrone/<task>`, `herdr tab create`, `herdr agent start worker-<task>` |
| `numbrone report <task> <status> "<note>"` | Updates the task file; on `blocked`/`review`/`done` it messages one level up (worker → manager → chief) and shows a herdr notification |
| `numbrone status [task]` | Reads task files plus live agent states (`herdr agent get`) |
| `numbrone close <task>` | `herdr tab close` the worker, `git worktree remove` (keeps the branch) |
| `numbrone chief` | `herdr agent rename <this pane> chief`, so reports can reach it |
| `numbrone log ["<note>"]` | Appends a note to today's work log, or prints it |

Worktrees go in `<project>/.numbrone/worktrees/`, listed in the repository's local `.git/info/exclude`. They
never appear in `git status` or get committed, and agents started there inherit the folder
trust you already gave the project.

Run `numbrone` with no arguments for the full command list.

## Configuration

`~/.numbrone/settings.sh`:

```bash
AGENT_KIND=claude       # any `herdr agent start --kind` value
AGENT_ARGUMENTS=""      # extra arguments for the agent
BASE_BRANCH=""          # branch new worktrees start from ("" = project's current HEAD)
PING_CHIEF=1            # 0 = don't type reports into the chief; just log and notify
```

**Permission prompts.** Workers stop at every permission prompt and show as `blocked` in herdr
until you answer. That's the safe default. To cut down on prompts with Claude Code, for example:

```bash
AGENT_ARGUMENTS="--permission-mode acceptEdits"
```

Pick what you're comfortable with. Agents run on your machine with your access.

**Folder trust.** The first time Claude Code opens a project, it asks whether you trust the
folder. If a manager hits this, `numbrone` shows a notification and waits up to 5 minutes for you to
answer in herdr. Workers inherit their project's trust, so they won't ask again.

## Using another agent

Set `AGENT_KIND` in `settings.sh` (for example `codex`, `gemini`, `opencode`) and install its herdr
integration (`herdr integration install codex`). The role files are plain Markdown and the numbrone
home folder has an `AGENTS.md` symlink, so any agent that reads `AGENTS.md` can be the chief. You
can install the skill for that agent with `npx skills add … -a <agent>`, or run
`bash skills/numbrone/scripts/numbrone init ~/.numbrone` yourself and follow `skills/numbrone/SKILL.md` by hand.

## Customizing

- **Change how roles behave**: edit `~/.numbrone/roles/manager.md` or `worker.md`.
- **Upgrade**: pull the repository and run `numbrone init ~/.numbrone` again. It updates `bin/numbrone`
  and never overwrites files you may have edited (`CLAUDE.md`, `roles/`, `settings.sh`,
  `projects.json`). To take a newer template, delete that file and run `init` again.
- **Change how the chief behaves**: edit `~/.numbrone/CLAUDE.md` directly.
- **Better routing**: improve the "Route here" and "Not here" sections in each project's `context.md`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `numbrone: no numbrone home found` | Run `~/.numbrone/bin/numbrone …` (not a copy elsewhere), or set `NUMBRONE_HOME=~/.numbrone` |
| A manager or worker shows `blocked` | It's waiting for an answer. Click its tab in herdr, or `herdr agent read <name> --source recent-unwrapped --lines 80` |
| Reports don't reach the chief | Run `numbrone chief` in the chief's session (it registers the name `chief`) |
| `manager-x already running` but it seems stuck | `herdr agent read manager-x …` to see its screen; close its tab in herdr and run `numbrone up x` |
| Managers gone after a reboot | `numbrone up` |
| Agent states look wrong | `herdr integration status`; `herdr agent explain <name>` |

## Uninstall

```bash
rm -rf ~/.claude/skills/numbrone ~/.numbrone
```

Then close the `numbrone/*` workspaces in herdr. Task branches (`numbrone/*`) stay in your repositories until you
delete them; any leftover worktrees can be removed with `git worktree remove <path>`.

## License

MIT
