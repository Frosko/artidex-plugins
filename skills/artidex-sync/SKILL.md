---
name: artidex-sync
description: Register Gemini share links, AI Studio app links and other AI-published links in Artidex and file them into the projects and sections of the user's teams. Use when the user asks to add, record, file, sort or tidy links in Artidex, or to sort the Artidex Inbox.
---

# Organise links in Artidex

Artidex is an index of links to AI-published artifacts shared by teams, organised as project →
section → artifact in each of the user's teams; the user's connection reaches every one of them. You register the links the user pastes and propose where each one belongs; the user
decides. The Artidex tools come from this plugin's MCP server (`artidex_artidex`).

## What can be registered

Only links the user pastes or names in this conversation:

- Gemini share links: `https://g.co/gemini/share/<id>`, which is the same page as
  `https://gemini.google.com/share/<id>`.
- Published AI Studio apps: `https://<name>.ai.studio`.
- Any other web link the user explicitly wants in the index.

Antigravity's own artifacts (plans, walkthroughs, screenshots) are local files, not links: do not
register them. There is no import of everything the user has shared: Google offers no way to list
it. Never open `gemini.google.com/sharing`, `aistudio.google.com/apps` or any other page to collect
links, and never use the browser, a URL reader or a shell command to read them. If the user wants
everything in Artidex, ask them to paste the links, or to add each page with the Artidex browser
panel.

## Rules

- Artidex stores links and labels only. Send it URLs, titles, ids, tags and nothing else. Never send
  page content, quotes, figures, names of people, file paths, working directories or anything else
  copied from inside a shared chat or an app.
- Never open, read or download a linked page, for any reason: not to place it, not to describe it,
  not to check it. Work from the link and the title the user gives.
- Never apply bulk changes without the user's confirmation. Registering into the Inbox is the only
  write you make before the user has seen the plan.
- `delete-section` deletes only an empty section, and only after the user agreed. Never move or
  reject what a section holds in order to delete it unless the user asked for that.
- Never invent ids. Take project and section ids from `list-projects`, and the `link_id` of a
  link in the Inbox from `register-artifacts` or `list-inbox`. An `artifact_id` is only for an
  artifact a team already has. Every id is a short text, never a number (a team's starts with
  `tm`, a project's with `pj`, a section's with `sc`, a link's with `ol`, an artifact's with
  `ar`): pass it exactly as the tool gave it.
- If an Artidex tool answers "Artidex needs an active subscription", tell the user in one sentence
  that Artidex needs an active subscription and give the link from that answer, then stop. Do not
  retry and do not call other Artidex tools.
- If an Artidex tool refuses with `other_account_linked` (this Artidex account is linked to another
  Google account), `switch_too_soon` (it switched Google accounts too recently) or `wrong_provider`
  (the connection was made for another AI tool), tell the user in one sentence what the answer says
  and give the link from it, then stop. Do not retry.
- If the Artidex tools are missing or fail with an authentication error, stop and tell the user to
  run `/artidex-connect`. Do not retry.

## Procedure

1. **Read the structure of the user's teams.** Call `list-projects` (paging with `offset` until
   `next_offset` is null) and note each team and each project's id and name. Then, for each team you
   may file into, call `list-projects` with its `team_id` and `"sections": true`, paged the same way,
   and note each project's description and sections (id and path).

2. **Collect the links** the user gave. Keep only each link and its title, if the user gave one.
   Ask once for missing titles; a link without a title can still be registered.

3. **Register them** with `register-artifacts`, at most 100 items per call, each item
   `{url, title, mine}`. Set `mine: true` only for links the user says they shared or published
   themselves; leave it out otherwise. New links land in the Inbox; links Artidex already knows are
   matched by URL and only updated. Report the created / updated / invalid counts and the reason for
   any invalid item.

4. **Collect what needs filing.** Call `list-inbox`, paging with `offset` and `limit` until
   `next_offset` is null. Artifacts already filed in a project are left alone.

5. **Propose a place for each Inbox artifact**, judged from its title and the project and section
   names and descriptions. Show one compact table per project, numbered so the user can correct by
   number:

    | #   | Artifact | Section        |
    | --- | -------- | -------------- |
    | 1   | Title    | Architecture   |
    | 2   | Title    | Research (new) |

    Then list what you would leave in the Inbox, with a short reason each, and separately what you
    would reject (scratch pages, probes, duplicates). Rejecting does not delete; the artifact moves
    to the Rejected list in Artidex, where the user can restore it. Propose a new section only when
    several artifacts clearly need it, marked "(new)". If a group of artifacts fits no project,
    propose a new project for it, marked "(new)", in a team where the user is owner or admin, and a
    new team only when none of theirs suits it. Never send the user to the Artidex site or a browser
    for something the tools can do.

6. **Ask the user to confirm or correct** the plan. Apply only what they confirmed, yourself:
   create each approved new team with `create-team` and each new project with `create-project`
   (it answers the project's id and sections; pass `"default_sections": false` when the plan brings
   its own sections for that project or files straight into it), each approved new section with
   `create-section`
   (first check that project's sections again with
   `list-projects`, its `project_id` and `"sections": true`, so you do not create a duplicate), then
   call `file-artifact` with `link_id`, `project_id` and, when there is one, `section_id`. Add
   `tags` or a one-line `description` only if the user asked for them. Call `reject-artifact`, also
   with `link_id`, only for artifacts the user agreed to reject. If a call fails because of the rate limit, wait a minute
   and continue.

7. **Report**: how many links were registered, how many were filed per project and section, which
   teams, projects and sections were created, which artifacts were rejected, and which stayed in the
   Inbox and why.
   Point the user to their Artidex site to review the result.
