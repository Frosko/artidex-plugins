# Artidex plugin for Antigravity

Connects Google Antigravity (app, CLI `agy` and IDE) to your Artidex account, once for every team
you are a member of:

- **Artidex tools for your assistant** (MCP, signed in with OAuth): your assistant can list
  projects, register links and file them.
- **`/artidex-connect`**: says as whom Antigravity is connected, or how to sign in.
- **`/artidex-sync`**: registers the Gemini share links (`g.co/gemini/share/…`,
  `gemini.google.com/share/…`) and AI Studio app links (`*.ai.studio`) you paste, and proposes where
  each belongs. Nothing is filed until you confirm.

Artidex stores links and labels, never content. The plugin holds no scripts and no hooks.

## What it cannot do

- **No automatic capture.** Antigravity's `PostToolUse` hook receives the tool call and any error,
  never the tool's result, so no hook can see an address. Publishing from Antigravity is a shell
  `firebase deploy`, Gemini share links are made in the browser, and AI Studio publishes on the web:
  none of them is an event a plugin can observe.
- **No import of everything you shared.** Google offers no API or listing for your public Gemini
  links or AI Studio apps; their pages (`gemini.google.com/sharing`, `aistudio.google.com/apps`) are
  signed-in pages the plugin does not read.

## Install

Artidex's **Connect → Gemini** page shows the install command with the plugin's source:

```sh
agy plugin install <the source named on the Connect page>
```

The plugin has no settings and asks for no address: it knows where Artidex is. If it shows as
turned off, turn it on (Space on it under `/plugin` → **Installed** in the CLI, or
**Customizations → Installed** in the app, or `agy plugin enable artidex`).

Then sign in: when the Artidex server shows **Authenticate**, choose it. Your browser opens Artidex:
sign in and approve; the connection works in every team you are a member of. Antigravity's callback
page shows a code; paste it back into Antigravity. Antigravity keeps the token in `~/.gemini/antigravity/mcp_oauth_tokens.json`; the
plugin stores none.

Use it by asking ("file these links in Artidex: …") or with `/artidex-sync`. There is no `init`: nothing is
recorded by itself here, so there is no folder to tie to a project.

## What is sent

Only what the `artidex-sync` skill sends through the Artidex tools: links, titles, ids, the filing you
approved, and a one-line description only if you ask for one. The skill never opens the pages it
files.

## Remove

`agy plugin uninstall artidex` (or **⋮ → Uninstall** under **Customizations → Installed**). Then
disconnect the Antigravity connection in Artidex under **Settings → Access tokens → Connected apps**.
