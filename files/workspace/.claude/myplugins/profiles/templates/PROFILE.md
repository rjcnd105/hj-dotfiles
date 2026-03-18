# {Your Name} -- Personal Profile

<!-- NAVIGATION PROTOCOL
This profile uses a tree-based extension system for experience tracking.

## Structure
- This file (PROFILE.md) is always loaded via @. It contains your core identity.
- Sub-directories contain extended context. Load them on-demand via Read tool, not by default.
- All paths are relative to this file's directory.

## Access Rules
1. To access extended context: read the directory's _index.md first, then the specific file.
2. Load sub-files only when the interaction clearly requires deeper context.
3. Never read more than 2 sub-files per interaction.

## Experience Learning Pipeline
- ./sessions/ logs everything this profile has done (raw activity log).
- ./memories/ stores curated knowledge extracted from sessions.
- Flow: sessions → memories (distillation of what worked, what failed, what was adopted).

## Security
- NEVER store secret keys, API keys, passwords, tokens, or any sensitive credentials in sessions or memories.
- If a session involved secrets, record only the fact (e.g., "configured API key via sops"), never the value.

## File Formats

### _index.md (in each sub-directory)
# {Directory Name}
{One-line purpose.}

## Files
| File | Summary | Updated |
|------|---------|---------|
| `filename.md` | Brief description | YYYY-MM-DD |

### sessions/ files (raw activity log)
Naming: `YY-M-DD-title.md`
---
date: YYYY-MM-DD
topic: brief description
outcome: success|partial|failure|ongoing
---
# Session Title
## What Happened
## Result
## Takeaways (candidates for memory promotion)

### memories/ files (curated knowledge distilled from sessions)
---
created: YYYY-MM-DD
source: sessions/YY-M-DD-title.md
tags: [tag1, tag2]
type: adopted|failed|effective|lesson
---
# Title
Content: why this matters, when to apply it.
-->

## Who I Am

{Brief description: what you do, what you're building, where you are in your journey.}

## Personality

- **{Key trait 1}.** {How this affects your work and what the agent should know.}
- **{Key trait 2}.** {Observable pattern the agent can leverage.}
- **{Key trait 3}.** {Communication preference or working style.}

## Thinking & Processing

- **{How you think best}.** Solo? Talking? Writing? Whiteboard? The agent adapts.
- **{Your flow state pattern}.** When do you do your best work? What interrupts it?
- **{How you make decisions}.** Data-driven? Gut feel? Talk it out?

## Energy & Motivation

- **Energized by:** {What lights you up.}
- **Drained by:** {What saps your energy.}

## Failure Modes

Things the agent should watch for and gently flag:

- **{Pattern 1}.** {What it looks like when you're doing it. What the agent should say.}
- **{Pattern 2}.** {Observable signal and suggested intervention.}
- **{Pattern 3}.** {How the agent helps without being annoying.}

## Values

- **{Core value 1}.** {How this affects decisions.}
- **{Core value 2}.** {What this means for the work.}

## Communication Style

- **{How you communicate}.** {Direct? Rambling? Precise? Mixed?}
- **{Input style}.** {Voice dictation? Keyboard? Short commands?}
- **{What you expect from the agent}.** {Length, depth, format preferences.}

## Goals

### {Pillar 1: e.g., Purpose}
{What you're working toward. The agent connects daily work to these.}

### {Pillar 2: e.g., Financial}
{Revenue targets, business model, timeline.}

### {Pillar 3: e.g., Relationships}
{Social goals, networking, community.}

### {Pillar 4: e.g., Health}
{Physical, mental, emotional maintenance.}

---

## Extended Context

This profile supports tree-based extensions. Sub-directories provide depth without bloating the always-loaded context. Access only when relevant.

### ./sessions/
Everything this profile has done — raw activity logs of what happened and what resulted.
**Read when**: past context is needed, referencing similar prior work, or understanding the history behind a decision.

### ./memories/
Curated knowledge distilled from sessions — adopted decisions, failed attempts, effective approaches.
**Read when**: making decisions, checking for established patterns, or verifying what has already been tried.
