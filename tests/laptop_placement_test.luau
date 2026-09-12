-- A mapper may place a laptop open, running and with a disk in (docs/LAPTOP.md):
-- its `open` and `powered` knobs and the engine's `media` row. Placed so, the
-- very first press on it is the screen, and B: is the disk's own store. Placed
-- powered but closed, the lid comes up lit; placed open but dark, the power
-- button comes before the screen.
t.world([==[(
    name: "laptop desk",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#####", "#...#", "#...#", "#####"],
    structures: [(2, 1, "player_spawn")],
    items: [
        (1, 1, "laptop", { "open": true, "powered": true, "media": "floppy_disk.atmos_stock" }),
        (3, 1, "laptop"),
        (1, 2, "laptop", { "powered": true }),
        (3, 2, "laptop", { "open": true }),
    ],
)]==], 0)
local p = t.join()
t.run_ticks(20)

local function file(ui, side, name)
    for _, row in ipairs(ui.files or {}) do
        if row.store == side and row.name == name then return row end
    end
    return nil
end

-- The mapped laptop, used where it stands: one press, and the desktop
-- with both drives.
local placed = assert(t.target_at(p, 1, 1, "laptop"))
t.use_item(p, placed, "secondary")
t.run_ticks(2)
local desktop = t.ui(p)
assert(desktop and desktop.stores and #desktop.stores == 2,
    "a laptop placed open and running shows its desktop on the first press")
assert(file(desktop, "media", "airlock") and file(desktop, "media", "readme"),
    "B: is the placed disk, holding its own files")
t.ui_close(p)
t.run_ticks(2)

-- A laptop placed as it ships: the first press is only the lid.
local stock = assert(t.target_at(p, 3, 1, "laptop"))
t.use_item(p, stock, "secondary")
t.run_ticks(2)
local after = t.ui(p)
assert(after == nil or after.stores == nil, "a stock laptop raises its lid and opens nothing")

-- The docked disk is disclosed as the eject hint; an empty drive has none.
local EJECT = "lunatic/tfs:ui.affordance.eject_cartridge"
local function offers_eject(target)
    for _, action in ipairs(t.action_hints(p, target)) do
        if action.label and action.label.key == EJECT then return true end
    end
    return false
end
assert(offers_eject(t.target_at(p, 1, 1, "laptop")), "a placed disk lights the eject hint")
assert(not offers_eject(t.target_at(p, 3, 1, "laptop")), "an empty drive offers no eject")

-- Placed powered but closed: the first press raises the lid, already lit.
local charged = assert(t.target_at(p, 1, 2, "sprite:laptop_closed"), "placed with its lid down")
t.use_item(p, charged, "secondary")
t.run_ticks(2)
assert(t.target_at(p, 1, 2, "sprite:laptop_on"), "a charged laptop raises its lid lit")

-- Placed open but unpowered: a dark screen, then the power button, then
-- the desktop.
local dark = assert(t.target_at(p, 3, 2, "sprite:laptop_off"), "placed open and dark")
t.use_item(p, dark, "secondary")
t.run_ticks(2)
local lit = assert(t.target_at(p, 3, 2, "sprite:laptop_on"), "the first press powers it on")
t.use_item(p, lit, "secondary")
t.run_ticks(2)
local screen = t.ui(p)
assert(screen and screen.stores, "the next press opens the desktop")
