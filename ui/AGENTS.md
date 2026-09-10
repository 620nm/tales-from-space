# UI routing

Read [the station interface contract](../docs/UI.md) before changing a surface.
The engine's `docs/pack-ui/authoring.md` owns the restricted SDK, and its
`docs/pack-ui/lab.md` owns fixture input and screenshot contracts.
Commands below run from the engine with `LUNATIC_PACK` set to this pack;
`node tools/test.mjs <engine>` runs from the pack checkout.

| Surface | Owner | Narrow command | Acceptance evidence |
|---|---|---|---|
| Shared controls/type | `view.ts`, `theme/roles.ts`, `theme/kit.ts` | `node tools/test.mjs <engine>` | valid tokens, readable labels, 28px controls |
| HUD/chat/inspection | `main.tsx`, `chat.ts`, `inspect.ts`, `inventory*.ts`, `actions.ts` | `node tools/ui-lab.mjs shot hud-busy-compact --lint` | [state checklist](../docs/ui/surfaces-acceptance.md), contained regions and real input |
| Crew board/condition | `lobby.ts` | `node tools/ui-lab.mjs shot lobby lobby-empty --lint` | empty/full/unavailable states |
| Device documents | `documents*.ts`, `matter-block.ts` | `node tools/ui-lab.mjs shot document-matter document-shelf --lint` | heading, status, scrolling, disclosed disabled reason |
| Computer/files | `documents-desktop.ts`, `files*.ts`, `theme/workspace.ts` | `node tools/ui-lab.mjs shot laptop-create-cancel --lint` | previews, single modal, naming/draft preservation |
| Hover/world overlays | `overlay/`, `world-overlays.ts` | `node tools/ui-lab.mjs shot hover-actions --lint` | edge containment, native-size pixel type |
| New/changed fixtures | `fixtures/` | `node tools/ui-lab.mjs shot <fixture> --lint` | real browser actions, geometry and reviewed baseline |
| Trusted shell/editor | engine `web/`, `crates/lunatic-client/` | engine `web/AGENTS.md` route | actual compiled client; engine-owned fixtures |
