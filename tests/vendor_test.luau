-- The vending machine: dense on bump, opens its TGUI window on click,
-- dispenses on act('vend') as a PLAYER-attributed action, and a closed
-- window disarms acts. (Port of the Rust m4 vendor test.)
t.world([==[(
    name: "canteen",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'V': (turf: Floor, fixture: Some(Vendor)),
    },
    rows: [
        "#####",
        "#.V.#",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
)]==], 7)

local p = t.join()
t.tick()

-- Dense: you can't walk through it, and bumping fires on_bump.
t.move(p, "east")
t.tick()
local x, y = t.pos(p)
assert(x == 1 and y == 1, "vending machines are solid")
local msgs = table.concat(t.messages(p), "\n")
assert(msgs:find("wobbles", 1, true), "on_bump fired: " .. msgs)

-- Click it: the machine's real TGUI window opens with tg's shape.
t.click(p, 2, 1)
t.tick()
local ui = t.last_ui(p)
assert(ui, "clicking the machine opens its window")
assert(ui:find('"Vending"', 1, true), "tg Vending interface: " .. ui:sub(1, 120))
assert(ui:find('"cola"', 1, true), "cola is on the product list")

-- act('vend') dispenses; the ledger names the player, not a script.
assert(t.count_items("cola") == 0)
t.ui_act(p, "vend")
t.tick()
assert(t.count_items("cola") == 1, "act('vend') dispenses")
local sounds = table.concat(t.sounds(p), "\n")
assert(sounds:find("vend", 1, true), "the vend clunk played")
assert(t.ledger_has("ItemSpawned", "cola", "Player"),
    "UI acts are player-attributed")

-- Closing the window disarms acts.
t.ui_close(p)
t.ui_act(p, "vend")
t.tick()
assert(t.count_items("cola") == 1, "no window, no vending")
