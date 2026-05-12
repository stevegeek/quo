# Claude Code skill: Quo

A [Claude Code](https://claude.com/claude-code) skill that teaches Claude
how to use the [Quo gem](https://github.com/stevegeek/quo) for building
composable, type-safe query objects in a Rails application.

## What this skill provides

`SKILL.md` (loaded automatically by Claude Code) covers:

- The two composition modes (class vs instance) and when to use each
- Core query object patterns for ActiveRecord and collections
- Type-safe property declarations using Literal
- Pagination, transformer, and `wrap` patterns
- A short cookbook of common patterns

`references/` (loaded on demand by Claude when it needs depth):

| File | Read when… |
|---|---|
| `references/QUERY_TYPES.md` | Detail on RelationBackedQuery vs CollectionBackedQuery |
| `references/COMPOSITION.md` | Composition modes, merge strategies, joins, conditional building |
| `references/PAGINATION.md` | Page navigation, counts, unpaginated access |
| `references/TRANSFORMERS.md` | Result transformation, presenter patterns |
| `references/API_REFERENCE.md` | Method-by-method reference for queries and results |

## Versioning

Each markdown file in this skill carries a banner near the top declaring
which Quo version it targets, e.g.:

> **Targets Quo `~> 2.0`.**

When you upgrade the gem, re-run the install generator with `--force` to
refresh the skill content:

```bash
bin/rails generate quo:install --force
```

## Installation

The intended path is the bundled Rails generator (ships with Quo `~> 1.0`):

```bash
bin/rails generate quo:install
```

This copies the skill into your app's `.claude/skills/quo/` directory.
Claude Code picks it up automatically on the next session.

You can also install manually by copying this directory to
`.claude/skills/quo/` in your project root.

### CLAUDE.md fragment

The generator can optionally append a "Quo" section to your project's
top-level `CLAUDE.md`, telling Claude that the project uses Quo and
where the skill lives. This is opt-in:

```bash
bin/rails generate quo:install --with-claude-md
```

If you prefer to manage `CLAUDE.md` by hand, just add a line like:

```markdown
## Quo

This project uses the Quo gem for query objects. See
`.claude/skills/quo/SKILL.md` for usage guidance.
```

## How it works

When Claude Code starts a session, it loads `SKILL.md` automatically.
That makes the core concepts and quick references immediately available
in context. When Claude needs depth on a specific topic, it reads the
relevant file from `references/` on demand.

The skill is organised around progressive disclosure: keep `SKILL.md`
short and grep-friendly; put the long detail in references.

## Contributing

To improve this skill:

1. Edit the relevant markdown file
2. Keep `SKILL.md` concise — quick references and patterns
3. Put detailed material in the `references/` files
4. Update the version banner if the API surface you describe changed
5. Use the `Post` / `Author` / `Comment` fixture models from the gem's
   own test suite for examples — they're verifiable against the gem's
   tests and avoid project-specific terminology

## Related

- Quo source: <https://github.com/stevegeek/quo>
- Quo documentation site: <https://quo-gem.diaconou.com/>
- Literal (type system): <https://github.com/joeldrapper/literal>
