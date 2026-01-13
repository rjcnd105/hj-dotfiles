name: using-jj
description: Use when managing source control with Jujutsu (jj), including commits, branching (bookmarks), rebasing, and GitHub PRs.

# Using Jujutsu (jj)

## Overview
Jujutsu (jj) is a Git-compatible VCS that treats commits as mutable objects identified by a Change ID. It emphasizes a "stacked diffs" workflow where you can easily manipulate history.

## When to Use
- **Always** for VCS operations in this project (instead of `git`).
- Creating commits, branches (bookmarks), and PRs.
- Rebasing, splitting, or squashing changes.

## Core Concepts
- **Change ID**: Constant identifier (e.g., `kkmpptxz`) for a change. Persists across rewrites.
- **Commit ID**: Git SHA (e.g., `a1b2c3d`). Changes every time you modify the revision.
- **Bookmark**: Equivalent to a Git branch. Points to a specific revision.
- **Working Copy (@)**: The revision you are currently editing.

## Workflow: Creating a PR

1.  **Work**: Make changes in the working copy.
2.  **Describe**: `jj describe -m "feat: description"`
3.  **Bookmark**: `jj bookmark create <branch-name>`
4.  **Push**: `jj git push --bookmark <branch-name>`
5.  **PR**: `gh pr create`

## Common Operations

| Goal | Git Command | JJ Command |
| :--- | :--- | :--- |
| **Status** | `git status` | `jj st` |
| **Log** | `git log --graph` | `jj log` |
| **Commit** | `git add . && git commit` | `jj describe -m "msg"` (no staging needed) |
| **Amend** | `git commit --amend` | `jj describe -m "new msg"` (metadata) or edit files (content) |
| **New Branch** | `git switch -c feat` | `jj new -m "feat" && jj bookmark create feat` |
| **Switch** | `git switch main` | `jj edit main` (edits existing) or `jj new main` (new on top) |
| **Push** | `git push` | `jj git push` |
| **Pull** | `git pull` | `jj git fetch` (updates remote pointers, doesn't merge) |

## Stacking & Reshaping

- **Rebase**: `jj rebase -s <revision> -d <destination>`
- **Split**: `jj split` (interactive split of current change)
- **Squash**: `jj squash` (moves changes into parent)

## Red Flags / Anti-Patterns
- ❌ **Don't use `git` commands directly** for creating commits/branches (except `gh` CLI).
- ❌ **Don't panic about "detached HEAD"**. JJ is always detached. Use `jj new` to start fresh.
- ❌ **Don't forget to push bookmarks**. Changes without bookmarks are local-only.

## Troubleshooting
- **Conflict**: `jj` records conflicts in the file. Edit file to resolve `<<<<` markers, then no `git add` needed.
- **Lost**: `jj op log` shows operation history. `jj undo` works like magic.
