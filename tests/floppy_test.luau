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
local function listing(ui)
    local out = {}
    for _, row in ipairs(ui.files) do
        table.insert(out, row.store .. ":" .. row.name .. "." .. row.ext)
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

local function addr(row)
    return row.store .. ":" .. string.format("%d", row.uid) .. ":" .. row.binding
end

-- A wired closet: generator, panel, port, and the terminal standing
-- on the port's cord. The terminal is `corded`, so the map owes it a
-- port it can path to (docs/POWER.md, "Outlets and cords") -- a spec
-- that skipped the wiring would be asserting against a boot warning.
t.world([==[(
    name: "terminal closet",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "######",
        "#o...#",
        "#a..g#",
        "######",
    ],
    spawns: [(2, 1)],
    machines: [(3, 1, "programming_terminal")],
    items: [(2, 1, "floppy_disk"), (2, 2, "floppy_disk")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land

-- ---- the disk goes in ------------------------------------------------
-- One click with a disk in the hand, and the slot takes it. There is no
-- verb for this and no window open yet: a held medium docks before a
-- click can open anything, which is why the drive works for somebody
-- who has never seen the panel.
t.click(p, 2, 1, t.target_at(p, 2, 1, "floppy_disk"))
t.run_ticks(2)
t.click(p, 3, 1, t.target_at(p, 3, 1))
t.tick()

local inserted = t.ledger_rows("media_inserted")
assert(#inserted == 1, "fitting a disk is a row of its own: " .. #inserted)
assert(inserted[1].item == "floppy disk", "the row names the medium: " .. tostring(inserted[1].item))
assert(inserted[1].machine == "programming terminal",
    "and the machine: " .. tostring(inserted[1].machine))

-- ---- a full slot refuses the second disk -----------------------------
-- The click is SPENT on the refusal rather than falling through to
-- swinging a disk at the console, so the second one is still in hand
-- afterwards.
t.click(p, 2, 2, t.target_at(p, 2, 2, "floppy_disk"))
t.run_ticks(2)
t.click(p, 3, 1, t.target_at(p, 3, 1))
t.tick()
assert(said(p, "There is already"), "an occupied drive says so: "
    .. table.concat(t.messages(p), " | "))
assert(#t.ledger_rows("media_inserted") == 1, "and nothing was fitted twice")
t.drop(p)
t.run_ticks(2)

-- ---- the panel ------------------------------------------------------
t.click(p, 3, 1, t.target_at(p, 3, 1))
t.tick()
local ui = t.ui(p)
assert(ui, "a bare-handed click opens the terminal's window")
assert(ui.presentation == "panes", "the files module is the panes one")
assert(ui.media_slot.id == "files.media.loaded", "and it knows there is a disk in it")

assert(#ui.stores == 2, "two stores in reach: " .. #ui.stores)
assert(ui.stores[1].key == "host" and ui.stores[1].label.text == "programming terminal",
    "the host store comes first, under the machine's own name")
assert(ui.stores[1].capacity == HOST_BYTES and ui.stores[1].count_cap == HOST_FILES,
    "the terminal is scratch space: " .. ui.stores[1].capacity)
assert(ui.stores[2].key == "media" and ui.stores[2].label.text == "floppy disk",
    "the medium is the second store, under its own name")
-- The two numbers this pack's fiction is actually about: a
-- double-density 3.5" floppy and FAT12's root directory.
assert(ui.stores[2].capacity == DISK_BYTES, "720 KiB: " .. ui.stores[2].capacity)
assert(ui.stores[2].count_cap == DISK_FILES, "112 entries: " .. ui.stores[2].count_cap)
assert(#ui.files == 0, "both stores start bare")

-- The create control is exactly the roster's creatable subset, in
-- declared order (content/filetypes.luau), PER WRITABLE SIDE: a create
-- names where it lands (`<side>:<ext>`), never inferred
-- (docs/files/scriptable-machine.md §2).
assert(#ui.create.host == 4 and ui.create.host[1] == "md" and ui.create.host[2] == "disl"
    and ui.create.host[3] == "atmo" and ui.create.host[4] == "pem",
    "the pack's four formats reach the host side: " .. table.concat(ui.create.host, ","))
assert(#ui.create.media == 4 and ui.create.media[1] == "md" and ui.create.media[2] == "disl"
    and ui.create.media[3] == "atmo" and ui.create.media[4] == "pem",
    "and the disk side: " .. table.concat(ui.create.media, ","))

-- ---- make one ---------------------------------------------------------
-- Create lands on the MEDIUM, because a crewman who put a disk in came
-- to write to the disk -- and now SAYS so, in the option itself.
ui_files.create(p, "media", "md", "untitled")
t.tick()
ui = t.ui(p)
assert(ui.open, "the new file is what the panel is showing")
assert(ui.open.store == "media", "and it landed on the disk")
assert(ui.open.name == "untitled" and ui.open.ext == "md", "named for nothing yet")
assert(ui.open.revision == 0, "and unedited")
assert(ui.open.cap == BODY_CAP, "the panel publishes the byte cap a save is held to")
local disk_file = addr(ui.open)
assert(#t.ledger_rows("file_created") == 1, "made files are on the record")

-- ---- type into it ------------------------------------------------------
local other = t.join()
t.tick()
t.click(other, 3, 1, t.target_at(other, 3, 1))
t.tick()
ui_files.address(other, disk_file, "open")
t.tick()
local stale_input = ui_files.edit(other, "and I checked it twice")
t.ui_press(other, stale_input, "change")
local NOTE = "Pressure in the tank room reads low. Do not vent it to check."
ui_files.save(p, NOTE)
t.tick()
ui = t.ui(p)
assert(ui.open.body == NOTE, "the body comes back whole")
assert(ui.open.revision == 1, "and a save moves the revision")
-- The store readout weighs stem, extension and body rather than
-- counting entries.
assert(ui.stores[2].used == #NOTE + #"untitled" + #"md",
    "the disk's used figure is what it holds: " .. ui.stores[2].used)

local saved = t.ledger_rows("file_saved")
assert(#saved == 1 and saved[1].body == NOTE,
    "the save is on the record with the body VERBATIM -- the point of the whole ledger")
assert(saved[1].revision == 1, "at the revision it became")

-- ---- the source control bounds a long paste ---------------------------
t.run_ticks(10)
ui_files.save(p, string.rep("x", BODY_CAP + 1))
t.tick()
ui = t.ui(p)
assert(#ui.open.body == BODY_CAP, "the rendered editor caps the submitted text")
assert(ui.open.revision == 2, "the bounded text is a normal save")
t.run_ticks(10)
ui_files.save(p, NOTE)
t.tick()
assert(t.ui(p).open.body == NOTE, "the first reader restores the note")

-- ---- a save at a revision that moved ----------------------------------
-- Two crew at one terminal. The first save moved the file; the second
-- names the revision it was seeded from, and that number is stale, so
-- it is refused rather than allowed to clobber the faster hand.
t.run_ticks(20)
local stale_save = ui_controls.node(other, "/editor/save")
assert(stale_save.disabled, "a conflicting draft disables Save")
assert(ui_controls.find(other, "/editor/conflict"), "the editor explains the conflict")
assert(not pcall(function() t.ui_press(other, stale_save.id) end), "a disabled Save cannot overwrite newer text")
ui = t.ui(p)
assert(ui.open.body == NOTE, "and the first hand's work is still there")

local restored = ui_files.edit(p, NOTE)
t.ui_press(p, restored, "change")

-- ---- name it ----------------------------------------------------------
-- The rename would land in the same breath as the save above, and an
-- accepted text act inside the pacing window is dropped on purpose
-- (docs/TGUI.md: refusals speak, successes wait). A person renaming a
-- file they just saved has this half-second without noticing it.
t.run_ticks(10)
ui_files.rename(p, "tank_room")
t.tick()
ui = t.ui(p)
assert(ui.open.name == "tank_room", "renamed")
assert(has(listing(ui), "media:tank_room.md"), "and the listing agrees: "
    .. table.concat(listing(ui), " "))
assert(#t.ledger_rows("file_renamed") == 1, "renames are on the record too")

-- ---- disk -> terminal -------------------------------------------------
-- Copy goes to the OTHER store, because there is only ever one other.
ui_files.address(p, disk_file, "copy")
t.tick()
ui = t.ui(p)
assert(has(listing(ui), "host:tank_room.md"),
    "the note is on the terminal now: " .. table.concat(listing(ui), " "))
assert(has(listing(ui), "media:tank_room.md"), "and still on the disk -- copy, never move")
local copied = t.ledger_rows("file_copied")
assert(#copied == 1 and copied[1].body == NOTE,
    "a copy carries the body into the record, which is the counterplay to copying a secret")

-- ---- delete off the disk ----------------------------------------------
ui_files.address(p, disk_file, "delete")
t.tick()
ui = t.ui(p)
assert(not has(listing(ui), "media:tank_room.md"), "gone from the disk: "
    .. table.concat(listing(ui), " "))
assert(not ui.open, "and the selection went with the file it named")
assert(#t.ledger_rows("file_deleted") == 1, "deletions are on the record")

-- ---- terminal -> disk -------------------------------------------------
-- The other direction, over the same one act: whichever side a file is
-- on, copy means "to the one it is not on".
local host_file
for _, row in ipairs(ui.files) do
    if row.store == "host" then
        host_file = addr(row)
    end
end
assert(host_file, "the terminal kept its copy")
ui_files.address(p, host_file, "copy")
t.tick()
ui = t.ui(p)
assert(has(listing(ui), "media:tank_room.md"),
    "and back onto the disk: " .. table.concat(listing(ui), " "))
assert(#t.ledger_rows("file_copied") == 2, "both crossings are attributed")

-- ---- take it back out -------------------------------------------------
local eject_control = ui_controls.node(p, "/drive/media/eject").id
ui_controls.press(p, "/drive/media/eject")
t.tick()
ui = t.ui(p)
assert(ui.media_slot.id == "files.media.empty", "the slot is empty")
assert(#ui.stores == 1, "and the disk's store left with it")
assert(not has(listing(ui), "media:tank_room.md"),
    "so the note is somewhere in a pocket, which is the whole point of a disk")
assert(#t.ledger_rows("media_ejected") == 1, "and taking one out is a row as well")
local hands = t.hands(p)
assert(hands[1] == "floppy_disk" or hands[2] == "floppy_disk",
    "it came back into a hand rather than onto the deck")

-- A delayed second press no longer has authority over a mounted store.
assert(not pcall(function() t.ui_press(p, eject_control) end), "an empty drive offers no eject")
t.tick()
assert(#t.ui(p).stores == 1, "the stale binding cannot restore access to the removed disk")
assert(#t.ledger_rows("media_ejected") == 1, "and ejected nothing twice")
