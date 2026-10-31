-- Ignition: what lights a tile. Every source calls one verb on the tile
-- and the tile decides at that instant; a spark that finds nothing
-- leaves nothing (tg LINDA_fire.dm:23-58 `hotspot_expose`).
--
-- A spark sets the cell column `alight` to 1; the burn rule in
-- `reactions/ethanol_fire.luau` requires it. `on_ignited` tends a
-- lit cell, spreads to the cardinals and clears the column once the
-- fire can no longer burn. The scratch table below is Lua heap, not
-- world state: a stale entry ages out (the engine's
-- docs/scripting/execution-model.md §1.4).
local ignition = {}

-- tg __DEFINES/atmospherics/atmos_core.dm:130 (fire needs 373.15 K).
local IGNITE_K = 373.15
-- tg effects_sparks.dm:94 (a spark exposes at 1000 K).
local SPARK_K = 1000
-- tg items.dm:958 (`open_flame(700)` for held and worn flames).
local FLAME_K = 700
-- tg LINDA_fire.dm:32 (no fire under half a mole of oxygen).
local MIN_O2_MOL = 0.5
-- The burn rule's `requires` and `column_below` (reactions/ethanol_fire.luau).
local MIN_FUEL_GAS_MOL = 0.01
local RESIN_FLOOR = 0.1
-- Substances the latch can light; acetone and naphtha are unmodelled.
local FUELS = { "ethanol" }
-- Pack feel; tg spreads and tends once per process.
local SPREAD_SECONDS = 2
local TEND_SECONDS = 1
-- A tending entry older than this many spreads is stale.
local STALE_SPREADS = 3
-- tg effects_sparks.dm:8-13,20-21,44: light 1.5 / 2, lives 2 s.
local SPARK_STRENGTH = 2
local SPARK_SECONDS = 0.35
local GLOW_STRENGTH = 2
local GLOW_RANGE = 1.5
local GLOW_SECONDS = 2

local LATCH_COLUMN = "alight"
local LATCH_ON = 0.5
local TENDED_VAR = "flame_tended"
local LIT_STATE = "lit"

ignition.IGNITE_K = IGNITE_K
ignition.SPARK_K = SPARK_K
ignition.FLAME_K = FLAME_K
ignition.MIN_O2_MOL = MIN_O2_MOL
ignition.MIN_FUEL_GAS_MOL = MIN_FUEL_GAS_MOL
ignition.RESIN_FLOOR = RESIN_FLOOR
ignition.FUELS = FUELS
ignition.SPREAD_SECONDS = SPREAD_SECONDS
ignition.TEND_SECONDS = TEND_SECONDS

-- Cells whose tending task is running: "x:y:z" of the plane-absolute
-- tile, to the tick of the task's last visit.
local tending: { [string]: number } = {}

local CARDINALS = {
    { dx = 1, dy = 0 },
    { dx = -1, dy = 0 },
    { dx = 0, dy = 1 },
    { dx = 0, dy = -1 },
}

local function burnable(reading: MatterRead): boolean
    local oxygen = reading.contents.o2
    if oxygen == nil or (oxygen.gas or 0) < MIN_O2_MOL then
        return false
    end
    if (reading.columns.atmos_resin or 0) >= RESIN_FLOOR then
        return false
    end
    for _, id in FUELS do
        local fuel = reading.contents[id]
        if fuel ~= nil and ((fuel.gas or 0) >= MIN_FUEL_GAS_MOL or (fuel.liquid or 0) > 0) then
            return true
        end
    end
    return false
end

-- Nil past the map's edge or for a stale address.
local function tile_beside(centre: TileAddress, dx: number, dy: number): TileAddress?
    local ok, at = pcall(sim.map_tile, centre, centre.x + dx, centre.y + dy, centre.z)
    return if ok then at else nil
end

-- A tile that burns and is not yet latched takes the latch; true when the
-- tile is (now) latched. Read before writing: a wall has no cell.
function ignition.expose(at: TileAddress, heat_k: number): boolean
    if heat_k < IGNITE_K then
        return false
    end
    local reading = sim.matter_read(at.matter)
    if reading == nil or not burnable(reading) then
        return false
    end
    if (reading.columns[LATCH_COLUMN] or 0) >= LATCH_ON then
        return true
    end
    sim.matter.set_column({ owner = at.matter, column = LATCH_COLUMN, value = 1 })
    return true
end

function ignition.spark(at: TileAddress): ()
    sim.visual.sparks({ at = at, strength = SPARK_STRENGTH, duration = SPARK_SECONDS })
    sim.visual.glow({
        at = at,
        strength = GLOW_STRENGTH,
        range = GLOW_RANGE,
        duration = GLOW_SECONDS,
    })
    ignition.expose(at, SPARK_K)
end

-- A lit tool clicked on a tile: lights it when it burns, else declines.
function ignition.act(self: Handle, user: Handle, ev: InteractionUsePayload): { replaced: boolean }
    if self.state ~= LIT_STATE then
        return { replaced = false }
    end
    local reading = sim.matter_read(ev.at.matter)
    if reading == nil or not burnable(reading) then
        return { replaced = false }
    end
    ignition.expose(ev.at, FLAME_K)
    sim.message.send({
        recipient = user,
        message = sim.msg("lunatic/tfs:ui.message.ignite", {}),
    })
    return { replaced = true }
end

local function spread(at: TileAddress): ()
    for _, step in CARDINALS do
        local beside = tile_beside(at, step.dx, step.dy)
        if beside ~= nil then
            ignition.expose(beside, FLAME_K)
        end
    end
end

local function cell_key(at: TileAddress): string
    return string.format("%d:%d:%d", at.absolute_x, at.absolute_y, at.z)
end

-- `matter.ignition.done`: one task per lit cell spreads to the
-- cardinals every `SPREAD_SECONDS` and drops the latch once the fire
-- cannot burn. A ceiling flap re-fires the edge; the entry absorbs it.
function ignition.on_ignited(ev: MatterIgnitionDonePayload): ()
    local at = ev.at
    local key = cell_key(at)
    local spread_ticks = sim.ticks(SPREAD_SECONDS)
    local last = tending[key]
    if last ~= nil and sim.tick() - last <= spread_ticks * STALE_SPREADS then
        return
    end
    tending[key] = sim.tick()
    spread(at)
    sim.spawn_task("round", function()
        while true do
            sim.sleep(spread_ticks)
            local ok, reading = pcall(sim.matter_read, at.matter)
            if not ok or reading == nil then
                tending[key] = nil
                return
            end
            if not burnable(reading) then
                sim.matter.set_column({ owner = at.matter, column = LATCH_COLUMN, value = 0 })
                tending[key] = nil
                return
            end
            tending[key] = sim.tick()
            spread(at)
        end
    end)
end

local function live_tile(self: Handle, holder: Handle): TileAddress?
    local ok, at = pcall(function(): TileAddress
        return self.tile
    end)
    if ok and at ~= nil then
        return at
    end
    local holder_ok, holder_at = pcall(function(): TileAddress
        return holder.tile
    end)
    if holder_ok and holder_at ~= nil then
        return holder_at
    end
    return nil
end

-- A lit item tends its tile once a second while it burns. Call beside
-- each `sim.set_flame(self, true)`; the task ends with the flame.
function ignition.tend_flame(self: Handle, holder: Handle): ()
    if self.vars[TENDED_VAR] then
        return
    end
    self.vars[TENDED_VAR] = true
    local tend_ticks = sim.ticks(TEND_SECONDS)
    sim.spawn_task(self, function()
        sim.sleep(tend_ticks)
        while self.alive and self.state == LIT_STATE do
            local site = live_tile(self, holder)
            if site ~= nil then
                pcall(ignition.expose, site, FLAME_K)
            end
            sim.sleep(tend_ticks)
        end
        self.vars[TENDED_VAR] = false
    end)
end

return ignition
