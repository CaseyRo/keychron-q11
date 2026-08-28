# Wiki Doctrine

Structure rules for this repository's documentation. Every wiki operation
(generation, update, manual edit, compiler run) follows these rules. When tool
output conflicts with this doctrine, the doctrine wins.

This file replaces the global wiki doctrine in full for this repository.

## 0. The code is the canonical home for behavior

The wiki holds why, architecture, tradeoffs, and how to operate. It never
restates what the code says. A page that paraphrases code is deleted at lint;
behavior questions are answered by reading the code, and the wiki may only
point there.

This repository is unusually strict about it, because the code carries its own
reasoning inline and the README already holds the control table, the macOS
traps and the troubleshooting. Those are canonical. The wiki links them.

## 1. Single entrypoint

`quickstart.md` is the front door. Above the fold it gives a reader the
shortest path to understanding and running this project. Its closing section
is a Map: every wiki page, one line each. If a page is not reachable from the
Map, it does not exist.

## 2. Sections must earn themselves

A section (subdirectory) exists only when it holds multiple substantive pages.
One thin page does not justify a folder; it becomes a heading inside a broader
page. Default to flat. This wiki is flat and expected to stay that way at the
current size of the project.

## 3. No stubs

No placeholder pages, no "write this later", no single paragraph files.
Content too thin to stand alone merges upward into its parent topic.

## 4. One canonical home per concept

Every concept is explained in exactly one place. Other pages link to it; they
never re-explain it. When a concept appears twice, merge into the stronger
home and link from the other.

## 5. Prune what you touched

Every wiki operation ends by reviewing the pages it touched and their parents:
merge new stubs, collapse sections that no longer earn themselves, keep the
Map accurate for those pages. The whole tree review is a separate lint
operation, run on request: it additionally removes pages describing code that
no longer exists, deletes code paraphrase pages (rule 0), and verifies the Map
links everything.

## Update discipline

- Docs follow landed change. Update pages whose content is now wrong,
  incomplete, or missing; do not rewrite pages that are still accurate.
- `CLAUDE.md` links this wiki so agents read docs before exploring source.
  Keep that reference accurate.
- All documentation is plain markdown in this repository. No external systems,
  no lock in.
- No em-dashes. No all-caps words.

## Compiler behavior in this repository

`llm-wiki-compiler` is configured by `.wiki-compiler.json` and its default
output shape disagrees with this doctrine. The doctrine wins, so a compile run
in this repository must:

- write `quickstart.md` as the entrypoint, not `INDEX.md`
- stay flat: no `topics/` or `concepts/` directories at the current project
  size, per rule 2
- produce pages that hold reasoning, not summaries of the README or of code,
  per rules 0 and 4
- add any new page to the Map in `quickstart.md`, per rule 1

Prefer fewer, longer pages. Five thin articles compiled from one README are
stubs by rule 3, regardless of what the compiler template suggests.
