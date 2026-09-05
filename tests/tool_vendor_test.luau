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
    machines: [(2, 1, "tool_vendor"), (2, 2, "vendor")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

-- Dense, and it wobbles when shoved: the shared vendor script.
t.move(p, "east")
t.tick()
local x, y = t.pos(p)
assert(x == 1 and y == 1, "tool vendors are solid too")
assert(table.concat(t.messages(p), "\n"):find("wobbles", 1, true),
    "the shared move.bump fired")

-- Its clean-room shelf document is stocked from ITS OWN list.
t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
local ui = t.ui(p)
assert(ui, "clicking the tool vendor opens its window")
assert(ui.document == "modules" and ui.presentation == "shelf",
    "the generic shelf document")
assert(ui.notice.text == "Tools for tools.", "and its own ad copy")
local shelf = {}
for _, rec in ipairs(ui.products) do
    shelf[rec.payload.product] = rec
end
-- This is the complete TfS tool roster, not only tg's base YouTool
-- stock. Keep the explicit inventory here as the tripwire: every
-- currently implemented tool has a named expectation, and removing
-- one from the machine fails this spec.
local tools = {
    "cable_coil",
    "crowbar",
    "welder",
    "wirecutters",
    "wrench",
    "analyzer",
    "screwdriver",
    "multitool",
    "rpd",
    "pipe_painter",
    "light_replacer",
    "light_bulb",
    "light_tube",
    "toolbelt",
    "toolbox",
    "box_lights",
}
-- The second shelf: what a framed machine is built out of. tg's Robco
-- Tool Maker stocks the stock parts (vending/engineering.dm:29-30); the
-- BOARDS are this pack's own addition, because circuit boards come off a
-- departmental techfab in tg and there is no lathe of any kind here.
--
-- Every part here is the PLAIN rung of its ladder (lib/stock_parts.luau
-- argues the ladder). A better one is something you find, so the shelf
-- sells tier one and no variant of it appears in this roster.
local parts = {
    "matter_bin",
    "micro_laser",
    "capacitor",
    "servo",
    "scanning_module",
    -- The sixth kind of stock part, and the one with no tg ancestor at
    -- all: a network card is what gives a box an ADDRESS
    -- (docs/DEVICES.md SS5a). It is on an open shelf because an address
    -- is an identifier and never a credential -- there is nothing here
    -- to gate.
    "network_card",
    "machine_board.thermomachine",
    "machine_board.access_point",
    -- The air alarm hangs in the same wall frame the access point does
    -- and is built out of the same ladder, so its board is on the same
    -- shelf (machines/tool_vendor.luau).
    "machine_board.air_alarm",
    "machine_board.network_router",
    "machine_board.transceiver",
    -- The encryption keys ride the same no-lathe argument as the
    -- boards: a shipped world must be able to key a tower it built,
    -- and a channel word is fiction, not a credential
    -- (machines/tool_vendor.luau).
    "encryption_key",
    "encryption_key.common",
    "encryption_key.engineering",
    "encryption_key.medical",
    "encryption_key.security",
    "encryption_key.command",
    "machine_board.programming_terminal",
}
-- The third shelf, and the only row here that is neither a tool nor
-- something a frame is built out of: blank media. A disk is how work
-- typed at a programming terminal LEAVES the room it was typed in
-- (content/items/floppy_disk.luau), and nothing else on this station
-- sells one.
local media = {
    "floppy_disk",
}
for _, item in ipairs(tools) do
    assert(shelf[item], item .. " is missing from the tool vendor")
    assert(shelf[item].category == "Tools", item .. " is not under Tools")
    assert(shelf[item].sprite ~= "missing",
        item .. " does not resolve to atlas art")
    assert(shelf[item].stock > 0, item .. " has no displayed stock")
end
for _, item in ipairs(parts) do
    assert(shelf[item], item .. " is missing from the tool vendor")
    assert(shelf[item].category == "Parts", item .. " is not under Parts")
    assert(shelf[item].sprite ~= "missing",
        item .. " does not resolve to atlas art")
    assert(shelf[item].stock > 0, item .. " has no displayed stock")
end
for _, item in ipairs(media) do
    assert(shelf[item], item .. " is missing from the tool vendor")
    assert(shelf[item].category == "Media", item .. " is not under Media")
    assert(shelf[item].sprite ~= "missing",
        item .. " does not resolve to atlas art")
    assert(shelf[item].stock > 0, item .. " has no displayed stock")
end
assert(#ui.products == #tools + #parts + #media,
    "the tool shelf and its asserted roster drifted apart")
assert(shelf.cable_coil.sprite == "coil",
    "item ids that differ from their sprite still select their atlas art")
assert(shelf.cola == nil, "the tool vendor does not sell cola")

-- The additions are not merely rows in a window: each row resolves to
-- its real item prototype when vended. The light tube covers the long
-- replacement fitting too, and the two boxes prove stocked containers
-- survive the same route.
local additions = {
    "rpd",
    "pipe_painter",
    "light_replacer",
    "light_bulb",
    "light_tube",
    "toolbox",
    "box_lights",
    -- The parts shelf goes through the very same route: the boards and
    -- the stock parts a framed machine is assembled from
    -- (thermomachine_construction_test.luau walks what they build, and
    -- parts_test.luau walks what a better rung is worth).
    "matter_bin",
    "micro_laser",
    "capacitor",
    "servo",
    "scanning_module",
    "machine_board.thermomachine",
}
for _, item in ipairs(additions) do
    assert(t.count_items(item) == 0)
    t.ui_act(p, "vend", '{"product":"' .. item .. '"}')
    t.tick()
    assert(t.count_items(item) == 1, item .. " did not dispense")
    assert(t.ledger_has("ItemSpawned", item, "Player"),
        item .. " was not attributed to the buyer")
end

-- act('vend') names WHICH shelf; the item lands at the buyer's feet
-- and the ledger names the buyer, not the script that opened the
-- window.
assert(t.count_items("wrench") == 0)
t.ui_act(p, "vend", '{"product":"wrench"}')
t.tick()
assert(t.count_items("wrench") == 1, "the named product dispensed")
assert(t.count_items("crowbar") == 0, "and only that one")
assert(table.concat(t.sounds(p), "\n"):find("vend", 1, true), "the vend clunk played")
assert(t.ledger_has("ItemSpawned", "wrench", "Player"),
    "a UI act is a direct player action")

-- NEGATIVE: the client is hostile. A product this machine does not stock
-- mints nothing at all — not the first product, not a fallback, and
-- certainly not an arbitrary prototype named by the payload.
t.ui_act(p, "vend", '{"product":"cola"}')
t.tick()
assert(t.count_items("cola") == 0, "a machine cannot be talked into stock it lacks")
t.ui_act(p, "vend", '{"product":"id_engineering"}')
t.tick()
assert(t.count_items("id_engineering") == 0, "nor into minting an ID card")

-- NEGATIVE: closing the window disarms acts, as for any machine.
t.ui_close(p)
t.ui_act(p, "vend", '{"product":"wrench"}')
t.tick()
assert(t.count_items("wrench") == 1, "no window, no vending")

-- The machine next door is a DIFFERENT shelf through the same code.
t.click(p, 2, 2, t.target_at(2, 2))
t.tick()
local cola_ui = t.ui(p)
assert(cola_ui.products[1].payload.product == "cola",
    "the softdrinks machine still sells softdrinks")
t.ui_act(p, "vend", '{"product":"cola"}')
t.tick()
assert(t.count_items("cola") == 1, "and dispenses them")
