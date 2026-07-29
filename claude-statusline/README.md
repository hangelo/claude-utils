# Claude Code status line for Salesforce developers

A single-script status line for [Claude Code](https://claude.com/claude-code) that adds a
**wrong-org deploy tripwire** for `sf` CLI users, plus session cost and staleness cues.

```
user@host: ~/repos/my-sfdx-project [main !?] [Fable 5 · high] │ ⚡servicedev │ 42% 85k/200k │ $4.12 +320/-85 │ 1h42m
```

| Segment | What it shows |
|---|---|
| `user@host` | macOS user and machine name |
| `~/repos/…` | Claude Code's current working directory |
| `[main !?]` | git branch + dirty bits: `!` modified, `?` untracked, `+` staged new, `x` deleted, `>` renamed, `*` ahead of remote |
| `[Fable 5 · high]` | model powering the session · reasoning effort |
| `⚡servicedev` | **the default org `sf` commands will hit** — shown only inside an SFDX project. Green when it's your approved sandbox, red for anything else (including `⚡no-org`) |
| `42% 85k/200k` | context-window usage: green < 50%, yellow 50–74%, red ≥ 75% |
| `$4.12 +320/-85` | API-equivalent session cost + lines added/removed by Claude |
| `1h42m` | session wall-clock age |

Segments with no data (no git repo, no SFDX project, no cost yet) disappear instead of
rendering empty.

## Install

1. Copy the script and make it executable:

   ```bash
   cp statusline-command.sh ~/.claude/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```

2. Add to `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash ~/.claude/statusline-command.sh"
     }
   }
   ```

3. **Set your approved org.** The script greenlights exactly one org alias and shows every
   other target in red. Edit this line in the script to your own sandbox alias:

   ```bash
   if [ "$sf_org" = "servicedev" ]; then
   ```

Requires `jq` (`brew install jq`). Everything else is standard macOS/git tooling.

## How the org detection works

The script walks up from the current directory looking for `sfdx-project.json`; when found,
it reads `target-org` from that project's `.sf/config.json`, falling back to
`~/.sf/config.json`. It deliberately reads the JSON directly instead of shelling out to
`sf config get target-org` — the CLI takes seconds to start, far too slow for a status line
that re-renders on every turn.
