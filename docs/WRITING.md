# Writing and printing

The pack's writing system treats a sheet of paper as one append-only file.
The file is named `paper1.md`, carries at most 8 KiB of body text, accepts at
most 64 immutable fragments, and accepts at most 4096 bytes in one append.
The engine's file store owns those bounds and the fragment ledger. The pack
owns the paper, pen, crayon, and machine vocabulary.

`paper` seeds one empty `paper1.md` entry in an append-only `FileStore`.
Ordinary file create, save, rename, and delete operations refuse that store.
The writing helper is the only player path that appends. It snapshots the
implement's color, font family, and author on each fragment; it never puts a
document body or remote reference in ScriptVars.

The four-color pen cycles black, red, green, and blue. It has unlimited uses
and writes in `patrick-hand`. A crayon box contains one physical crayon for
each of red, orange, yellow, green, blue, purple, and black. Each crayon has 30
uses and writes in `kalam-bold`. A crayon append is paper-only and spends one
use only after native append admission succeeds. A refused target or full
paper spends nothing.

The paper bin has 30 blank-sheet units. Drawing materializes one `paper`
entity and debits one unit. Refilling a machine transfers only the missing
amount, leaves the source container in place, and applies the transfer as one
atomic native operation. A toner cartridge follows the same rule with 30
toner units.

The photocopier starts with 30 paper units and 30 toner units. It scans paper
without charge. The operator chooses one to ten copies, with one and
black-and-white as defaults. Every completed output consumes exactly one
paper unit and one toner unit, including color output. Before a batch starts,
the native job preflights the complete requested batch. If the batch cannot
be fully resourced, nothing is consumed. A failure after work begins keeps
the completed prefix and its charges. A page takes 80 ticks. The source sheet
stays in the scanner until the operator ejects it manually, and busy state
locks every competing action. A player leaving the area does not cancel an
admitted job.

The fax holds one paper sheet. Scanning takes 40 ticks. A successful send
ejects the source sheet onto the sender's ground tile and creates a fresh
monochrome sheet at the same 40-tick deadline. It never teleports a sheet or
waits for a second receive operation. A known preflight
failure creates no job. A late failure ejects the source at tick 40 without
charging paper or toner. The fax has no queue and remains busy until its
operation settles.

Fax endpoints advertise no service by default. A player enables a trimmed,
control-free name of at most 64 bytes. Duplicate display names remain plain in
the native directory; the pack UI adds each endpoint's MAC suffix when it
renders an ambiguous name. Discovery includes only online endpoints in the
same connected device tree, with 32 rows per page. The service bridge uses
the five messages `fax.print`, `fax.send`, `fax.printed`, `fax.sent`, and
`fax.failed`, with Markdown chunks no larger than 4096 bytes and no more
than 8192 bytes total. The delivery and reply hooks use the native
`link.service.delivery` and `link.service.reply` anchors. Replies remain
private and correlated by native request tokens; no remote entity handle
crosses the script boundary.
`reference/scripts/fax.luau` is an inert editable DiSL example: an engineering
button chooses named directory rows, sends bounded Markdown through a joined
fax endpoint, and correlates `fax.printed`, `fax.sent`, or `fax.failed` by its
request id. The AP-hosted controller bridge originates requests from its
controller; native routing validates the remote MAC, service, advertisement,
and connected device tree before delivery.

The fax panel places the endpoint name in the top bar, a paper preview on the
left, and the paged directory on the right. Clicking a directory recipient
selects it and opens a viewer-specific confirmation; only its confirm/send
action submits the selected MAC. The UI reads native resource, busy, source, and directory
state; content handlers only translate the pack's action keys into generic
writing, resource, printing, and addressed-service helpers. Writing appends
through `sim.documents.append`; copier/fax pages use `sim.documents.start`
with `duration_ticks` and one paper and one toner cost per output. Fax input
uses a `source.chunks` table capped at 4096 bytes per chunk and 8192 total.
The private
`documents.operation.done` completion refreshes machine panels and settles a
received fax. Stock moves use
`sim.resources.transfer` with the amount omitted to transfer the available
missing quantity.

Script action payloads are always `{ value = "..." }`, including button
actions. The copier publishes `set_count`, `set_color`, `copy`, and `eject`;
the fax publishes `advertise`, `name`, `target`, `page`, `confirm`,
`cancel`, `send`, and `eject`. Fax target and confirmation state is retained
per viewer, while the destination sent to native link routing is the selected
MAC string.

Porting anchors: tg `code/modules/paperwork/paper.dm:701-748`,
`code/modules/paperwork/pen.dm:125-152`,
`code/modules/paperwork/paperbin.dm:3-18,42-77,91-141`,
`code/modules/paperwork/photocopier.dm:140-152,281-379,386-464`,
`code/modules/paperwork/fax.dm:222-237,294-351,406-428`, and
`code/game/objects/items/crayons.dm:24-74,628-634,726-752`.
Tuned values above follow the pack's
approved writing contract where it intentionally differs from tg.
