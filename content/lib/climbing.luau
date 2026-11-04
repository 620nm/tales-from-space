local climbing = {}

type ClimbAttempt = {
    actor: Handle,
    support: Handle,
    request: RequestId?,
}

local active_attempts: { ClimbAttempt } = {}

local CRATE_CLIMB_SECONDS = 2.0
local OPEN_CLIMB_FRACTION = 0.5

local function remove_attempt(attempt: ClimbAttempt): ()
    for index = #active_attempts, 1, -1 do
        if active_attempts[index] == attempt then
            table.remove(active_attempts, index)
            return
        end
    end
end

-- Who may climb: a live, controllable body. tg refuses an immobile climber
-- before the wait (`code/datums/elements/climbable.dm:140`) and never checks
-- lying. Returns the refusal reason, or nil when the actor may climb.
local function refusal_reason(actor: Handle): string?
    if actor.alive ~= true then
        return "body_unavailable"
    end
    local body = sim.body.read(actor)
    if body == nil then
        return "body_observer"
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
    local refused_at_start = refusal_reason(actor)
    if refused_at_start ~= nil then
        send(actor, "lunatic/tfs:lib.climbing.refused." .. refused_at_start)
        return true
    end
    for _, attempt in ipairs(active_attempts) do
        if attempt.actor == actor then
            return true
        end
    end

    -- Crate numbers, applied to every climbable structure (crate, freezer):
    -- 2 s closed, half that open
    -- (`code/game/objects/structures/crates_lockers/crates.dm:27,121,133`).
    -- Sampled once; later open/close changes do not retime an attempt.
    local duration_seconds = if support.state == "open"
        then CRATE_CLIMB_SECONDS * OPEN_CLIMB_FRACTION
        else CRATE_CLIMB_SECONDS
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

            -- tg's wait breaks on incapacitation (`timed_actions.dm:77-78`); the
            -- engine guard has no such flag, so control is judged again here.
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
