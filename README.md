# messagevoicehook

A [Claude Code](https://claude.com/claude-code) hook that reads Claude's replies aloud on macOS.

When Claude finishes a reply, the hook sends it to Claude Haiku for a one- or two-sentence summary, then speaks that summary with the macOS `say` command. You hear what happened without reading the full reply.

## Requirements

- macOS (uses `say`)
- [Claude Code](https://claude.com/claude-code), logged in
- [`jq`](https://jqlang.org/), which ships with recent macOS versions; otherwise `brew install jq`

## Installation

Copy the `.claude` folder into your project, or copy the two files by hand:

```
.claude/
├── settings.json        # registers the hook
└── hooks/
    └── readaloud.sh      # the hook script
```

Make the script executable:

```bash
chmod +x .claude/hooks/readaloud.sh
```

Restart Claude Code, or open `/hooks` to confirm that the hook is listed.

To use it in every project, put the hook in `~/.claude/settings.json` and point `command` at the script's absolute path.

## How it works

`.claude/settings.json` registers the script as a `Stop` hook, which runs each time Claude finishes a reply:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/readaloud.sh"
          }
        ]
      }
    ]
  }
}
```

The script:

1. Reads the hook's JSON input from stdin and extracts `last_assistant_message` with `jq -e`. If the field is missing or `null`, it exits quietly.
2. Runs `claude -p --model haiku` to summarize the message as plain spoken text. The summary has no markdown or symbols; `say` stops reading at characters such as `<` and `>`.
3. Speaks the summary with `say -r 200`.

### Why `disableAllHooks`?

The nested `claude -p` call runs in the same project and would load the same `Stop` hook. Its reply would then trigger another summary, and so on without end. Passing `--settings '{"disableAllHooks": true}'` turns hooks off for that one call only, and keeps your normal login.

(`--bare` would also skip hooks, but it authenticates only with `ANTHROPIC_API_KEY`.)

## Behavior with background tasks

- `Stop` fires every time Claude finishes a reply, even while background commands or subagents are still running.
- While the hook is speaking, Claude Code waits for it to finish. Background tasks that complete during the speech are queued, and Claude reports them together in its next reply, so voices don't overlap.
- A subagent finishing fires `SubagentStop`, not `Stop`. You hear only Claude's main reply that reports the subagent's result.

Don't run `say` in the background (`say ... &`). The hook would then return immediately, and consecutive replies could be spoken over each other.

## Customization

| What                             | Where                                              |
| -------------------------------- | -------------------------------------------------- |
| Speaking rate (words per minute) | `say -r 200`                                       |
| Voice                            | add `-v <name>`; run `say -v '?'` for the list     |
| Summary length or style          | the prompt passed to `claude -p`                   |
| Summary model                    | `--model haiku`                                    |

## Debugging

Start Claude Code with `claude --debug`. Logs are written to `~/.claude/debug/<session-id>.txt`, not the terminal. To watch hook runs live:

```bash
tail -f ~/.claude/debug/<session-id>.txt | grep "Hooks:"
```

Each run appears as a line like:

```
Hooks: Stop [${CLAUDE_PROJECT_DIR}/.claude/hooks/readaloud.sh] finished with status 0 (13445ms)
```

To test the script without Claude Code:

```bash
echo '{"last_assistant_message":"Hello from the hook"}' | .claude/hooks/readaloud.sh
```

## Cost

Each reply makes one extra Claude Haiku call, which adds a few seconds before you hear anything.
