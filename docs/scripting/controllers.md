# Device controller guests

`content/lib/controller.luau` bridges a host's `controller` program slot and its
device network. The [airlock program](airlocks.md) is one consumer; its
sequencing and permission policy live in its own reference source.

## Inputs

The guest receives `event`, `devices`, `directory` and persistent `mem`.
`devices` lists only live, reachable direct members with their address, kind,
coordinates and native door or vent readouts. `directory` is a separate,
bounded whole-tree list of advertised `{ mac, service, name }` rows, so a
service behind another member remains discoverable without becoming a guest
handle. An address identifies a member; the host does not resolve arbitrary
addresses into world capabilities.

Events are button requests, door completions, pressure completions, addressed
service deliveries/replies, send outcomes and bounded timeouts. A button
supplies `engineering`, a verified access check on the clicking actor. Every
admitted press reaches the guest's permission policy, including repeats and
interruptions. Service reply tokens remain native opaque values; guests use
the authenticated event and their own bounded state rather than payload
correlation fields.

## Who a door answers to

A door a controller drives answers to the guest, not to its own access tag.
`content/fixtures/airlock.luau` grants every actor-less `door.permission`
request and hands a request that has an actor the engine's own answer back
untouched, so a program opens an `airlock.engineering` leaf the presser
could not open by hand, and the hand stays refused. The gate is reaching the host and loading a program: the
panel's lock and the host's own access decide who may install policy, and
the installed policy decides the rest. `door.permission` carries no
requesting host, so the grant cannot be narrowed to the joined parent.

## Outputs

Return `{ commands, status?, timer?, replace?, accepted? }`. Each command
names `mac`, a bounded correlation `id`, and an operation:

| Operation | Fields |
| --- | --- |
| `open`, `close` | no extra fields |
| `bolt` | `bolted` boolean |
| `vent` | `on`; while on, `direction = "fill" \| "drain"`, `target` kPa |
| `watch` | `target` kPa, `comparison = "at_least" \| "below"`, `ticks` |
| `service` | `to` advertised MAC, `service`, portable `payload`, `request` boolean |

`status` is `idle`, `working`, `denied` or `fault`. `timer = { id, ticks }`
replaces the host deadline, `timer = false` cancels it, and omission leaves
it alone. Ticks must be integers from 1 to 1200. Correlation IDs are nonempty
strings of at most 64 bytes.

`replace = true` discards unsent plans from an earlier request.
`accepted = true` advances the host's duplicate watermark for that button.
Authoritative press sequences are tracked per sender, so a newer packet
from another button cannot erase an older admitted press. Denials do not
advance the watermark. Cancellable task identities permit an edited guest
to replace a deadline with an earlier one without polling.

## Delivery and limits

Plans contain at most six commands and at most one `service` command. The bridge validates the complete plan
before queuing it. Ordinary device commands are sent to their direct member;
`service` commands are sent by the controller host after the same whole-plan
validation, while native link authorization rechecks the live tree and
advertisement. Each device independently validates commands addressed to it
and requires the emitter to be its current parent. Host fault-stop envelopes
can address all 64 direct children; each device still validates at most six
addressed commands.

`content/lib/device_queue.luau` paces real messages with one task and at most
four queued packets per sender. Button and completion packets batch up to
sixteen events; excess button requests receive a busy refusal. Its sleeps
are transmission deadlines, not per-tick polling.

Completions return through the same network. Correlate request identity and
operation; unbolting is not a motor completion. A malformed or faulted guest
stops reachable vents and reports a fault. The bridge adds no sequencing
interlock. Guest policy remains editable while native power, bolts and
physical obstruction checks remain authoritative.
