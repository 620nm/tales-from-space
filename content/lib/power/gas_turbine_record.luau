local gas_turbine = require("@lib/power/gas_turbine")
local stages = require("@lib/power/gas_turbine_stages")
local turbine_parts = require("@lib/power/turbine_parts")

-- The gas turbine's run record, kept in the rotor's one `RUN` var, and the
-- reads both the console's switch (lib/power/gas_turbine_run.luau) and the
-- sections' turns (lib/power/gas_turbine_turns.luau) make of a line: its
-- link, its parts' ratings and efficiencies, the intake's air.
local gas_turbine_record = {}

-- The switch, the wear, the pass clock and the works one section's turn
-- hands the next. `beat` is the tick of the rotor's last check.
export type RunRecord = {
    active: boolean,
    run: number,
    rpm: number,
    power_w: number,
    damage: number,
    intake: number,
    alarm_tick: number,
    epoch: number,
    beat: number,
    compressor_work: number,
    compressor_kpa: number,
    turbine_work: number,
}

gas_turbine_record.RUN = "lunatic/tfs:turbine_run"
gas_turbine_record.MESSAGE = "lunatic/tfs:lib.gas_turbine_run."

-- SSmachines fires every 2 s (code/controllers/subsystem/machines.dm:7).
gas_turbine_record.PASS_SECONDS = 2
-- The intake regulator starts at 0.5 (turbine.dm:293).
local INTAKE_DEFAULT = 0.5
-- `get_turbine_integrity`: damage against 500 (turbine.dm:623).
local INTEGRITY_RATING = 500
-- Pack-tuned: a run whose rotor has not checked in this many passes has
-- lost its turns (docs/POWER.md, The gas turbine).
local STALL_PASSES = 2

local FIELDS = {
    "run",
    "rpm",
    "power_w",
    "damage",
    "alarm_tick",
    "epoch",
    "beat",
    "compressor_work",
    "compressor_kpa",
    "turbine_work",
}

function gas_turbine_record.read(rotor: Handle): RunRecord
    local stored = rotor.vars[gas_turbine_record.RUN]
    if type(stored) ~= "table" then
        stored = {}
    end
    return {
        active = stored.active == true,
        run = tonumber(stored.run) or 0,
        rpm = tonumber(stored.rpm) or 0,
        power_w = tonumber(stored.power_w) or 0,
        damage = tonumber(stored.damage) or 0,
        intake = tonumber(stored.intake) or INTAKE_DEFAULT,
        alarm_tick = tonumber(stored.alarm_tick) or 0,
        epoch = tonumber(stored.epoch) or 0,
        beat = tonumber(stored.beat) or 0,
        compressor_work = tonumber(stored.compressor_work) or 0,
        compressor_kpa = tonumber(stored.compressor_kpa) or 0,
        turbine_work = tonumber(stored.turbine_work) or 0,
    }
end

function gas_turbine_record.save(rotor: Handle, record: RunRecord): ()
    local stored: { [string]: any } = { active = record.active, intake = record.intake }
    local fields = record :: any
    for _, field in ipairs(FIELDS) do
        stored[field] = fields[field]
    end
    rotor.vars[gas_turbine_record.RUN] = stored
end

-- An active run whose rotor stopped checking in: its turns are gone (a
-- transfer of the body that threw the switch cancels them; the engine's
-- docs/luau-api/runtime.md), so it neither turns nor holds the switch.
function gas_turbine_record.stalled(record: RunRecord): boolean
    local period = sim.ticks(gas_turbine_record.PASS_SECONDS)
    return record.active and sim.tick() - record.beat > STALL_PASSES * period
end

-- Whether the loop numbered `run` is still the one running.
function gas_turbine_record.current(rotor: Handle, run: number): boolean
    if not rotor.alive then
        return false
    end
    local record = gas_turbine_record.read(rotor)
    return record.active and record.run == run
end

-- `get_turbine_integrity`, percent (turbine.dm:620-623).
function gas_turbine_record.integrity(damage: number): number
    return math.max(stages.round_to(100 - damage / INTEGRITY_RATING * 100, 0.01), 0)
end

-- Whether the rotor's line is linked and still whole, read without writing;
-- `gas_turbine.connected` clears a stale flag once it is found broken.
function gas_turbine_record.linked(rotor: Handle): boolean
    return rotor.vars[gas_turbine.LINKED] == true and gas_turbine.inspect(rotor) == nil
end

local function part_of(section: Handle): PartSlotView?
    local slots = section.components
    return if slots ~= nil then slots[1] else nil
end

-- The parts' mean rated rpm and temperature over the three sockets
-- (`activate_parts`, turbine.dm:568-569); zero with no line to read.
function gas_turbine_record.ratings(rotor: Handle): (number, number)
    local compressor, outlet = gas_turbine.ends(rotor)
    if compressor == nil or outlet == nil then
        return 0, 0
    end
    local rpm, kelvin = 0, 0
    for _, section in ipairs({ compressor, rotor, outlet }) do
        local part = part_of(section)
        if part == nil then
            return 0, 0
        end
        rpm += turbine_parts.max_rpm(part.tier)
        kelvin += turbine_parts.max_temperature_k(part.tier)
    end
    return rpm / 3, kelvin / 3
end

function gas_turbine_record.efficiency(section: Handle?): number
    local part = if section ~= nil then part_of(section) else nil
    return if part ~= nil then part.efficiency else 0
end

function gas_turbine_record.air_at(tile: TileAddress?): MatterRead?
    return if tile ~= nil then sim.matter_read(tile.matter) else nil
end

-- The air behind the compressor (`compress_gases`, turbine.dm:319).
function gas_turbine_record.intake_air(compressor: Handle?): MatterRead?
    if compressor == nil then
        return nil
    end
    return gas_turbine_record.air_at(gas_turbine.along(compressor, -1))
end

-- Moves shut or turning sections into `state`; an open panel keeps its own.
function gas_turbine_record.dress(sections: { Handle? }, state: string): ()
    for _, section in ipairs(sections) do
        local now = if section ~= nil and section.alive then section.state else nil
        if now ~= state and (now == gas_turbine.CLOSED or now == gas_turbine.RUNNING) then
            sim.appearance.set_state({ entity = section :: Handle, state = state })
        end
    end
end

-- `deactivate_parts` (turbine.dm:575-586): off, still, and dressed shut.
-- The rotor's own change into `closed` takes its watts off, anchored where
-- it stands (lib/power/gas_turbine_run.luau `on_section_changed`).
function gas_turbine_record.halt(rotor: Handle, record: RunRecord): ()
    record.active = false
    record.rpm = 0
    record.power_w = 0
    gas_turbine_record.save(rotor, record)
    local compressor, outlet = gas_turbine.ends(rotor)
    gas_turbine_record.dress({ compressor, rotor, outlet }, gas_turbine.CLOSED)
end

return gas_turbine_record
