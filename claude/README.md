# Artidex plugin for Claude Code

Connects your Claude Code to your Artidex account, once for every team you are a member of:

- **Publish hook**: every artifact you publish from Claude Code is recorded in Artidex: in the
  project you tied the folder to, or in your Inbox.
- **Artidex tools for your assistant** (MCP): your Claude can list projects, register artifacts and
  file them.
- **Three commands**: `/artidex:connect` (sign in, or see as whom you are connected),
  `/artidex:sync` (send what you published and file it; nothing is filed until you confirm) and
  `/artidex:init` (tie this folder to a project).

Artidex stores links and labels, never artifact content. See [What is sent](#what-is-sent).

## Install and connect

You need Claude Code 2.1.285 or newer. Nothing asks for a token or an address: the plugin knows
where Artidex is, and you sign in through your browser.

1. **Add the marketplace.** Artidex's **Connect → Claude** page shows the command with the
   marketplace's name. In Claude Code:

    ```text
    /plugin marketplace add <the marketplace named on the Connect page>
    ```

2. **Install the plugin** and restart Claude Code:

    ```text
    /plugin install artidex@artidex
    ```

3. **Connect:** run `/artidex:connect`. The first time it sends you to `/mcp` →
   **plugin:artidex:artidex** → **Authenticate**: Artidex opens in your browser, you sign in and approve.
   Run `/artidex:connect` again and it says as whom you are connected. When the
   sign-in expires, the same command.
4. **Import your artifacts:** run `/artidex:sync`. Add `quick` to only send the gallery and hear
   what is new, `inbox only` to sort what is already in the Inbox, or a project name to file only
   into that project. It works from the listing (link, title, date); the plugin never opens or
   downloads an artifact.
5. **Tie a folder to a project** (optional): run `/artidex:init` in it. What you publish from that
   folder is then filed in the project; everything else waits in your Inbox.

The connection is with your account, never with one team, and Claude Code can be connected on up
to three machines; a fourth sign-in ends the oldest. To end one, disconnect **Claude Code** in
Artidex under **Settings → Access tokens → Connected apps**.

When Claude asks to use `file-artifact` or `create-section`, you can answer "don't ask again" for
the Artidex server.

### With a token instead

Only for a machine where the browser sign-in cannot be completed. Create a token in Artidex under
**Connect → Claude → Claude Code**, run `/artidex:connect token` and follow it: it gives a command
for a terminal of your own, which asks for the token without showing it and keeps it in a file
only you can read, in the plugin's data folder. The token never passes through a conversation.
The same command with an empty answer removes it. A token Artidex refuses is not sent again: the
plugin remembers the refusal (a checksum, never the token) and the server asks for the browser
sign-in under `/mcp` until you save a token again or remove it.

### Updates and removal

`/plugin marketplace update artidex` fetches a new version; it takes effect at the next session
start. To remove the plugin: `/plugin uninstall artidex@artidex`, then
`/plugin marketplace remove artidex`.

## What is sent

**Publish hook.** After a publish with the Artifact tool Claude Code calls Artidex's
`capture-artifact` tool over the plugin's own signed-in connection, with exactly these values of
the event:

| Value                      | What it is                                           |
| -------------------------- | ---------------------------------------------------- |
| `url`, `title`             | the artifact link and its title                      |
| `description`              | only when the publish sets one                       |
| `action`                   | empty or `publish`; the name of any other use        |
| `X-Artidex-Project` header | the id of the project you tied the folder to, if any |
| `X-Artidex-Client` header  | `claude-plugin/<version>`                            |

Claude Code runs the hook after every use of the Artifact tool: it cannot tell a publish from
another use before calling. For a read, a listing, opening, pinning or deleting, the event has no
link, title or description to send, so the call carries only the name of the use in `action`;
Artidex answers "not a publish" and stores nothing.
**Never sent:** your working directory or its name, a git remote, the session id, the page HTML,
edit fragments, a listing of your gallery, the local file that was published, the transcript, or
anything else in the event. No script of the plugin talks to Artidex.

**Your gallery** is sent only when you run `/artidex:sync`: Claude lists it and registers the
links, titles and dates through the Artidex tools. Listing your artifacts for any other reason
sends none of them. The plugin runs nothing when a session starts and nothing when you send a message,
and never adds anything to your conversations by itself.

**A tied folder.** `/artidex:init` writes one small file in the plugin's data folder
(`~/.claude/plugins/data/…`): a checksum of the folder's path, never the path, and the project's
id. When Claude Code connects the Artidex server it runs `scripts/folder.sh`, which reads that
file and adds the id as a header; it calls nothing.

**Which client.** Every request carries `X-Artidex-Client: claude-plugin/<version>` (`.mcp.json`
names it). Artidex shows it as the connection's last client; it decides nothing.

**Assistant tools.** Your assistant reads artifacts with its own access; that content stays in your
conversation. The `sync` skill tells it to send Artidex only links, titles, ids, the filing you
approved, and a one-line description only if you approve it.

## Without access to Artidex

Artidex is a paid product with a free trial. When your account has no access (the trial is over
and there is no subscription), nothing is recorded: the publish hook stays silent and the
assistant tools answer "Artidex needs an active subscription" with a link to Artidex. Everything
works again by itself once the account has access. The plugin never asks for or handles payment
details.

## When Artidex refuses

- **Not signed in, or the sign-in ended.** The hook never starts a sign-in and records nothing;
  run `/artidex:connect`.
- **Another Claude account is linked to your Artidex account**, or it switched accounts too
  recently: one sentence with the link Artidex gives, and nothing is recorded.
- **The connection is not recognised as Claude Code**: one sentence with the Connect page.

When and how often Claude Code itself tries a connection again is its own; Artidex answers a
refused connection plainly and limits how often it may be tried.

## Troubleshooting

**`plugin:artidex:artidex` is not connected.** Restart Claude Code after installing, then run
`/artidex:connect`.

**A publish did not appear.** Look in your Inbox first: a link is filed in a project only from a
folder you tied to it with `/artidex:init`, after the server reconnected. `/artidex:connect` says
whether the connection records publishes.
