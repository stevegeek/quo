# Who made this, and how carefully

*A [Rigor, Vouch, Stages](https://rigor.diaconou.com/) disclosure stamp. The format and vocabulary are specified at [rigor.diaconou.com/spec](https://rigor.diaconou.com/spec/), version 1.0.*

<!-- rigor:summary -->
**The idea was mine, inspired by the query objects of Andy Pike's Rectify gem.
Before LLMs, the plan was mine; the implementation was written by me; it was
reviewed for quality and for security, and tested, all by me. Since LLMs, the
plan and the implementation have been reworked by me with an AI, and it has been
reviewed for quality and for security, and tested, all by me with an AI. The
project is complete; it will not gain new features. I stand behind this code as
soundly engineered and hold architectural responsibility for it. This assessment
is as of 2026-09-04. I recommend this for use; I put my name behind it.
Statement made by: Stephen Ierodiaconou.**
<!-- /rigor:summary -->

## Notes

Quo began as an evolution of the query objects in Andy Pike's Rectify gem,
which had been abandoned; none of that code remains, but some of its
inspiration does. It was extracted from a client project and open-sourced in
2022. The design, the implementation, the reviews, and the test suite were
mine, by hand, before LLMs.

Since LLMs, an AI has assisted development and refactoring, most of it in the
2.0 release, under my direction; the work is still human-led. I have read that
work and can account for it, and I reviewed and tested it with an AI.

Quo is complete. What it will still receive is fixes and updates for new Rails
releases: `activity: active`, `scope: complete`. I use it myself and I
recommend it.

## Stamp

```yaml
spec: "1.0"
signed: "Stephen Ierodiaconou"
rigor: owned
vouch: yes
checks:
  comprehended: [human, human-with-ai]
  quality_reviewed: [human, human-with-ai]
  security_reviewed: [human, human-with-ai]
  tested: [human, human-with-ai]
  owned: human
stages:
  idea: {by: human, inspired_by: "the query objects of Andy Pike's Rectify gem"}
  plan: {by: [human, human-with-ai]}
  implementation: {by: [human, human-with-ai]}
  maintenance: {by: human-with-ai, activity: active, scope: complete}
assessed: 2026-09-04
```

<!--
checks: surface any subset; a done value names who did it.
  comprehended / quality_reviewed / security_reviewed / tested / owned:
    yes | human | ai | human-with-ai | no | not-applicable,
    or a pair [before LLMs, since LLMs] of actors.
  engineered and owned must surface the checks they imply; comprehended
  cannot be satisfied by an AI alone.
Run `rigor-md fmt RIGOR.md` after editing the stamp to refresh the summary.
-->