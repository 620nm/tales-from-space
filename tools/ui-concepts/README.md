# Floating HUD study

A local interactive proposal for a floating gameplay interface. Crew, cyborg
and AI examples change the controls according to the actor. The station fills
the viewport, with small HUD groups, temporary inspection messages, and movable
device windows. Only device contents need a substantial panel background.

This is trusted concept tooling, not a production pack UI implementation. It
uses an illustrative scene and mocked actions; it neither connects to a game
server nor demonstrates sandbox integration. Actual gameplay stays in `ui/`.

## Export and capture

Requires Node 22+ with native WebSocket support and the engine's existing
baked `web/assets/atlas.ron`, `delivery.ron`, and atlas objects. Capture also
requires a local Chromium executable. No dependencies are installed.

```sh
node tools/ui-concepts/build.mjs \
  --engine /home/josh/Source/lunatic --output /tmp/tfs-floating.html
node tools/ui-concepts/capture.mjs \
  --input /tmp/tfs-floating.html --output /tmp/tfs-floating-shots
```

Open the exported HTML directly in a browser. Scripts, styles and sprites are
embedded; no server or network request is needed. Both commands refuse to
overwrite existing output files. `--browser /path/to/chrome` selects Chromium;
`--width 1366 --height 768` changes the default 1600×1000 capture size.
Screenshots are working artifacts outside the repository. The study targets
desktop displays; it does not propose a phone layout.

## Interaction model

- The world stays full size when a bag, chat history, or a window opens.
  Hands and equipped slots do not reflow when storage opens. A compact tray
  highlights its source; labels remain available without filling every
  item slot with a caption.
- Shift-clicking a world tile creates a top-left inspect toast. Toasts expire,
  pause while being read, and can be pinned or recovered from bounded history.
  Repeated inspection refreshes the same message. These are local presentation
  choices; inspecting still requires the server's existing disclosure checks.
- Device windows move by their title bar and resize at their edges/corners.
  Multiple windows coexist. Each keeps its position and size when closed
  and reopened during this page session. Focused title bars accept arrow
  keys to move and Shift+arrows to resize. Contents scroll when needed.
- Chat uses a compact floating transcript and composer. More history expands
  over the world on request. Channel filters and local mock submission work.
- A few pinned actions form a short floating row. A grouped searchable
  palette holds the remainder. Toggle, disabled and cooldown states are
  explicit, and changing state does not reorder the row. Equipment actions
  remain attributable to their source rather than becoming anonymous icons.

Timing, pin limits and mock readouts are illustration choices, not copied tg
tuning or proposed gameplay values. Cyborg and AI scene markers are schematic:
the current baked atlas supplies no matching body sprites.

## tg reference behavior

References name the read-only sibling `tgstation` checkout:

| Behavior | Source |
| --- | --- |
| Human hands, gear, physiology and movement controls | `code/_onclick/hud/human.dm:1-35` |
| Cyborg's three module slots and radio/lamp/camera controls | `code/_onclick/hud/robot.dm:13-37` |
| AI's camera, crew, alerts, laws and operational controls | `code/_onclick/hud/ai.dm:1-26` |
| Minimal guardian interface and optional dextrous storage | `code/_onclick/hud/guardian.dm:1-21` |
| Action grant, removal and state-change listeners | `code/datums/actions/action.dm:90-162` |
| Mind-targeted actions follow body transfer | `code/datums/actions/action.dm:431-436` |
| Equipped items grant actions only in suitable slots | `code/game/objects/items.dm:761-802` |
| A helmet lamp uses the same toggle as in-hand use | `code/modules/clothing/head/hardhat.dm:9-31`, `:49-74` |
| Top-left list, collapsible palette and column counts | `code/_onclick/hud/action_group.dm:149-205` |
| Cooldown, selected and armed targeting states | `code/datums/actions/cooldown_action.dm:73-108`, `:216-265` |

These support actor-specific layouts and lifecycle-aware action presentation.
The proposal uses semantic groups and player pinning instead of copying tg's
positional action list. It also keeps Shift-click's meaning consistent for
world inspection; tg's action-position reset and silicon machinery overrides
are not part of this proposed gesture contract
(`code/_onclick/hud/screen_objects/action_button.dm:56-75`,
`code/_onclick/ai.dm:117-129`, `code/_onclick/cyborg.dm:94-121`).

## Production responsibilities

The pack owns composition, visual language, actor-specific controls, action
names/groups, and equipment behavior. A human inventory is one possible pack
layout; the engine need not prescribe one for every body or viewpoint.
Current bounded styles and sprites already support floating visuals
(engine `docs/pack-ui/styles.md`, `docs/pack-ui/sdk.md`). Opaque group panels
are not a security requirement.

The host already supports `expires`, including a final fade, without guest
clocks. Inspect currently replaces one snapshot with no occurrence identity;
a client-local receipt sequence or bounded queue can make repeated answers
distinct without a gameplay wire change. Hover/pin/history policies and
surface geometry remain trusted host responsibilities. Stable node IDs retain
expiry deadlines, so simply rerendering the same examine node does not renew it
(engine `docs/pack-ui/sdk.md:132-140`,
`web/src/pack-ui/renderer.ts:348-352`).

Dragging/resizing needs a declarative surface contract. The trusted host keeps
positions, sizes, stacking and pointer capture locally. No window coordinates
need to enter the interpreter or go to the server. This extends the pack UI
schema; it need not change gameplay messages. Core Escape and profile controls
remain protected, and the layout remains within the guest paint region.

Actions can first reuse existing server-Luau script documents: a pack view
declares a HUD presentation and renders its disclosed action capabilities in
the strip. Document identity, live actions, reach, ownership and activation
checks already exist (engine `docs/pack-ui/server.md`). Lifecycle must still
close or refresh the document when equipment or the controlled body changes.
A first-class session action roster is a possible later mechanism, not a
prerequisite for drawing the bar or a reason to add a second mutation path.

The prototype's raw DOM, timers and pointer coordinates belong to local tools.
Production keeps the restricted interpreter, validated JSON node/style grammar,
verified asset registry, package limits and server action checks. Proposed
host behaviors do not expose browser JavaScript, URLs, geometry, credentials
or draft text to game operators. See engine `docs/PACK-UI.md` and
`docs/pack-ui/runtime.md`.
