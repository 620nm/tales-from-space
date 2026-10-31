local ignition_room = require("@helpers/ignition_room")

-- A SMASHED TUBE SPARKS ONLY IF IT WAS ON (tg light.dm:690-702).
--
-- Two ceiling fittings in a room full of ethanol vapour: one on a
-- powered branch, one on bare plating with no cable. A toolbox swing
-- shatters either (fixtures/light.luau). The dead fitting breaks in
-- silence and leaves the room unlit; the burning one throws a spark
-- onto its tile and the room catches. Fails if an unlit tube sparks,
-- or if a lit one does not.
local LIT = { x = 2, y = 1 }
local DEAD = { x = 1, y = 2 }

local cables = {}
for _, at in ipairs({ { 1, 1 }, { 2, 1 }, { 3, 1 }, { 2, 2 }, { 3, 2 } }) do
    for _, channel in ipairs({ "l1", "l2" }) do
        table.insert(
            cables,
            string.format(
                '(x: %d, y: %d, network: "power", channel: "%s", kind: "cable", facing: 15),',
                at[1],
                at[2],
                channel
            )
        )
    end
end

local p = ignition_room.build({
    rows = {
        "#####",
        "#alo#",
        "#l.g#",
        "#...#",
        "#####",
    },
    legend = [[
        'l': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Light), light: Some("#FFD6AA")),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    ]],
    spawn = { x = 1, y = 1 },
    structures = '(1, 1, "apc"),',
    items = '(1, 1, "toolbox"),',
    networks = table.concat(cables, " "),
    spills = { { x = 2, y = 3, ethanol_mol = ignition_room.POOL_MOL } },
})

t.run_seconds(30)
assert(assert(t.light_at(LIT.x, LIT.y)).lit, "the powered fitting is fed")
assert(not assert(t.light_at(DEAD.x, DEAD.y)).lit, "the bare fitting is not")
for _, at in ipairs({ LIT, DEAD }) do
    assert(ignition_room.ethanol_gas(at.x, at.y) >= 0.05, "vapour hangs under each fitting")
end
assert(#t.ledger_rows("IgnitionAt") == 0, "the room is unlit")

t.click(p, 1, 1, assert(t.target_at(p, 1, 1, "toolbox")))
t.tick()
assert(t.hands(p).held == "toolbox", "picked the toolbox up")

-- The dead fitting first, so a spark from it could not hide behind the
-- fire the lit one starts.
local dead_target = assert(t.target_at(p, DEAD.x, DEAD.y))
t.click(p, DEAD.x, DEAD.y, assert(t.target_at(p, DEAD.x, DEAD.y, dead_target)))
t.tick()
assert(assert(t.light_at(DEAD.x, DEAD.y)).status == "broken", "the bare tube shattered")
t.run_seconds(5)
assert(#ignition_room.latch_rows() == 0, "a tube that was off throws no spark")
assert(#t.ledger_rows("IgnitionAt") == 0, "and the room stays unlit")

local lit_target = assert(t.target_at(p, LIT.x, LIT.y))
t.click(p, LIT.x, LIT.y, assert(t.target_at(p, LIT.x, LIT.y, lit_target)))
t.tick()
assert(assert(t.light_at(LIT.x, LIT.y)).status == "broken", "the burning tube shattered")
t.run_seconds(5)
assert(#t.ledger_rows("IgnitionAt") >= 1, "a tube that was on sparks and the room catches")
assert(ignition_room.latched_tiles()[ignition_room.tile_key(LIT.x, LIT.y)], "the latch is on the broken fitting's tile")
