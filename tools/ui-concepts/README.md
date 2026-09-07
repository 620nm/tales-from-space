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
  --input /tmp/tfs-floating.html --output /tmp/tfs-floating-shots --check true
node --test tools/ui-concepts/picking.test.mjs
```

Open the exported HTML directly in a browser. Scripts, styles and sprites are
embedded; no server or network request is needed. Both commands refuse to
overwrite existing output files. `--browser /path/to/chrome` selects Chromium;
`--width 1366 --height 768` changes the default 1600×1000 capture size.
Screenshots are working artifacts outside the repository. The study targets
desktop displays; it does not propose a phone layout.
`--check true` exercises layout, exact-pixel targets, gestures and device
drag/resize in Chromium, and captures the hover examples as well as each actor.

## Interaction model

- The world stays full size when a bag, chat history, or a window opens.
  Hands and equipped slots do not reflow when storage opens. A compact tray
  highlights its source; labels remain available without filling every
  item slot with a caption.
- Shift-clicking the visible object pixel creates a top-left inspect toast.
  Transparent sprite pixels fall through to the next drawn object or turf.
  Toasts expire,
  pause while being read, and can be pinned or recovered from bounded history.
  Repeated inspection refreshes the same message. These are local presentation
  choices; inspecting still requires the server's existing disclosure checks.
- Device windows move by their title bar and resize at their edges/corners.
  Multiple windows coexist. Each keeps its position and size when closed
  and reopened during this page session. Focused title bars accept arrow
  keys to move and Shift+arrows to resize. Contents scroll when needed.
- Chat occupies a larger bottom-left transcript and composer. More history expands
  over the world on request. Channel filters and local mock submission work.
- Worn slots sit left of the central hands, with bag/belt slots between them;
  target and intent sit immediately right. Abilities sit above this cluster,
  leaving both upper corners for information rather than permanent controls.
- A few pinned actions form a short floating row. A grouped searchable
  palette holds the remainder. Toggle, disabled and cooldown states are
  explicit, and changing state does not reorder the row. Equipment actions
  remain attributable to their source rather than becoming anonymous icons.
- The cursor hint is translucent, left-aligned and click-through. It sits
  right of the cursor and flips at the viewport edge. Its miniature uses the
  target's current drawn appearance; the rows describe gestures, not clickable
  menu entries. Opening the laptop's lid changes both the picture and verb.
- Exposed pipe layers 1 and 3 cross below a cable in the sample scene. The
  renderer and picker use one ordered primitive list and the same atlas alpha
  pixels. Only the frontmost nontransparent pixel wins; a fully occluded
  lower object is not secretly selectable through an upper object.

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

### Pointer disclosure proposal

The native picker already samples atlas alpha for entities and exposed static
carriers (`lunatic/crates/lunatic-client/src/hit.rs:167`, `:246`). However,
current hover retains only an entity ID, while an unmodified ground click
separately picks pipe/cable kind and layer. Shift-click on that ground examines
the turf (`app/boot/clicks.rs:258`, `:272`, `:512`). The prototype's shared
target is therefore a proposed integration, not a claim about the live game.

The live picker is not yet pixel-exact in every rendered case: named-family
and plain pipes use separate drawing passes but one combined picking order
(`lunatic/crates/lunatic-client/src/scene.rs:68`, `:205`). Animated draw frames
can differ from the logical sprite mask (`app/frame.rs:178`, `hit.rs:17`),
and hover does not refresh until mouse movement (`app/boot/clicks.rs:495`).
Production needs regression coverage for those cases, cable-over-pipe,
layer-1/layer-3 crossings, covered underlays, and composited display pixels.

A production extension needs one host-resolved target: entity, exposed carrier
with its precise layer, or turf. Hover, highlighting, preview and gesture
dispatch consume that same target, resolved against current rendered state.
Unknown, hidden and covered runs remain absent; exposure alone is insufficient,
so carrier disclosure also requires the current native FOV set. The host owns cursor geometry,
an edge-clamped noninteractive pointer anchor, and a verified composited
appearance handle. Neither cursor coordinates nor raw image URLs enter the UI
guest. Existing `@context` is a click-menu anchor, not a moving hover anchor
(engine `docs/pack-ui/sdk.md`, Spatial overlays).

The pack owns localized names and contextual verbs. A bounded disclosure can
pair supported semantic gestures with label, availability and disabled-reason
keys, tied to the current target and held-item state. A gesture bit alone says
neither "close lid" nor "unwrench". A hint grants no authority: activation
still enters the existing server-validated command/hook path. The native
inspector also needs an explicit exposed-carrier target to inspect a pipe layer
without describing the turf instead. These are schema/protocol changes to
design and test before production rollout, not unrestricted HTML/JS access.

The sample laptop demonstrates pickup and lid/interface gestures only; it does
not model the live held-tool click priority (engine `docs/luau-api/click.md`).
Its pipes disclose layers and allow inspection, not mocked construction work.

The prototype's raw DOM, timers and pointer coordinates belong to local tools.
Production keeps the restricted interpreter, validated JSON node/style grammar,
verified asset registry, package limits and server action checks. Proposed
host behaviors do not expose browser JavaScript, URLs, geometry, credentials
or draft text to game operators. See engine `docs/PACK-UI.md` and
`docs/pack-ui/runtime.md`.
