---
name: elixir
version: "0.3.1"
description: This skill should be used when the user asks to write, review, debug, or refactor Elixir code; design OTP supervision trees, GenServer/gen_statem processes, Ecto schemas/queries/migrations, Phoenix contexts, or Elixir release/production behaviour; or evaluate Elixir, Erlang/OTP, Ecto, LiveView, or Ash idioms and best practices.
---

# Elixir Programming Skill

Use this as a routing and decision guide. Keep detailed examples out of the
main context unless the task needs them.

## Version Stance

- Target modern Elixir code with Elixir 1.20 awareness and OTP 29 awareness.
- Treat Elixir 1.20 as an evolving type-system milestone, not a final static
  typing endpoint. Compiler type warnings are high-signal, but verify suspected
  false positives and keep Dialyzer for specs, callbacks, and cross-module
  contracts.
- Treat OTP 29 as a compatibility and hardening target. Check compiler
  warnings, deprecated Erlang forms, unsafe function warnings, SSH/SSL defaults,
  and release behaviour before claiming OTP 29 readiness.
- If a project pins older Elixir/OTP versions, follow the project pin first and
  avoid introducing APIs unavailable there.

## Load References

Read only the files needed for the current task:

| Task | Reference |
|---|---|
| Detailed core examples from the previous full skill body | `core-reference.md` |
| Control flow, pattern matching, with, comprehensions, behaviours, protocols | `language-patterns.md` |
| Module layout, formatter, Credo/style checks, readable conditionals | `code-style.md` |
| Lists, maps, structs, binaries, ETS-like choices, Erlang data structures | `data-structures.md` |
| Enum/Map/String/File/Process/Erlang stdlib quick lookup | `quick-references.md` |
| GenServer, supervision, ETS, process debugging, releases | `otp-reference.md` |
| Complete OTP patterns: workers, pools, cache, state machine, distribution | `otp-examples.md` |
| GenStage, Flow, Broadway, hot upgrades, advanced operations | `otp-advanced.md` |
| Ecto schemas, changesets, queries, Repo, Multi, migrations | `ecto-reference.md` |
| Complete Ecto examples | `ecto-examples.md` |
| ExUnit, Mox, LiveView tests, property testing | `testing-reference.md`, `testing-examples.md` |
| Types, compiler warnings, Dialyzer, @spec/@type guidance | `type-system.md` |
| Production, telemetry, Oban, HTTP clients, edge/IoT patterns | `production.md` |
| Architecture, Phoenix contexts, boundaries, anti-patterns | `architecture-reference.md` |
| Networking, TCP/UDP, framing, active/passive sockets | `networking.md` |
| Event sourcing with Commanded | `eventsourcing-reference.md`, `eventsourcing-examples.md` |

For Phoenix LiveView implementation details, prefer a dedicated LiveView skill
or project-local conventions after this base Elixir guidance. For Ash projects,
prefer Ash domain/resource/action/policy boundaries over generic Phoenix context
or hand-written Ecto service patterns.

## Core Rules

1. Prefer pattern matching, multi-clause functions, guards, and explicit data
   shapes over ad hoc branching.
2. Avoid `if` for structural dispatch. Use `if` freely for local boolean
   decisions where truthiness is intended and both branches are simple.
3. When strict `true`/`false` semantics matter, match explicitly with `case`.
4. Model expected failures as `{:ok, value}` / `{:error, reason}` and compose
   them with `case` or `with`. Reserve exceptions for programmer errors and
   system boundaries.
5. Let supervised processes crash for unexpected failures. Do not catch errors
   just to keep a broken process alive.
6. Use `try/rescue/catch` only at boundaries: untrusted decoding, adapter
   wrappers, process calls you do not own, or error translation.
7. Prefer `Enum`, `Stream`, comprehensions, and `Enum.reduce_while/3` over
   manual recursion for normal collection work. Use recursion for tree/graph
   traversal, early termination that does not fit `reduce_while`, or protocol
   internals.
8. Design transformation helpers data-first when you own the API and the result
   remains pipeable. Respect callback, constructor, and library API argument
   order when those contracts already exist.
9. Use `Map.fetch/2`, pattern matching, or explicit clauses when absence is part
   of the domain shape. A narrow `if is_nil(value)` is acceptable when the code
   is genuinely boolean and local.
10. Build repeated strings with IO data or a single final binary conversion.
11. Use atoms for bounded internal identifiers. Never convert untrusted external
    strings to atoms.
12. Use `%{struct | key: value}` for known struct updates. Use `Map.put/3` only
    when the key is dynamic by design.
13. Use `@impl` for behaviour callbacks.
14. Put `@derive` before `defstruct` or `schema`.
15. Prefer project-standard fixtures or factories for tests. Use ExMachina only
    when the project already standardizes on it or the dependency is justified.

## Construct Choice

| Need | Prefer | Avoid |
|---|---|---|
| Dispatch on data shape or struct type | Multi-clause functions | `if is_struct(...)` chains |
| One expected ok/error result | `case` | `if` |
| Two or more ok/error steps | `with` | deeply nested `case` |
| Local boolean branch | `if` | `case` ceremony |
| Strict boolean branch | `case bool do true -> ...; false -> ... end` | truthiness assumptions |
| Key may be absent and nil is valid | `Map.fetch/2` | `map[:key] != nil` |
| Early-exit accumulation | `Enum.reduce_while/3` | flags in `Enum.reduce/3` |
| Build a map from an enumerable | `Map.new/2`, `Enum.into/2`, `for ... into: %{}` | hand-written reduce by default |
| Parallel independent work | `Task.async_stream/3` | unbounded task spawning |
| Related database writes | `Ecto.Multi` + `Repo.transact/2` | deprecated `Repo.transaction/2` |
| Swap implementations by environment | Behaviour + config | `if Mix.env() == :test` in runtime code |

## OTP Design

- Put long-lived state behind supervised processes only when state, isolation,
  backpressure, or lifecycle ownership requires it. Do not use GenServer as an
  object or global bottleneck.
- Keep `init/1` fast. Use `handle_continue/2`, explicit warmup children, or
  project-standard async initialization for slow startup work.
- Keep callbacks small and non-blocking. Move pure transformation logic into
  ordinary modules.
- Bound queues, timeouts, concurrency, retries, and external calls. Make
  overload behaviour explicit.
- Use `PartitionSupervisor` or sharding when one process becomes a known
  bottleneck and the state can be partitioned.
- Use ETS, `:persistent_term`, `:counters`, or `:atomics` only when their
  lifecycle, write cost, and ownership model are understood.

## Ecto And Data

- Use changesets for input validation and casting. Use database constraints for
  uniqueness, referential integrity, and race-sensitive invariants.
- Compose related writes with `Ecto.Multi` and run them with `Repo.transact/2`.
- Keep queries composable and named by intent. Avoid loading data just to filter
  or aggregate in Elixir when the database should do the work.
- Preload deliberately. Watch for N+1 query paths in controllers, LiveViews,
  background jobs, and serializers.
- Keep migrations reversible where practical. For risky data migrations, make
  rollback and verification explicit.

## Phoenix, LiveView, And Ash Boundaries

- In Phoenix, keep domain rules in contexts or domain modules, not controllers
  or LiveViews.
- In LiveView, treat the LiveView as a state/event/render loop. Keep durable
  business rules outside the socket process. Use changesets for forms and
  project-standard components for UI composition.
- In Ash, resources, domains, actions, policies, validations, preparations, and
  code interfaces are the application boundary. Do not duplicate Ash actions as
  Phoenix-context service functions unless the project has a clear reason.

## Documentation And Types

- Document public modules and public APIs that form a contract. Internal helper
  functions may be left undocumented when names and local context are enough.
- Add `@spec` for public APIs, callbacks, boundary functions, and complex data
  contracts. Avoid noisy specs that just restate obvious private helpers.
- Use `@type`/`@typedoc` for domain data shared across modules.
- Treat compiler type warnings, Dialyzer warnings, and callback mismatches as
  design feedback, not just lint noise.

## Quality Gates

Run the strongest project-available checks before calling work done:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix dialyzer
mix credo --strict
mix sobelow
mix xref graph --label compile-connected
```

Use the subset available in the project. For OTP 29 readiness, also look for
deprecated Erlang forms, unsafe or potentially unsafe function warnings,
release/runtime warnings, and SSH/SSL option changes if the project uses Erlang
`:ssh`, `:ssl`, distribution, remote shells, or custom releases.

## Before Changing Code

1. Identify the project pins for Elixir, Erlang/OTP, Ecto, Phoenix, LiveView,
   Ash, and any OTP libraries involved.
2. Read existing project conventions before applying this skill globally.
3. Decide the responsible boundary: pure function, context/domain module,
   LiveView/component, Ash resource/action, process, supervisor, Repo, or
   adapter.
4. Make the smallest change that fixes the invariant.
5. Run the relevant quality gates and report exactly what ran.
