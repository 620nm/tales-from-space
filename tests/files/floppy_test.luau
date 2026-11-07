local ui_controls = require("@helpers/ui_controls")
local ui_files = require("@helpers/ui_files")
local record, rows = ui_controls.record, ui_controls.rows
local text, number = ui_controls.text, ui_controls.number

-- A disk, a terminal, and everything a crewman can do to a file.
--
-- The whole of this feature is two prototypes and one panel: the
-- floppy carries a bounded store of named text, the terminal has a
-- slot to put one in and a store of its own, and the files module is
-- the window over both (docs/CONTENT-SCHEMA.md 1.10d, docs/TGUI.md).
-- Nothing here is scripted, so what this spec is really asserting is
-- that the pack DECLARED the mechanism correctly -- that the caps are
-- the ones the fiction claims, that the roster's two words reach the
-- create control, and that every gesture the panel offers lands on the
-- record with somebody's name on it.
--
-- The ledger half matters more than the panel half. A disk is the one
-- object on this station that leaves a room carrying something
-- somebody wrote, so "who fitted what where, and what did it say when
-- they saved it" is the counterplay to every use a disk has.

local DISK_BYTES, DISK_FILES = 737280, 112
local HOST_BYTES, HOST_FILES = 65536, 16
local BODY_CAP = 8192 -- the engine's own per-file ceiling, published as `open.cap`

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m:find(want, 1, true) then
            return true
        end
    end
    return false
end

-- `name.ext` per listed entry, side included, in the order the server
-- sent them -- the same reading the engine's own panel test takes.
local function listing(ui: ui_controls.Record): { string }
    local out: { string } = {}
    for _, row in ipairs(rows(ui.files)) do
        table.insert(out, text(row.store) .. ":" .. text(row.name) .. "." .. text(row.ext))
    end
    return out
end

local function has(list, want)
    for _, got in ipairs(list) do
        if got == want then
            return true
        end
    end
    return false
end

local function addr(value: unknown): string
    local row = record(value)
    return text(row.store)
        .. ":"
        .. string.format("%d", number(row.uid))
        .. ":"
        .. text(row.binding)
end

local stress_disks: { string } = table.create(58, "")
for index = 1, 58 do
    stress_disks[index] = '(4, 1, "floppy_disk.strange")'
end

-- A wired closet: generator, panel, port, and the terminal standing
-- on the port's cord. The terminal is `corded`, so the map owes it a
-- port it can path to (docs/POWER.md, "Outlets and cords") -- a spec
-- that skipped the wiring would be asserting against a boot warning.
t.world(
    [==[(
    name: "terminal closet",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    },
    levels: [
        (
            rows: [
                "######",
                "#o...#",
                "#a..g#",
                "######",
            ],
            structures: [(2, 1, "player_spawn"), (1, 2, "apc")],
            machines: [(3, 1, "programming_terminal")],
            items: [
                (2, 1, "floppy_disk"),
                (2, 2, "floppy_disk"),
                (3, 1, "floppy_disk.strange"),
                (3, 2, "floppy_disk.strange"),
                (4, 1, "floppy_disk.strange"),
                (4, 1, "floppy_disk.strange"),
                (4, 1, "floppy_disk.strange"),
                (4, 1, "floppy_disk.strange"),
]==] .. table.concat(stress_disks, ",\n") .. [==[
            ],
            networks: [
                (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 4, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
            ],
        ),
    ],
)]==],
    7
)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land

-- ---- the disk goes in ------------------------------------------------
-- One click with a disk in the hand, and the slot takes it. There is no
-- verb for this and no window open yet: a held medium docks before a
-- click can open anything, which is why the drive works for somebody
-- who has never seen the panel.
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "floppy_disk")))
t.run_ticks(2)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "programming_terminal")))
t.tick()

local function audit_rows(kind: string): { ui_controls.Record }
    local found: { ui_controls.Record } = {}
    for _, row in ipairs(t.ledger_rows()) do
        if row.audit then
            local audit = record(row.audit)
            if audit.audit == kind then
                table.insert(found, audit)
            end
        end
    end
    return found
end
local inserted = audit_rows("media_inserted")
assert(#inserted == 1, "fitting a disk is a row of its own: " .. #inserted)
assert(
    inserted[1].item == "floppy disk",
    "the row names the medium: " .. tostring(inserted[1].item)
)
assert(
    inserted[1].machine == "programming terminal",
    "and the machine: " .. tostring(inserted[1].machine)
)
assert(
    type(inserted[1].owner) == "string" and #text(inserted[1].owner) == 32,
    "the media row carries the disk store identity"
)

-- ---- a full slot refuses the second disk -----------------------------
-- The click is SPENT on the refusal rather than falling through to
-- swinging a disk at the console, so the second one is still in hand
-- afterwards.
t.click(p, 2, 2, assert(t.target_at(p, 2, 2, "floppy_disk")))
t.run_ticks(2)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "programming_terminal")))
t.tick()
assert(
    said(p, "There is already"),
    "an occupied drive says so: " .. table.concat(t.messages(p), " | ")
)
assert(#audit_rows("media_inserted") == 1, "and nothing was fitted twice")
t.drop(p)
t.run_ticks(2)

-- ---- the panel ------------------------------------------------------
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "programming_terminal")))
t.tick()
local ui = record(assert(t.ui(p), "a bare-handed click opens the terminal's window"))
assert(ui.presentation == "panes", "the files module is the panes one")
assert(record(ui.media_slot).id == "files.media.loaded", "and it knows there is a disk in it")

local stores = rows(ui.stores)
assert(#stores == 2, "two stores in reach: " .. #stores)
assert(
    stores[1].key == "host" and record(stores[1].label).text == "programming terminal",
    "the host store comes first, under the machine's own name"
)
assert(
    stores[1].capacity == HOST_BYTES and stores[1].count_cap == HOST_FILES,
    "the terminal is scratch space: " .. number(stores[1].capacity)
)
assert(
    stores[2].key == "media" and record(stores[2].label).text == "floppy disk",
    "the medium is the second store, under its own name"
)
-- The two numbers this pack's fiction is actually about: a
-- double-density 3.5" floppy and FAT12's root directory.
assert(stores[2].capacity == DISK_BYTES, "720 KiB: " .. number(stores[2].capacity))
assert(stores[2].count_cap == DISK_FILES, "112 entries: " .. number(stores[2].count_cap))
assert(#rows(ui.files) == 0, "both stores start bare")

-- The create control is exactly the roster's creatable subset, in
-- declared order (content/filetypes.luau), PER WRITABLE SIDE: a create
-- names where it lands (`<side>:<ext>`), never inferred
-- (docs/files/scriptable-machine.md §2).
local host_formats = ui_controls.texts(record(ui.create).host)
local media_formats = ui_controls.texts(record(ui.create).media)
assert(
    #host_formats == 4
        and host_formats[1] == "md"
        and host_formats[2] == "disl"
        and host_formats[3] == "atmo"
        and host_formats[4] == "pem",
    "the pack's four formats reach the host side: " .. table.concat(host_formats, ",")
)
assert(
    #media_formats == 4
        and media_formats[1] == "md"
        and media_formats[2] == "disl"
        and media_formats[3] == "atmo"
        and media_formats[4] == "pem",
    "and the disk side: " .. table.concat(media_formats, ",")
)

-- ---- make one ---------------------------------------------------------
-- Create lands on the MEDIUM, because a crewman who put a disk in came
-- to write to the disk -- and now SAYS so, in the option itself.
ui_files.create(p, "media", "md", "untitled")
t.tick()
ui = ui_controls.state(p)
assert(ui.open, "the new file is what the panel is showing")
assert(record(ui.open).store == "media", "and it landed on the disk")
assert(record(ui.open).name == "untitled" and record(ui.open).ext == "md", "named for nothing yet")
assert(record(ui.open).revision == 0, "and unedited")
assert(record(ui.open).cap == BODY_CAP, "the panel publishes the byte cap a save is held to")
local disk_file = addr(ui.open)
local created = audit_rows("baseline")
local matching_created = 0
for _, event in ipairs(created) do
    local state = record(event.state)
    if state.name == "untitled" and state.ext == "md" then
        matching_created += 1
    end
end
assert(
    matching_created == 1,
    "made files are on the compact record"
)

-- ---- type into it ------------------------------------------------------
local other = t.join()
t.tick()
t.click(other, 3, 1, assert(t.target_at(other, 3, 1, "programming_terminal")))
t.tick()
ui_files.address(other, disk_file, "open")
t.tick()
local stale_input = ui_files.edit(other, "and I checked it twice")
t.ui_press(other, stale_input, "change")
local NOTE = "Pressure in the tank room reads low. Do not vent it to check."
ui_files.save(p, NOTE)
t.tick()
ui = ui_controls.state(p)
assert(record(ui.open).body == NOTE, "the body comes back whole")
assert(record(ui.open).revision == 1, "and a save moves the revision")
-- The store readout weighs stem, extension and body rather than
-- counting entries.
assert(
    rows(ui.stores)[2].used == #NOTE + #"untitled" + #"md",
    "the disk's used figure is what it holds: " .. number(rows(ui.stores)[2].used)
)

local saved = audit_rows("save")
assert(
    #saved == 1 and saved[1].result_revision == 1 and saved[1].splices,
    "the save is on the compact record with deterministic splices"
)

-- ---- the source control bounds a long paste ---------------------------
t.run_seconds(0.5) -- the pacing window on text acts (docs/TGUI.md)
ui_files.save(p, string.rep("x", BODY_CAP + 1))
t.tick()
ui = ui_controls.state(p)
assert(#text(record(ui.open).body) == BODY_CAP, "the rendered editor caps the submitted text")
assert(record(ui.open).revision == 2, "the bounded text is a normal save")
t.run_seconds(0.5) -- the pacing window again
ui_files.save(p, NOTE)
t.tick()
assert(record(ui_controls.state(p).open).body == NOTE, "the first reader restores the note")

-- ---- a save at a revision that moved ----------------------------------
-- Two crew at one terminal. The first save moved the file; the second
-- names the revision it was seeded from, and that number is stale, so
-- it is refused rather than allowed to clobber the faster hand.
t.run_seconds(1.0) -- the pane republishes on the window cadence
local stale_save = ui_controls.node(other, "/editor/save")
assert(stale_save.disabled, "a conflicting draft disables Save")
assert(ui_controls.find(other, "/editor/conflict"), "the editor explains the conflict")
assert(not pcall(function()
    t.ui_press(other, stale_save.id)
end), "a disabled Save cannot overwrite newer text")
ui = ui_controls.state(p)
assert(record(ui.open).body == NOTE, "and the first hand's work is still there")

local restored = ui_files.edit(p, NOTE)
t.ui_press(p, restored, "change")

-- ---- name it ----------------------------------------------------------
-- The rename would land in the same breath as the save above, and an
-- accepted text act inside the pacing window is dropped on purpose
-- (docs/TGUI.md: refusals speak, successes wait). A person renaming a
-- file they just saved has this half-second without noticing it.
t.run_seconds(0.5)
ui_files.rename(p, "tank_room")
t.tick()
ui = ui_controls.state(p)
assert(record(ui.open).name == "tank_room", "renamed")
assert(
    has(listing(ui), "media:tank_room.md"),
    "and the listing agrees: " .. table.concat(listing(ui), " ")
)
local renamed = audit_rows("rename")
assert(#renamed == 1 and renamed[1].to == "tank_room", "renames are on the compact record too")

-- ---- disk -> terminal -------------------------------------------------
-- Copy goes to the OTHER store, because there is only ever one other.
ui_files.address(p, disk_file, "copy")
t.tick()
ui = ui_controls.state(p)
assert(
    has(listing(ui), "host:tank_room.md"),
    "the note is on the terminal now: " .. table.concat(listing(ui), " ")
)
assert(has(listing(ui), "media:tank_room.md"), "and still on the disk -- copy, never move")
local copied = audit_rows("copy")
assert(
    #copied == 1 and copied[1].source and copied[1].destination and copied[1].destination_hash,
    "a copy carries source and destination identities, never a body"
)

-- ---- delete off the disk ----------------------------------------------
ui_files.address(p, disk_file, "delete")
t.tick()
ui = ui_controls.state(p)
assert(
    not has(listing(ui), "media:tank_room.md"),
    "gone from the disk: " .. table.concat(listing(ui), " ")
)
assert(not ui.open, "and the selection went with the file it named")
local deleted = audit_rows("deleted")
assert(#deleted == 1 and deleted[1].identity, "deletions are on the compact record")

-- ---- terminal -> disk -------------------------------------------------
-- The other direction, over the same one act: whichever side a file is
-- on, copy means "to the one it is not on".
local host_file
for _, row in ipairs(rows(ui.files)) do
    if row.store == "host" then
        host_file = addr(row)
    end
end
assert(host_file, "the terminal kept its copy")
ui_files.address(p, host_file, "copy")
t.tick()
ui = ui_controls.state(p)
assert(
    has(listing(ui), "media:tank_room.md"),
    "and back onto the disk: " .. table.concat(listing(ui), " ")
)
assert(#audit_rows("copy") == 2, "both crossings are attributed")

-- ---- take it back out -------------------------------------------------
local eject_control = ui_controls.node(p, "/drive/media/eject").id
ui_controls.press(p, "/drive/media/eject")
t.tick()
ui = ui_controls.state(p)
assert(record(ui.media_slot).id == "files.media.empty", "the slot is empty")
assert(#rows(ui.stores) == 1, "and the disk's store left with it")
assert(
    not has(listing(ui), "media:tank_room.md"),
    "so the note is somewhere in a pocket, which is the whole point of a disk"
)
assert(#audit_rows("media_ejected") == 1, "and taking one out is a row as well")
local hands = t.hands(p)
assert(
    hands[1] == "floppy_disk" or hands[2] == "floppy_disk",
    "it came back into a hand rather than onto the deck"
)

-- A delayed second press no longer has authority over a mounted store.
assert(not pcall(function()
    t.ui_press(p, eject_control)
end), "an empty drive offers no eject")
t.tick()
assert(
    #rows(ui_controls.state(p).stores) == 1,
    "the stale binding cannot restore access to the removed disk"
)
assert(#audit_rows("media_ejected") == 1, "and ejected nothing twice")

-- ---- map entropy becomes an active reader -----------------------------
-- Each strange disk samples its own map site. Its only file is inert text
-- until the terminal opens it; that open decodes the image and score from
-- the stored body through the registered pack reader.
t.ui_close(p)
t.drop(p)
t.run_ticks(2)
local dropped_hands = t.hands(p)
assert(
    dropped_hands[1] == nil and dropped_hands[2] == nil,
    "the ejected floppy left the hand before pickup: "
        .. tostring(dropped_hands[1])
        .. "/"
        .. tostring(dropped_hands[2])
)
t.click(p, 3, 2, assert(t.target_at(p, 3, 2, "floppy_disk.strange")))
t.run_ticks(2)
local remounted_hands = t.hands(p)
assert(
    remounted_hands[1] == "floppy_disk.strange" or remounted_hands[2] == "floppy_disk.strange",
    "the adjacent strange disk was picked up: "
        .. tostring(remounted_hands[1])
        .. "/"
        .. tostring(remounted_hands[2])
)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "programming_terminal")))
t.tick()
local docked_hands = t.hands(p)
assert(
    #audit_rows("media_inserted") == 2
        and docked_hands[1] == nil
        and docked_hands[2] == nil,
    "the strange disk docks before the files panel opens: hands="
        .. tostring(docked_hands[1])
        .. "/"
        .. tostring(docked_hands[2])
        .. " inserts="
        .. #audit_rows("media_inserted")
)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "programming_terminal")))
t.tick()
ui = ui_controls.state(p)
assert(
    record(ui.media_slot).id ~= "files.media.empty",
    "the mounted Strange Disk is present in the opened panel"
)
local strange_files: { ui_controls.Record } = {}
for _, row in ipairs(rows(ui.files)) do
    if row.store == "media" then
        table.insert(strange_files, row)
    end
end
assert(
    #strange_files == 1
        and strange_files[1].name == "Adam"
        and strange_files[1].ext == "HC",
    "the disk has only Adam.HC; all listed files: " .. table.concat(listing(ui), ",")
)
assert(
    has(listing(ui), "media:Adam.HC"),
    "the file keeps the exact HC suffix: " .. table.concat(listing(ui), ",")
)
local strange_file = addr(strange_files[1])
ui_files.address(p, strange_file, "open")
t.tick()
ui = ui_controls.state(p)
local strange_open = record(ui.open)
local first_body = text(strange_open.body)
assert(string.sub(first_body, 1, 9) == "STRANGE1\n", "the stored file is generated inert media")
local bitmap = record(strange_open.reader_output)
assert(bitmap.width == 64 and bitmap.height == 48, "the server reader presents the generated raster")
local bitmap_pixels = bitmap.pixels
assert(type(bitmap_pixels) == "string" and #bitmap_pixels == 64 * 48,
    "the reader preserves the bounded indexed-pixel string")
local pixel_counts: { [string]: number } = {}
for pixel_index = 1, #bitmap_pixels do
    local color_index = string.lower(string.sub(bitmap_pixels, pixel_index, pixel_index))
    pixel_counts[color_index] = (pixel_counts[color_index] or 0) + 1
end
local histogram_parts: { string } = {}
for palette_index = 0, 15 do
    local color_index = string.format("%x", palette_index)
    local count = pixel_counts[color_index]
    if count then
        table.insert(histogram_parts, color_index .. ":" .. count)
    end
end
print("[strange-disk-reader-pixels] " .. table.concat(histogram_parts, ","))
local palette = ui_controls.texts(bitmap.palette)
assert(palette[1] == "#000000", "the darkest pixel stays pure black")
assert(palette[3] == "#AAAAAA" and palette[4] == "#555555",
    "the grayscale palette keeps TempleOS light-before-dark tie order")
-- A second placed disk has a separate site fingerprint and produces its
-- own permanent body rather than reusing a cached presentation.
ui_controls.press(p, "/drive/media/eject")
t.tick()
t.ui_close(p)
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "floppy_disk.strange")))
t.run_ticks(2)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "programming_terminal")))
t.tick()
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "programming_terminal")))
t.tick()
ui = ui_controls.state(p)
assert(record(ui.media_slot).id ~= "files.media.empty", "the second site's disk docks")
local second_disk_files: { ui_controls.Record } = {}
for _, row in ipairs(rows(ui.files)) do
    if row.store == "media" then
        table.insert(second_disk_files, row)
    end
end
assert(
    #second_disk_files == 1
        and second_disk_files[1].name == "Adam"
        and second_disk_files[1].ext == "HC",
    "the second site's disk has only Adam.HC"
)
ui_files.address(p, addr(second_disk_files[1]), "open")
t.tick()
local second_open = record(ui_controls.state(p).open)
assert(text(second_open.body) ~= first_body, "local map entropy distinguishes the two disk sites")
	local second_output = record(second_open.reader_output)
	assert(second_output.width == 64 and second_output.height == 48,
		"the second body's current revision produces an image presentation")
	assert(type(second_output.pixels) == "string" and #text(second_output.pixels) == 64 * 48,
		"the second revision decodes its indexed-pixel string")
