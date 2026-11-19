# Artidex plugin for Codex

Connects Codex (the ChatGPT desktop app and Codex CLI) to your Artidex account, once for every team
you are a member of:

- **Artidex tools for your assistant** (MCP, signed in with OAuth): your assistant can list
  projects, register links and file them.
- **`artidex-connect` skill**: says as whom Codex is connected, or how to sign in.
- **`artidex-sync` skill**: registers the ChatGPT Sites and shared-chat links you give it, or the
  address the Sites plugin reports after a deploy, and proposes where each belongs. Nothing is
  filed until you confirm.

Not included yet: **automatic capture** of a Sites deploy and **import of all your sites**. OpenAI
documents neither the Sites tool's name and result nor any listing of your sites. This package
ships a **probe** to find out, and a capture that stays off until the probe has shown what to set
(see [Optional hooks](#optional-hooks-off-by-default)).

Artidex stores links and labels, never content. See [What is sent](#what-is-sent).

## Install

OpenAI states no minimum Codex version. Plugins with hooks are supported for plugins installed by
hand in the ChatGPT desktop app; the MCP server and the skill also work in Codex CLI.

Add the Artidex marketplace; Artidex's **Connect → ChatGPT** page shows the command with the
marketplace's name:

```sh
codex plugin marketplace add <the marketplace named on the Connect page>
```

Then restart the ChatGPT desktop app, open the Plugins Directory, choose the **Artidex**
marketplace and install **Artidex** (in the CLI: `/plugins`, then the Artidex tab). Nothing asks
for an address: the plugin knows where Artidex is.

## Sign in

Installing asks you to authenticate the Artidex server. If it does not, open **Settings → MCP
servers** and choose **Authenticate**, or run `codex mcp login <name>` (`codex mcp list` shows the
name). Your browser opens Artidex: sign in and approve. The plugin stores no token; Codex keeps the
OAuth credentials in its own store. The connection works in every team you are a member of, with
your rights there; Codex can be connected on up to three machines, and a fourth sign-in ends the
oldest. To end it, disconnect **Codex** in Artidex under **Settings → Access tokens → Connected
apps**.

## Use

Ask for it ("file these links in Artidex: …", "sort my Artidex Inbox") or call `$artidex-sync`; `$artidex-connect` says as whom you are connected. There is no `init`:
nothing is recorded by itself here, so there is no folder to tie to a project. The
skill never opens the pages it files and never reads `chatgpt.com/sites`.

## What is sent

**Assistant tools.** The `artidex-sync` skill tells the assistant to send Artidex only links, titles,
ids, the filing you approved, and a one-line description only if you ask for one.

**Probe** (only when you turn it on): nothing leaves your machine. It appends to
`~/.codex/artidex-probe.log` one line per tool call: the time, the tool name, the key names of the
tool's input and result, and for each web address found in them the scheme, the host and the first
path word (`/share`; anything that is not a short word becomes `/*`). Titles, prompts, file
contents, other values, queries and the rest of each path are never written. It stops writing at
1 MB.

**Capture** (only when you turn it on and have set it up): for a `*.chatgpt.site` address found
where the settings point, it posts to `https://artidex.app/api/tools/v1/ingest/chatgpt/capture`:

| Field                     | What it is                                                 |
| ------------------------- | ---------------------------------------------------------- |
| `url`                     | `https://<site host>` only, without path or query          |
| `title`                   | only when the result has one at the configured title field |
| `X-Artidex-Client` header | `codex-plugin/<version>` from `plugin.json`                |

Your working directory, a git remote and the session id are never sent (since 0.1.4).

It needs a capture token for ChatGPT from Artidex in `ARTIDEX_TOKEN` in the environment Codex runs
hooks with. The token reaches `curl` through stdin, never its command line. It gives up on a request after 2 seconds, makes one request per deploy and never keeps trying by
itself: a refused token (`401`, `403`) is said once, with the reason, and nothing more is sent
until another token is exported; `429` is waited out for as long as Artidex says; a server error
or no answer gets one more try a second later and then waits for the next deploy;
`other_account_linked` and `switch_too_soon` show one sentence with the address Artidex gives; a
token of the wrong kind (`wrong_provider`, `wrong_entry_point`) is answered with what to create
instead and the address of the Connect page;
everything else stays silent. What it remembers for that (a checksum of the refused token, never
the token, and a time) is kept in the plugin's data folder, else in `~/.codex/artidex/`.

## Optional hooks (off by default)

None of these runs until you name it in `plugin.json` and trust it in Codex:

| File                           | What it does                                                        |
| ------------------------------ | ------------------------------------------------------------------- |
| `hooks/probe.json`             | runs `scripts/probe.sh` after every tool call (local log only)      |
| `hooks/capture.json`           | runs `scripts/capture.sh` after the Sites tool (needs a token)      |
| `hooks/register-with-mcp.json` | calls `register-artifacts` over the signed-in MCP server (no token) |

**Turn one on:** add it to `extensions.com.openai` in `plugin.json`, for example
`"hooks": "./hooks/probe.json"` (or a list of paths), reinstall or restart the desktop app so the
installed copy is refreshed, then review and trust it with `/hooks` in the CLI or **Settings →
Hooks** in the app.

**Turn it off:** remove the `hooks` line again and restart, or disable it under `/hooks`. Delete
`~/.codex/artidex-probe.log` when you no longer need it.

The capture settings (tool name, address field, title field) are in one marked block at the top of
`scripts/capture.sh`; the same tool name goes into the `matcher` of `hooks/capture.json` or
`hooks/register-with-mcp.json`.

## Remove

Uninstall **Artidex** in the Plugins Directory (or `/plugins` in the CLI), then
`codex plugin marketplace remove artidex`. Disconnect **Codex** in Artidex under **Settings →
Access tokens → Connected apps**, and delete `~/.codex/artidex-probe.log` if the probe ever ran.
