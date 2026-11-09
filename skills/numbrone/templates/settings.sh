# numbrone settings. bin/numbrone reads this file as a shell script, so use shell syntax.

# The agent numbrone starts for managers and workers, as the command to run. Rex runs it with your
# login shell's environment, so PATH applies but aliases don't: put any flags you rely on in
# AGENT_ARGUMENTS. numbrone follows each agent's state (idle, working, blocked) through the status
# it reports to Rex, which Claude Code does by itself. claude is the tested choice; another agent
# works only if it reports its status to Rex too (see "Using another agent" in the README).
AGENT_KIND=claude

# Extra arguments passed to that agent when it starts. The default runs Claude Code in auto mode,
# which handles permission requests itself (by the rules `claude auto-mode config` prints) instead
# of stopping to ask you. To approve actions yourself, use "--permission-mode manual": workers then
# stop at every permission prompt and show as "blocked" in Rex until you answer. These are Claude
# Code flags, so change them if you change AGENT_KIND.
AGENT_ARGUMENTS="--permission-mode auto"

# Branch new worktrees start from. Empty = the project's current HEAD.
BASE_BRANCH=""

# 1 = managers' blocked/review/done reports are typed into the chief's session.
# 0 = only log them and show a notification (check with `numbrone status`).
PING_CHIEF=1
