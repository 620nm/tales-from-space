-- IV line lifecycle (tg code/game/machinery/iv_drip.dm:182-185,220-244,288-306).
-- One damage receipt opens the tear wound through content/lib/bloodshed.luau:144-149.
local iv_flow = require("@lib/medical/iv_flow")

local iv_line = {}

export type Mode = "inject" | "draw"
export type ModeState = {
    mode: Mode,
    rate: number,
    connected: boolean,
    state: string,
}

type AttachAttempt = {
    generation: number,
    drip: Handle,
    actor: Handle,
    actor_key: string,
    patient: Handle,
    vessel: Handle,
    instance: MapInstance,
    task: Task?,
}

type ActiveLine = {
    key: string,
    generation: number,
    drip: Handle,
    patient: Handle,
    vessel: Handle,
    instance: MapInstance,
    endpoint_keys: { string },
    flow_task: Task?,
}

type Lifecycle = {
    key: string,
    drip: Handle,
    generation: number,
    active_generation: number?,
    active: ActiveLine?,
    pending: AttachAttempt?,
}

type PendingActorEntry = {
    stand_key: string,
    attempt: AttachAttempt,
}

type PendingActorBucket = { [string]: AttachAttempt }
type PendingActorIndex = { [string]: PendingActorBucket }

local MODE_VAR = "iv_mode"
local RATE_VAR = "iv_rate"
local CONNECTED_VAR = "iv_connected"
-- Pack room radius follows content/lib/controller.luau:186-190, not tg hearing.
local ROOM_MESSAGE_RADIUS = 5

local MESSAGE_KEYS = {
    "lunatic/tfs:iv_drip.attach_start",
    "lunatic/tfs:iv_drip.attach_done",
    "lunatic/tfs:iv_drip.attached",
    "lunatic/tfs:iv_drip.detached",
    "lunatic/tfs:iv_drip.detach_room",
    "lunatic/tfs:iv_drip.ripped",
    "lunatic/tfs:iv_drip.rip_room",
    "lunatic/tfs:iv_drip.reconnect",
    "lunatic/tfs:iv_drip.full",
    "lunatic/tfs:iv_drip.low_blood",
    "lunatic/tfs:iv_drip.beeps",
}

local generations: { [string]: number } = {}
local lifecycles: { [string]: Lifecycle } = {}
local endpoint_drips: { [string]: { [string]: boolean } } = {}
local pending_actor_attempts: PendingActorIndex = {}
local hooks_attached = false
local rip_draw_sequence = 0

local function opaque_key(handle: Handle): string
    return tostring(handle)
end

local function retain_pending_actor(record: Lifecycle, attempt: AttachAttempt): ()
    local members = pending_actor_attempts[attempt.actor_key]
    if members == nil then
        members = {}
        pending_actor_attempts[attempt.actor_key] = members
    end
    members[record.key] = attempt
end

local function forget_pending_actor(record: Lifecycle, attempt: AttachAttempt): ()
    local members = pending_actor_attempts[attempt.actor_key]
    if members == nil or members[record.key] ~= attempt then
        return
    end
    members[record.key] = nil
    if next(members) == nil then
        pending_actor_attempts[attempt.actor_key] = nil
    end
end

local function next_generation(key: string): number
    local generation = (generations[key] or 0) + 1
    generations[key] = generation
    return generation
end

local function alive(handle: Handle): boolean
    local ok, value = pcall(function()
        return handle.alive
    end)
    return ok and value == true
end

local function snapshot_pending_actor_attempts(actor: Handle): { PendingActorEntry }
    local members = pending_actor_attempts[opaque_key(actor)]
    local snapshot: { PendingActorEntry } = {}
    if members ~= nil then
        for stand_key, attempt in pairs(members) do
            table.insert(snapshot, { stand_key = stand_key, attempt = attempt })
        end
    elseif not alive(actor) then
        for _, actor_members in pairs(pending_actor_attempts) do
            for stand_key, attempt in pairs(actor_members) do
                if attempt.actor == actor then
                    table.insert(snapshot, { stand_key = stand_key, attempt = attempt })
                end
            end
        end
    end
    return snapshot
end

local function own_tile(handle: Handle): TileAddress?
    local ok, value = pcall(function()
        return handle.tile
    end)
    if ok then
        return value
    end
    return nil
end

local function body_exists(handle: Handle): boolean
    local ok, body = pcall(sim.body, handle)
    return ok and body ~= nil
end

local function instance_alive(instance: MapInstance): boolean
    local ok, value = pcall(function()
        return instance.alive
    end)
    return ok and value == true
end

local function same_plane(left: TileAddress, right: TileAddress): boolean
    return left.instance == right.instance and left.z == right.z
end

local function adjacent(left: TileAddress, right: TileAddress): boolean
    return same_plane(left, right)
        and math.max(math.abs(left.x - right.x), math.abs(left.y - right.y)) <= 1
end

local function visible(actor: Handle, target: Handle): boolean
    local ok, result = pcall(function()
        return sim.query.los(actor, target)
    end)
    return ok and result == true
end

local function actor_can_attach(actor: Handle, drip: Handle, patient: Handle): boolean
    if not alive(actor) or not body_exists(actor) then
        return false
    end
    local actor_tile = own_tile(actor)
    local drip_tile = own_tile(drip)
    local patient_tile = own_tile(patient)
    if actor_tile == nil or drip_tile == nil or patient_tile == nil then
        return false
    end
    return adjacent(actor_tile, drip_tile)
        and adjacent(actor_tile, patient_tile)
        and visible(actor, drip)
        and visible(actor, patient)
end

local function read_var(drip: Handle, key: string): unknown
    local ok, value = pcall(function()
        return drip.vars[key]
    end)
    if ok then
        return value
    end
    return nil
end

local function write_var(drip: Handle, key: string, value: unknown): ()
    if not alive(drip) then
        return
    end
    pcall(function()
        drip.vars[key] = value
    end)
end

local function bounded_rate(value: unknown, fallback: number): number
    if type(value) ~= "number" or value ~= value then
        return fallback
    end
    local clamped = math.max(0, math.min(5, value))
    return math.floor(clamped * 100 + 0.5) / 100
end

local function current_mode(drip: Handle): Mode
    return if read_var(drip, MODE_VAR) == "draw" then "draw" else "inject"
end

local function current_rate(drip: Handle): number
    return bounded_rate(read_var(drip, RATE_VAR), 5)
end

local function message(key: string): Message
    return sim.msg(key, {})
end

local function send_to(recipient: Handle, key: string): ()
    if alive(recipient) then
        sim.message.send({ recipient = recipient, message = message(key) })
    end
end

local function broadcast(at: TileAddress?, key: string): ()
    if at ~= nil then
        sim.message.broadcast({ at = at, radius = ROOM_MESSAGE_RADIUS, message = message(key) })
    end
end

local function broadcast_settled_event(at: TileAddress?, key: string): ()
    pcall(broadcast, at, key)
end

local function mode_state(drip: Handle): ModeState
    local mode = current_mode(drip)
    local rate = current_rate(drip)
    local record = lifecycles[opaque_key(drip)]
    local connected = record ~= nil and record.active ~= nil and read_var(drip, CONNECTED_VAR) == true
    local state: string
    if connected and rate > 0 then
        state = if mode == "inject" then "iv_drip_injecting" else "iv_drip_donating"
    else
        state = if mode == "inject" then "iv_drip_injectidle" else "iv_drip_donateidle"
    end
    return { mode = mode, rate = rate, connected = connected, state = state }
end

local function refresh_appearance(drip: Handle): ()
    if alive(drip) then
        sim.appearance.set_state({ entity = drip, state = mode_state(drip).state })
    end
end

local function set_connected(drip: Handle, connected: boolean): ()
    write_var(drip, CONNECTED_VAR, connected)
    refresh_appearance(drip)
end

local function add_endpoints(line: ActiveLine): ()
    local unique: { [string]: boolean } = {}
    -- E10 covers Body/Structure edges only; E9 catches dock removal within two seconds.
    local handles = { line.drip, line.patient, line.vessel }
    for _, handle in ipairs(handles) do
        local key = opaque_key(handle)
        if not unique[key] then
            unique[key] = true
            local members = endpoint_drips[key]
            if members == nil then
                members = {}
                endpoint_drips[key] = members
            end
            members[line.key] = true
            table.insert(line.endpoint_keys, key)
        end
    end
end

local function remove_endpoints(line: ActiveLine): ()
    for _, endpoint_key in ipairs(line.endpoint_keys) do
        local members = endpoint_drips[endpoint_key]
        if members ~= nil then
            members[line.key] = nil
            if next(members) == nil then
                endpoint_drips[endpoint_key] = nil
            end
        end
    end
    table.clear(line.endpoint_keys)
end

local function cancel_task(task: Task?, skip: Task?): ()
    if task == nil or task == skip then
        return
    end
    pcall(function()
        task:cancel()
    end)
end

local function current_line(record: Lifecycle, line: ActiveLine): boolean
    return lifecycles[record.key] == record
        and record.active == line
        and line.generation == record.active_generation
end

local function current_attempt(record: Lifecycle, attempt: AttachAttempt): boolean
    return lifecycles[record.key] == record
        and record.pending == attempt
        and attempt.generation == record.generation
end

local function remove_if_empty(record: Lifecycle): ()
    if record.active == nil and record.pending == nil and lifecycles[record.key] == record then
        lifecycles[record.key] = nil
        generations[record.key] = nil
    end
end

local function retire_attempt(record: Lifecycle, attempt: AttachAttempt, skip: Task?): ()
    if record.pending ~= attempt then
        return
    end
    record.pending = nil
    record.generation = next_generation(record.key)
    forget_pending_actor(record, attempt)
    local task = attempt.task
    attempt.task = nil
    if record.active == nil then
        set_connected(record.drip, false)
    end
    remove_if_empty(record)
    cancel_task(task, skip)
end

local function retire_all(record: Lifecycle, skip_attempt: Task?, skip_flow: Task?): ()
    local attempt = record.pending
    local line = record.active
    if attempt ~= nil then
        forget_pending_actor(record, attempt)
    end
    record.pending = nil
    record.active = nil
    record.active_generation = nil
    record.generation = next_generation(record.key)
    if line ~= nil then
        remove_endpoints(line)
    end
    if lifecycles[record.key] == record then
        lifecycles[record.key] = nil
        generations[record.key] = nil
    end
    set_connected(record.drip, false)
    if attempt ~= nil then
        local task = attempt.task
        attempt.task = nil
        cancel_task(task, skip_attempt)
    end
    if line ~= nil then
        local task = line.flow_task
        line.flow_task = nil
        cancel_task(task, skip_flow)
    end
end

local function docked_is(drip: Handle, vessel: Handle): boolean
    if not alive(drip) or not alive(vessel) then
        return false
    end
    local ok, installed = pcall(function()
        return drip:docked()
    end)
    return ok and installed == vessel
end

local function valid_attach(attempt: AttachAttempt): boolean
    if not alive(attempt.drip)
        or not alive(attempt.actor)
        or not alive(attempt.patient)
        or not alive(attempt.vessel)
        or not body_exists(attempt.patient)
        or not docked_is(attempt.drip, attempt.vessel)
        or not instance_alive(attempt.instance)
    then
        return false
    end
    local stand_tile = own_tile(attempt.drip)
    local patient_tile = own_tile(attempt.patient)
    if
        stand_tile == nil
        or patient_tile == nil
        or stand_tile.instance ~= attempt.instance
        or patient_tile.instance ~= attempt.instance
        or not adjacent(stand_tile, patient_tile)
    then
        return false
    end
    return actor_can_attach(attempt.actor, attempt.drip, attempt.patient)
end

local function start_flow(record: Lifecycle, line: ActiveLine): ()
    local flow_connection = {
        drip = line.drip,
        patient = line.patient,
        vessel = line.vessel,
        generation = line.generation,
        current = function(): boolean
            return current_line(record, line)
        end,
        disconnect = function(): ()
            if current_line(record, line) then
                retire_all(record, nil, line.flow_task)
            end
        end,
        mode = function(): Mode
            return current_mode(line.drip)
        end,
        rate = function(): number
            return current_rate(line.drip)
        end,
        set_rate = function(rate: number): ()
            if current_line(record, line) then
                iv_line.set_rate(line.drip, rate)
            end
        end,
    }
    local task: Task? = nil
    local ok = pcall(function()
        task = iv_flow.start(flow_connection)
    end)
    if not ok then
        if current_line(record, line) then
            retire_all(record, nil, nil)
        end
        return
    end
    if current_line(record, line) then
        line.flow_task = task
    else
        cancel_task(task, nil)
    end
end

local function commit_attempt(record: Lifecycle, attempt: AttachAttempt): ()
    if not current_attempt(record, attempt) or not valid_attach(attempt) then
        retire_attempt(record, attempt, attempt.task)
        return
    end
    local old_line = record.active
    local line: ActiveLine = {
        key = record.key,
        generation = attempt.generation,
        drip = attempt.drip,
        patient = attempt.patient,
        vessel = attempt.vessel,
        instance = attempt.instance,
        endpoint_keys = {},
        flow_task = nil,
    }
    record.pending = nil
    forget_pending_actor(record, attempt)
    record.active = line
    record.active_generation = line.generation
    attempt.task = nil
    if old_line ~= nil then
        remove_endpoints(old_line)
        local old_task = old_line.flow_task
        old_line.flow_task = nil
        cancel_task(old_task, nil)
    end
    add_endpoints(line)
    set_connected(line.drip, true)
    broadcast(own_tile(line.drip), "lunatic/tfs:iv_drip.attach_done")
    send_to(line.patient, "lunatic/tfs:iv_drip.attached")
    start_flow(record, line)
end

local function attempt_attach(record: Lifecycle, attempt: AttachAttempt): ()
    local task = sim.spawn_task(attempt.actor, function()
        if not current_attempt(record, attempt) then
            return
        end
        local ok, completed = pcall(function()
            return sim.do_after(attempt.actor, sim.ticks(1), { subject = attempt.patient })
        end)
        if not current_attempt(record, attempt) then
            return
        end
        if not ok or completed ~= "ok" then
            retire_attempt(record, attempt, attempt.task)
            return
        end
        commit_attempt(record, attempt)
    end)
    attempt.task = task
end

local function choose_rip_part(patient: Handle): string?
    local parts_ok, parts = pcall(sim.parts, patient)
    if not parts_ok or parts == nil then
        return nil
    end
    local left = parts.l_arm ~= nil and parts.l_arm.present == true
    local right = parts.r_arm ~= nil and parts.r_arm.present == true
    if left and right then
        rip_draw_sequence += 1
        local draw_key = "lunatic/tfs:iv_drip/rip/" .. tostring(rip_draw_sequence)
        local ok, draw = pcall(sim.random_keyed, "iv_drip.rip_part", draw_key)
        if ok and type(draw) == "number" and draw >= 0.5 then
            return "r_arm"
        end
        return "l_arm"
    elseif left then
        return "l_arm"
    elseif right then
        return "r_arm"
    elseif parts.chest ~= nil and parts.chest.present == true then
        return "chest"
    end
    return nil
end

local function rip_line(record: Lifecycle, line: ActiveLine, moved_at: TileAddress?): ()
    local patient = line.patient
    if not alive(patient) or not body_exists(patient) then
        retire_all(record, nil, nil)
        return
    end
    local part = choose_rip_part(patient)
    retire_all(record, nil, nil)
    send_to(patient, "lunatic/tfs:iv_drip.ripped")
    broadcast_settled_event(moved_at, "lunatic/tfs:iv_drip.rip_room")
    sim.damage.apply({ target = patient, amounts = { brute = 3 }, part = part })
end

local function line_is_separated(line: ActiveLine): boolean
    local stand_tile = own_tile(line.drip)
    local patient_tile = own_tile(line.patient)
    return stand_tile == nil or patient_tile == nil or not adjacent(stand_tile, patient_tile)
end

function iv_line.connect(args: { drip: Handle, actor: Handle, patient: Handle, vessel: Handle }): boolean
    local drip, actor, patient, vessel = args.drip, args.actor, args.patient, args.vessel
    if
        not alive(drip)
        or not alive(actor)
        or not alive(patient)
        or not alive(vessel)
        or not body_exists(patient)
        or not docked_is(drip, vessel)
    then
        return false
    end
    local stand_tile = own_tile(drip)
    local patient_tile = own_tile(patient)
    if
        stand_tile == nil
        or patient_tile == nil
        or not instance_alive(stand_tile.instance)
        or not adjacent(stand_tile, patient_tile)
        or not actor_can_attach(actor, drip, patient)
    then
        return false
    end

    local key = opaque_key(drip)
    local record = lifecycles[key]
    if record == nil then
        local new_record: Lifecycle = {
            key = key,
            drip = drip,
            generation = 0,
            active_generation = nil,
            active = nil,
            pending = nil,
        }
        record = new_record
        lifecycles[key] = record
    end
    local generation = next_generation(key)
    record.generation = generation
    local previous = record.pending
    if previous ~= nil then
        record.pending = nil
        forget_pending_actor(record, previous)
        local previous_task = previous.task
        previous.task = nil
        cancel_task(previous_task, nil)
    end
    local attempt: AttachAttempt = {
        generation = generation,
        drip = drip,
        actor = actor,
        actor_key = opaque_key(actor),
        patient = patient,
        vessel = vessel,
        instance = stand_tile.instance,
        task = nil,
    }
    record.pending = attempt
    retain_pending_actor(record, attempt)
    set_connected(drip, record.active ~= nil)
    local ok = pcall(function()
        attempt_attach(record, attempt)
    end)
    if not ok then
        retire_attempt(record, attempt, nil)
        return false
    end
    broadcast(stand_tile, "lunatic/tfs:iv_drip.attach_start")
    return true
end

function iv_line.disconnect(drip: Handle): ()
    local key = opaque_key(drip)
    local record = lifecycles[key]
    if record ~= nil then
        local line = record.active
        local patient: Handle? = nil
        local at: TileAddress? = nil
        if line ~= nil and current_line(record, line) then
            patient = line.patient
            at = own_tile(line.drip) or own_tile(line.patient)
        end
        retire_all(record, nil, nil)
        if patient ~= nil then
            send_to(patient, "lunatic/tfs:iv_drip.detached")
            broadcast(at, "lunatic/tfs:iv_drip.detach_room")
        end
    else
        set_connected(drip, false)
    end
end

function iv_line.set_mode(drip: Handle, mode: Mode): ()
    if mode == "inject" or mode == "draw" then
        write_var(drip, MODE_VAR, mode)
        refresh_appearance(drip)
    end
end

function iv_line.set_rate(drip: Handle, rate: number): ()
    write_var(drip, RATE_VAR, bounded_rate(rate, 5))
    refresh_appearance(drip)
end

function iv_line.mode_state(drip: Handle): ModeState
    return mode_state(drip)
end

function iv_line.on_location_changed(ev: { entity: Handle }): ()
    for _, entry in ipairs(snapshot_pending_actor_attempts(ev.entity)) do
        local record = lifecycles[entry.stand_key]
        if record ~= nil and current_attempt(record, entry.attempt) then
            retire_attempt(record, entry.attempt, nil)
        end
    end

    local members = endpoint_drips[opaque_key(ev.entity)]
    local affected: { string } = {}
    if members ~= nil then
        for key in pairs(members) do
            table.insert(affected, key)
        end
    elseif not alive(ev.entity) then
        for key, record in pairs(lifecycles) do
            local line = record.active
            if
                line ~= nil
                and (
                    line.drip == ev.entity
                    or line.patient == ev.entity
                    or line.vessel == ev.entity
                )
            then
                table.insert(affected, key)
            end
        end
    end
    if #affected == 0 then
        return
    end
    local moved_at = own_tile(ev.entity)
    for _, key in ipairs(affected) do
        local record = lifecycles[key]
        local line = record and record.active or nil
        if line ~= nil and record ~= nil and current_line(record, line) then
            if
                not alive(line.drip)
                or not alive(line.patient)
                or not alive(line.vessel)
                or not body_exists(line.patient)
                or not docked_is(line.drip, line.vessel)
            then
                retire_all(record, nil, nil)
            elseif line_is_separated(line) then
                rip_line(record, line, moved_at)
            else
                local stand_tile = own_tile(line.drip)
                local patient_tile = own_tile(line.patient)
                if
                    stand_tile ~= nil
                    and patient_tile ~= nil
                    and (stand_tile.instance ~= line.instance or patient_tile.instance ~= line.instance)
                then
                    retire_all(record, nil, nil)
                    broadcast_settled_event(stand_tile, "lunatic/tfs:iv_drip.reconnect")
                end
            end
        end
    end
end

function iv_line.on_second(_ev: unknown): ()
    local stale: { Lifecycle } = {}
    for _, record in pairs(lifecycles) do
        local line = record.active
        local attempt = record.pending
        if line ~= nil then
            if
                not alive(line.drip)
                or not alive(line.patient)
                or not alive(line.vessel)
                or not instance_alive(line.instance)
            then
                table.insert(stale, record)
            end
        elseif attempt ~= nil then
            if
                not alive(attempt.drip)
                or not alive(attempt.actor)
                or not alive(attempt.patient)
                or not alive(attempt.vessel)
                or not instance_alive(attempt.instance)
            then
                retire_attempt(record, attempt, nil)
            end
        end
    end
    for _, record in ipairs(stale) do
        retire_all(record, nil, nil)
    end
end

function iv_line.attach(): ()
    if hooks_attached then
        return
    end
    sim.define("script_var", "lunatic/tfs:iv_mode", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:iv_rate", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:iv_connected", { replicate = "server" })
    for _, key in ipairs(MESSAGE_KEYS) do
        sim.define("message", key, { placeholders = {} })
    end
    sim.handle("entity.location.changed", { kind = "react" }, iv_line.on_location_changed)
    sim.handle("clock.second", { kind = "react" }, iv_line.on_second)
    hooks_attached = true
end

return iv_line
