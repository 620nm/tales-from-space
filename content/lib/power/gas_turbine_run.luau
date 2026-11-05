local blast = require("@lib/blast")
local gas_turbine = require("@lib/power/gas_turbine")
local stages = require("@lib/power/gas_turbine_stages")
local turbine_parts = require("@lib/power/turbine_parts")

-- The gas turbine running: tg's `core_rotor/process` (turbine.dm:625-685)
-- as a rotor-scoped task looping every machines tick, and the console's
-- switch and regulator (`ui_act`, turbine_computer.dm:85-119). The stage
-- arithmetic is lib/power/gas_turbine_stages.luau; a section that holds no
-- gas moves none, so the shaft stays still (docs/POWER.md, The gas turbine).
local gas_turbine_run = {}

export type Readout = {
    connected: boolean,
    active: boolean,
    rpm: number,
    power_w: number,
    integrity: number,
    max_rpm: number,
    max_temperature_k: number,
    intake_k: number,
    intake: number,
}

-- What the rotor keeps between passes, in its one `RUN` var.
type RunRecord = {
    active: boolean,
    run: number,
    rpm: number,
    power_w: number,
    damage: number,
    intake: number,
    alarm_tick: number,
}

gas_turbine_run.RUN = "lunatic/tfs:turbine_run"

local MESSAGE = "lunatic/tfs:lib.gas_turbine_run."

-- SSmachines fires every 2 s (code/controllers/subsystem/machines.dm:7).
local PASS_SECONDS = 2
-- code/__DEFINES/turbine_defines.dm:14-18.
local MAX_DAMAGE_PER_PASS = 10
local DAMAGE_HEALING = 2
local ALARM_START = 15
-- The damage curve: `round(log(90, max(dT, 1)), 0.5) * 0.5` (turbine.dm:636-637).
local DAMAGE_LOG_BASE = 90
local DAMAGE_ROUNDING = 0.5
local DAMAGE_SCALE = 0.5
-- An alarm sounds on a jump of this much in one pass (turbine.dm:642).
local ALARM_JUMP = 2
-- `get_turbine_integrity`: damage against 500 (turbine.dm:623).
local INTEGRITY_RATING = 500
-- The alarm's cooldown floor, seconds (turbine.dm:643).
local ALARM_MIN_SECONDS = 5
-- The intake regulator: 0.5 fresh (turbine.dm:293), 0.01..1 on the
-- console (turbine_computer.dm:118).
local INTAKE_DEFAULT = 0.5
local INTAKE_MIN = 0.01
local INTAKE_MAX = 1
-- The switch refuses a stop above this (turbine_computer.dm:94).
local STOP_MAX_RPM = 1000
-- Pack-tuned: how far the alarm and the failure are heard. tg sends the
-- alarm over the engineering channel (turbine.dm:661); this pack has no
-- machine voice on a channel yet.
local ALARM_RADIUS = 7

local REFUSALS = { "not_linked", "running", "not_running", "unpowered", "wrecked", "too_fast" }

-- Every message key, with its placeholders, for the roster file to define.
function gas_turbine_run.messages(): { { key: string, placeholders: { string } } }
    local rows: { { key: string, placeholders: { string } } } = {}
    for _, name in ipairs(REFUSALS) do
        table.insert(rows, { key = MESSAGE .. name, placeholders = {} })
    end
    table.insert(rows, { key = MESSAGE .. "failed", placeholders = {} })
    table.insert(rows, { key = MESSAGE .. "damage_alarm", placeholders = { "integrity" } })
    return rows
end

local function refuse(actor: Handle?, reason: string): (boolean, string?)
    local key = MESSAGE .. reason
    if actor ~= nil then
        sim.message.send({ recipient = actor, message = sim.msg(key, {}) })
    end
    return false, key
end

local function record_of(rotor: Handle): RunRecord
    local stored = rotor.vars[gas_turbine_run.RUN]
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
    }
end

local function save(rotor: Handle, record: RunRecord): ()
    rotor.vars[gas_turbine_run.RUN] = {
        active = record.active,
        run = record.run,
        rpm = record.rpm,
        power_w = record.power_w,
        damage = record.damage,
        intake = record.intake,
        alarm_tick = record.alarm_tick,
    }
end

-- `get_turbine_integrity`, percent (turbine.dm:620-623).
local function integrity_of(damage: number): number
    return math.max(stages.round_to(100 - damage / INTEGRITY_RATING * 100, 0.01), 0)
end

local function part_of(section: Handle): PartSlotView?
    local slots = section.components
    return if slots ~= nil then slots[1] else nil
end

-- The parts' mean rated rpm and temperature over the three sockets
-- (`activate_parts`, turbine.dm:568-569); zero with no line to read.
local function ratings(rotor: Handle): (number, number)
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

local function efficiency_of(section: Handle): number
    local part = part_of(section)
    return if part ~= nil then part.efficiency else 0
end

local function air_at(tile: TileAddress?): MatterRead?
    return if tile ~= nil then sim.matter_read(tile.matter) else nil
end

-- The air behind the compressor (`compress_gases`, turbine.dm:319).
local function intake_air(compressor: Handle?): MatterRead?
    return if compressor ~= nil then air_at(gas_turbine.along(compressor, -1)) else nil
end

-- Moves shut or turning sections into `state`; an open panel keeps its own.
local function dress(sections: { Handle? }, state: string): ()
    for _, section in ipairs(sections) do
        local now = if section ~= nil and section.alive then section.state else nil
        if now ~= state and (now == gas_turbine.CLOSED or now == gas_turbine.RUNNING) then
            sim.appearance.set_state({ entity = section :: Handle, state = state })
        end
    end
end

-- `deactivate_parts` (turbine.dm:575-586): off, still, and dressed shut.
local function halt(rotor: Handle, record: RunRecord): ()
    record.active = false
    record.rpm = 0
    record.power_w = 0
    save(rotor, record)
    sim.flow.set_output({ subject = rotor, watts = 0 })
    local compressor, outlet = gas_turbine.ends(rotor)
    dress({ compressor, rotor, outlet }, gas_turbine.CLOSED)
end

-- Writes the shaft's rpm and the grid's watts.
local function settle(rotor: Handle, record: RunRecord, rpm: number): ()
    local watts = stages.watts(rpm)
    if watts ~= record.power_w then
        sim.flow.set_output({ subject = rotor, watts = watts })
    end
    record.rpm = rpm
    record.power_w = watts
    save(rotor, record)
end

-- Whether the rotor's line is linked and still whole, read without writing;
-- `gas_turbine.connected` clears a stale flag once it is found broken.
local function linked(rotor: Handle): boolean
    return rotor.vars[gas_turbine.LINKED] == true and gas_turbine.inspect(rotor) == nil
end

-- Whether the loop numbered `run` is still the one running.
local function current(rotor: Handle, run: number): boolean
    if not rotor.alive then
        return false
    end
    local record = record_of(rotor)
    return record.active and record.run == run
end

-- Damage off the intake temperature, the alarm and the failure
-- (turbine.dm:634-662). Answers false when the rotor failed.
local function wear(rotor: Handle, record: RunRecord, intake_k: number, max_k: number): boolean
    local archived = record.damage
    local difference = intake_k - max_k
    local done = stages.round_to(math.log(math.max(difference, 1), DAMAGE_LOG_BASE), DAMAGE_ROUNDING)
    local damage = math.max(archived + done * DAMAGE_SCALE, 0)
    damage = math.min(archived + MAX_DAMAGE_PER_PASS, damage)
    if difference < 0 then
        damage = math.max(damage - DAMAGE_HEALING, 0)
    end
    record.damage = damage
    local now = sim.tick()
    if (damage - archived < ALARM_JUMP and damage <= ALARM_START) or now < record.alarm_tick then
        return true
    end
    -- DM's one-argument `round` is a floor (turbine.dm:643).
    local cooldown = math.max(math.floor(ALARM_START - done), ALARM_MIN_SECONDS)
    record.alarm_tick = now + sim.ticks(cooldown)
    local integrity = integrity_of(damage)
    if integrity > 0 then
        local said = string.format("%.2f", integrity)
        sim.message.broadcast({
            at = rotor.tile,
            radius = ALARM_RADIUS,
            message = sim.msg(MESSAGE .. "damage_alarm", { integrity = said }),
        })
        return true
    end
    -- tg's blast grows with the rpm (:646-659); this pack has one blast.
    halt(rotor, record)
    sim.message.broadcast({ at = rotor.tile, radius = ALARM_RADIUS, message = sim.msg(MESSAGE .. "failed", {}) })
    blast.apply(rotor.tile)
    blast.cast(rotor.tile)
    return false
end

-- The stage passes, one segment each so every pass reads what the last
-- one moved (turbine.dm:632, :666-668, :672-685). Answers the ticks spent.
local function expand(rotor: Handle, run: number, compressor: Handle, outlet: Handle, intake: number): number
    local spent = 0
    local function next_stages(): stages.Stages?
        sim.sleep(1)
        spent += 1
        if not (current(rotor, run) and compressor.alive and outlet.alive) then
            return nil
        end
        return stages.read(compressor, rotor, outlet)
    end
    local held = stages.read(compressor, rotor, outlet)
    local intake_tile = gas_turbine.along(compressor, -1)
    local inlet = air_at(intake_tile)
    if held == nil or intake_tile == nil or inlet == nil then
        return spent
    end
    local compressor_work = stages.transfer(intake_tile.matter, inlet, compressor, held.compressor, 0, intake)
    held = next_stages()
    if held == nil then
        return spent
    end
    local compressor_kpa = stages.floored_kpa(held.compressor)
    local rotor_work = stages.transfer(compressor, held.compressor, rotor, held.rotor, compressor_work, 1)
    held = next_stages()
    if held == nil then
        return spent
    end
    local turbine_work = stages.transfer(rotor, held.rotor, outlet, held.outlet, math.abs(rotor_work), 1)
    held = next_stages()
    if held == nil then
        return spent
    end
    local record = record_of(rotor)
    -- `expel_gases` (turbine.dm:363-379): only onto a tile that shares air;
    -- nothing ejected is no rpm and no power (:673-676).
    local exhaust_tile = gas_turbine.along(outlet, 1)
    local exhaust = air_at(exhaust_tile)
    local ejected = if exhaust ~= nil then stages.pump_moles(held.outlet, exhaust, held.outlet.pressure_kpa) else 0
    if exhaust_tile == nil or ejected <= 0 then
        settle(rotor, record, 0)
        return spent
    end
    sim.matter.transfer({ from = outlet, to = exhaust_tile.matter, amount = ejected, phases = { "gas" } })
    local work = stages.ejected_work(ejected, held.outlet, compressor_kpa, compressor_work, turbine_work)
    local max_rpm = ratings(rotor)
    local rpm =
        stages.rpm(work, efficiency_of(compressor), efficiency_of(rotor), efficiency_of(outlet), max_rpm)
    settle(rotor, record, rpm)
    return spent
end

-- One pass: step 0 (turbine.dm:626-628), the intake and its wear, then
-- the stages. Answers the ticks spent, or nil when the loop is over.
local function pass(rotor: Handle, run: number): number?
    if not current(rotor, run) then
        return nil
    end
    local record = record_of(rotor)
    local compressor, outlet = gas_turbine.ends(rotor)
    if compressor == nil or outlet == nil or not linked(rotor) or not sim.is_powered(rotor) then
        gas_turbine.connected(rotor)
        halt(rotor, record)
        return nil
    end
    local inlet = intake_air(compressor)
    local _, max_k = ratings(rotor)
    if not wear(rotor, record, if inlet ~= nil then inlet.temp_k else 0, max_k) then
        return nil
    end
    if stages.read(compressor, rotor, outlet) == nil then
        settle(rotor, record, 0)
        return 0
    end
    save(rotor, record)
    return expand(rotor, run, compressor, outlet, record.intake)
end

local function loop(rotor: Handle, run: number): ()
    local period = sim.ticks(PASS_SECONDS)
    local spent = 0
    while true do
        sim.sleep(math.max(period - spent, 1))
        local used = pass(rotor, run)
        if used == nil then
            return
        end
        spent = used
    end
end

-- The power switch on (turbine_computer.dm:89-99; `toggle_power`,
-- turbine.dm:593-617): the line linked and whole, the rotor fed and sound.
-- Answers whether it started, else the message key it told `actor`.
function gas_turbine_run.start(rotor: Handle, actor: Handle?): (boolean, string?)
    local record = record_of(rotor)
    if record.active then
        return refuse(actor, "running")
    end
    if not linked(rotor) then
        gas_turbine.connected(rotor)
        return refuse(actor, "not_linked")
    end
    if integrity_of(record.damage) <= 0 then
        return refuse(actor, "wrecked")
    end
    if not sim.is_powered(rotor) then
        return refuse(actor, "unpowered")
    end
    record.active = true
    record.run += 1
    record.rpm = 0
    record.power_w = 0
    save(rotor, record)
    sim.flow.set_output({ subject = rotor, watts = 0 })
    local compressor, outlet = gas_turbine.ends(rotor)
    dress({ compressor, rotor, outlet }, gas_turbine.RUNNING)
    local run = record.run
    sim.spawn_task(rotor, function()
        loop(rotor, run)
    end)
    return true, nil
end

-- The power switch off, refused above 1000 rpm (turbine_computer.dm:94).
function gas_turbine_run.stop(rotor: Handle, actor: Handle?): (boolean, string?)
    local record = record_of(rotor)
    if not record.active then
        return refuse(actor, "not_running")
    end
    if record.rpm > STOP_MAX_RPM then
        return refuse(actor, "too_fast")
    end
    halt(rotor, record)
    return true, nil
end

-- The regulator: the share of the intake's pressure the compressor draws
-- to (`regulate`, turbine_computer.dm:107-119). Raises on a non-finite share.
function gas_turbine_run.set_intake(rotor: Handle, fraction: number): ()
    if fraction ~= fraction or math.abs(fraction) == math.huge then
        error("gas_turbine_run.set_intake: fraction must be finite")
    end
    local record = record_of(rotor)
    record.intake = math.clamp(fraction, INTAKE_MIN, INTAKE_MAX)
    save(rotor, record)
end

-- What the console shows (`ui_data`, turbine_computer.dm:56-78). It only
-- reads: a stale link reads as not connected without clearing the flag.
function gas_turbine_run.readout(rotor: Handle): Readout
    local record = record_of(rotor)
    local max_rpm, max_k = ratings(rotor)
    local inlet = intake_air((gas_turbine.ends(rotor)))
    return {
        connected = linked(rotor),
        active = record.active,
        rpm = record.rpm,
        power_w = record.power_w,
        integrity = integrity_of(record.damage),
        max_rpm = max_rpm,
        max_temperature_k = max_k,
        intake_k = if inlet ~= nil then inlet.temp_k else 0,
        intake = record.intake,
    }
end

return gas_turbine_run
