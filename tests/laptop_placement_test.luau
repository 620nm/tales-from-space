-- A mapper may place a laptop open, running and with a disk in (docs/LAPTOP.md):
-- its `open` and `powered` knobs and the engine's `media` row. Placed so, the
-- very first press on it is the screen, and B: is the disk's own store.
t.world([==[(
    name: "laptop desk",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#####", "#...#", "#####"],
    spawns: [(2, 1)],
    items: [
        (1, 1, "laptop", { "open": true, "powered": true, "media": "floppy_disk.atmos_stock" }),
        (3, 1, "laptop"),
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
