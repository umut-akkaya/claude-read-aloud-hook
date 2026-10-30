#!/usr/bin/env bash
# Reads hook JSON from stdin, summarizes .last_assistant_message with Claude, and speaks the summary.

message=$(jq -er '.last_assistant_message') || exit 0

summary=$(claude -p --model haiku --settings '{"disableAllHooks": true}' \
  "Summarize this assistant message in one or two short sentences to be spoken aloud. Plain text only, no markdown or symbols." \
  <<< "$message")

say -r 200 "$summary"
