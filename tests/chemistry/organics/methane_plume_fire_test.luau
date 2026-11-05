local ignition_room = require("@helpers/ignition_room")

-- A LEAK OF OXYGEN INTO A METHANE SKY BURNS, AND THE SMOKE SNOWS.
--
-- Open ground under the cryo-hydrocarbon sky (`cryo_hydrocarbon`: 94 K,
-- nitrogen with methane in it). A habitat's oxygen leaks onto one tile
-- and a struck burner clicks it alight.
--
-- * Before the leak a spark finds nothing: methane without oxygen is
--   not a fire.
-- * With the leak the tile lights, and the rule that burns is
--   `methane_fire` (content/reactions/organics/methane_fire.luau).
-- * The flame heats the tile far past the sky.
-- * Once the sky has cooled it back, carbon dioxide the fire made lies
--   on the ground as dry ice: matter the world holds that no cell's gas
--   accounts for.
local SPARK_X, SPARK_Y = 2, 1
-- One tile's worth of habitat oxygen (tests/helpers/ignition_room.luau).
local LEAK_O2_MOL = ignition_room.AIR_O2
-- Carbon dioxide at 94 K is solid well under 1 Pa (substances/co2.luau's
-- triple point and latent heats), so any not in a cell's gas is frost.
local SNOW_FLOOR_MOL = 0.01
local ROWS = { ".....", ".....", "....." }

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
        '.': (composition: (), outdoors: true),
    },
    levels: [
        (
            rows: [%s],
            structures: [(1, 1, "player_spawn")],
            items: [(2, 1, "burner")],
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
t.use_self(p) -- snuffed: the leak is the only thing left to burn
t.tick()
local peak_k = sky_k
local lit = ignition_room.run_until(30, 0.25, function()
    peak_k = math.max(peak_k, t.room_temperature(SPARK_X, SPARK_Y) or 0.0)
    return methane_fire_rows() > 0
end)
assert(lit ~= nil, "the plume lit as a methane fire")
ignition_room.run_until(20, 0.25, function()
    peak_k = math.max(peak_k, t.room_temperature(SPARK_X, SPARK_Y) or 0.0)
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
