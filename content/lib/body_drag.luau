local climbing = require("@lib/climbing")

local body_drag = {}

local BODY_CAPABLE_BASES: { [string]: boolean } = {
    crate = true,
    freezer = true,
    locker = true,
}

local function base_prototype(prototype: string): string
    return string.match(prototype, "^([^.]+)") or prototype
end

local function adjacent(left: Handle, right: Handle): boolean
    local left_tile = left.tile
    local right_tile = right.tile
    if left_tile == nil or right_tile == nil then
        return false
    end
    if left_tile.instance ~= right_tile.instance or left_tile.z ~= right_tile.z then
        return false
    end
    return math.max(math.abs(left_tile.x - right_tile.x), math.abs(left_tile.y - right_tile.y)) <= 1
end

local function actor_ready(actor: Handle): boolean
    if actor.alive ~= true then
        return false
    end
    local body = sim.body(actor)
    return body ~= nil and body.controllable == true
end

local function entry_context_ready(actor: Handle, body: Handle, receiver: Handle): boolean
    if not actor_ready(actor)
        or body.alive ~= true
        or receiver.alive ~= true
        or receiver.state ~= "open"
        or sim.body(body) == nil
    then
        return false
    end
    return adjacent(actor, body) and adjacent(actor, receiver) and adjacent(body, receiver)
end

local function begin_entry(ev: InteractionDragPayload): boolean
    local actor = ev.actor
    local body = ev.subject
    local receiver = ev.target
    if not entry_context_ready(actor, body, receiver) then
        return false
    end

    -- tg allows four seconds to hide or stuff a living body
    -- (`code/game/objects/structures/crates_lockers/closets.dm:987-1020`).
    local spawned = pcall(function()
        sim.spawn_task(actor, function()
            local outcome = sim.do_after(actor, sim.ticks(4.0), {
                subject = body,
                stationary = true,
                target_stationary = true,
                subject_stationary = true,
            })
            if outcome ~= "ok" or not entry_context_ready(actor, body, receiver) then
                return
            end
            sim.container.enter({ body = body, container = receiver })
        end)
    end)
    if not spawned then
        return false
    end

    local key = if actor == body
        then "lunatic/tfs:lib.body_drag.hide_start"
        else "lunatic/tfs:lib.body_drag.stuff_start"
    sim.message.send({ recipient = actor, message = sim.msg(key, {}) })
    return true
end

function body_drag.on_drag(ev: InteractionDragPayload): { replaced: boolean }
    local receiver = ev.target
    local prototype = receiver.prototype
    if type(prototype) ~= "string" or sim.body(ev.subject) == nil then
        return { replaced = false }
    end
    local base = base_prototype(prototype)

    if receiver.state == "open" and BODY_CAPABLE_BASES[base] == true then
        return { replaced = begin_entry(ev) }
    end
    if receiver.state == "closed"
        and climbing.supports_prototype(prototype)
        and ev.actor == ev.subject
    then
        return { replaced = climbing.begin(ev.actor, receiver) }
    end
    return { replaced = false }
end

return body_drag
