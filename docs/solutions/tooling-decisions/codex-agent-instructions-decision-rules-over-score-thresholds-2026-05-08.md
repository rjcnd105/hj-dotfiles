---
title: Prefer decision rules over score thresholds in Codex agent instructions
date: 2026-05-08
category: tooling-decisions
module: Codex AGENTS instructions
problem_type: tooling_decision
component: assistant
severity: low
applies_when:
  - "Writing persistent AGENTS.md guidance for coding agents"
  - "A rule could be phrased as a numeric confidence or fit threshold"
  - "The instruction should improve judgment without causing literal over-application"
related_components:
  - codex
  - agents-md
  - prompting
  - llm
tags: [codex, agents-md, prompt-engineering, llm, decision-rules, maintainability]
---

# Prefer decision rules over score thresholds in Codex agent instructions

## Context

Global Codex instructions needed to capture several operator preferences:

- say when evidence is missing instead of guessing
- ask when several real options exist
- push back when a user instruction conflicts with facts, safety, or maintainability
- avoid code that is forced into an unnatural shape or hard to maintain after future changes

One tempting framing is to make this mathematical, such as assigning each option a
fit score and asking the user when the difference is below a threshold. That looks
precise, but in persistent agent instructions it usually creates false precision.
The model can generate score-like text without those scores being calibrated
probabilities, expected utilities, or stable uncertainty estimates.

A fresh-context implementation trial on 2026-07-14 exposed a related failure:
the existing advice to keep one source of truth and use the least machinery was
too abstract. Given an interface constraint that forbade passing state or a
handler, the agent treated the constraint as sufficient justification for local
state, lifecycle synchronization, an event listener, and a DOM helper. Its final
deletion review kept all of them because each supported the chosen interface.
The missing decision rule was to surface a boundary that forces parallel
authority or compensating coordination as a contract conflict before building
around it.

## Guidance

Use qualitative decision rules for persistent AGENTS guidance. Prefer rules that
name the observable condition that should change behavior:

```md
- Ground claims in files, docs, command help, runtime state, or current primary sources. If evidence is missing, say so and label assumptions rather than guessing.
- Default to action when the path is clear. Ask only when missing information materially changes the outcome, creates risk, or forces a meaningful tradeoff.
- When user direction conflicts with observed facts, safety, or long-term maintainability, state the concern and confirm or propose a safer path before proceeding.
- Avoid speculative abstractions, broad rewrites, normalization/fallback layers, cleanup, or new helpers unless the observed contract requires them.
```

Avoid hard scoring rules in global instructions:

```md
- Score each option from 0 to 1. If the top two scores differ by less than 0.1, ask the user.
```

For mechanism choices across frontend, backend, data, infrastructure, and
operations, use authority and boundary language rather than framework APIs:

```md
- Identify the authoritative owner, contract, or invariant before acting. Prefer reusing or strengthening it, and avoid introducing another copy that must be reconciled.
- If a requested boundary creates parallel authority or coordination solely to keep representations aligned, report the contract conflict and ask for the smallest boundary adjustment.
- Before completion, justify every new artifact or mechanism by the current requirement only it satisfies; remove it when an existing capability or stronger invariant can replace it.
```

This does not prohibit caches, replicas, sagas, controllers, or reconciliation.
Those remain valid when the actual contract requires them. It targets machinery
introduced only to compensate for an avoidable ownership or interface boundary.

That kind of rule can be useful inside an eval harness, review rubric, or
structured decision record where scores are measured consistently. It is weaker
as standing prompt guidance because the score may be a post-hoc rationalization
of a choice the model already leaned toward.

## Why This Matters

LLM-generated scores are often uncalibrated. A `0.65` versus `0.70` comparison
may only mean "B seems a bit better" while implying a precision the model does
not actually have. The problem gets worse when the score combines unrelated
dimensions such as correctness, maintainability, risk, reversibility, time cost,
and user preference into one scalar.

Hard numeric thresholds also encourage literal compliance. A coding agent may
start scoring every option, asking unnecessary questions, or shaping the work
around the threshold instead of the user's goal and the local project boundary.
For GPT-5.5-style prompts, the better fit is outcome-first guidance with clear
success criteria and stopping conditions, leaving the model room to choose the
efficient path when the task is already clear.

The practical distinction:

- Use decision rules when the instruction should guide judgment across many
  contexts.
- Use numeric rubrics when the scoring process is external, repeatable, and
  reviewable.
- Use hard thresholds only for true invariants, not for fuzzy fit judgments.

## Evaluation Evidence

The clean trial produced a working narrow interaction and strong focused checks,
but its shared implementation added two local states, two refs, two layout
effects, one input listener, and a separate DOM helper. It also mutated a value
owned by the rendering layer, leaving correctness dependent on future rerenders
and the current component DOM structure.

After adjusting the boundary, the production implementation used one owner for
the password state and derived its input type, icon, and accessibility state from
that owner. Clear-button visibility used platform state rather than a mirrored
runtime state. This removed the lifecycle synchronization while preserving the
behavioral contract. The trial therefore supports a qualitative global rule:
detect ownership conflicts before implementation, not a numeric complexity
threshold or a list of frontend-specific APIs.

## When to Apply

- When editing global or repo-level `AGENTS.md`.
- When a user preference is real but should not become a rigid ritual.
- When the agent should ask fewer but better questions.
- When maintainability matters more than maximizing apparent autonomy.

## Examples

Decision-rule phrasing handles the same intent without false precision:

```md
Ask only when missing information materially changes the outcome, creates risk,
or forces a meaningful tradeoff.
```

This covers the intended "ask when options are close" behavior without requiring
the model to invent calibrated scores. It also lets high-risk work ask sooner
and low-risk reversible work proceed even when several acceptable approaches
exist.

For maintenance code, use invariant and contract language:

```md
Choose the smallest behavior-preserving change that fixes the invariant, not one
visible symptom.
```

This is more robust than asking the model to optimize a generic maintainability
score, because it names the domain behavior: preserve existing behavior, fix the
actual invariant, and keep the diff within the smallest responsible surface.

## Related

- [Global Codex AGENTS source](../../../files/workspace/.codex/AGENTS.md)
- [OpenAI Codex best practices](https://learn.chatgpt.com/guides/best-practices.md)
- [OpenAI GPT-5.5 guide](https://developers.openai.com/api/docs/guides/latest-model)
