-- Wading, swimming and drowning in standing liquid: tg's water turf
-- (code/game/turfs/open/water.dm) and swimming element
-- (code/datums/elements/swimming_tile.dm). `BANDS` prices a step off a
-- tile by the liquid standing on it; a body that steps into swimming depth
-- gets a pass every `SWIM.interval_s` while there, and lying in it without
-- internals it drowns through the oxy pool and the breathing role.
-- NOT PORTED: stamina, athletics, swimmer traits and the high-gravity
-- doubling (swimming_tile.dm:79-101,145-153): this pack has none of them.
local airborne = require("@lib/medical/airborne")

export type WadingBand = {
    key: string,
    -- The least depth, in metres of liquid over the tile's floor.
    min_depth_m: number,
    -- Seconds added to every step taken FROM a tile this deep.
    step_add_s: number,
    -- Whether a body in it gets the swimming pass.
    swims: boolean,
}

local wading = {}

-- Deepest first. tg's water turf has `slowdown = 1` (water.dm:9), one
-- decisecond on a step off it (living_movement.dm:83-90); deep water adds
-- `swimming_deep` 7 on top (movespeed/modifiers/mobs.dm:180-182, added at
-- swimming_tile.dm:131), so 0.1 s and 0.8 s. tg's depth is the turf's type;
-- these thresholds are this pack's: a sea's 0.5 m shallows wade, its 1.5 m
-- swims, a 1 m lake wades, and a spill under 0.2 m is a puddle.
wading.BANDS = {
    { key = "swimming", min_depth_m = 1.2, step_add_s = 0.8, swims = true },
    { key = "wading", min_depth_m = 0.2, step_add_s = 0.1, swims = false },
} :: { WadingBand }

-- The swimming status effect's numbers (swimming_tile.dm:113-169).
wading.SWIM = {
    -- tick_interval = 5 SECONDS (swimming_tile.dm:118).
    interval_s = 5,
    -- ticking_oxy_damage 2 (water.dm:40), times the seconds of the pass
    -- (swimming_tile.dm:166).
    oxy_per_s = 2,
    -- drowning_process_probability 20 (swimming_tile.dm:124,149).
    lose_breath_chance = 0.2,
    -- `losebreath += oxygen_per_interval` (swimming_tile.dm:167-168): two
    -- breaths missed, each one of tg's breath periods (SSmobs 2 s x
    -- `next_breath` 4, the engine's docs/matter-world/breathing.md).
    lost_breaths = 2,
    breath_period_s = 8,
    -- The capacity this pack's breath pass reads (bodies/human.luau).
    breath_capacity = "breathing",
}

-- A tile is one metre square, so a cubic metre of liquid is a metre deep.
local ML_PER_M_DEPTH = 1e6
local LOSE_BREATH_PURPOSE = "wading.lose_breath"

-- A contribute handler must answer a table; this one adds nothing.
local NO_COST = {}

local function depth_m(at: TileAddress): number
    local read = sim.matter_read(at.matter)
    if read == nil then
        return 0
    end
    local ml = 0
    for _, phases in pairs(read.contents) do
        ml += phases.liquid_ml or 0
    end
    return ml / ML_PER_M_DEPTH
end

local function band_at(at: TileAddress): WadingBand?
    local depth = depth_m(at)
    for _, band in ipairs(wading.BANDS) do
        if depth >= band.min_depth_m then
            return band
        end
    end
    return nil
end

-- `move.cross` contribute on a body plan: a step costs the band of the
-- tile it leaves, as tg's turf slowdown is the turf the mob stands on.
-- Fractional ticks: settlement rounds the step's whole cost once.
function wading.on_cross(ev: MoveCrossPayload): { [string]: any }
    local band = band_at(ev.from)
    if band == nil then
        return NO_COST
    end
    return { move_cost = { add = band.step_add_s * sim.tick_hz() } }
end

type Swimmer = { body: Handle, generation: number, due_tick: number }

-- Ephemeral: a lost entry only means the next step restarts the pass.
local swimmers: { Swimmer } = {}

local function swimmer_of(body: Handle): Swimmer?
    for _, swimmer in ipairs(swimmers) do
        if swimmer.body == body then
            return swimmer
        end
    end
    return nil
end

local function forget(swimmer: Swimmer): ()
    for index, held in ipairs(swimmers) do
        if held == swimmer then
            table.remove(swimmers, index)
            return
        end
    end
end

-- The tile a body stands on; nil while something contains it, which
-- takes it out of the water as tg's turf Exited does (swimming_tile.dm:66-69).
local function standing_tile(body: Handle): TileAddress?
    local ok, at = pcall(function(): TileAddress
        return body.tile
    end)
    return if ok then at else nil
end

local function swims_at(at: TileAddress?): boolean
    if at == nil then
        return false
    end
    local band = band_at(at)
    return band ~= nil and band.swims
end

-- tg's exemptions (swimming_tile.dm:156-165): a human-sized body standing
-- up keeps its head out, a body that does not breathe cannot drown, and
-- internals breathe for it.
local function drowning(body: Handle): boolean
    local reading = sim.body(body)
    if reading == nil or reading.animate ~= true or reading.posture ~= "lying" then
        return false
    end
    if sim.capacity(body, wading.SWIM.breath_capacity) == nil then
        return false
    end
    return not airborne.uses_internals(body)
end

local function swim_pass(body: Handle): ()
    if not drowning(body) then
        return
    end
    local swim = wading.SWIM
    sim.damage.apply({ target = body, amounts = { oxy = swim.oxy_per_s * swim.interval_s } })
    -- A missed breath is the breathing role reading 0 (bodies/human.luau).
    if sim.random_for(LOSE_BREATH_PURPOSE, body) < swim.lose_breath_chance then
        sim.capacity_mod(body, swim.breath_capacity, 0, swim.lost_breaths * swim.breath_period_s)
    end
end

-- `move.cross.done` react on a body plan: a step into swimming depth
-- starts the body's pass unless one already runs (dip_in,
-- swimming_tile.dm:46-63,76-101); it ends when the body is out.
function wading.on_cross_done(ev: MoveCrossDonePayload): ()
    if ev.outcome ~= "completed" or not swims_at(ev.to) then
        return
    end
    local body = ev.mover
    local now = sim.tick()
    local swimmer = swimmer_of(body)
    if swimmer ~= nil and now <= swimmer.due_tick then
        return
    end
    if swimmer == nil then
        swimmer = { body = body, generation = 0, due_tick = 0 }
        table.insert(swimmers, swimmer)
    end
    local held = swimmer :: Swimmer
    held.generation += 1
    local generation = held.generation
    local interval = sim.ticks(wading.SWIM.interval_s)
    held.due_tick = now + interval
    sim.spawn_task(body, function()
        while held.generation == generation do
            sim.sleep(interval)
            if not body.alive or not swims_at(standing_tile(body)) then
                break
            end
            held.due_tick = sim.tick() + interval
            swim_pass(body)
        end
        if held.generation == generation then
            forget(held)
        end
    end)
end

return wading
