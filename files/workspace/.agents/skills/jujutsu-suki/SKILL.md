---
name: jj
description: DAG-native version control discipline for jj repositories (a `.jj/` directory is present, possibly alongside `.git/`). Use when the task touches version control at all — commit, push, fetch, pull, status, diff, log, bookmark, branch, merge, rebase, split, squash, stash, undo, conflicts, PR prep. All mutations go through jj; git is read-only.
---

# jj

Verified against jj 0.45.1. Syntax lives in `jj help <cmd>`; this file carries the discipline, plus the danger surface no `--help` will confess.

## You operate on a DAG

Picture the commit DAG and act on it directly. `@` (the working copy) is a cursor marking where file edits land — one node among many, not the center of operations.

What makes this cheap in jj:

1. **Every node is addressable.** A change ID (the k–z letter ID in `jj log`) names a node forever, across rewrites. Address nodes by change ID; `@` shorthand is for the node you are authoring right now.
2. **History rebuilds itself.** Rewrite any node — `describe`, `squash`, `split`, `rebase` — and descendants rebase automatically. Editing mid-DAG is routine, not surgery.
3. **The cursor moves freely.** `jj new <id>` / `jj edit <id>` park it anywhere. Work in progress is already a commit, so there is nothing to stash.
4. **Snapshots are automatic.** Every jj command folds the current file state into `@`. New files included — `@` *is* the staging area, already committed.
5. **Changes route to where they belong.** Misplaced hunks move between nodes while the cursor stays put (toolbox below).

Addressing needs an ID, so every operation starts by reading the graph:

```bash
jj log    # read before you write; IDs stay valid to reuse this turn
          # after ANY rewrite (squash/rebase/split/abandon): re-read, prefixes shift
```

If a change ID resolves to two commits (jj marks it divergent), that ID stops being addressable — `jj abandon <id>` fails. Abandon the loser by commit ID or change offset (`<id>/0`, `<id>/1`), then re-read.

## Two states

You are always in exactly one.

**Authoring** — writing new work. Open a node and declare intent *before* editing files:

```bash
jj new <parent-id> -m "feat: what this will become"
```

Edits auto-snapshot into it as you work. Finish = task probe green (below). The next task opens its own node with `jj new`.

**Correcting** — fixing what already exists on the DAG. The cursor stays put; address the node:

```bash
jj describe <id> -m "better message"              # fix a message
jj squash --from <A> --into <B> -m "msg"          # fold node A into node B
```

Entry test: *am I writing something new, or fixing something that exists?*

## Routing toolbox

When `jj diff -r <id>` shows content that belongs elsewhere, in order of preference:

| Move | Command |
|---|---|
| hunks back to the ancestors that last touched those lines | `jj absorb --from <id>` (never opens an editor) |
| specific files/hunks into a chosen node | `jj squash --from <A> --into <B> <paths> -m "msg"` |
| some files out into their own node, in place | `jj split -r <id> <paths> -m "msg for extracted part"` |
| files out to a new node anywhere on the DAG | `jj split -r <id> <paths> -m "msg" -A <dest-parent>` |

After `split`, bookmarks on the node follow the *second* half (legacy default) — re-read the log.

## Danger surface (why `-m` appears everywhere above)

jj forks `$EDITOR` without checking for a TTY: in an agent shell that hangs forever, and under a no-op `$EDITOR` it "succeeds" while doing nothing.

**Hangs unless flagged** — always pass `-m` (or `-u` where noted):
- `describe` / `commit` without `-m`
- `squash` without `-m`/`-u` when both source and destination carry descriptions (works bare otherwise — a nondeterministic trap, so always `-m`)
- `split <paths>` without `-m`
- `converge` without `--no-interactive` (forks `$EDITOR` to merge descriptions; with the flag it exits 1 rather than guessing, and even a successful converge can leave a conflicted commit)
- everything `-i`/`--interactive`/`--tool`, `jj resolve`, `jj diffedit`

**Exits 0 while lying:**
- `jj git push` can print `Warning: Refusing to create new remote bookmark` and push nothing → push probe is mandatory
- revset `description("x")` is a full-string *glob* (real descriptions end in `\n`, so it matches nothing) → use `subject("x")` or `description(substring:"x")`
- `jj log` hides abandoned commits and deep ancestors by default; a "missing" commit is usually visible via `jj log -r <id>` or found through `jj op log`

**Destructive with exit 0:**
- `jj restore` bare resets *all* of `@` to its parent — auto-tracking means it deletes brand-new files too. Restore only exact `<paths>` you mean to reset; misplaced work is a routing job (toolbox above).
- `jj abandon` bare targets `@`.

Recovery: `jj op log` records every operation on the whole repo. `jj undo` reverses the last one — at most once; then read `jj op log` and `jj op restore <op-id>` to the state you want.

## Done = probes green

Claim completion only on green probes, read from the DAG:

```bash
# Task probe — EMPTY output is green (described, non-empty, conflict-free):
jj log -r '<id> & (empty() | conflicts() | description(exact:""))'

# Push probe — NON-EMPTY output is green (remote pointer actually moved):
jj log -r '<id> & remote_bookmarks()'
```

Judge probes by their *output*, never by exit status — jj exits 0 on an empty set, so chaining `&& echo ok` manufactures a false green.

## Sync and push

Bookmarks are name tags for remotes, bound late: work anonymously, name at push time.

```bash
jj git fetch
jj rebase -d 'trunk()'            # conflicts land inside commits; rebase always completes
jj log                            # re-read after the rewrite
jj bookmark set <name> -r <id>    # create-or-move, right before pushing
jj git push -b <name>             # then run the push probe
```

An existing PR branch uses the same commands: `bookmark set` moves it, and push force-pushes rewritten history automatically.

## Conflicts

A conflicted node is a normal node whose files contain conflict markers (`<<<<<<<` with `%%%%%%%` diff sections). Edit those files to their intended final state — markers gone — until `jj st` stops listing unresolved conflicts. Fix it where it lives: `jj new <conflicted-id>`, resolve, `jj squash -m "resolve"`, or edit the files via the toolbox from wherever the cursor is.

## Colocated repos (`.git/` + `.jj/`)

git serves read-only needs (CI scripts, tooling that shells out to `git log`). Every mutation goes through jj, which keeps both views consistent.
