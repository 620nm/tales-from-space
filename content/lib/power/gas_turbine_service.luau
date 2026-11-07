local gas_turbine = require("@lib/power/gas_turbine")
local gas_turbine_run = require("@lib/power/gas_turbine_run")
local record_lib = require("@lib/power/gas_turbine_record")

-- The gas turbine on the device network: the core rotor advertises one
-- addressed service, `turbine.control`, and every remote hand rides it --
-- the control console's window (lib/power/gas_turbine_console.luau) and a
-- controller guest (lib/controller.luau) alike. A request is a plain table
-- naming one operation; the reply carries the rotor's readout, so reading
-- status and acting are the same round trip. Only a sender on the rotor's
-- own hub is answered: the hub itself (a guest's host) or a sibling joined
-- to it (the console). A turbine further up the same tree is another
-- room's plant, and one tree over is nobody this code can hear anyway
-- (the engine's docs/devices/services.md).
local gas_turbine_service = {}

gas_turbine_service.SERVICE = "turbine.control"
gas_turbine_service.REPLY_KIND = "turbine.status"

export type Status = gas_turbine_run.Readout
export type Reply = {
    kind: string,
    op: string,
    ok: boolean,
    reason: string?,
    status: Status?,
}
export type Candidate = { mac: string, name: string }

local OPS: { [string]: boolean } = {
    status = true,
    start = true,
    stop = true,
    set_intake = true,
}
-- The run module's refusal words, the only reasons a start or stop names.
local REFUSALS: { [string]: boolean } = {
    not_linked = true,
    running = true,
    not_running = true,
    wrecked = true,
    too_fast = true,
}

local function finite(value: unknown): boolean
    return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

-- Whether `payload` is a request this service acts on. The controller
-- bridge asks the same question of a guest's plan, so a shape the rotor
-- would refuse never spends network traffic.
function gas_turbine_service.valid_request(payload: unknown): boolean
    if type(payload) ~= "table" then
        return false
    end
    local fields = payload :: { [unknown]: unknown }
    for key in pairs(fields) do
        if key ~= "op" and key ~= "intake" then
            return false
        end
    end
    local op = fields.op
    if type(op) ~= "string" or not OPS[op] then
        return false
    end
    if op == "set_intake" then
        return finite(fields.intake)
    end
    return fields.intake == nil
end

local STATUS_NUMBERS =
    { "rpm", "power_w", "integrity", "max_rpm", "max_temperature_k", "intake_k", "intake" }

local function clean_status(value: unknown): Status?
    if type(value) ~= "table" then
        return nil
    end
    local fields = value :: { [string]: unknown }
    if type(fields.connected) ~= "boolean" or type(fields.active) ~= "boolean" then
        return nil
    end
    local status: Status = {
        connected = fields.connected :: boolean,
        active = fields.active :: boolean,
        rpm = 0,
        power_w = 0,
        integrity = 0,
        max_rpm = 0,
        max_temperature_k = 0,
        intake_k = 0,
        intake = 0,
    }
    local writable = status :: { [string]: unknown }
    for _, field in ipairs(STATUS_NUMBERS) do
        if not finite(fields[field]) then
            return nil
        end
        writable[field] = fields[field]
    end
    return status
end

-- A reply, re-spelled as fresh plain data, or nil where it is not one a
-- reader may trust. The console caches only this, and the controller
-- bridge hands a guest only this.
function gas_turbine_service.sanitize_reply(payload: unknown): Reply?
    if type(payload) ~= "table" then
        return nil
    end
    local fields = payload :: { [string]: unknown }
    local op = fields.op
    if
        fields.kind ~= gas_turbine_service.REPLY_KIND
        or type(op) ~= "string"
        or not OPS[op]
        or type(fields.ok) ~= "boolean"
    then
        return nil
    end
    local reason = fields.reason
    if
        reason ~= nil
        and (type(reason) ~= "string" or (not REFUSALS[reason] and reason ~= "bad_request" and reason ~= "unreachable"))
    then
        return nil
    end
    local status: Status? = nil
    if fields.status ~= nil then
        status = clean_status(fields.status)
        if status == nil then
            return nil
        end
    end
    if fields.ok and status == nil then
        return nil
    end
    return {
        kind = gas_turbine_service.REPLY_KIND,
        op = op :: string,
        ok = fields.ok :: boolean,
        reason = reason :: string?,
        status = status,
    }
end

-- The refusal word inside the run module's message key, for replies.
local function reason_of(key: string?): string?
    if key == nil then
        return nil
    end
    local prefix = record_lib.MESSAGE
    if string.sub(key, 1, #prefix) == prefix then
        local word = string.sub(key, #prefix + 1)
        if REFUSALS[word] then
            return word
        end
    end
    return "bad_request"
end

local function prototype_of(thing: Handle): string?
    return thing.base or thing.prototype
end

-- The hub a node answers to: its parent, or itself where it is one.
local function hub_of(state: LinkState): string?
    return if state.role == "endpoint" then state.parent else state.mac
end

-- Whether the sender `mac` stands on `rotor`'s hub, resolved out of the
-- tree the rotor already stands in -- the only address book there is
-- (the engine's docs/luau-api/devices.md). The hub itself counts: a
-- controller guest speaks as its host.
local function same_hub(rotor: Handle, mac: string): boolean
    local own = sim.link_state(rotor)
    if own == nil or own.suspended or own.parent == nil or mac == own.mac then
        return false
    end
    if mac == own.parent then
        return true
    end
    for _, node in ipairs(sim.query.link_tree(rotor)) do
        local state = sim.link_state(node)
        if state ~= nil and state.mac == mac then
            return state.parent == own.parent and not state.suspended
        end
    end
    return false
end

-- Every functional turbine standing on `subject`'s hub: a core rotor,
-- online, whose line inspects whole. Ascending by address, as the tree
-- read answers.
function gas_turbine_service.candidates(subject: Handle): { Candidate }
    local out: { Candidate } = {}
    local own = sim.link_state(subject)
    if own == nil or own.suspended then
        return out
    end
    local hub = hub_of(own)
    if hub == nil then
        return out
    end
    for _, node in ipairs(sim.query.link_tree(subject)) do
        if node.alive and prototype_of(node) == gas_turbine.CORE then
            local state = sim.link_state(node)
            if
                state ~= nil
                and state.parent == hub
                and not state.suspended
                and record_lib.linked(node)
            then
                table.insert(out, { mac = state.mac, name = node.name or "core rotor" })
            end
        end
    end
    return out
end

local rotors: { [string]: Handle } = {}

local function advertise(rotor: Handle): ()
    if sim.link_state(rotor) == nil then
        return
    end
    sim.link.advertise({
        subject = rotor,
        service = gas_turbine_service.SERVICE,
        name = rotor.name or "core rotor",
    })
end

-- `entity.initialize.done` through the sections' handler: a rotor joins
-- the advertisement registry. Its address is its own and never changes,
-- so advertising once stands; the directory pass below repeats it for
-- whatever a topology change may have missed.
function gas_turbine_service.on_initialized(ev: EntityInitializeDonePayload): ()
    local rotor = ev.entity
    if not rotor.alive or prototype_of(rotor) ~= gas_turbine.CORE then
        return
    end
    rotors[tostring(rotor)] = rotor
    advertise(rotor)
end

-- `link.directory.changed`: hold every live rotor's advertisement.
function gas_turbine_service.on_directory_changed(): ()
    for key, rotor in pairs(rotors) do
        if not rotor.alive then
            rotors[key] = nil
        else
            advertise(rotor)
        end
    end
end

-- The reply a refused send stands in for, for bridges that must settle
-- a request no rotor ever saw (lib/controller.luau).
function gas_turbine_service.failure_reply(payload: unknown): Reply
    local op = "status"
    if type(payload) == "table" then
        local asked = (payload :: { [string]: unknown }).op
        if type(asked) == "string" and OPS[asked] then
            op = asked
        end
    end
    return {
        kind = gas_turbine_service.REPLY_KIND,
        op = op,
        ok = false,
        reason = "unreachable",
    }
end

-- `link.service.delivery` on the core rotor. The run module stays the
-- one answer for what a start, a stop and the valve do; this checks who
-- is asking and spells the outcome as data.
function gas_turbine_service.on_delivery(ev: LinkServiceDeliveryPayload): ()
    local rotor = ev.self
    if ev.service ~= gas_turbine_service.SERVICE or not rotor.alive then
        return
    end
    local payload: unknown = ev.payload
    local op = "status"
    if type(payload) == "table" and type((payload :: { [string]: unknown }).op) == "string" then
        local asked = (payload :: { [string]: unknown }).op :: string
        if OPS[asked] then
            op = asked
        end
    end
    local token = ev.reply
    local function reply(ok: boolean, reason: string?, with_status: boolean): ()
        if token == nil then
            return
        end
        sim.link.reply({
            subject = rotor,
            token = token,
            payload = {
                kind = gas_turbine_service.REPLY_KIND,
                op = op,
                ok = ok,
                reason = reason,
                status = if with_status then gas_turbine_run.readout(rotor) else nil,
            },
        })
    end
    if not same_hub(rotor, ev.from) then
        reply(false, "unreachable", false)
        return
    end
    if not gas_turbine_service.valid_request(payload) then
        reply(false, "bad_request", false)
        return
    end
    local request = payload :: { op: string, intake: number? }
    if request.op == "start" then
        local started, refusal = gas_turbine_run.start(rotor, nil)
        reply(started, reason_of(refusal), true)
    elseif request.op == "stop" then
        local stopped, refusal = gas_turbine_run.stop(rotor, nil)
        reply(stopped, reason_of(refusal), true)
    elseif request.op == "set_intake" then
        gas_turbine_run.set_intake(rotor, request.intake :: number)
        reply(true, nil, true)
    else
        reply(true, nil, true)
    end
end

return gas_turbine_service
