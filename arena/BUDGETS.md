# Arena Budgets

Budgets are part of the benchmark. A result is only comparable to runs in the same budget class.

## Standard 24h Blind Arena

Use this as the default class for GPT-5.5 vs Opus 4.7.

| Limit | Value |
| --- | ---: |
| Wall-clock time | 24 hours |
| Official validator calls | 50 |
| Final submissions | 3 |
| Human clarification answers | 0 |
| Human infrastructure interventions | Allowed only for tool failures |
| Web/search access | Disabled if possible; otherwise prohibited by prompt |

The agent may run unlimited internal scripts, local preflight checks, numerical searches, and self-written validators within the wall-clock budget.

## Sprint 6h Blind Arena

Use this when cost or scheduling matters.

| Limit | Value |
| --- | ---: |
| Wall-clock time | 6 hours |
| Official validator calls | 20 |
| Final submissions | 2 |

## Marathon 72h Blind Arena

Use this for long-horizon agent capability testing.

| Limit | Value |
| --- | ---: |
| Wall-clock time | 72 hours |
| Official validator calls | 100 |
| Final submissions | 5 |

## Budget Enforcement

The operator records:

- Start and end timestamps.
- Every official validator invocation.
- Every final submission attempt.
- Any infrastructure interruption.

If a run exceeds a hard limit, it is marked `over budget`. The artifacts may still be archived, but the run is not ranked in that budget class.

