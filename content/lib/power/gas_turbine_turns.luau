local blast = require("@lib/blast")
local gas_turbine = require("@lib/power/gas_turbine")
local record_lib = require("@lib/power/gas_turbine_record")
local stages = require("@lib/power/gas_turbine_stages")

-- The gas turbine's pass, tg's `core_rotor/process` (turbine.dm:625-685),
-- split over one task per section. Each is spawned from that section's own
-- change into `running`, so it is anchored on its tile and moves only the
-- gas beside it; each takes its turn a tick apart in flow order, so every
-- turn reads what the last one moved. The run record is
-- lib/power/gas_turbine_record.luau; the arithmetic, gas_turbine_stages.
local gas_turbine_turns = {}

type RunRecord = record_lib.RunRecord

local read, save, halt = record_lib.read, record_lib.save, record_lib.halt
local current, ratings = record_lib.current, record_lib.ratings
local efficiency, air_at = record_lib.efficiency, record_lib.air_at

-- Each section's tick within a pass: the rotor's check, then the gas.
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
-- The alarm's cooldown floor, seconds (turbine.dm:643).
local ALARM_MIN_SECONDS = 5
-- Pack-tuned: how far the alarm and the failure are heard. tg sends the
-- alarm over the engineering channel (turbine.dm:661); this pack has no
-- machine voice on a channel yet.
local ALARM_RADIUS = 7

-- Takes the rotor's watts off the grid; a source keeps its last setpoint.
local function zero(rotor: Handle): ()
    sim.flow.set_output({ subject = rotor, watts = 0 })
end
gas_turbine_turns.zero = zero

type Placeholders = { [string]: UnsafeMarkup | boolean | number | string }

local function shout(rotor: Handle, key: string, values: Placeholders): ()
    sim.message.broadcast({
        at = rotor.tile,
        radius = ALARM_RADIUS,
        message = sim.msg(record_lib.MESSAGE .. key, values),
    })
end

-- Sleeps to the next pass's `phase` tick after `epoch`, so the three
-- sections' tasks take their turns in flow order whatever order they wake.
local function sleep_to(epoch: number, phase: number): ()
    local period = sim.ticks(record_lib.PASS_SECONDS)
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
    local integrity = record_lib.integrity(damage)
    if integrity > 0 then
        shout(rotor, "damage_alarm", { integrity = string.format("%.2f", integrity) })
        return true
    end
    -- tg's blast grows with the rpm (:646-659); this pack has one blast.
    halt(rotor, record)
    zero(rotor)
    shout(rotor, "failed", {})
    blast.apply(rotor.tile)
    blast.cast(rotor.tile)
    return false
end

-- Step 0 (turbine.dm:626-628) and the wear off the intake's heat, before
-- the compressor draws (:632-634); stamps the beat. False ends the loop.
local function check(rotor: Handle, record: RunRecord): boolean
    local compressor, outlet = gas_turbine.ends(rotor)
    local whole = compressor ~= nil and outlet ~= nil and record_lib.linked(rotor)
    if not whole or not sim.is_powered(rotor) then
        gas_turbine.connected(rotor)
        halt(rotor, record)
        zero(rotor)
        return false
    end
    local inlet = record_lib.intake_air(compressor)
    local _, max_k = ratings(rotor)
    if not wear(rotor, record, if inlet ~= nil then inlet.temp_k else 0, max_k) then
        return false
    end
    record.beat = sim.tick()
    record.compressor_work = 0
    record.compressor_kpa = 0
    record.turbine_work = 0
    save(rotor, record)
    return true
end

-- The rotor's turns: the check, then compressor to rotor and rotor to outlet
-- (turbine.dm:666-668). A run the switch ended takes its watts off here.
local function rotor_loop(rotor: Handle, run: number, epoch: number): ()
    while true do
        sleep_to(epoch, CHECK_PHASE)
        if not current(rotor, run) then
            break
        end
        if not check(rotor, read(rotor)) then
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
            local record = read(rotor)
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
            local record = read(rotor)
            local remove = math.abs(rotor_work)
            record.turbine_work = stages.transfer(rotor, held.rotor, outlet, held.outlet, remove, 1)
            save(rotor, record)
        end
    end
    if rotor.alive and read(rotor).run == run then
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
            local record = read(rotor)
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
        local record = read(rotor)
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
            local stator = efficiency(outlet)
            rpm = stages.rpm(work, efficiency(compressor), efficiency(rotor), stator, max_rpm)
        end
        record.rpm = rpm
        record.power_w = stages.watts(rpm)
        save(rotor, record)
        sim.flow.set_output({ subject = rotor, watts = record.power_w })
    end
end

-- Spawns `section`'s task for the rotor's run numbered `run`, its passes
-- counted from `epoch`.
function gas_turbine_turns.spawn(section: Handle, rotor: Handle, run: number, epoch: number): ()
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

return gas_turbine_turns
