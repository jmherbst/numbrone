# numbrone settings. bin/numbrone reads this file as a shell script, so use shell syntax.

# Which agent herdr starts for managers and workers.
# Any `herdr agent start --kind` value works: claude, codex, gemini, opencode, ...
AGENT_KIND=claude

# Extra arguments passed to that agent when it starts.
# Workers wait for you every time they hit a permission prompt (they show as
# "blocked" in herdr). To let them edit files without asking, for Claude Code:
#   AGENT_ARGUMENTS="--permission-mode acceptEdits"
AGENT_ARGUMENTS=""

# Branch new worktrees start from. Empty = the project's current HEAD.
BASE_BRANCH=""

# 1 = managers' blocked/review/done reports are typed into the chief's session.
# 0 = only log them and show a herdr notification (check with `numbrone status`).
PING_CHIEF=1
