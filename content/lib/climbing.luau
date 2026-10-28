local climbing = {}

type ClimbAttempt = {
    actor: Handle,
    support: Handle,
    request: RequestId?,
}

local active_attempts: { ClimbAttempt } = {}

local function remove_attempt(attempt: ClimbAttempt): ()
    for index = #active_attempts, 1, -1 do
        if active_attempts[index] == attempt then
            table.remove(active_attempts, index)
            return
        end
    end
end

-- The pack's rule for who may climb: a live, standing, controllable body.
-- Returns the refusal reason, or nil when the actor may climb.
local function refusal_reason(actor: Handle): string?
    if actor.alive ~= true then
        return "body_unavailable"
    end
    local body = sim.body(actor)
    if body == nil then
        return "body_observer"
    end
    if body.posture == "lying" then
        return "body_not_standing"
    end
    if body.controllable ~= true then
        return "body_not_controllable"
    end
    return nil
end

local function send(actor: Handle, key: string): ()
    if actor.alive == true then
        sim.message.send({ recipient = actor, message = sim.msg(key, {}) })
    end
end

function climbing.supports(structure: Handle): boolean
    return structure.climbable ~= nil
end

function climbing.begin(actor: Handle, support: Handle): boolean
    if actor.alive ~= true or support.alive ~= true then
        return false
    end
    -- Only a bodiless actor is refused up front; posture and control are
    -- judged when the wait ends, as tg's `do_climb` re-checks
    -- (`code/datums/elements/climbable.dm:61-103`).
    if sim.body(actor) == nil then
        send(actor, "lunatic/tfs:lib.climbing.refused.body_observer")
        return true
    end
    for _, attempt in ipairs(active_attempts) do
        if attempt.actor == actor then
            return true
        end
    end

    -- Crates take two seconds closed and one second once open. Sample once;
    -- later open/close changes do not retime an attempt
    -- (`code/game/objects/structures/crates_lockers/crates.dm:22-27,118-138`).
    local duration_seconds = if support.state == "open" then 1.0 else 2.0
    local duration_ticks = sim.ticks(duration_seconds)
    local attempt: ClimbAttempt = { actor = actor, support = support, request = nil }
    local task: Task? = nil
    local spawned = pcall(function()
        task = sim.spawn_task(actor, function()
            local outcome = sim.do_after(actor, duration_ticks, {
                stationary = true,
                target_stationary = true,
            })
            if outcome ~= "ok" then
                remove_attempt(attempt)
                return
            end

            local refused = refusal_reason(actor)
            if refused ~= nil then
                remove_attempt(attempt)
                send(actor, "lunatic/tfs:lib.climbing.refused." .. refused)
                return
            end

            local request: RequestId? = nil
            local issued = pcall(function()
                request = sim.climb({ support = support })
            end)
            if not issued or request == nil then
                remove_attempt(attempt)
                return
            end
            attempt.request = request
        end)
    end)
    if not spawned or task == nil then
        return false
    end

    table.insert(active_attempts, attempt)
    send(actor, "lunatic/tfs:lib.climbing.start")
    return true
end

function climbing.on_done(ev: ClimbDonePayload): ()
    for index = #active_attempts, 1, -1 do
        local attempt = active_attempts[index]
        if attempt.request == ev.request then
            if attempt.actor ~= ev.body or attempt.support ~= ev.support then
                return
            end
            table.remove(active_attempts, index)
            if ev.outcome == "completed" then
                send(ev.body, "lunatic/tfs:lib.climbing.completed")
            else
                local key = if ev.reason == nil
                    then "lunatic/tfs:lib.climbing.failed"
                    else "lunatic/tfs:lib.climbing.refused." .. ev.reason
                send(ev.body, key)
            end
            return
        end
    end
end

return climbing
