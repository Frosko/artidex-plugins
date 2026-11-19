---
name: artidex-connect
description: Connect Codex to the user's Artidex account, or say as whom it is connected. Use when the user asks to connect or sign in to Artidex, to check the Artidex connection, or when the Artidex tools are missing or refused.
---

# Connect to Artidex

The connection is between this Codex and the user's Artidex account. It reaches every team the
user is a member of; no team is chosen here. The user signs in to Artidex in their browser: nobody
types an address, and no token is copied. The Artidex tools come from this plugin's `artidex` MCP
server.

## Rules

- Never ask for a password, a token or an address in the conversation.
- You cannot start the sign-in yourself: it runs in the user's browser.
- Call `whoami` at most once per run. Do not call other Artidex tools here.

## Procedure

1. Call `whoami`.

2. **It answers.** Say in a few lines: the account (`account.name`, `account.email`), the tool
   Artidex recognises (`connection.tool`), how many teams it reaches, and how many links wait in
   the Inbox (`inbox.count`, with `inbox.url`). Then say what comes next: the `artidex-sync` skill
   registers the links they give and files them.

3. **The tool is missing, or it fails because the server is not signed in, or the sign-in has
   expired.** Tell the user to sign in to the Artidex MCP server: in the ChatGPT desktop app under
   Settings → MCP servers → Authenticate, or with `codex mcp login <server name>` in the CLI
   (`codex mcp list` shows the name). Artidex opens in their browser: sign in and approve. Then
   ask for this skill again. Stop there; do not retry by yourself.

4. **Artidex refuses** with "Artidex needs an active subscription", `other_account_linked`,
   `switch_too_soon` or `wrong_provider`: say in one sentence what the answer says, give the link
   from it, and stop.
