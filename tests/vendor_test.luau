-- The vending machine: dense on bump, opens its TGUI window on click,
-- dispenses on act('vend') as a PLAYER-attributed action, and a closed
-- window disarms acts. (Port of the Rust m4 vendor test.)
t.world([==[(
    name: "canteen",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#o..#",
        "#a.g#",
        "#####",
    ],
    spawns: [(1, 1)],
    machines: [(2, 1, "vendor")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

-- Dense: you can't walk through it, and bumping fires move.bump.
t.move(p, "east")
t.tick()
local x, y = t.pos(p)
assert(x == 1 and y == 1, "vending machines are solid")
local msgs = table.concat(t.messages(p), "\n")
assert(msgs:find("wobbles", 1, true), "move.bump fired: " .. msgs)

-- Click it: the machine's real TGUI window opens, and the state it
-- carries is tg's Vending contract, asserted as a shape.
t.click(p, 2, 1)
t.tick()
local missed = t.last_ui(p)
assert(missed == nil, "a target-less transparent-pixel click is only ground")

t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
local raw, pushes = t.last_ui(p)
assert(raw, "clicking the machine opens its window")
local ui = t.ui(p)
assert(ui.payload.config.interface.name == "Vending",
    "tg's Vending window, got " .. tostring(ui.payload.config.interface.name))
assert(ui.payload.data.product_records[1].ref == "cola",
    "cola heads the product list")
assert(ui.payload.data.product_records[1].path == "atlas-cola-cola",
    "the shelf points tg's spritesheet class at cola's atlas art")
assert(ui.payload.data.stock["atlas-cola-cola"].amount == 99,
    "stock uses the same unique icon path as the product row")

-- act('vend') dispenses; the ledger names the player, not a script.
assert(t.count_items("cola") == 0)
t.ui_act(p, "vend")
t.tick()
assert(t.count_items("cola") == 1, "act('vend') dispenses")
local sounds = table.concat(t.sounds(p), "\n")
assert(sounds:find("vend", 1, true), "the vend clunk played")
local _, after = t.last_ui(p)
assert(after > pushes, "the window got fresh state")

-- A UI act is a DIRECT player action: the row names the crewman, not
-- the file that ran on their behalf.
local spawned = t.ledger_rows("ItemSpawned")
assert(#spawned == 1 and spawned[1].proto == "cola"
    and spawned[1].actor.kind == "player",
    "UI acts are player-attributed")
assert(t.ledger_has("ItemSpawned", "cola", "Player"), "and grep finds it too")

-- Closing the window disarms acts.
t.ui_close(p)
t.ui_act(p, "vend")
t.tick()
assert(t.count_items("cola") == 1, "no window, no vending")
