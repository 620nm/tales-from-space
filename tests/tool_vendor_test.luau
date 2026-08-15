-- The tool vendor, beside the softdrinks machine: same behaviour, a
-- different shelf. It proves the mechanism is generic — the engine
-- has no word for either machine, so a second one costs two content
-- files and nothing else.
t.world([==[(
    name: "tool room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    machines: [(2, 1, "tool_vendor"), (2, 2, "vendor")],
)]==], 7)

local p = t.join()
t.tick()

-- Dense, and it wobbles when shoved: the shared vendor script.
t.move(p, "east")
t.tick()
local x, y = t.pos(p)
assert(x == 1 and y == 1, "tool vendors are solid too")
assert(table.concat(t.messages(p), "\n"):find("wobbles", 1, true),
    "the shared on_bump fired")

-- Its window is tg's Vending interface, stocked from ITS OWN list.
t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
local ui = t.ui(p)
assert(ui, "clicking the tool vendor opens its window")
assert(ui.payload.config.interface.name == "Vending", "tg's Vending window")
assert(ui.payload.config.title == "YouTool vending machine",
    "the window wears the machine's own name: " .. tostring(ui.payload.config.title))
assert(ui.payload.data.ad == "Tools for tools.", "and its own ad copy")
local shelf = {}
for _, rec in ipairs(ui.payload.data.product_records) do
    shelf[rec.ref] = rec
end
assert(shelf.crowbar and shelf.crowbar.category == "Tools",
    "the crowbar is on the shelf under Tools")
assert(shelf.cable_coil.path == "atlas-coil-cable_coil",
    "item ids that differ from their sprite still select their atlas art")
assert(shelf.toolbelt, "and so is the toolbelt")
assert(shelf.cola == nil, "the tool vendor does not sell cola")

-- act('vend') names WHICH shelf; the item lands at the buyer's feet
-- and the ledger names the buyer, not the script that opened the
-- window.
assert(t.count_items("wrench") == 0)
t.ui_act(p, "vend", '{"ref":"wrench"}')
t.tick()
assert(t.count_items("wrench") == 1, "the named product dispensed")
assert(t.count_items("crowbar") == 0, "and only that one")
assert(table.concat(t.sounds(p), "\n"):find("vend", 1, true), "the vend clunk played")
assert(t.ledger_has("ItemSpawned", "wrench", "Player"),
    "a UI act is a direct player action")

-- NEGATIVE: the client is hostile. A ref this machine does not stock
-- mints nothing at all — not the first product, not a fallback, and
-- certainly not an arbitrary prototype named by the payload.
t.ui_act(p, "vend", '{"ref":"cola"}')
t.tick()
assert(t.count_items("cola") == 0, "a machine cannot be talked into stock it lacks")
t.ui_act(p, "vend", '{"ref":"id_engineering"}')
t.tick()
assert(t.count_items("id_engineering") == 0, "nor into minting an ID card")

-- NEGATIVE: closing the window disarms acts, as for any machine.
t.ui_close(p)
t.ui_act(p, "vend", '{"ref":"wrench"}')
t.tick()
assert(t.count_items("wrench") == 1, "no window, no vending")

-- The machine next door is a DIFFERENT shelf through the same code.
t.click(p, 2, 2, t.target_at(2, 2))
t.tick()
local cola_ui = t.ui(p)
assert(cola_ui.payload.data.product_records[1].ref == "cola",
    "the softdrinks machine still sells softdrinks")
t.ui_act(p, "vend", '{"ref":"cola"}')
t.tick()
assert(t.count_items("cola") == 1, "and dispenses them")
