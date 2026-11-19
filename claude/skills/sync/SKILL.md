---
description: Send the artifacts the user published at Claude to Artidex and file them into the projects and sections of the user's teams. Use when the user asks to sync, import, sort, file or tidy their artifacts in Artidex, or to sort the Artidex Inbox.
argument-hint: '[quick | inbox only | project name]'
allowed-tools: mcp__plugin_artidex_artidex__list-projects mcp__plugin_artidex_artidex__get-project-tree mcp__plugin_artidex_artidex__list-inbox mcp__plugin_artidex_artidex__register-artifacts mcp__plugin_artidex_artidex__search-artifacts mcp__plugin_artidex_artidex__list-artifacts
---

# Sync artifacts with Artidex

Artidex (https://artidex.app) is an index of links to AI-published artifacts shared by teams,
organised as project → section → artifact in each of the user's teams; the user's connection reaches
every one of them. You import the user's artifacts into it and propose where each one
belongs; the user decides.

A sync runs only when the user asks for it, with this command; nothing sends their gallery at any
other time.

Scope requested by the user: "$ARGUMENTS". Empty means the whole gallery. "quick" means a
re-sync, which must be quick and quiet: do steps 1 to 3 without asking which artifacts to register
(the user's own and the ones shared with them, as last time, always sending the whole gallery so
Artidex records the sync). Then page through `list-artifacts` (its default view gives each
entry's id, URL and whether it is rejected) and compare its URLs with the gallery: an Artidex
entry at claude.ai whose URL is no longer in the gallery was deleted at Claude or is no longer
shared with the user. Report in a few lines: how many artifacts are new and now
wait in the Inbox (with titles), how many known ones were refreshed, and which entries no longer
exist at Claude. Ask before rejecting those, and reject only the ones the user confirms. Stop
there unless the user asks you to go on and file the new ones. A re-sync never moves, renames in
place or deletes anything; rejected artifacts stay rejected. "inbox only" means skip
steps 2 and 3 and only sort what is already in the Inbox. A project name means import as usual but
propose filing only into that project, leaving everything else in the Inbox.

## Rules

- Artidex stores links and labels only. Send it URLs, titles, ids, tags and nothing else. Never send page content,
  quotes, figures, names of people, file paths, working directories or anything else copied from
  inside an artifact.
- Never open, read or download an artifact, for any reason: not to place it, not to describe it,
  not to check it. Everything here works from the listing (URL, title, date). Never use
  subagents, workflows, parallel work or a browser for any of this.
- Never apply bulk changes without the user's confirmation. Registering into the Inbox is the only
  write you make before the user has seen the plan, and you ask first unless they already said to
  import everything.
- `delete-section` deletes only an empty section, and only after the user agreed. Never move or
  reject what a section holds in order to delete it unless the user asked for that.
- Never invent ids. Take project and section ids from `list-projects`, and the `link_id` of a
  link in the Inbox from `register-artifacts` or `list-inbox`. An `artifact_id` is only for an
  artifact a team already has. Every id is a short text, never a number (a team's starts with
  `tm`, a project's with `pj`, a section's with `sc`, a link's with `ol`, an artifact's with
  `ar`): pass it exactly as the tool gave it.
- If an Artidex tool answers "Artidex needs an active subscription", tell the user in one sentence
  that Artidex needs an active subscription and give the link from that answer, then stop. Do not
  retry, do not call other Artidex tools and do not list the gallery.
- If an Artidex tool refuses with `other_account_linked` (this Artidex account is linked to another
  Claude account), `switch_too_soon` (it switched Claude accounts too recently) or `wrong_provider`
  (the connection was made for another AI tool), tell the user in one sentence what the answer says
  and give the link from it, then stop. Do not retry and do not call other Artidex tools.
- If an Artidex tool is missing or fails with an authentication error, stop and tell the user to run
  `/artidex:connect`. Do not retry.

## Procedure

1. **Read the structure of the user's teams.** Call `list-projects` (paging with `offset` until
   `next_offset` is null) and note each team and each project's id and name. Then, for each team you
   may file into, call `list-projects` with its `team_id` and `"sections": true`, paged the same way,
   and note each project's description and sections (id and path).

2. **List the user's artifacts** with the built-in Artifact tool: `action: "list"` with
   `scope: "mine"`, then with `scope: "shared"`, each with `limit: 200`, following
   `next_page_token` until there are no more pages. Keep only each artifact's URL, title and `updatedAt`,
   and which of the two listings it came from. Tell
   the user how many you found (mine / shared with me) and ask whether to register all of them,
   only their own, or a subset. Skip the question if their request already said which.

3. **Register them** with `register-artifacts`, at most 100 items per call, each item
   `{url, title, published_at, mine}` with `published_at` set to the artifact's `updatedAt` and
   `mine: true` only for artifacts from the `scope: "mine"` listing (it tells Artidex the user can
   open it; leave it out for shared ones), so Artidex
   shows when it was really published and not when it was imported. New artifacts land in the Inbox; artifacts Artidex already knows are matched by
   URL and only updated. This is the only way the gallery reaches Artidex: send each artifact
   once. Report the created / updated / invalid counts and the reason for any invalid item.

4. **Collect what needs filing.** Call `list-inbox`, paging with `offset` and `limit` until
   `next_offset` is null. These are the artifacts to place; artifacts already filed in a project
   are left alone.

5. **Propose a place for each Inbox artifact**, judged from its title and the project and section
   names and descriptions. Show one compact table per project, numbered so the user can correct by
   number:

    | #   | Artifact | Section        |
    | --- | -------- | -------------- |
    | 1   | Title    | Architecture   |
    | 2   | Title    | Research (new) |

    Then list the artifacts you would leave in the Inbox, with a short reason each (unclear title,
    no fitting project), and separately the ones you would reject: obvious scratch pages, probes
    and duplicates. Rejecting does not delete; the artifact moves to the Rejected list in Artidex,
    where the user can restore it. Propose a new section only when several artifacts clearly need it, marked
    "(new)". If a group of artifacts fits no project, propose a new project for it, marked "(new)",
    in a team where the user is owner or admin, and a new team only when none of theirs suits it.
    Never send the user to the Artidex site or a browser for something the tools can do.
    A title too ambiguous to place stays in the Inbox; do not open the artifact to find out.

6. **Ask the user to confirm or correct** the plan. Apply only what they confirmed, yourself:
   create each approved new team with `create-team` and each new project with `create-project`
   (it answers the project's id and sections; pass `"default_sections": false` when the plan brings
   its own sections for that project or files straight into it), each approved new section with
   `create-section`
   (first check that project's sections again with
   `list-projects`, its `project_id` and `"sections": true`, so you do not create a duplicate), then
   call `file-artifact` with `link_id`, `project_id` and, when there is one, `section_id`. Add
   `tags` or a one-line `description` only if the user asked for them. Call `reject-artifact`, also
   with `link_id`, only for artifacts the user agreed to reject. Leave every doubtful artifact in the Inbox. If a call
   fails because of the rate limit, wait a minute and continue.

7. **Report**: how many artifacts were registered, how many were filed per project and section,
   which teams, projects and sections were created, which artifacts were rejected, and which
   artifacts stayed in the Inbox and why. Point the user to https://artidex.app to review the result.
