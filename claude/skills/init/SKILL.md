---
description: Tie the folder Claude Code is working in to one Artidex project, so that what the user publishes from it is filed there and not left in the Inbox. Use when the user asks to link, tie or set up this folder or repository for Artidex.
argument-hint: '[project name | untie]'
allowed-tools: mcp__plugin_artidex_artidex__list-projects
---

# Tie this folder to an Artidex project

What the user publishes from Claude Code is recorded in Artidex and waits in their Inbox. A folder
tied to a project sends that project's id with the connection, and a publish made from it is filed
in the project straight away.

Argument given by the user: "$ARGUMENTS". Empty means: propose a project. "untie" means: remove
the tie of this folder (step 4).

## Rules

- The tie lives on this machine only, in the plugin's own data folder: a checksum of this folder's
  path and the id of the project. Artidex receives the project's id and nothing else: never send
  it this folder's path or name, a repository address or a branch, in any tool call.
- Take the project's id from `list-projects`: a short text that starts with `pj`, never a number.
  Never invent one.
- Tie only the project the user confirmed.
- If an Artidex tool is missing or fails with an authentication error, tell the user to run
  `/artidex:connect` and stop.

## Procedure

1. **Read the user's projects.** Call `list-projects`, paging with `offset` until `next_offset` is
   null, and note each team and each project's id and name.

2. **Choose the project.** With a project name in the argument, find it. Otherwise look for a
   project whose name resembles this folder's name; compare on your side only. Show the user the
   project you would tie (team and project) or, when none fits, a short list to choose from. If
   the project does not exist yet, say that it is created in Artidex first (no tool creates
   projects) and stop. Wait for the user's answer.

3. **Tie it.** Run exactly this command, with the confirmed project's id in place of
   `PROJECT_ID`:

    ```sh
    sh '${CLAUDE_PLUGIN_ROOT}/scripts/folder.sh' tie '${CLAUDE_PLUGIN_DATA}' '${CLAUDE_PROJECT_DIR}' PROJECT_ID
    ```

    Then tell the user: the tie takes effect when the Artidex server reconnects, which is `/mcp` →
    **plugin:artidex:artidex** → **Reconnect**, or the next session. From then on a publish from this
    folder is filed in that project; a project they may not add to is ignored and the link waits
    in the Inbox.

4. **Untie.** Run:

    ```sh
    sh '${CLAUDE_PLUGIN_ROOT}/scripts/folder.sh' untie '${CLAUDE_PLUGIN_DATA}' '${CLAUDE_PROJECT_DIR}'
    ```

    and say that publishes from this folder wait in the Inbox again after the next reconnect.
