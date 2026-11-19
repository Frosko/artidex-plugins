# Artidex plugins

[Artidex](https://artidex.app) is a shared index of the pages your team publishes with AI tools:
Claude artifacts, ChatGPT Sites and shared chats, Gemini share links and AI Studio apps. The pages
stay where they were published; Artidex keeps their links and labels, never their content.

These plugins connect an AI tool to your Artidex account, so that your assistant can register
links and file them into your teams' projects. You need an Artidex account; you sign in through
your browser and no plugin asks for a password, a token or an address.

## Install

| Tool               | Install                                                                                                           | Details                                       |
| ------------------ | ----------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| Claude Code        | `/plugin marketplace add frosko/artidex-plugins`, then `/plugin install artidex@artidex`                          | [claude/](claude/README.md)                   |
| Codex              | `codex plugin marketplace add frosko/artidex-plugins`, then install **Artidex** from the Plugins Directory        | [codex/](codex/README.md)                     |
| Google Antigravity | `agy plugin install https://github.com/frosko/artidex-plugins`                                                    | [Antigravity](.antigravity-plugin/README.md) |

Then sign in from the tool: `/artidex:connect` in Claude Code, **Authenticate** for the Artidex
server in Codex and Antigravity. The **Connect** page of your Artidex account shows the same steps
and says when the tool is connected.

## What each tool can do

| Capability                             | Claude Code | Codex | Antigravity |
| -------------------------------------- | ----------- | ----- | ----------- |
| File links by asking your assistant    | yes         | yes   | yes         |
| Record a page when you publish it      | yes         | no    | no          |
| Import everything you published before | yes         | no    | no          |

Codex and Antigravity give a plugin no way to see a publish or to list what you published, so
there you give your assistant the links.

## What is sent

Links, titles and the filing you approve. No plugin opens or downloads a page, and none sends a
working directory, a repository or a session. Nothing runs when a session starts or when you send
a message: a plugin calls Artidex only when you publish (Claude Code) or when you ask. Each
package's page lists exactly what leaves your machine.

- Privacy: <https://artidex.app/privacy>
- Questions and problems: <https://artidex.app/contact>

## Where the files are

The root of this repository is the Antigravity plugin (`.antigravity-plugin/`, `mcp_config.json`,
`skills/`, `assets/`), because Antigravity installs a plugin from a repository's root. The Claude
Code plugin is in `claude/` and the Codex plugin in `codex/`; each tool reads only its own.

## License

[MIT](LICENSE).
