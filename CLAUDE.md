# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Umbrella monorepo for the [Dracula Theme](https://draculatheme.com) project. It contains **447 git submodules** — one per supported application — stored under `themes/`. Each submodule points to an independent repository in the `dracula` GitHub organization. There is no build system, no tests, and no source code here; all theme files live in the individual submodule repos.

## Submodule operations

```bash
# Initialize and check out all submodules (slow — 447 repos)
git submodule update --init --recursive

# Update all submodules to their latest remote HEAD
git submodule update --recursive --remote

# Initialize + update a single submodule
git submodule update --init themes/<name>

# Add a new accepted theme as a submodule
git submodule add https://github.com/dracula/<name>.git themes/<name>
git add .gitmodules themes/<name>
git commit -m "feat(<name>): add <Name> theme"
```

The CI workflow (`update-submodules.yml`) runs this automatically on the first of every month and can be triggered manually via `workflow_dispatch`.

## Contribution flow for new themes

1. Contributor creates a repo from the [dracula/template](https://github.com/dracula/template).
2. They open an issue here linking their repo and a screenshot.
3. Maintainers accept → repo is transferred to the `dracula` GitHub org → contributor retains maintainer access.
4. A PR adds the submodule entry to this repo (`.gitmodules` + `themes/<name>`).

PRs that arrive here with just a link to an external repo should be redirected to follow this issue-first flow. Per the PR template, only accepted themes get merged as submodules.

## Color palette

The canonical Dracula colors (hex) — use these when evaluating or reviewing any theme:

| Role         | Dracula   | Alucard (light) |
|--------------|-----------|-----------------|
| Background   | `#282a36` | `#fffbeb`       |
| Current Line | `#44475a` | `#6c664b`       |
| Foreground   | `#f8f8f2` | `#1f1f1f`       |
| Comment      | `#6272a4` | `#6c664b`       |
| Cyan         | `#8be9fd` | `#036a96`       |
| Green        | `#50fa7b` | `#14710a`       |
| Orange       | `#ffb86c` | `#a34d14`       |
| Pink         | `#ff79c6` | `#a3144d`       |
| Purple       | `#bd93f9` | `#644ac9`       |
| Red          | `#ff5555` | `#cb3a2a`       |
| Yellow       | `#f1fa8c` | `#846e15`       |

All themes must maintain a `4.5:1` contrast ratio (WCAG 2.1 Level AA).
