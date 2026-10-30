-- The gravity battery's operating cycle: spin up, hold the field, spin
-- down, and the status glyph on the south panel.
--
-- The machine's states are standby, startup, active and shutdown, each
-- steady one also wearing a glyph as `<state>_<status>`
-- (structures/power/grav_smes.luau). The bank's internal load and its
-- gravity source switch together: the load bills the store, and the
-- field is effective only while the store pays it.
local grav_smes_run = {}

export type Status = "charging" | "discharging" | "fault" | "unpowered"

-- What the status glyph reads from a store's report.
export type Report = {
    charging: string,
    fed: boolean,
    level: number,
    tripped: boolean,
}

local BODY = "grav_smes"
local STANDBY = "standby"
local STARTUP = "startup"
local ACTIVE = "active"
local SHUTDOWN = "shutdown"
local MESSAGE = "lunatic/tfs:lib.grav_smes_run."

grav_smes_run.STATUSES = { "charging", "discharging", "fault", "unpowered" }

-- tg's gravity generator draws BASE_MACHINE_ACTIVE_CONSUMPTION * 3
-- (gravitygenerator.dm:120); the base is BASE_MACHINE_IDLE_CONSUMPTION
-- (100 W) * 10 (__DEFINES/machines.dm:35-37), and a watt is 1
-- (__DEFINES/power.dm:14,18): 3000 W.
grav_smes_run.SELF_DRAW_W = 3000

-- Pack-tuned: the spin-up and spin-down each last as long as the
-- startup and shutdown animations (art tags 09_startup, 11_shutdown).
local RAMP_SECONDS = 0.8
-- A start needs enough charge to hold the field this long.
local START_RESERVE_SECONDS = 10

-- Every message key this module speaks, for the roster file to define.
function grav_smes_run.message_keys(): { string }
    return {
        MESSAGE .. "not_standby",
        MESSAGE .. "no_charge",
        MESSAGE .. "starting",
        MESSAGE .. "not_running",
        MESSAGE .. "stopping",
    }
end

local function tell(actor: Handle?, key: string): ()
    if actor ~= nil then
        sim.message.send({ recipient = actor, message = sim.msg(key, {}) })
    end
end

-- `standby_charging` -> `standby`.
local function base_of(state: string?): string?
    if state == nil then
        return nil
    end
    return string.match(state, "^[^_]+")
end

local function set_state(body: Handle, state: string): ()
    if body.state ~= state then
        sim.appearance.set_state({ entity = body, state = state })
    end
end

-- Charge going in, or a full bank on a live supply, reads charging; a
-- running bank spends its store (discharging); a network trip is a
-- fault; a bank with no supply and nothing to run is unpowered.
local function status_of(report: Report, running: boolean): Status
    if report.tripped then
        return "fault"
    elseif report.charging == "charging" then
        return "charging"
    elseif running then
        return if report.level > 0 then "discharging" else "unpowered"
    elseif report.fed then
        return "charging"
    end
    return "unpowered"
end

local function report_of(body: Handle): Report?
    local store = sim.flow.store(body)
    if store == nil then
        return nil
    end
    return { charging = store.charging, fed = store.fed, level = store.level, tripped = false }
end

-- The dress a steady `base` wears for its report (the store's own when
-- none is given), or nil with no store to read.
local function dressed(body: Handle, base: string, report: Report?): string?
    local seen = report or report_of(body)
    if seen == nil then
        return nil
    end
    return `{base}_{status_of(seen, base == ACTIVE)}`
end

-- The state a machine settling into `base` takes: dressed in its glyph
-- at once, since a state set this tick is not yet the one `body` reads.
function grav_smes_run.settled(body: Handle, base: string): string
    return dressed(body, base, nil) or base
end

-- Dresses a steady machine in the glyph its report asks for.
function grav_smes_run.show_status(body: Handle, report: Report?): ()
    local base = base_of(body.state)
    if base ~= STANDBY and base ~= ACTIVE then
        return
    end
    local state = dressed(body, if base == ACTIVE then ACTIVE else STANDBY, report)
    if state ~= nil then
        set_state(body, state)
    end
end

-- Load and field off, the shutdown animation, then standby.
local function spin_down(body: Handle): ()
    sim.flow.set_load({ subject = body, on = false })
    sim.gravity_source.set({ subject = body, on = false })
    set_state(body, SHUTDOWN)
    sim.spawn_task(body, function()
        sim.sleep(sim.ticks(RAMP_SECONDS))
        if body.alive and body.state == SHUTDOWN then
            set_state(body, grav_smes_run.settled(body, STANDBY))
        end
    end)
end

function grav_smes_run.start(body: Handle, actor: Handle?): ()
    if base_of(body.state) ~= STANDBY then
        tell(actor, MESSAGE .. "not_standby")
        return
    end
    local store = sim.flow.store(body)
    if store == nil or store.charge_j < grav_smes_run.SELF_DRAW_W * START_RESERVE_SECONDS then
        tell(actor, MESSAGE .. "no_charge")
        return
    end
    tell(actor, MESSAGE .. "starting")
    sim.flow.set_load({ subject = body, on = true })
    sim.gravity_source.set({ subject = body, on = true })
    set_state(body, STARTUP)
    sim.spawn_task(body, function()
        sim.sleep(sim.ticks(RAMP_SECONDS))
        if body.alive and body.state == STARTUP then
            set_state(body, grav_smes_run.settled(body, ACTIVE))
        end
    end)
end

function grav_smes_run.stop(body: Handle, actor: Handle?): ()
    local base = base_of(body.state)
    if base ~= ACTIVE and base ~= STARTUP then
        tell(actor, MESSAGE .. "not_running")
        return
    end
    tell(actor, MESSAGE .. "stopping")
    spin_down(body)
end

-- `interaction.act`: the panel's start and stop buttons.
function grav_smes_run.act(ev: InteractionActPayload): boolean | { replaced: boolean }
    if ev.action == "start" then
        grav_smes_run.start(ev.subject, ev.actor)
        return true
    elseif ev.action == "stop" then
        grav_smes_run.stop(ev.subject, ev.actor)
        return true
    end
    return { replaced = false }
end

-- `flow.store.done`: the glyph follows the store.
function grav_smes_run.on_store(ev: FlowStoreDonePayload): ()
    if ev.subject.prototype ~= BODY then
        return
    end
    grav_smes_run.show_status(ev.subject, {
        charging = ev.charging,
        fed = ev.fed,
        level = ev.level,
        tripped = ev.tripped,
    })
end

-- `flow.load.done`: a load the store cannot pay stops the field.
function grav_smes_run.on_load(ev: FlowLoadDonePayload): ()
    if ev.subject.prototype ~= BODY or ev.supplied then
        return
    end
    local base = base_of(ev.subject.state)
    if base == ACTIVE or base == STARTUP then
        spin_down(ev.subject)
    end
end

-- `entity.initialize.done`: a machine the map placed running switches its
-- load and field on, since the engine spawns sources off; a finished one
-- takes its glyph.
function grav_smes_run.on_initialize(ev: EntityInitializeDonePayload): ()
    local body = ev.entity
    if body.prototype ~= BODY then
        return
    end
    if base_of(body.state) == ACTIVE then
        sim.flow.set_load({ subject = body, on = true })
        sim.gravity_source.set({ subject = body, on = true })
    end
    grav_smes_run.show_status(body, nil)
end

return grav_smes_run
