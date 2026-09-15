local composition = require("@helpers/composition")

-- The vending machine: dense on bump, opens its shelf document on click,
-- dispenses on act('vend') as a PLAYER-attributed action, and a closed
-- window disarms acts. (Port of the Rust m4 vendor test.)
local ui_controls = require("@helpers/ui_controls")

t.world(
    [==[(
    name: "canteen",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Apc)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#o..#",
        "#a.g#",
        "#####",
    ],
    structures: [(1, 1, "player_spawn")],
    machines: [(2, 1, "vendor")],
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
    ],
)]==],
    7
)

local p = t.join()
t.tick()

-- Dense: you can't walk through it, and bumping fires move.bump.
t.move(p, "east")
t.tick()
local x, y = t.pos(p)
assert(x == 1 and y == 1, "vending machines are solid")
local msgs = table.concat(t.messages(p), "\n")
assert(msgs:find("wobbles", 1, true), "move.bump fired: " .. msgs)

-- Click it: the machine's content-authored clean-room shelf opens.
composition.click_deck(p, 2, 1)
t.tick()
local missed = t.last_ui(p)
assert(missed == nil, "a target-less transparent-pixel click is only ground")

t.click(p, 2, 1, t.target_at(p, 2, 1))
t.tick()
local raw, pushes = t.last_ui(p)
assert(raw, "clicking the machine opens its window")
local ui = ui_controls.record(t.ui(p))
assert(ui.document == "modules" and ui.presentation == "shelf", "the clean-room shelf document")
assert(
    ui_controls.record(ui.notice).text == "Robust! Refreshing! Occasionally fermented!",
    "the shelf wears the content-authored notice"
)
local product = ui_controls.rows(ui.products)[1]
assert(ui_controls.record(product.payload).product == "cola", "cola heads the product list")
assert(product.sprite == "cola", "the shelf names cola's atlas sprite")
assert(product.stock == 99, "the product row carries its live stock")

-- act('vend') dispenses; the ledger names the player, not a script.
assert(t.count_items("cola") == 0)
local spawned_before = #t.ledger_rows("ItemSpawned")
ui_controls.vend(p, "cola")
t.tick()
assert(t.count_items("cola") == 1, "act('vend') dispenses")
local sounds = table.concat(t.sounds(p), "\n")
assert(sounds:find("vend", 1, true), "the vend clunk played")
local _, after = t.last_ui(p)
assert(after > pushes, "the window got fresh state")

-- A UI act is a DIRECT player action: the row names the crewman, not
-- the file that ran on their behalf.
local spawned = t.ledger_rows("ItemSpawned")
assert(
    #spawned == spawned_before + 1
        and spawned[spawned_before + 1].proto == "cola"
        and spawned[spawned_before + 1].actor.kind == "player",
    "UI acts are player-attributed"
)
assert(t.ledger_has("ItemSpawned", "cola", "Player"), "and grep finds it too")

-- Closing the window disarms acts.
t.ui_close(p)
assert(not ui_controls.has_product(p, "cola"), "closing removes the shelf control")
t.tick()
assert(t.count_items("cola") == 1, "no window, no vending")
