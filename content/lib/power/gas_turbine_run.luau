local blast = require("@lib/blast")
local gas_turbine = require("@lib/power/gas_turbine")
local stages = require("@lib/power/gas_turbine_stages")
local turbine_parts = require("@lib/power/turbine_parts")

-- The gas turbine running: tg's `core_rotor/process` (turbine.dm:625-685)
-- split over one task per section, each anchored on its own tile and
-- taking its turn of every machines tick in flow order, and the console's
-- switch and regulator (`ui_act`, turbine_computer.dm:85-119). The stage
-- arithmetic is lib/power/gas_turbine_stages.luau (docs/POWER.md).
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

-- What the rotor keeps between passes, in its one `RUN` var: the switch, the
-- wear, and the works one section's turn hands the next.
type RunRecord = {
    active: boolean,
    run: number,
    rpm: number,
    power_w: number,
    damage: number,
    intake: number,
    alarm_tick: number,
    epoch: number,
    compressor_work: number,
    compressor_kpa: number,
    turbine_work: number,
}

gas_turbine_run.RUN = "lunatic/tfs:turbine_run"

local MESSAGE = "lunatic/tfs:lib.gas_turbine_run."

-- SSmachines fires every 2 s (code/controllers/subsystem/machines.dm:7).
local PASS_SECONDS = 2
-- Each section's tick within a pass: the check, then the gas in flow order,
-- one tick apart so each turn reads what the last one moved.
local CHECK_PHASE = 0
local COMPRESS_PHASE = 1
local ROTOR_PHASE = 2
local TURBINE_PHASE = 3
local EXPEL_PHASE = 4
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

type MessageRow = { key: string, placeholders: { string } }

local function row(name: string, placeholders: { string }): MessageRow
    return { key = MESSAGE .. name, placeholders = placeholders }
end

-- Every message key, with its placeholders, for the roster file to define.
function gas_turbine_run.messages(): { MessageRow }
    local rows: { MessageRow } = {}
    for _, name in ipairs(REFUSALS) do
        table.insert(rows, row(name, {}))
    end
    table.insert(rows, row("failed", {}))
    table.insert(rows, row("damage_alarm", { "integrity" }))
    return rows
end

-- A refusal's full message key; the caller decides who hears it.
local function refuse(reason: string): (boolean, string?)
    return false, MESSAGE .. reason
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
        epoch = tonumber(stored.epoch) or 0,
        compressor_work = tonumber(stored.compressor_work) or 0,
        compressor_kpa = tonumber(stored.compressor_kpa) or 0,
        turbine_work = tonumber(stored.turbine_work) or 0,
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
        epoch = record.epoch,
        compressor_work = record.compressor_work,
        compressor_kpa = record.compressor_kpa,
        turbine_work = record.turbine_work,
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

local function efficiency_of(section: Handle?): number
    local part = if section ~= nil then part_of(section) else nil
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

-- `deactivate_parts` (turbine.dm:575-586): off, still, and dressed shut. The
-- rotor's own task zeroes the grid's watts (`zero`), anchored where it stands.
local function halt(rotor: Handle, record: RunRecord): ()
    record.active = false
    record.rpm = 0
    record.power_w = 0
    save(rotor, record)
    local compressor, outlet = gas_turbine.ends(rotor)
    dress({ compressor, rotor, outlet }, gas_turbine.CLOSED)
end

local function zero(rotor: Handle): ()
    sim.flow.set_output({ subject = rotor, watts = 0 })
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

-- Sleeps to the next pass's `phase` tick after `epoch`, so the three
-- sections' tasks take their turns in flow order whatever order they wake.
local function sleep_to(epoch: number, phase: number): ()
    local period = sim.ticks(PASS_SECONDS)
    local now = sim.tick()
    local pass = math.max(math.floor((now - epoch - phase) / period) + 1, 1)
    sim.sleep(epoch + pass * period + phase - now)
end

-- Damage off the intake temperature, the alarm and the failure
-- (turbine.dm:634-662). Answers false when the rotor failed.
local function wear(rotor: Handle, record: RunRecord, intake_k: number, max_k: number): boolean
    local archived = record.damage
    local difference = intake_k - max_k
    local curve = math.log(math.max(difference, 1), DAMAGE_LOG_BASE)
    local done = stages.round_to(curve, DAMAGE_ROUNDING)
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
    zero(rotor)
    sim.message.broadcast({
        at = rotor.tile,
        radius = ALARM_RADIUS,
        message = sim.msg(MESSAGE .. "failed", {}),
    })
    blast.apply(rotor.tile)
    blast.cast(rotor.tile)
    return false
end

-- Step 0 (turbine.dm:626-628) and the wear off the intake's heat, before
-- the compressor draws (:632-634). Answers false once the loop is over.
local function check(rotor: Handle, record: RunRecord): boolean
    local compressor, outlet = gas_turbine.ends(rotor)
    if compressor == nil or outlet == nil or not linked(rotor) or not sim.is_powered(rotor) then
        gas_turbine.connected(rotor)
        halt(rotor, record)
        zero(rotor)
        return false
    end
    local inlet = intake_air(compressor)
    local _, max_k = ratings(rotor)
    if not wear(rotor, record, if inlet ~= nil then inlet.temp_k else 0, max_k) then
        return false
    end
    record.compressor_work = 0
    record.compressor_kpa = 0
    record.turbine_work = 0
    save(rotor, record)
    return true
end

-- The rotor's turns: the check, then compressor to rotor and rotor to outlet
-- (turbine.dm:666-668), each reading what the turn before it moved.
local function rotor_loop(rotor: Handle, run: number, epoch: number): ()
    while true do
        sleep_to(epoch, CHECK_PHASE)
        if not current(rotor, run) then
            break
        end
        if not check(rotor, record_of(rotor)) then
            return
        end
        sleep_to(epoch, ROTOR_PHASE)
        if not current(rotor, run) then
            break
        end
        local compressor, outlet = gas_turbine.ends(rotor)
        local held = if compressor ~= nil and outlet ~= nil
            then stages.read(compressor, rotor, outlet)
            else nil
        local rotor_work = 0
        if held ~= nil and compressor ~= nil then
            local record = record_of(rotor)
            record.compressor_kpa = stages.floored_kpa(held.compressor)
            local remove = record.compressor_work
            rotor_work = stages.transfer(compressor, held.compressor, rotor, held.rotor, remove, 1)
            save(rotor, record)
        end
        sleep_to(epoch, TURBINE_PHASE)
        if not current(rotor, run) then
            break
        end
        held = if compressor ~= nil and outlet ~= nil and compressor.alive and outlet.alive
            then stages.read(compressor, rotor, outlet)
            else nil
        if held ~= nil and outlet ~= nil then
            local record = record_of(rotor)
            local remove = math.abs(rotor_work)
            record.turbine_work = stages.transfer(rotor, held.rotor, outlet, held.outlet, remove, 1)
            save(rotor, record)
        end
    end
    -- Stopped from the switch: this run's last word is no watts.
    if rotor.alive and record_of(rotor).run == run then
        zero(rotor)
    end
end

-- The compressor's turn: the intake tile into the compressor
-- (`compress_gases`, turbine.dm:313-331).
local function compressor_loop(compressor: Handle, rotor: Handle, run: number, epoch: number): ()
    while true do
        sleep_to(epoch, COMPRESS_PHASE)
        if not (compressor.alive and current(rotor, run)) then
            return
        end
        local intake_tile = gas_turbine.along(compressor, -1)
        local inlet = air_at(intake_tile)
        local held = sim.matter_read(compressor)
        if intake_tile ~= nil and inlet ~= nil and held ~= nil then
            local record = record_of(rotor)
            record.compressor_work =
                stages.transfer(intake_tile.matter, inlet, compressor, held, 0, record.intake)
            save(rotor, record)
        end
    end
end

-- The outlet's turn: the exhaust onto the tile ahead (`expel_gases`,
-- turbine.dm:363-379), then the shaft's rpm and the grid's watts
-- (:672-685). Nothing ejected is no rpm and no power (:673-676).
local function outlet_loop(outlet: Handle, rotor: Handle, run: number, epoch: number): ()
    while true do
        sleep_to(epoch, EXPEL_PHASE)
        if not (outlet.alive and current(rotor, run)) then
            return
        end
        local record = record_of(rotor)
        local held = sim.matter_read(outlet)
        local exhaust_tile = gas_turbine.along(outlet, 1)
        local exhaust = air_at(exhaust_tile)
        local ejected = if held ~= nil and exhaust ~= nil
            then stages.pump_moles(held, exhaust, held.pressure_kpa)
            else 0
        local rpm = 0
        if held ~= nil and exhaust_tile ~= nil and ejected > 0 then
            sim.matter.transfer({
                from = outlet,
                to = exhaust_tile.matter,
                amount = ejected,
                phases = { "gas" },
            })
            local work = stages.ejected_work(
                ejected,
                held,
                record.compressor_kpa,
                record.compressor_work,
                record.turbine_work
            )
            local compressor = gas_turbine.ends(rotor)
            local max_rpm = ratings(rotor)
            local stator = efficiency_of(outlet)
            rpm = stages.rpm(work, efficiency_of(compressor), efficiency_of(rotor), stator, max_rpm)
        end
        record.rpm = rpm
        record.power_w = stages.watts(rpm)
        save(rotor, record)
        sim.flow.set_output({ subject = rotor, watts = record.power_w })
    end
end

-- `structure.changed` on every section: a section the switch set turning
-- takes its turns in the run, its task anchored on its own tile so each
-- stage moves only the gas beside it.
function gas_turbine_run.on_section_changed(ev: StructureChangedPayload): ()
    local section = ev.structure
    if ev.state ~= gas_turbine.RUNNING or ev.previous == ev.state or not section.alive then
        return
    end
    local rotor = gas_turbine.core_of(section)
    if rotor == nil then
        return
    end
    local record = record_of(rotor)
    if not record.active then
        return
    end
    local run, epoch = record.run, record.epoch
    local kind = section.base or section.prototype
    sim.spawn_task(section, function()
        if kind == gas_turbine.CORE then
            rotor_loop(rotor, run, epoch)
        elseif kind == gas_turbine.COMPRESSOR then
            compressor_loop(section, rotor, run, epoch)
        else
            outlet_loop(section, rotor, run, epoch)
        end
    end)
end

-- The power switch on (turbine_computer.dm:89-99; `toggle_power`,
-- turbine.dm:593-617): the line linked and whole, the rotor fed and sound.
-- Answers whether it started, else the refusal's message key; `actor` is
-- who threw the switch, and hears nothing from here.
function gas_turbine_run.start(rotor: Handle, _actor: Handle?): (boolean, string?)
    local record = record_of(rotor)
    if record.active then
        return refuse("running")
    end
    if not linked(rotor) then
        gas_turbine.connected(rotor)
        return refuse("not_linked")
    end
    if integrity_of(record.damage) <= 0 then
        return refuse("wrecked")
    end
    if not sim.is_powered(rotor) then
        return refuse("unpowered")
    end
    record.active = true
    record.run += 1
    record.epoch = sim.tick()
    record.rpm = 0
    record.power_w = 0
    save(rotor, record)
    local compressor, outlet = gas_turbine.ends(rotor)
    dress({ compressor, rotor, outlet }, gas_turbine.RUNNING)
    return true, nil
end

-- The power switch off, refused above 1000 rpm (turbine_computer.dm:94).
function gas_turbine_run.stop(rotor: Handle, _actor: Handle?): (boolean, string?)
    local record = record_of(rotor)
    if not record.active then
        return refuse("not_running")
    end
    if record.rpm > STOP_MAX_RPM then
        return refuse("too_fast")
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
