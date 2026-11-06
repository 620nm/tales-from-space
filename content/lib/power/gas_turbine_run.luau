local gas_turbine = require("@lib/power/gas_turbine")
local record_lib = require("@lib/power/gas_turbine_record")
local turns = require("@lib/power/gas_turbine_turns")

-- The gas turbine's console switch and regulator (`ui_act`,
-- turbine_computer.dm:85-119; `toggle_power`, turbine.dm:593-617) and the
-- handler that sets a turning section to its turns of the run
-- (lib/power/gas_turbine_turns.luau). The record is
-- lib/power/gas_turbine_record.luau (docs/POWER.md, The gas turbine).
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

gas_turbine_run.RUN = record_lib.RUN

local MESSAGE = record_lib.MESSAGE

-- The console's regulator range (turbine_computer.dm:118).
local INTAKE_MIN = 0.01
local INTAKE_MAX = 1
-- The switch refuses a stop above this (turbine_computer.dm:94).
local STOP_MAX_RPM = 1000
-- Pack-tuned: how far a mapped rotor's refused start is heard, the alarm's
-- reach (lib/power/gas_turbine_turns.luau).
local REFUSAL_RADIUS = 7

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

-- Whether the run is turning: active, and its rotor still checking in.
local function turning(record: record_lib.RunRecord): boolean
    return record.active and not record_lib.stalled(record)
end

-- `structure.changed` on every section, anchored on its own tile: a section
-- set turning takes its turns in the run; a rotor shut takes its watts off
-- at once, not at its lease's end;
-- a turning section the switch shut to restart a stall turns again.
function gas_turbine_run.on_section_changed(ev: StructureChangedPayload): ()
    local section = ev.structure
    if ev.previous == ev.state or not section.alive then
        return
    end
    local rotor = gas_turbine.core_of(section)
    if rotor == nil then
        return
    end
    local record = record_lib.read(rotor)
    if ev.state == gas_turbine.CLOSED then
        if (section.base or section.prototype) == gas_turbine.CORE then
            turns.zero(rotor)
        end
        if ev.previous == gas_turbine.RUNNING and turning(record) then
            sim.appearance.set_state({ entity = section, state = gas_turbine.RUNNING })
        end
    elseif ev.state == gas_turbine.RUNNING and record.active then
        turns.spawn(section, rotor, record.run, record.epoch)
    end
end

-- A refused start; a stalled run it refuses is halted, its sections shut.
-- Its watts are already off: the turns that renewed their lease are gone.
local function refuse_start(
    rotor: Handle,
    record: record_lib.RunRecord,
    reason: string
): (boolean, string?)
    if record.active then
        record_lib.halt(rotor, record)
    end
    return refuse(reason)
end

-- The power switch on: the line linked and whole, the rotor fed and sound.
-- A stalled run counts as stopped, so the switch restarts it. Answers
-- whether it started, else the refusal's key; `actor` hears nothing here.
function gas_turbine_run.start(rotor: Handle, _actor: Handle?): (boolean, string?)
    local record = record_lib.read(rotor)
    if turning(record) then
        return refuse("running")
    end
    if not record_lib.linked(rotor) then
        gas_turbine.connected(rotor)
        return refuse_start(rotor, record, "not_linked")
    end
    if record_lib.integrity(record.damage) <= 0 then
        return refuse_start(rotor, record, "wrecked")
    end
    if not sim.is_powered(rotor) then
        return refuse_start(rotor, record, "unpowered")
    end
    local compressor, outlet = gas_turbine.ends(rotor)
    record.active = true
    record.run += 1
    record.epoch = sim.tick()
    record.beat = record.epoch
    record.rpm = 0
    record.power_w = 0
    record_lib.save(rotor, record)
    -- One state write per section, the last of an occurrence being the one
    -- kept: a shut section turns; a stalled one still wearing `running` is
    -- shut, and its own change sets it turning afresh (`on_section_changed`).
    for _, section in ipairs({ compressor, rotor, outlet }) do
        local now = if section ~= nil and section.alive then section.state else nil
        if now == gas_turbine.CLOSED then
            sim.appearance.set_state({ entity = section :: Handle, state = gas_turbine.RUNNING })
        elseif now == gas_turbine.RUNNING then
            sim.appearance.set_state({ entity = section :: Handle, state = gas_turbine.CLOSED })
        end
    end
    return true, nil
end

-- `entity.initialize.done` on every section, after `gas_turbine`'s own
-- link: a rotor mapped running (`STARTS_RUNNING`) starts its first run off
-- its own stand-up, once its line links. A map's sections all stand before
-- any initializes (the engine's docs/luau-api/lifecycle.md), so the rotor's
-- own link sees the whole line. A rotor that has run once never restarts
-- off the knob, so a later rebuild leaves the switch alone; a refused start
-- is said to the room round the rotor, which stays shut. The start runs in
-- a task the rotor's own initializer spawns: initialization may not dress
-- the line, and a task keeps its spawner's anchor, the rotor's tile, whose
-- 3x3 reaches both ends.
local function mapped_start(rotor: Handle): ()
    if not rotor.alive or rotor.vars[gas_turbine.STARTS_RUNNING] ~= true then
        return
    end
    local record = record_lib.read(rotor)
    if record.active or record.run > 0 or not record_lib.linked(rotor) then
        return
    end
    local started, refusal = gas_turbine_run.start(rotor, nil)
    if not started and refusal ~= nil then
        sim.message.broadcast({
            at = rotor.tile,
            radius = REFUSAL_RADIUS,
            message = sim.msg(refusal, {}),
        })
    end
end

function gas_turbine_run.on_section_initialized(ev: EntityInitializeDonePayload): ()
    local rotor = ev.entity
    if not rotor.alive or (rotor.base or rotor.prototype) ~= gas_turbine.CORE then
        return
    end
    if rotor.vars[gas_turbine.STARTS_RUNNING] ~= true then
        return
    end
    local record = record_lib.read(rotor)
    if record.active or record.run > 0 or not record_lib.linked(rotor) then
        return
    end
    sim.spawn_task(rotor, function()
        mapped_start(rotor)
    end)
end

-- The power switch off, refused above 1000 rpm (turbine_computer.dm:94);
-- a stalled run stops at any speed. The rotor shut takes its watts off.
function gas_turbine_run.stop(rotor: Handle, _actor: Handle?): (boolean, string?)
    local record = record_lib.read(rotor)
    if not record.active then
        return refuse("not_running")
    end
    if record.rpm > STOP_MAX_RPM and not record_lib.stalled(record) then
        return refuse("too_fast")
    end
    record_lib.halt(rotor, record)
    return true, nil
end

-- The regulator: the share of the intake's pressure the compressor draws
-- to (`regulate`, turbine_computer.dm:107-119). Raises on a non-finite share.
function gas_turbine_run.set_intake(rotor: Handle, fraction: number): ()
    if fraction ~= fraction or math.abs(fraction) == math.huge then
        error("gas_turbine_run.set_intake: fraction must be finite")
    end
    local record = record_lib.read(rotor)
    record.intake = math.clamp(fraction, INTAKE_MIN, INTAKE_MAX)
    record_lib.save(rotor, record)
end

-- What the console shows (`ui_data`, turbine_computer.dm:56-78). It only
-- reads: a stale link reads as not connected without clearing the flag,
-- and a stalled run as inactive.
function gas_turbine_run.readout(rotor: Handle): Readout
    local record = record_lib.read(rotor)
    local max_rpm, max_k = record_lib.ratings(rotor)
    local inlet = record_lib.intake_air((gas_turbine.ends(rotor)))
    return {
        connected = record_lib.linked(rotor),
        active = turning(record),
        rpm = record.rpm,
        power_w = record.power_w,
        integrity = record_lib.integrity(record.damage),
        max_rpm = max_rpm,
        max_temperature_k = max_k,
        intake_k = if inlet ~= nil then inlet.temp_k else 0,
        intake = record.intake,
    }
end

return gas_turbine_run
