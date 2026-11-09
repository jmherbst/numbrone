# numbrone settings. bin/numbrone reads this file as a shell script, so use shell syntax.

# The agent numbrone starts for managers and workers, as the command to run. Rex runs it with your
# login shell's environment, so PATH applies but aliases don't: put any flags you rely on in
# AGENT_ARGUMENTS. numbrone follows each agent's state (idle, working, blocked) through the status
# it reports to Rex, which Claude Code does by itself. claude is the tested choice; another agent
# works only if it reports its status to Rex too (see "Using another agent" in the README).
AGENT_KIND=claude

# Extra arguments passed to that agent when it starts.
# Workers wait for you every time they hit a permission prompt (they show as
# "blocked" in Rex). To let them edit files without asking, for Claude Code:
#   AGENT_ARGUMENTS="--permission-mode acceptEdits"
AGENT_ARGUMENTS=""

# Branch new worktrees start from. Empty = the project's current HEAD.
BASE_BRANCH=""

# 1 = managers' blocked/review/done reports are typed into the chief's session.
# 0 = only log them and show a notification (check with `numbrone status`).
PING_CHIEF=1
