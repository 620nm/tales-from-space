local ignition_room = require("@helpers/ignition_room")

-- SELF-IGNITION: ethanol vapor with air does not light by itself.
--
-- The burn rule runs only where the `alight` column is set, and only a
-- source (`lib/ignition.luau`) sets it. Two sealed single-tile rooms
-- hold a 2 L spill each: one painted warm, inside the rule's window
-- from the first second, and one painted hot, which starts above the
-- window and cools through it. Both have the fuel and the oxygen the
-- rule asks for for ten minutes; neither has a spark.
--
-- Fails if the rule ever fires without the latch (an `IgnitionAt` row)
-- or if anything writes the latch column with no source in the room.
local WARM = { x = 1, y = 1 }
local HOT = { x = 3, y = 1 }
local WINDOW_LO_K, WINDOW_HI_K = 255.0, 311.0
local STEP_SECONDS = 20
local STEPS = 30

ignition_room.build({
    rows = { "#####", "#.#.#", "#####" },
    spawn = WARM,
    spills = {
        { x = WARM.x, y = WARM.y, ethanol_mol = ignition_room.POOL_MOL, temperature_k = 305.0 },
        { x = HOT.x, y = HOT.y, ethanol_mol = ignition_room.POOL_MOL, temperature_k = 350.0 },
    },
})

-- A tile has been inside the rule's window with fuel and oxygen in it.
local function in_window(tile: { x: number, y: number }): boolean
    local kelvin = t.room_temperature(tile.x, tile.y) or 0.0
    return kelvin >= WINDOW_LO_K
        and kelvin <= WINDOW_HI_K
        and ignition_room.ethanol_gas(tile.x, tile.y) >= 0.5
        and ignition_room.oxygen_gas(tile.x, tile.y) >= 5.0
end

local warm_seen, hot_seen = false, false
for _ = 1, STEPS do
    t.run_seconds(STEP_SECONDS)
    warm_seen = warm_seen or in_window(WARM)
    hot_seen = hot_seen or in_window(HOT)
end

-- Without these the silence below would prove nothing: the rule's own
-- conditions held on both tiles, and only the cause was missing.
assert(warm_seen, "the warm spill sat inside the window with fuel and air")
assert(hot_seen, "the hot spill cooled into the window with fuel and air")

assert(#t.ledger_rows("IgnitionAt") == 0, "nothing lit by itself")
assert(#ignition_room.latch_rows() == 0, "and no source ever set the latch")
assert(#t.ledger_rows("ExtinguishedAt") == 0, "so nothing went out either")
