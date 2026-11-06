#!/usr/bin/env bash
# Workflow commands for the actions' run: scripts (#267). A step sources it:
#
#   # shellcheck source=scripts/workflow-command.sh
#   . "$GITHUB_ACTION_PATH/../scripts/workflow-command.sh"
#
# The runner reads every line a step prints that starts with '::' as a
# workflow command, and an annotation's message as the command's data, in
# which %, CR and LF must be written %25, %0D and %0A. So a value printed in
# an annotation goes through esc, and an input that is never more than one
# line is refused, in the action's first step, when it holds a line break:
# then no later line that prints it can start a command of its own.
#
# Each substitution is a plain assignment. Inside double quotes,
# "${s//$'\n'/'%0A'}" keeps the single quotes in some bash versions, and an
# assignment after local can be word-split in old ones.

# esc VALUE: VALUE as a workflow command's data.
esc() {
  local s
  s=${1//'%'/'%25'}
  s=${s//$'\r'/'%0D'}
  s=${s//$'\n'/'%0A'}
  printf '%s' "$s"
}

# annotate LEVEL MESSAGE: one ::error::, ::warning:: or ::notice:: line,
# with MESSAGE escaped.
annotate() {
  printf '::%s::%s\n' "$1" "$(esc "$2")"
}

# single_line NAME=VALUE...: an ::error:: for each VALUE that holds a line
# break, naming its input. Returns 1 if any did.
single_line() {
  local arg bad=0
  for arg in "$@"; do
    case "${arg#*=}" in
      *$'\n'* | *$'\r'*)
        annotate error "${arg%%=*} must be a single line, got '${arg#*=}'"
        bad=1
        ;;
    esac
  done
  return "$bad"
}
