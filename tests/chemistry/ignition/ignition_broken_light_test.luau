local ignition_room = require("@helpers/ignition_room")

-- A SMASHED TUBE SPARKS ONLY IF IT WAS ON (tg light.dm:690-702).
--
-- The same ceiling fitting in a room full of ethanol vapour, twice: with
-- no power in the room and its own cell run flat, then fed by an APC and
-- generator. A toolbox swing shatters either (fixtures/light.luau). The dead fitting
-- breaks in silence and leaves the room unlit; the burning one throws a
-- spark onto its tile and the room catches.
local LIGHT = { x = 2, y = 1 }

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

local function room(powered: boolean): number
    return ignition_room.build({
        rows = {
            "#####",
            "#alo#",
            "#..g#",
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
        structures = if powered then '(1, 1, "apc"),' else "",
        items = '(2, 2, "toolbox"),',
        networks = if powered then table.concat(cables, " ") else "",
        spills = { { x = 2, y = 3, ethanol_mol = ignition_room.POOL_MOL } },
    })
end

local function smash(p: number)
    assert(ignition_room.ethanol_gas(LIGHT.x, LIGHT.y) >= 0.05, "vapour hangs under the fitting")
    assert(#t.ledger_rows("IgnitionAt") == 0, "the room is unlit")
    t.click(p, 2, 2, assert(t.target_at(p, 2, 2, "toolbox")))
    t.tick()
    assert(t.hands(p).held == "toolbox", "picked the toolbox up")
    local fitting = assert(t.target_at(p, LIGHT.x, LIGHT.y))
    t.click(p, LIGHT.x, LIGHT.y, fitting)
    t.tick()
    assert(assert(t.light_at(LIGHT.x, LIGHT.y)).status == "broken", "the tube shattered")
    t.run_seconds(5)
end

do
    local p = room(false)
    -- Ten minutes runs the fitting's own cell flat (emergency_light_test).
    t.run_seconds(620)
    assert(not assert(t.light_at(LIGHT.x, LIGHT.y)).lit, "the unfed fitting is off")
    smash(p)
    assert(#ignition_room.latch_rows() == 0, "a tube that was off throws no spark")
    assert(#t.ledger_rows("IgnitionAt") == 0, "and the room stays unlit")
end

do
    local p = room(true)
    t.run_seconds(30)
    assert(assert(t.light_at(LIGHT.x, LIGHT.y)).lit, "the fed fitting is on")
    smash(p)
    assert(#t.ledger_rows("IgnitionAt") >= 1, "a tube that was on sparks and the room catches")
    assert(
        ignition_room.latched_tiles()[ignition_room.tile_key(LIGHT.x, LIGHT.y)],
        "the latch is on the broken fitting's tile"
    )
end
