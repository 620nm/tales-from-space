# File workspace acceptance

The computer skin uses delivered owner and file artwork, square instrument
borders, readable labels, and distinct physical power and viewer controls.
The engine owns modal isolation; one workspace chooses its active dialog.

| Surface/state | Required evidence |
|---|---|
| Powered computer, unavailable/offline | Owner identity; power action and explanation; no undisclosed files |
| Empty, populated, full drives | Named drive; empty/full text; capacity; selected file visibly outlined |
| Long names, both drives, long reader | Contained split panes and scrolling at 1024×768, 1366×768, 1600×1000 |
| Markdown, valid ATMO, PEM | View/Edit tabs; View/Source for read-only; retained edited draft |
| Invalid ATMO/source diagnostics | Editable source; disclosed markers, budget and conflict explanation |
| Dirty editor → Create → guard | Only guard visible; editor text, filename and extension retained |
| Guard → Cancel | Create restored with naming draft; eligible focus restored by host |
| Guard → Save | Guard remains during acknowledgement; matching receipt continues exactly once |
| Guard → Discard | Create continues exactly once; stale repeated event cannot repeat action |
| Document/media revocation | Pending operation abandoned; no late continuation |

`tools/test-file-workspaces.mjs` renders the real pack components and dispatches
registered events. `tools/test-file-buffers.mjs` tests receipt and revocation
boundaries; `tools/test-file-readers.mjs` verifies inert, bounded readers.
The engine lab runs the laptop fixtures through browser input. The engine's
`docs/pack-ui/lab.md` and `docs/pack-ui/components.md` own fixture and modal
contracts. `docs/LAPTOP.md` owns computer operation and file semantics.
