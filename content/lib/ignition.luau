-- Ignition: what lights a tile. Every source calls one verb on the tile
-- and the tile decides at that instant; a spark that finds nothing
-- leaves nothing (tg LINDA_fire.dm:23-58 `hotspot_expose`).
--
-- A spark sets the cell column `alight` to 1; every burn rule in FIRES
-- requires it. One task tends each latched cell: it spreads to the
-- cardinals once the cell has burned and clears the column when the cell
-- cannot burn, or when `QUIET_SPREADS` pass with no fire at all (a spark
-- that lit nothing is gone; a fire paused over its ceiling is not). The
-- scratch table below is Lua heap, not world state: a stale entry ages
-- out (the engine's docs/scripting/execution-model.md §1.4).
local ignition = {}

-- tg __DEFINES/atmospherics/atmos_core.dm:130 (fire needs 373.15 K).
local IGNITE_K = 373.15
-- tg effects_sparks.dm:94 (a spark exposes at 1000 K).
local SPARK_K = 1000
-- tg items.dm:958 (`open_flame(700)` for held and worn flames).
local FLAME_K = 700
-- tg LINDA_fire.dm:32 (no fire under half a mole of oxygen).
local MIN_O2_MOL = 0.5
-- The burn rules' `requires` and `column_below` (reactions/*_fire.luau).
local MIN_FUEL_MOL = 0.01
-- A plant coat thinner than this carries no flame (reactions/grass_fire.luau).
local MIN_PLANT_MOL = 0.1
local RESIN_FLOOR = 0.1

-- A substance in one phase the latch can light: present when it holds
-- more than nothing and at least `min_mol`.
type Fuel = { id: string, phase: "gas" | "liquid" | "solid", min_mol: number }

-- Liquids burn as vapor over their pool; plants burn where they stand.
-- Acetone and naphtha are unmodeled.
local FUELS: { Fuel } = {
    { id = "ethanol", phase = "gas", min_mol = MIN_FUEL_MOL },
    { id = "ethanol", phase = "liquid", min_mol = 0 },
    { id = "methane", phase = "gas", min_mol = MIN_FUEL_MOL },
    { id = "methane", phase = "liquid", min_mol = 0 },
    { id = "ethane", phase = "gas", min_mol = MIN_FUEL_MOL },
    { id = "ethane", phase = "liquid", min_mol = 0 },
    { id = "hcn", phase = "gas", min_mol = MIN_FUEL_MOL },
    { id = "hcn", phase = "liquid", min_mol = 0 },
    { id = "grass", phase = "solid", min_mol = MIN_PLANT_MOL },
    { id = "moss", phase = "solid", min_mol = MIN_PLANT_MOL },
}
-- What the latch lights against liquid oxygen with no air at all: the
-- `requires` of reactions/organics/lox_detonation.luau.
local MIN_LOX_MOL = MIN_FUEL_MOL
local LOX_FUELS: { Fuel } = {
    { id = "methane", phase = "liquid", min_mol = MIN_FUEL_MOL },
}
-- Rules whose firing lights the neighbors; other reactions also raise
-- `matter.ignition.done` (the engine's docs/reactions/fire.md).
local FIRES = {
    ["lunatic/reaction:ethanol_fire"] = true,
    ["lunatic/reaction:grass_fire"] = true,
    ["lunatic/reaction:moss_fire"] = true,
    ["lunatic/reaction:plasma_fire"] = true,
    ["lunatic/reaction:plasma_fire_supersaturated"] = true,
    ["lunatic/reaction:methane_fire"] = true,
    ["lunatic/reaction:ethane_fire"] = true,
    ["lunatic/reaction:hcn_fire"] = true,
    ["lunatic/reaction:lox_detonation"] = true,
}
-- Rules whose onset is a blast as well as a fire (content/main.luau).
local DETONATIONS = {
    ["lunatic/reaction:lox_detonation"] = true,
}
-- Pack feel; tg spreads and tends once per process.
local SPREAD_SECONDS = 2
local TEND_SECONDS = 1
-- A tending entry older than this many spreads is stale.
local STALE_SPREADS = 3
-- A latched cell that has not lit within this many spreads loses the latch.
local QUIET_SPREADS = 3
-- A tool's tending stamp older than this many tends died with its task.
local STALE_TENDS = 3
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
ignition.MIN_FUEL_MOL = MIN_FUEL_MOL
ignition.RESIN_FLOOR = RESIN_FLOOR
ignition.FUELS = FUELS
ignition.SPREAD_SECONDS = SPREAD_SECONDS
ignition.TEND_SECONDS = TEND_SECONDS

type Tending = {
    at: TileAddress,
    key: string,
    -- The tick of the task's last visit.
    visited: number,
    -- Whether the cell has burned since it latched.
    lit: boolean,
    -- The tick the row began.
    latched: number,
    -- Whether the task began in this cell's own ignition edge. A task
    -- carries its spawner's reach, and only that anchor reaches every
    -- neighbor a spread may latch.
    anchored: boolean,
}

-- Cells whose tending task is running, by "x:y:z" of the plane-absolute
-- tile; planes share those, so a key holds a row per plane.
local tending: { [string]: { Tending } } = {}

local CARDINALS = {
    { dx = 1, dy = 0 },
    { dx = -1, dy = 0 },
    { dx = 0, dy = 1 },
    { dx = 0, dy = -1 },
}

local function holds_any(reading: MatterRead, fuels: { Fuel }): boolean
    for _, fuel in fuels do
        local held = reading.contents[fuel.id]
        local moles: number? = nil
        if held == nil then
            moles = nil
        elseif fuel.phase == "gas" then
            moles = held.gas
        elseif fuel.phase == "liquid" then
            moles = held.liquid
        else
            moles = held.solid
        end
        if moles ~= nil and moles > 0 and moles >= fuel.min_mol then
            return true
        end
    end
    return false
end

-- Air with a fuel in it, or liquid oxygen with a liquid fuel.
local function burnable(reading: MatterRead): boolean
    if (reading.columns.atmos_resin or 0) >= RESIN_FLOOR then
        return false
    end
    local oxygen = reading.contents.o2
    if oxygen == nil then
        return false
    end
    if (oxygen.gas or 0) >= MIN_O2_MOL and holds_any(reading, FUELS) then
        return true
    end
    return (oxygen.liquid or 0) >= MIN_LOX_MOL and holds_any(reading, LOX_FUELS)
end

-- Nil past the map's edge or for a stale address.
function ignition.tile_beside(center: TileAddress, dx: number, dy: number): TileAddress?
    local ok, at = pcall(sim.map_tile, center, center.x + dx, center.y + dy, center.z)
    return if ok then at else nil
end

local function cell_key(at: TileAddress): string
    return string.format("%d:%d:%d", at.absolute_x, at.absolute_y, at.z)
end

local function tending_row(at: TileAddress): Tending?
    for _, row in tending[cell_key(at)] or {} do
        if row.at == at then
            return row
        end
    end
    return nil
end

local function stop_tending(row: Tending): ()
    local rows = tending[row.key]
    local index = if rows ~= nil then table.find(rows, row) else nil
    if rows == nil or index == nil then
        return
    end
    table.remove(rows, index)
    if #rows == 0 then
        tending[row.key] = nil
    end
end

local function spread(at: TileAddress): ()
    for _, step in CARDINALS do
        local beside = ignition.tile_beside(at, step.dx, step.dy)
        if beside ~= nil then
            ignition.expose(beside, FLAME_K)
        end
    end
end

local function clear_latch(at: TileAddress, reading: MatterRead): ()
    if (reading.columns[LATCH_COLUMN] or 0) >= LATCH_ON then
        sim.matter.set_column({ owner = at.matter, column = LATCH_COLUMN, value = 0 })
    end
end

-- The cell's tending row, its task started unless a live one holds it.
-- A later task on the same row key ends an older, delayed one, and an
-- `anchored` call replaces a row a tool or a neighbor began.
local function ensure_tending(at: TileAddress, anchored: boolean): Tending
    local spread_ticks = sim.ticks(SPREAD_SECONDS)
    local held = tending_row(at)
    local latched = sim.tick()
    if held ~= nil then
        local live = sim.tick() - held.visited <= spread_ticks * STALE_SPREADS
        if live and (held.anchored or not anchored) then
            return held
        end
        if live then
            latched = held.latched
        end
        stop_tending(held)
    end
    local key = cell_key(at)
    local row: Tending = {
        at = at,
        key = key,
        visited = sim.tick(),
        lit = false,
        latched = latched,
        anchored = anchored,
    }
    tending[key] = tending[key] or {}
    table.insert(tending[key], row)
    sim.spawn_task("round", function()
        while true do
            sim.sleep(spread_ticks)
            local rows = tending[key]
            if rows == nil or table.find(rows, row) == nil then
                return
            end
            local ok, reading = pcall(function(): MatterRead?
                return sim.matter_read(at.matter)
            end)
            if not ok or reading == nil then
                stop_tending(row)
                return
            end
            local quiet = not row.lit and sim.tick() - row.latched >= spread_ticks * QUIET_SPREADS
            if quiet or not burnable(reading) then
                clear_latch(at, reading)
                stop_tending(row)
                return
            end
            row.visited = sim.tick()
            if row.lit then
                spread(at)
            end
        end
    end)
    return row
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
    if (reading.columns[LATCH_COLUMN] or 0) < LATCH_ON then
        sim.matter.set_column({ owner = at.matter, column = LATCH_COLUMN, value = 1 })
    end
    ensure_tending(at, false)
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

-- `matter.ignition.done`: a fire keeps its cell tended and spreads at once.
-- A ceiling flap re-fires the edge; the row absorbs it.
function ignition.on_ignited(ev: MatterIgnitionDonePayload): ()
    if not FIRES[ev.rule] then
        return
    end
    local row = ensure_tending(ev.at, true)
    if not row.lit then
        row.lit = true
        spread(ev.at)
    end
end

-- Whether a `matter.ignition.done` rule is a blast as well as a fire.
-- The cell's first firing names its biggest-energy rule, so a cell that
-- was already burning raises no edge (the engine's docs/reactions/fire.md).
function ignition.detonates(rule: string): boolean
    return DETONATIONS[rule] == true
end

-- A lit item tends the tile it is at once a second while it burns. Call
-- beside each `sim.set_flame(self, true)`; the task ends with the flame.
function ignition.tend_flame(self: Handle): ()
    local tend_ticks = sim.ticks(TEND_SECONDS)
    local stamp = self.vars[TENDED_VAR]
    if type(stamp) == "number" and sim.tick() - stamp <= tend_ticks * STALE_TENDS then
        return
    end
    self.vars[TENDED_VAR] = sim.tick()
    sim.spawn_task(self, function()
        sim.sleep(tend_ticks)
        while self.alive and self.state == LIT_STATE do
            local site = self.site
            if site ~= nil then
                ignition.expose(site, FLAME_K)
            end
            self.vars[TENDED_VAR] = sim.tick()
            sim.sleep(tend_ticks)
        end
        if self.alive then
            self.vars[TENDED_VAR] = nil
        end
    end)
end

return ignition
