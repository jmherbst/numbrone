# numbrone

> This is a fork of [numbrone](https://github.com/stevenmichaelthomas/numbrone) that runs on
> [Rex](https://www.superlogical.com/rex) instead of [herdr](https://herdr.dev). Both are independent
> community projects, not made by or affiliated with Superlogical or the herdr team.

**A chief of staff for your coding agents.** You give one agent requests in plain language.
It works out which of your projects each request belongs to and hands it to that project's
manager. The manager runs workers in parallel, each in its own git worktree, and everyone
reports back up. All of it runs in [Rex](https://www.superlogical.com/rex), so you can watch any agent at any time.

We all need a numbrone at work. This is yours.

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
   └───────┬───────┘          └───────┬───────┘   one per project: Rex session numbrone/<project>
      ┌────┴─────────┐                │
      ▼              ▼                ▼
 worker-rate-   worker-fix-     worker-new-       one per code task: Rex tab and git worktree
 limit          login           navbar                               on branch numbrone/<task>

  reports flow back up:  worker ──▶ manager ──▶ chief ──▶ you
```

- **Chief**: the agent you talk to. It doesn't write code. It routes and delegates
  requests, and it tells you what's happening.
- **Managers**: one per project, living in that project's Rex session. A manager answers
  small things itself (questions, investigations) and spawns workers for code changes. It
  reviews their work before reporting it as ready.
- **Workers**: one per task, each in its own tab and git worktree, so many tasks run at once
  without stepping on each other or on your own checkout.

It's one skill, one bash script, and three Markdown role files. State is plain text files you
can read and edit.

## Requirements

- [Rex](https://www.superlogical.com/rex), currently in beta (see its [installation page](https://www.superlogical.com/rex/docs/installation))
- `git` and `jq`
- A coding agent that reports its state to Rex. [Claude Code](https://claude.com/claude-code) does
  this by itself and is the default (see [Using another agent](#using-another-agent)).
- macOS or Linux

## Setup

### 1. Install the skill

With the [skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add jmherbst/numbrone -g
```

Or by hand:

```bash
git clone https://github.com/jmherbst/numbrone.git
cp -r numbrone/skills/numbrone ~/.claude/skills/
```

### 2. Start your agent in Rex

Open Rex, and in a Rex terminal start Claude Code:

```bash
claude
```

There's no integration to install. Claude Code tells Rex what it's doing (working, idle, or
waiting for you) through Rex's [Program Status Protocol](https://www.superlogical.com/rex/docs/build/program-status),
and that's how numbrone follows every agent.

### 3. Run the setup skill

In Claude Code, type:

```
/numbrone
```

The skill walks you through:

1. **Checks**: that Rex, git and jq are present, and that your agent reports its state to Rex.
2. **The numbrone home**: the folder where the chief lives (default `~/.numbrone`).
3. **Your projects**: give it paths, or a parent folder to pick git repositories from.
4. **Context**: it reads each project (README, manifests, layout, recent history) and writes
   `projects/<name>/context.md` so the chief can route requests accurately.
5. **Inputs** (optional): sources the chief or a manager should watch, such as Linear tickets
   or Sentry errors (see [Inputs](#inputs-you-or-anything-else)).
6. **Knowledge** (optional): a few questions about your goals and standards, to give the chief a head start.
7. **Agent settings**: which agent to use, and how many permission prompts you want (see below).
8. **Managers**: it opens one Rex session per project and starts a manager in each.

### 4. Start your chief of staff

Open a new Rex terminal and run:

```bash
cd ~/.numbrone && claude
```

The chief reads `~/.numbrone/CLAUDE.md` and registers itself. From then on, just ask for things:

> Fix the flaky login test in the API, and add a dark mode toggle to the web application.

It splits that into two tasks, hands each to the right manager, and tells you. Managers spawn
workers, and the workers' tabs appear in each project's session in Rex. When something
needs you (a question, or work ready for review), the chief gets a `[numbrone] …` message and
passes it on. Rex also marks each agent's tab while it works or waits for you (see [Notifications](#notifications)).

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

The WORKER column and the managers line show what each agent last reported to Rex: `working`,
`idle`, `done` (finished its turn), `blocked` (waiting for you to answer it), `unknown` (no report
yet, usually a startup prompt), or `-` (not running).

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

**Learned** is kept short on purpose: the chief merges overlapping lessons, replaces ones that
no longer hold, and moves project-specific detail into that project's `context.md`. The work log
keeps the full history of your feedback.

## Work log

`~/.numbrone/log/<date>.md` is the record of what the chief and its teams got done each day,
one Markdown file per day. It holds outcomes and decisions, not progress chatter:

- **Milestones**, written by the script as managers report them: queued, blocked, review, done, closed.
- **Outcomes**, written by the chief when a task finishes: what was delivered, how it went
  (rework, blocks, time taken), and a one-line lesson.
- **Decisions**: your answers to blocked questions, priority calls, work sent back. Managers
  log the decisions they make on your behalf, too.
- **Feedback and context** you gave the chief.

Workers' step-by-step progress stays in each task file (`numbrone status <task>`), so a day's log
stays short enough to read in a minute.

```markdown
# Work log 2026-11-08

- 15:59 [chief] add-name: queued for demo
- 16:01 [manager-demo] add-name: review: Branch numbrone/add-name (c880b98): greet.sh takes an
  optional name and falls back to "world". Tests pass.
- 16:02 [chief] outcome: add-name (demo): optional name argument, one pass, no rework. Lesson: none
- 16:20 [chief] decision: user accepted add-name; fix-login goes before new-navbar (launch Friday)
- 16:21 [chief] add-name: closed (branch numbrone/add-name kept)
```

Ask the chief "what got done today?" and it answers by project from this file. To skim
outcomes across days yourself: `grep -h "outcome:" ~/.numbrone/log/*.md`.

Entries are only ever appended, so the log is an audit trail you can trust. It's also how the
setup gets better over time. Ask the chief for a retro and it reads the log, tells you where work
stalled or was redone and how often, and proposes changes to its own instructions, the role files, or a
project's context. It only makes them once you agree.

## Day to day

| You want to… | Do this |
| --- | --- |
| Give work | Tell the chief in plain language |
| See progress | Ask the chief, or `numbrone status` |
| See one task in full | `numbrone status <task>` (brief, status, full log) |
| Watch an agent work | Open its session (`numbrone/<project>`) and tab in Rex, or `numbrone peek <agent>` |
| Message an agent yourself | `numbrone tell <agent> "<message>"` |
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
├── settings.sh             which agent to run, with which arguments
├── projects.json           project index: name → path + one-line summary
├── projects/<name>/
│   └── context.md          what the project is, its commands, which requests belong to it
├── tasks/<task>.md         one file per task: brief, status, append-only log
├── log/<date>.md           the daily work log (see below)
├── knowledge/              what the chief knows about your world, by topic (index.md lists them)
├── panes/<agent>           the Rex session and pane each agent runs in (kept by the script)
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

The `numbrone` script is a thin wrapper around the [rex CLI](https://www.superlogical.com/rex/docs/automate/cli).
Every `rex` call is in one section of the script, the `mux_*` functions:

| Command | What it does in Rex / git |
| --- | --- |
| `numbrone up [project]` | `rex new numbrone/<project>` (or `rex window new` in that session if it exists), with the manager agent running in a `manager` tab |
| `numbrone delegate <project> <task> "<brief>"` | Writes `tasks/<task>.md`, then types a message into `manager-<project>` |
| `numbrone spawn <task>` | `git worktree add <project>/.numbrone/worktrees/<task> -b numbrone/<task>`, then `rex window new` in the project's session, with a worker agent running in it |
| `numbrone report <task> <status> "<note>"` | Updates the task file; on `blocked`/`review`/`done` it messages one level up (worker → manager → chief) and asks Rex for a notification |
| `numbrone status [task]` | Reads task files, plus each agent's state from Rex (`rex block call … program_status`) |
| `numbrone close <task>` | `rex window close` the worker's tab, `git worktree remove` (keeps the branch) |
| `numbrone chief` | `rex block rename` this pane to `chief` and records it, so reports can reach it |
| `numbrone tell <agent> "<message>"` | Types a message into an agent and submits it |
| `numbrone peek <agent> [lines]` | `rex capture` the end of an agent's screen |
| `numbrone log ["<note>" \| <date>]` | Appends a note to today's work log, or prints a day's log |

Worktrees go in `<project>/.numbrone/worktrees/`, listed in the repository's local `.git/info/exclude`. They
never appear in `git status` or get committed, and agents started there inherit the folder
trust you already gave the project.

Run `numbrone` with no arguments for the full command list.

### How numbrone finds and talks to agents

- **Where each agent is.** Each project gets a Rex session, `numbrone/<project>`. Each agent runs
  in its own tab there, in a pane labelled with its name (`manager-api`, `worker-fix-login`). Labels
  can change, so numbrone records each agent's session and pane IDs in `panes/<agent>` and goes by
  those. When an agent runs `numbrone`, Rex's `REX_BLOCK` variable tells the script which agent it is.
- **What each agent is doing.** An agent's state is what it last reported to Rex through the
  [Program Status Protocol](https://www.superlogical.com/rex/docs/build/program-status). Claude Code
  reports `working` while it works, `done` when it finishes a turn, and `blocked` at a permission
  prompt or question, with the reason.
- **Messages.** A message is pasted into the agent's input and submitted with Enter, so a message
  of several lines stays in one piece. An agent that's busy queues it until its current turn ends.
  numbrone never types into an agent that's `blocked`, because Enter could answer its prompt;
  it says so instead, and the chief brings the question to you.
- **The first prompt** is passed on the agent's command line, so it runs as soon as the agent is
  ready, even if the agent first stops to ask whether you trust the folder.

## Configuration

`~/.numbrone/settings.sh`:

```bash
AGENT_KIND=claude       # the command Rex runs for managers and workers
AGENT_ARGUMENTS=""      # extra arguments for the agent
BASE_BRANCH=""          # branch new worktrees start from ("" = project's current HEAD)
PING_CHIEF=1            # 0 = don't type reports into the chief; just log and notify
```

**Permission prompts.** Workers stop at every permission prompt and show as `blocked` in Rex
until you answer. That's the safe default. To cut down on prompts with Claude Code, for example:

```bash
AGENT_ARGUMENTS="--permission-mode acceptEdits"
```

Pick what you're comfortable with. Agents run on your machine with your access.

**Aliases.** Rex starts agents with your login shell's environment, so your `PATH` applies but
aliases don't. If you normally run `claude` through an alias that adds flags, put those flags in
`AGENT_ARGUMENTS`.

**Folder trust.** The first time Claude Code opens a project, it asks whether you trust the
folder. If a manager hits this, `numbrone` tells you, shows a notification, and waits up to 5 minutes
for you to answer in that manager's tab in Rex. Workers inherit their project's trust, so they won't ask again.

## Notifications

Rex shows each agent's state on its tab (working, waiting for you, finished), in its activity
view, and in the session picker. In Rex's settings, under **Notifications › Program Activity**,
you can also have it send macOS notifications, badge the Dock icon, or play a sound when an agent
is blocked or finishes.

On top of that, `numbrone report` asks for a notification whenever a task becomes `blocked`,
`review` or `done`, as does `numbrone up` when a manager waits at a startup prompt. Rex shows these
when **Notifications › System Notifications › Terminal notifications** is on. Each one comes from
the pane of the agent that sent it.

## Using another agent

Set `AGENT_KIND` in `settings.sh` to the agent's command (for example `codex`). numbrone follows an
agent only through the state it reports to Rex, so the agent must support Rex's
[Program Status Protocol](https://www.superlogical.com/rex/docs/build/program-status). To check,
start the agent in a Rex tab, then from another Rex terminal find its pane with
`rex block ls -s <session>` and run `rex block call -s <session> -b <pane> program_status`. An
empty list means numbrone can't tell when that agent is working or waiting, and won't send it
messages. Claude Code and Codex get their first prompt on the command line; other agents have it
typed in once they report a state. Only Claude Code has been tested with this fork.

The role files are plain Markdown and the numbrone home folder has an `AGENTS.md` symlink, so any
agent that reads `AGENTS.md` can be the chief. You can install the skill for that agent with
`npx skills add … -a <agent>`, or run `bash skills/numbrone/scripts/numbrone init ~/.numbrone`
yourself and follow `skills/numbrone/SKILL.md` by hand.

## Customizing

- **Change how roles behave**: edit `~/.numbrone/roles/manager.md` or `worker.md`.
- **Upgrade**: pull the repository and run `numbrone init ~/.numbrone` again. It updates `bin/numbrone`
  and never overwrites files you may have edited (`CLAUDE.md`, `roles/`, `settings.sh`,
  `projects.json`). To take a newer template, delete that file and run `init` again.
- **Change how the chief behaves**: edit `~/.numbrone/CLAUDE.md` directly.
- **Better routing**: improve the "Route here" and "Not here" sections in each project's `context.md`.

### Moving from the herdr version

Your projects, tasks, log and knowledge carry over unchanged. Run `numbrone init ~/.numbrone` from
this repository to replace `bin/numbrone`. Since `init` keeps the files you may have edited, your
`CLAUDE.md` and `roles/*.md` still tell agents to run `herdr agent prompt` and `herdr agent read`:
change those to `numbrone tell <agent> "<message>"` and `numbrone peek <agent>`, or delete the files
and run `init` again for fresh copies. Then close the old herdr workspaces and run `numbrone up`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `numbrone: no numbrone home found` | Run `~/.numbrone/bin/numbrone …` (not a copy elsewhere), or set `NUMBRONE_HOME=~/.numbrone` |
| `numbrone: can't reach the Rex server` | Rex isn't running, or this shell can't reach it. Check with `rex whoami` |
| A manager or worker shows `blocked` | It's waiting for you to answer a permission prompt or question. Open its tab in Rex, or `numbrone peek <agent>` to see what it's asking |
| A manager or worker shows `unknown` | It hasn't reported a state yet: usually it's waiting at a startup prompt such as "trust this folder". Answer it in its tab |
| `… exited as soon as it started` | Rex couldn't run `AGENT_KIND`. It uses your login shell's `PATH` and ignores aliases; check the command in `settings.sh` |
| Reports don't reach the chief | Run `numbrone chief` in the chief's session (it records the chief's pane) |
| `manager-x already running` but it seems stuck | `numbrone peek manager-x` to see its screen; close its tab in Rex and run `numbrone up x` |
| Managers gone after a reboot | `numbrone up` |
| Agent states look wrong | `panes/<agent>` holds the agent's session and pane IDs; `rex block call -s <session> -b <pane> program_status` shows what it last reported |

## Uninstall

```bash
rm -rf ~/.claude/skills/numbrone ~/.numbrone
```

Then close the `numbrone/*` sessions in Rex (`rex kill numbrone/<project>`). Task branches (`numbrone/*`) stay in
your repositories until you delete them; any leftover worktrees can be removed with `git worktree remove <path>`.

## License

MIT
