---
description: Connect Claude Code to the user's Artidex account, or say as whom it is connected. Use when the user asks to connect or sign in to Artidex, to check the Artidex connection, or when an Artidex tool is missing or refused.
argument-hint: '[token]'
allowed-tools: mcp__plugin_artidex_artidex__whoami
---

# Connect to Artidex

The connection is between this Claude Code and the user's Artidex account. It reaches every team
the user is a member of; no team is chosen here. The user signs in to Artidex in their browser:
nobody types an address, and no token is copied.

Argument given by the user: "$ARGUMENTS".

## Rules

- Never ask for a password, a token or an address in the conversation, and never offer to store
  one. If the user pastes a token here, tell them to revoke it in Artidex and create another.
- You cannot start the sign-in yourself: it runs in the user's browser, from `/mcp`.
- Call `whoami` at most once per run. Do not call other Artidex tools here.

## Procedure

1. **Unless the argument is "token"**, call `whoami`.

2. **It answers.** Say in a few lines: the account (`account.name`, `account.email`), the tool
   Artidex recognises (`connection.tool`) and how it signed in (`connection.signed_in_with`), how
   many teams it reaches, and how many links wait in the Inbox (`inbox.count`, with `inbox.url`).
   Then:
    - `connection.records_publishes` is false: say that this connection is not recognised as
      Claude Code, so what is published is not recorded, and give `connect_url`.
    - `connection.token_expires_at` is set: say when the token expires.
    - Otherwise say what comes next: `/artidex:sync` sends what they published and files it,
      `/artidex:init` ties this folder to a project.

3. **The tool is missing, or it fails because the server is not signed in, or the sign-in has
   expired.** Tell the user, in these words or close to them:

    > Run `/mcp`, choose **plugin:artidex:artidex**, then **Authenticate**. Artidex opens in your
    > browser: sign in and approve. Then run `/artidex:connect` again.

    Stop there. Do not retry by yourself.

4. **Artidex refuses** with "Artidex needs an active subscription", `other_account_linked`,
   `switch_too_soon` or `wrong_provider`: say in one sentence what the answer says, give the link
   from it, and stop.

5. **The argument is "token"** (only for a machine where the browser sign-in cannot be completed).
   Do not call any tool. Tell the user to create a token in Artidex under Connect → Claude →
   Claude Code, and then to run this in a terminal of their own, outside this session, where it
   asks for the token without showing it:

    ```sh
    sh '${CLAUDE_PLUGIN_ROOT}/scripts/folder.sh' token '${CLAUDE_PLUGIN_DATA}'
    ```

    Then to reconnect the server under `/mcp` and run `/artidex:connect` again. The same command
    with an empty answer removes the saved token and returns to the browser sign-in. If Artidex
    refuses the saved token, the plugin stops sending it and the server asks for the browser
    sign-in under `/mcp`: the user saves a token again or removes it, with the same command.
