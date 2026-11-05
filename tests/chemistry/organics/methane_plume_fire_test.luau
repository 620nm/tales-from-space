local ignition_room = require("@helpers/ignition_room")

-- A LEAK OF OXYGEN INTO A METHANE SKY BURNS, AND THE SMOKE SNOWS.
--
-- An open deck under the cryo-hydrocarbon sky (`cryo_hydrocarbon`: 94 K,
-- nitrogen with methane in it), the pad outside a habitat. Its oxygen
-- leaks onto one plated tile and a struck burner clicks it alight. A
-- deck, not bare ice: a ground tile's cell holds its bed of ice at one
-- temperature with the air over it, and that bed swallows the flame.
--
-- * Before the leak a spark finds nothing: methane without oxygen is
--   not a fire.
-- * With the leak the tile lights, and the rule that burns is
--   `methane_fire` (content/reactions/organics/methane_fire.luau).
-- * The flame heats the tile far past the sky.
-- * Once the sky has cooled it back, carbon dioxide the fire made lies
--   on the deck as dry ice: matter the world holds that no cell's gas
--   accounts for.
local SPARK_X, SPARK_Y = 3, 2
-- One tile's worth of habitat oxygen (tests/helpers/ignition_room.luau).
local LEAK_O2_MOL = ignition_room.AIR_O2
-- Then the leak keeps coming while the fire burns: 8 mol/s for 20 s.
local LEAK_STEP_S = 0.25
local LEAK_MOL_PER_STEP = 2.0
local LEAK_SECONDS = 20
-- Carbon dioxide at 94 K is solid well under 1 Pa (substances/co2.luau's
-- triple point and latent heats), so any not in a cell's gas is frost.
local SNOW_FLOOR_MOL = 0.01
local ROWS = { ".......", ".......", ".......", ".......", "......." }

local quoted: { string } = {}
for _, row in ipairs(ROWS) do
    table.insert(quoted, string.format("%q", row))
end
t.world(
    string.format(
        [==[(
    name: "methane plume",
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(94.0)),
    legend: {
        '.': (
            outdoors: true,
            composition: (components: [(component: "station_base"), (component: "floor_tiles")]),
        ),
    },
    levels: [
        (
            rows: [%s],
            structures: [(2, 2, "player_spawn")],
            items: [(3, 2, "burner")],
        ),
    ],
)]==],
        table.concat(quoted, ", ")
    ),
    0,
    "free_build"
)
assert(t.environment().id == "cryo_hydrocarbon", "the cold methane sky: " .. t.environment().id)
t.set_breathing(false)
local p = t.join()
t.run_ticks(4)

local function gas(x: number, y: number, key: string): number
    local held = t.room_gas(x, y)
    return (held and held[key]) or 0.0
end

local function co2_in_gas(): number
    local total = 0.0
    for y = 0, #ROWS - 1 do
        for x = 0, #ROWS[1] - 1 do
            total += gas(x, y, "co2")
        end
    end
    return total
end

local function co2_in_world(): number
    return t.matter_totals().substances.co2 or 0.0
end

local function methane_fire_rows(): number
    local n = 0
    for _, row in ipairs(t.ledger_rows("IgnitionAt")) do
        local fields: any = row
        if string.find(fields.rule, "methane_fire", 1, true) ~= nil then
            n += 1
        end
    end
    return n
end

local sky_k = assert(t.room_temperature(SPARK_X, SPARK_Y))
assert(math.abs(sky_k - 94.0) < 1.0, ("the ground stands at the sky's 94 K: %.2f"):format(sky_k))
assert(gas(SPARK_X, SPARK_Y, "methane") > 1.0, "the sky's methane is over the tile")
local co2_before = co2_in_world()

-- No oxygen, no fire: the lib declines the click and writes no latch.
ignition_room.take_lit_burner(p, SPARK_X, SPARK_Y)
ignition_room.touch(p, SPARK_X, SPARK_Y)
t.run_seconds(2)
assert(#ignition_room.latch_rows() == 0, "methane air alone does not take the latch")

-- The leak, then the same click.
assert(t.foul_room(SPARK_X, SPARK_Y, "o2", LEAK_O2_MOL), "habitat oxygen leaks onto the tile")
t.tick()
ignition_room.touch(p, SPARK_X, SPARK_Y)
local peak_k = sky_k
local function leak_and_watch(): ()
    t.foul_room(SPARK_X, SPARK_Y, "o2", LEAK_MOL_PER_STEP)
    peak_k = math.max(peak_k, t.room_temperature(SPARK_X, SPARK_Y) or 0.0)
end
local lit = ignition_room.run_until(30, LEAK_STEP_S, function()
    leak_and_watch()
    return methane_fire_rows() > 0
end)
assert(lit ~= nil, "the plume lit as a methane fire")
t.use_self(p) -- snuffed: the leak is the only thing left to burn
ignition_room.run_until(LEAK_SECONDS, LEAK_STEP_S, function()
    leak_and_watch()
    return false
end)
assert(peak_k > 300.0, ("the flame heats the tile far past the sky: peak %.1f K"):format(peak_k))

-- The sky takes the heat back, and the fire's CO2 freezes out of it.
local cooled = ignition_room.run_until(600, 5, function()
    return (t.room_temperature(SPARK_X, SPARK_Y) or 1e9) < 100.0
end)
assert(cooled ~= nil, "the sky cools the burnt tile back down")
local snow = (co2_in_world() - co2_before) - co2_in_gas()
assert(snow > SNOW_FLOOR_MOL, ("the fire's CO2 lies as dry ice: %.4f mol"):format(snow))
