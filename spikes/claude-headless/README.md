# Spike: Sophia on the unmodified Claude Code binary

Question: can a Mac app run Sophia by launching the installed, unmodified `claude` binary in headless mode, signed in with the person's own Claude subscription, with Sophia's prompt, a restricted tool set, and Sophia's own notebook tools?

## Run

```sh
node driver.mjs <empty-scratch-dir>
```

`driver.mjs` creates a disposable notebook and a canary file in the scratch directory, starts `claude` with the flags below, runs two scripted turns, then resumes the session in a second process. It writes `results.json` to the scratch directory. `server.mjs` is a minimal stdio MCP server with `read_page` and `propose_page`; `propose_page` only appends to `proposals.jsonl`.

Flags used:

```text
claude -p --input-format stream-json --output-format stream-json --verbose
  --restricted --tools WebSearch
  --strict-mcp-config --mcp-config <sophia server>
  --allowedTools mcp__sophia__read_page mcp__sophia__propose_page WebSearch
  --system-prompt <SOPHIA.md>
```

The child environment drops `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, and the Bedrock/Vertex switches.

## Observed (Oct 14, 2026; Claude Code 2.1.299, Node 26.0.0)

The first run resolved `claude` on PATH to cmux's wrapper script, which adds its own settings inside a cmux terminal. It was re-run with `CLAUDE_BIN=~/.local/bin/claude`, the official binary, with the same results below. The app must launch the official binary, not a wrapper.

| Check | Result |
|---|---|
| Authentication | Init event reported `apiKeySource: "none"` (the subscription login, not an API key). Model `claude-opus-5-5`. |
| Effective tools | Init listed exactly `WebSearch`, `mcp__sophia__propose_page`, `mcp__sophia__read_page`. No shell, file, or fetch tools. |
| Tool delivery | The model called `propose_page`; the server received the call and recorded `pr-1`. No page file was written. |
| Pending, not saved | Sophia told the person the proposal was pending and not saved, and repeated that after resuming. |
| Capability limits | Asked to run `ls ~` and read a file outside the notebook, Sophia had no tool to do either and made no tool call. |
| Instruction isolation | A `CLAUDE.md` in the working directory with a codeword was not loaded; Sophia reported no codeword. |
| Resume | A second process with `--resume <session-id>` recalled the proposal and its status. The MCP server restarted cleanly. |
| Companion behaviour | Unprompted, Sophia marked an unread citation "not checked in this session" and named a next topic. |

The CLI reported a running `total_cost_usd` of about $0.10 for the three turns. That is the CLI's own estimate; with `apiKeySource: "none"` the usage should count against the subscription, but subscription attribution was not independently confirmed (inconclusive, per AGENTS.md).

## Not yet tested

- Web search and a denied fetch; cancellation of a slow tool call; Streamable HTTP instead of stdio for the MCP server.
- Whether a user-level `~/.claude/CLAUDE.md` or managed settings reach the session under `--restricted`.
- Long sessions, the session-end checkpoint and return briefing from DATA-MODEL.md, and a Swift host instead of Node.
- Permission: whether Anthropic considers this arrangement within the conditions on its legal page for a paid, closed-source app. A written question is pending.
