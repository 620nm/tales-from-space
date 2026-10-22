local blood_identity = require("@lib/blood_identity")
local vessel = require("@lib/vessel")

export type Mode = "inject" | "draw"
export type FlowConnection = {
    drip: Handle,
    patient: Handle,
    vessel: Handle,
    generation: number,
    current: () -> boolean,
    disconnect: () -> (),
    mode: () -> Mode,
    rate: () -> number,
    set_rate: (number) -> (),
}

type FlowContext = { full_notified: boolean, low_blood_notified: boolean }
type CompletionNote = { connection: FlowConnection, context: FlowContext, mode: Mode }

local flow = {}
local ISSUER = "iv_drip"

-- Tg runs machines every two seconds and caps IV flow at 5 u/s.
-- One tg unit is 0.025 mol (code/controllers/subsystem/machines.dm:7,149;
-- code/game/machinery/iv_drip.dm:5-8; docs/CHEMISTRY.md §4).
local MOL_PER_UNIT = 0.025
local MAX_RATE_UNITS_PER_SECOND = 5
local STROKE_SECONDS = 2.0

-- Match the vessel gesture's 1 mL full cutoff (content/lib/vessel.luau:58-60).
local FULL_HEADSPACE_L = 0.001

-- Tg's BAD threshold is 40% of normal after a 60% loss
-- (code/__DEFINES/mobs.dm:20-24; code/modules/mob/living/blood.dm:373-391).
local DRAW_FLOOR_FRACTION = 0.40

-- Tg's SAFE fraction is 476/560, and its drip beeps with prob(5) below it
-- (code/__DEFINES/mobs.dm:16-25; code/game/machinery/iv_drip.dm:262-265).
local SAFE_BLOOD_FRACTION = 476 / 560
local BEEP_CHANCE = 5 / 100
local FULL_MESSAGE = "lunatic/tfs:iv_drip.full"
local LOW_BLOOD_MESSAGE = "lunatic/tfs:iv_drip.low_blood"
local BEEPS_MESSAGE = "lunatic/tfs:iv_drip.beeps"

-- Tg uses sound/machines/beep/twobeep_high.ogg
-- (code/game/machinery/iv_drip.dm:265).
local BEEPS_SOUND = "lunatic/tfs:sound/twobeep_high"
-- Match the pack's nearby broadcast pattern as a local range judgment;
-- it does not claim tg hearing fidelity (content/lib/controller.luau:186-190).
local ROOM_MESSAGE_RADIUS = 5
local INJECT_PHASES: { "solid" | "liquid" | "gas" } = { "liquid", "solid" }
local DRAW_PHASES: { "solid" | "liquid" | "gas" } = { "liquid" }
-- Transfer receipts have no endpoints; all stands share the issuer FIFO.
-- Keep notes across disconnects so issued strokes still settle in order
-- (the engine's `docs/luau-api/matter-commands.md`).
local pending: { CompletionNote } = {}

local function placed(entity: Handle): boolean
    local ok, tile = pcall(function()
        return entity.tile
    end)
    return ok and tile ~= nil
end

local function disconnect_if_current(connection: FlowConnection): ()
    if connection.current() then
        connection.disconnect()
    end
end

local function notify_patient(connection: FlowConnection, key: string): ()
    if not connection.current() then
        return
    end
    local mind = connection.patient.mind
    if mind ~= nil then
        sim.message.notify({ audience = mind, message = sim.msg(key, {}) })
    end
end

local function notify_room(connection: FlowConnection, key: string): ()
    if not connection.current() then
        return
    end
    sim.message.broadcast({
        at = connection.drip.tile,
        radius = ROOM_MESSAGE_RADIUS,
        message = sim.msg(key, {}),
    })
end

-- Handle.tile is an entity's own Position and errors when it has none
-- (the engine's `crates/lunatic-server/src/script/handle_methods/obj_methods.rs:add_obj_place_fields`).
local function live_body(connection: FlowConnection): { [any]: any }?
    if not connection.current() then
        return nil
    end
    if not connection.drip.alive or not connection.patient.alive or not connection.vessel.alive then
        disconnect_if_current(connection)
        return nil
    end
    if not placed(connection.drip) or not placed(connection.patient) then
        disconnect_if_current(connection)
        return nil
    end
    local body = sim.body(connection.patient)
    if body == nil then
        disconnect_if_current(connection)
        return nil
    end
    local docked = connection.drip:docked()
    if docked == nil or docked ~= connection.vessel then
        disconnect_if_current(connection)
        return nil
    end
    return body
end

local function warn_full(connection: FlowConnection, context: FlowContext): ()
    if not connection.current() then
        return
    end
    if connection.rate() ~= 0 then
        connection.set_rate(0)
    end
    if not context.full_notified then
        context.full_notified = true
        notify_room(connection, FULL_MESSAGE)
        notify_patient(connection, FULL_MESSAGE)
    end
end

local function beep(connection: FlowConnection): ()
    if not connection.current() then
        return
    end
    notify_room(connection, BEEPS_MESSAGE)
    notify_patient(connection, BEEPS_MESSAGE)
    sim.sound.play({ asset = BEEPS_SOUND, at = connection.drip.tile })
end

local function stroke(
    connection: FlowConnection,
    context: FlowContext,
    body: { [any]: any },
    mode: Mode,
    rate: number
): ()
    local amount = rate * STROKE_SECONDS * MOL_PER_UNIT
    local donor: number? = nil
    local receiver: number? = nil
    local phases: { "solid" | "liquid" | "gas" }
    local from: Handle
    local to: Handle

    if mode == "inject" then
        phases = INJECT_PHASES
        local available = vessel.moles(connection.vessel)
        if available == nil then
            disconnect_if_current(connection)
            return
        end
        if available <= 0 then
            return
        end
        donor = blood_identity.type_of(connection.vessel)
        receiver = blood_identity.type_of(connection.patient)
        from = connection.vessel
        to = connection.patient
    else
        phases = DRAW_PHASES
        local blood, normal = body.blood, body.blood_normal
        if
            type(blood) ~= "number"
            or type(normal) ~= "number"
            or blood ~= blood
            or normal ~= normal
            or normal <= 0
        then
            return
        end

        if blood < normal * SAFE_BLOOD_FRACTION then
            if sim.random_for("iv_drip.beeps", connection.drip) < BEEP_CHANCE then
                beep(connection)
            end
        end

        local floor = normal * DRAW_FLOOR_FRACTION
        if blood <= floor then
            if not context.low_blood_notified and connection.current() then
                context.low_blood_notified = true
                notify_patient(connection, LOW_BLOOD_MESSAGE)
            end
            return
        end
        amount = math.min(amount, blood - floor)
        from = connection.patient
        to = connection.vessel
    end

    if amount <= 0 then
        return
    end

    sim.matter.transfer({ from = from, to = to, amount = amount, phases = phases })
    blood_identity.note_transfusion(ISSUER, connection.patient, donor, receiver)
    table.insert(pending, { connection = connection, context = context, mode = mode })
end

local function run(connection: FlowConnection, context: FlowContext): ()
    local stroke_ticks = sim.ticks(STROKE_SECONDS)
    while true do
        sim.sleep(stroke_ticks)
        local body = live_body(connection)
        if body == nil then
            return
        end

        local mode = connection.mode()
        local headspace = vessel.headspace_l(connection.vessel)
        if headspace == nil then
            disconnect_if_current(connection)
            return
        end
        if headspace > FULL_HEADSPACE_L then
            context.full_notified = false
        elseif mode == "draw" then
            warn_full(connection, context)
            continue
        end

        local rate = math.min(connection.rate(), MAX_RATE_UNITS_PER_SECOND)
        if rate ~= rate or rate <= 0 then
            continue
        end
        stroke(connection, context, body, mode, rate)
    end
end

function flow.start(connection: FlowConnection): Task
    local context: FlowContext = { full_notified = false, low_blood_notified = false }
    return sim.spawn_task(connection.vessel, function()
        local ok = pcall(run, connection, context)
        if not ok and connection.current() then
            connection.disconnect()
        end
    end)
end

function flow.on_transfer_done(ev: MatterTransferDonePayload): ()
    local note = table.remove(pending, 1)
    if note ~= nil and note.connection.patient.alive == false then
        blood_identity.settle_injection(ISSUER, 0)
    else
        blood_identity.settle_injection(ISSUER, ev.moved)
    end
    if note == nil or note.mode ~= "draw" then
        return
    end

    local connection = note.connection
    if live_body(connection) == nil or connection.mode() ~= "draw" then
        return
    end
    local headspace = vessel.headspace_l(connection.vessel)
    if headspace == nil then
        disconnect_if_current(connection)
        return
    end
    if headspace > FULL_HEADSPACE_L or not connection.current() then
        return
    end
    warn_full(connection, note.context)
end

return flow
