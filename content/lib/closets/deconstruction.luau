-- Salvage waits for one exact native despawn receipt before creating items.
-- Callers validate their own action guards and treat a true request as queued.
-- Every despawn producer for an attached prototype family uses this helper.

export type DeconstructionSpec = {
    definition: string,
    count: number,
    units: number?,
}

-- Optional callbacks run only after a successful receipt and queued salvage spawns.
export type Request = (target: Handle, on_completed: (() -> ())?) -> boolean

type Ticket = {
    token: string,
    target: Handle,
    root_proto: string,
    prototype: string,
    at: TileAddress,
    definition: string,
    count: number,
    units: number?,
    on_completed: (() -> ())?,
}

local TICKET_KEY = "deconstruction_ticket"
local TICKET_DEFINITION = "lunatic/tfs:deconstruction_ticket"
local TICKET_IDLE = "idle"

local ticket: Ticket? = nil
local request_serial = 0
local processing_receipt = false
local ticket_var_declared = false
local receipt_handler_installed = false

local function in_prototype_family(prototype: string, root_proto: string): boolean
    return prototype == root_proto
        or string.sub(prototype, 1, #root_proto + 1) == root_proto .. "."
end

local function clear_committed_ticket(): ()
    ticket = nil
    sim.script_var.set({ scope = "mod", key = TICKET_KEY, value = TICKET_IDLE })
end

local function on_despawn_done(ev: EntityDespawnDonePayload): ()
    if processing_receipt then
        return
    end

    local active_ticket = ticket
    if active_ticket == nil then
        return
    end

    if sim.var("mod", TICKET_KEY) ~= active_ticket.token then
        -- A staged error can leave Lua scratch behind after its effects roll back.
        -- Only the committed token can authorize this receipt.
        ticket = nil
        return
    end

    local at = ev.at
    if not in_prototype_family(active_ticket.prototype, active_ticket.root_proto)
        or ev.identity ~= active_ticket.prototype
        or at == nil
        or at ~= active_ticket.at
    then
        return
    end

    local salvage_authorized = ev.outcome == "completed"
        and ev.reason == nil
        and not active_ticket.target.alive
    clear_committed_ticket()
    if not salvage_authorized then
        return
    end

    processing_receipt = true
    local units = active_ticket.units
    if units == nil then
        for _ = 1, active_ticket.count do
            sim.entity.spawn({ definition = active_ticket.definition, at = at })
        end
    else
        for _ = 1, active_ticket.count do
            sim.entity.spawn({
                definition = active_ticket.definition,
                at = at,
                initial = { units = units },
            })
        end
    end
    if active_ticket.on_completed ~= nil then
        active_ticket.on_completed()
    end
    processing_receipt = false
end

local function ensure_runtime_bindings(): ()
    if not ticket_var_declared then
        sim.define("script_var", TICKET_DEFINITION, {
            replicate = "server",
            private = true,
        })
        ticket_var_declared = true
    end

    if not receipt_handler_installed then
        sim.handle("entity.despawn.done", { kind = "react" }, on_despawn_done)
        receipt_handler_installed = true
    end
end

local function attach(
    _behavior: Definition,
    root_proto: string,
    spec: DeconstructionSpec
): Request
    assert(root_proto ~= "", "deconstruction root prototype is required")
    assert(spec.definition ~= "", "deconstruction salvage definition is required")
    assert(
        spec.count > 0 and spec.count % 1 == 0,
        "deconstruction count must be a positive integer"
    )
    local units = spec.units
    assert(
        units == nil
            or (
                units >= 1
                and units <= 4294967295
                and units % 1 == 0
            ),
        "deconstruction units must be a positive finite integer in the u32 range"
    )

    ensure_runtime_bindings()

    local definition = spec.definition
    local count = spec.count

    local function request(
        target: Handle,
        on_completed: (() -> ())?
    ): boolean
        if processing_receipt then
            return false
        end

        local committed_ticket = sim.var("mod", TICKET_KEY)
        if committed_ticket ~= nil and committed_ticket ~= TICKET_IDLE then
            local active_ticket = ticket
            if active_ticket == nil
                or active_ticket.token ~= committed_ticket
                or active_ticket.target.alive
            then
                return false
            end
            clear_committed_ticket()
        end

        -- This also drops scratch left by an occurrence whose effects rolled back.
        ticket = nil
        if not target.alive then
            return false
        end

        local prototype = target.prototype
        if prototype == nil or not in_prototype_family(prototype, root_proto) then
            return false
        end

        local at = target.tile
        if at == nil then
            return false
        end
        request_serial += 1
        local token = tostring(target) .. ":" .. tostring(request_serial)
        ticket = {
            token = token,
            target = target,
            root_proto = root_proto,
            prototype = prototype,
            at = at,
            definition = definition,
            count = count,
            units = units,
            on_completed = on_completed,
        }

        sim.script_var.set({ scope = "mod", key = TICKET_KEY, value = token })
        sim.entity.despawn({ entity = target })
        return true
    end

    return request
end

return {
    attach = attach,
}
