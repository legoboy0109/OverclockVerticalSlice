# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Redot 26.2 (Godot 4.x-compatible fork)
- **Language**: GDScript (C# may be added later for performance-critical systems)
- **Version Control**: Git with trunk-based development
- **Build System**: Redot Export Templates (same pipeline as Godot)
- **Asset Pipeline**: Redot/Godot Import System + custom resource pipeline

> **Note**: Redot is a hard-fork of Godot 4 and is backward-compatible with
> Godot 4.x projects and APIs, so the **Godot** engine-specialist agent set
> (`godot-specialist` and sub-specialists) is the correct one for this project.
> The engine binary is exposed at the repo root as `./redot`.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

> Redot is Godot-4-compatible, so the Godot engine reference is authoritative
> for this project (no Redot-specific reference is maintained).

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
