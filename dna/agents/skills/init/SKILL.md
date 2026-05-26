---
name: init
description: Initialize a new CLAUDE.md file with codebase documentation. Detects the project type, asks the user to confirm, and folds the matching guide from `dna/agents/guides/` into the generated CLAUDE.md. Also writes a `PROJECT_STRUCTURE.md` into `dna/_override/` and includes its content in CLAUDE.md.
---

# Initialize CLAUDE.md (DNA-aware)

Analyze the current repository and produce a CLAUDE.md tailored to it. This skill is aware of the **DNA layout** that ships with `gg_dna`-style repos: project-specific guides live under `dna/agents/guides/`, and project-local overrides go into `dna/_override/`.

The end result is one CLAUDE.md at the repo root that combines:

1. The standard `init` analysis (commands, architecture, repo-specific notes).
2. The content of `dna/_override/PROJECT_STRUCTURE.md` (created by this skill).
3. The matching guide from `dna/agents/guides/` (if any).

---

## 1. Discover available guides

List the markdown files in `dna/agents/guides/` (relative to the repo root). Each file there is a candidate guide for one project type. If the folder is missing or empty, skip ahead to step 3 and produce a CLAUDE.md without a guide section.

The set of guides — and the heuristics for matching them — is **not hardcoded in this skill**. A consuming repo (typically via a `gg_dna sync <overlay>`) provides the concrete guides. For example, a project might ship a guide per framework or package family (one Markdown file per project type); treat any specific filenames you encounter as examples, not as a closed list.

## 2. Suggest a guide and confirm with the user

Inspect the working directory (package manifests, file structure, naming patterns) and pick the most plausible guide from step 1 as your initial guess. Heuristics you can use:

- **Package manifests**: `package.json` name/dependencies, `pubspec.yaml` name, `Cargo.toml`, `pyproject.toml`, etc.
- **Folder structure**: presence of `lib/src/`, `src/`, language-specific test layouts.
- **Tooling references**: scripts in `package.json`, workflow files, CLI tools mentioned in `README.md`.
- **Sibling repos**: directories next to this repo that share a naming prefix.

If none of the signals are conclusive, default to "no guide".

Then use `AskUserQuestion` to confirm:

> Detected project type: **<guide-name | none>**. Load the matching guide from `dna/agents/guides/<guide-name>.md`?

Options:

- `<detected guide> (Recommended)` — load that guide.
- Each remaining guide found in step 1 as an alternative option.
- `No guide` — skip the guide section entirely.
- (The `Other` option is added automatically.)

If the chosen guide file does not exist, tell the user, ask whether to continue **without** a guide section, and proceed accordingly. Do not invent guide content.

## 3. Analyze the codebase

1. **Commands** that will be commonly used — build, lint, run tests, run a single test, anything specific to this repo.
2. **High-level code architecture and structure** — the "big picture" that requires reading multiple files to understand.

Rules:

- If a `CLAUDE.md` already exists, **suggest improvements** to it instead of overwriting blindly. Surface the diff to the user before writing.
- Do **not** repeat obvious instructions ("write unit tests", "don't commit secrets", "provide helpful error messages").
- Do **not** enumerate every component or file structure that is trivially discoverable.
- Do **not** include generic development practices.
- Pull in important parts of `README.md`, `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md` if present.
- Do **not** invent sections like "Common Development Tasks", "Tips for Development", "Support and Documentation" unless they actually exist in source material you read.

## 4. Write `dna/_override/PROJECT_STRUCTURE.md`

Create the directory `dna/_override/` inside the target repo if it does not exist, and write a file `PROJECT_STRUCTURE.md` there.

`PROJECT_STRUCTURE.md` contains the **repo-specific** part of the analysis from step 3 — i.e. the parts that are unique to this concrete repository (its commands, its architecture, its conventions). It should NOT contain content from the chosen guide — that comes from `dna/agents/guides/` and is folded in separately.

Suggested structure (omit sections that don't apply):

```markdown
# PROJECT_STRUCTURE

## Commands
…repo-specific build / test / lint / run-single-test commands…

## Architecture
…big-picture overview that requires reading multiple files…

## Repo-specific notes
…anything pulled from README, cursor rules, copilot instructions…
```

Show the proposed content to the user before writing. After writing, mention the absolute path.

## 5. Compose `CLAUDE.md`

Write `CLAUDE.md` at the repo root with this exact ordering:

1. **Required prefix** (verbatim, including the blank line after):

   ```
   # CLAUDE.md

   This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
   ```

2. **Project structure section** — include the full content of `dna/_override/PROJECT_STRUCTURE.md` (without its top-level `# PROJECT_STRUCTURE` heading, which becomes a `## Project structure` heading here so the document keeps a single H1).

3. **Guide section** — include the full content of the chosen guide from `dna/agents/guides/`. Put it under a clearly named heading derived from the guide's file name (e.g. `## <guide-name> workflow`). If the guide already starts with its own H1, demote it to H2 so there is still only one H1 in CLAUDE.md.

If the user opted to skip the guide in step 2, simply omit section 3.

If `CLAUDE.md` already exists:

- Diff your proposal against the existing file.
- Show the user what would change and ask for confirmation before writing.
- Preserve any existing content the user added that isn't part of the analysis or the guide — when in doubt, ask.

## 6. Wrap up

Briefly tell the user:

- Absolute path of `CLAUDE.md`.
- Absolute path of `dna/_override/PROJECT_STRUCTURE.md`.
- Which guide was folded in (or that none was, if skipped).

Do not push, commit, or run any further tooling unless explicitly asked.

---

## Important

- **Never** write `CLAUDE.md` or `PROJECT_STRUCTURE.md` without showing the proposed content to the user first when an existing file would be overwritten.
- **Never** invent guide content — only fold in what actually exists at `dna/agents/guides/<name>.md`.
- **Never** add generic boilerplate ("use unit tests", "don't commit secrets", etc.) that this skill explicitly forbids.
- The `dna/_override/` folder is the canonical place for project-local overrides — do not write project-specific notes anywhere else.
