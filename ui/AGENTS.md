# UI routing

Read [the station interface contract](../docs/UI.md) before changing a surface.
The engine's `docs/pack-ui/authoring.md` owns the restricted SDK, its
`docs/pack-ui/lab.md` owns fixture input, and its
`docs/pack-ui/windowless-shots.md` owns the GPUI `ui_shot` pictures.
A fixture below is drawn from the engine checkout with `LUNATIC_PACK` set
to this pack (`--audience staff` for `ui/staff/fixtures`):
`cargo run -p lunatic-gui --features shots --bin ui_shot -- "$LUNATIC_PACK/<fixture>" --out <dir> --web "$LUNATIC_PACK/target/web"`.
`node tools/test.mjs <engine>` runs from the pack checkout.

| Surface | Owner | Narrow check | Acceptance evidence |
|---|---|---|---|
| Shared controls/type | `view.ts`, `theme/roles.ts`, `theme/kit.ts` | `node tools/test.mjs <engine>` | valid tokens, readable labels, 28px controls |
| HUD/chat/inspection | `main.tsx`, `chat.ts`, `inspect.ts`, `inventory*.ts`, `actions.ts` | `ui/fixtures/hud/hud-busy-compact.json` | [state checklist](../docs/ui/surfaces-acceptance.md), contained regions and real input |
| Crew board/condition | `lobby.ts` | `ui/fixtures/lobby/` | empty/full/unavailable states |
| Staff workspaces | `staff/` | `ui/staff/fixtures/` | [staff acceptance](../docs/STAFF.md), live edits, exact references and profile flows |
| Player staff contact | `contact/` | `ui/fixtures/contact/contact-inbox.json` | private conversation, replies and fresh-message sound |
| Device documents | `documents*.ts`, `matter-block.ts` | `ui/fixtures/document/` | heading, status, scrolling, disclosed disabled reason |
| Computer/files | `documents-desktop.ts`, `files*.ts`, `theme/workspace.ts` | `ui/fixtures/laptop/laptop-create-cancel.json` | previews, single modal, naming/draft preservation |
| Hover/world overlays | `overlay/`, `world-overlays.ts` | `ui/fixtures/hover/hover-actions.json` | edge containment, native-size pixel type |
| New/changed fixtures | `fixtures/` | the fixture itself | steps, geometry and tree |
| Trusted shell/editor | engine `web/`, `crates/lunatic-web/` | engine `web/AGENTS.md` route | actual compiled client; engine-owned fixtures |
