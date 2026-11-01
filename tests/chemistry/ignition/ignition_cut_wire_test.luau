local ignition_room = require("@helpers/ignition_room")
local network_channels = require("@helpers/network_channels")

-- THE ACTORLESS PATH: a cut cable sparks, with no hand behind the spark.
--
-- `flow.segment_split.done` fires `ignition.spark` (main.luau) with no
-- body attached, and every later write rides a task anchored at the lit
-- tile. A run of five open-deck cable tiles lies under a spill; the
-- player stands on the second and cuts the third. The spark lights the
-- cut tile, and the fire then walks to tiles the player cannot reach
-- (two and three tiles off): those latch rows are written by the
-- spreading task, so their actor is the script alone, with no
-- `triggered_by` body. A reach rule that demanded a live actor would
-- stop the first spark or the first spread, and nothing would light.
local CUT = 3
local PLAYER = 2
local FAR = 5

local cables = {}
for x = 1, FAR do
    table.insert(
        cables,
        string.format('(x: %d, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),', x)
    )
end

local spills: { ignition_room.Spill } = {}
for x = CUT, FAR do
    table.insert(spills, { x = x, y = 1, ethanol_mol = ignition_room.POOL_MOL })
end

local p = ignition_room.build({
    rows = { "#######", "#ccccc#", "#######" },
    legend = [['c': (composition: (components: [(component: "station_base")])),]],
    spawn = { x = PLAYER, y = 1 },
    items = string.format('(%d, 1, "wirecutters"),', PLAYER),
    networks = table.concat(cables, " "),
    spills = spills,
})

t.run_seconds(30)
assert(ignition_room.ethanol_gas(CUT, 1) >= 0.5, "the cut tile is wreathed in vapour")
assert(t.network_exposed(CUT, 1, "power"), "the run lies open to the cutters")
assert(#t.ledger_rows("IgnitionAt") == 0 and #ignition_room.latch_rows() == 0, "the spill sits unlit until cut")

t.click(p, PLAYER, 1, assert(t.target_at(p, PLAYER, 1, "wirecutters")))
t.tick()
assert(t.hands(p).held == "wirecutters", "cutters in hand")
t.click_network(p, CUT, 1, assert(t.network_instance(CUT, 1, "power", "l1")))
t.run_seconds(1.5)
assert(network_channels.at(CUT, 1, "power") == "", "the cut tile gave its cable up")
t.run_seconds(15)

assert(#t.ledger_rows("IgnitionAt") >= 1, "the cut lit the spill")

local lit = ignition_room.latched_tiles()
assert(lit[ignition_room.tile_key(CUT, 1)], "the cut tile is latched")

-- Every latch row is a script's, and the far ones carry no body.
local far_rows = 0
for _, row in ipairs(ignition_room.latch_edges(true)) do
    local actor: any = row.actor
    assert(actor.kind == "script", "the file that decided owns the write: " .. tostring(actor.kind))
    local tile = ignition_room.tile_of(row)
    if math.abs(tile.x - PLAYER) > 1 then
        far_rows = far_rows + 1
        assert(
            actor.triggered_by == nil,
            ("the spreading write at (%d, %d) has no body behind it"):format(tile.x, tile.y)
        )
    end
end
assert(far_rows >= 1, "the fire walked past the player's reach")
