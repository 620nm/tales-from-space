local climbing = {}

-- One timed climb per actor: onto a climbable structure (`support`) or
-- onto a ground step on the tile beside it (`onto`, a terrain.luau step).
-- `committing` is set once the wait is done and the native climb issued,
-- so the climb's own crossing passes the ledge veto below.
type ClimbAttempt = {
    actor: Handle,
    support: Handle?,
    onto: TileAddress?,
    request: RequestId?,
    committing: boolean,
}

local active_attempts: { ClimbAttempt } = {}

local CRATE_CLIMB_SECONDS = 2.0
local OPEN_CLIMB_FRACTION = 0.5
-- tg's climbable element default (`code/datums/elements/climbable.dm:13`,
-- `climb_time = 2 SECONDS`), which a table takes.
local STEP_CLIMB_SECONDS = 2.0

local function remove_attempt(attempt: ClimbAttempt): ()
    for index = #active_attempts, 1, -1 do
        if active_attempts[index] == attempt then
            table.remove(active_attempts, index)
            return
        end
    end
end

local function same_tile(a: TileAddress, b: TileAddress): boolean
    return a.absolute_x == b.absolute_x and a.absolute_y == b.absolute_y and a.z == b.z
end

-- Who may climb: a live, controllable body. tg refuses an immobile climber
-- before the wait (`code/datums/elements/climbable.dm:140`) and never checks
-- lying. Returns the refusal reason, or nil when the actor may climb.
local function refusal_reason(actor: Handle): string?
    if actor.alive ~= true then
        return "body_unavailable"
    end
    local body = sim.body(actor)
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

-- How high the ground stands on a tile, in metres: the height of a step
-- lying there, else 0 (a full block is never walked onto). A pack with no
-- tile height still ranks a step over flat ground.
local function step_height(at: TileAddress): number
    local block = sim.ground.block(at)
    if block == nil or block.step == nil then
        return 0
    end
    return block.height_m or 1
end

local function committing_onto(actor: Handle, at: TileAddress): boolean
    for _, attempt in ipairs(active_attempts) do
        local onto = attempt.onto
        if
            attempt.actor == actor
            and attempt.committing
            and onto ~= nil
            and same_tile(onto, at)
        then
            return true
        end
    end
    return false
end

-- Wait `duration_seconds` standing still, judge the climber again, then
-- issue the native climb. False when no task could be started.
local function start(
    attempt: ClimbAttempt,
    duration_seconds: number,
    options: DoAfterOptions
): boolean
    local actor = attempt.actor
    local duration_ticks = sim.ticks(duration_seconds)
    local task: Task? = nil
    local spawned = pcall(function()
        task = sim.spawn_task(actor, function()
            local outcome = sim.do_after(actor, duration_ticks, options)
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

            attempt.committing = true
            local request: RequestId? = nil
            local issued = pcall(function()
                request = sim.climb({ support = attempt.support, onto = attempt.onto })
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

-- Refuse an unfit climber out loud, or keep the attempt already running.
-- Returns nil when a new attempt may start.
local function settled_before_start(actor: Handle): boolean?
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
    return nil
end

function climbing.supports(structure: Handle): boolean
    return structure.climbable ~= nil
end

function climbing.begin(actor: Handle, support: Handle): boolean
    if actor.alive ~= true or support.alive ~= true then
        return false
    end
    local settled = settled_before_start(actor)
    if settled ~= nil then
        return settled
    end

    -- Crate numbers, applied to every climbable structure (crate, freezer):
    -- 2 s closed, half that open
    -- (`code/game/objects/structures/crates_lockers/crates.dm:27,121,133`).
    -- Sampled once; later open/close changes do not retime an attempt.
    local duration_seconds = if support.state == "open"
        then CRATE_CLIMB_SECONDS * OPEN_CLIMB_FRACTION
        else CRATE_CLIMB_SECONDS
    local attempt: ClimbAttempt =
        { actor = actor, support = support, onto = nil, request = nil, committing = false }
    return start(attempt, duration_seconds, { stationary = true, target_stationary = true })
end

-- Climb onto the ground step on tile `at`, beside the actor.
function climbing.begin_onto(actor: Handle, at: TileAddress): boolean
    if actor.alive ~= true then
        return false
    end
    local settled = settled_before_start(actor)
    if settled ~= nil then
        return settled
    end
    local attempt: ClimbAttempt =
        { actor = actor, support = nil, onto = at, request = nil, committing = false }
    return start(attempt, STEP_CLIMB_SECONDS, { stationary = true })
end

-- `move.cross` veto: a body walks along a ledge or down off one freely, as
-- tg's `climb_walkable` table top, but must climb up onto one. Only the
-- climb's own crossing passes. A pulled body is held back too.
function climbing.on_cross_veto(ev: MoveCrossPayload): { cancelled: boolean }
    if step_height(ev.to) <= step_height(ev.from) then
        return { cancelled = false }
    end
    return { cancelled = not committing_onto(ev.mover, ev.to) }
end

-- `move.cross.done`: a body's own walk refused at a ledge starts its climb.
function climbing.on_cross_done(ev: MoveCrossDonePayload): ()
    if ev.outcome ~= "cancelled" or ev.pulled_by ~= nil then
        return
    end
    if step_height(ev.to) <= step_height(ev.from) then
        return
    end
    climbing.begin_onto(ev.mover, ev.to)
end

function climbing.on_done(ev: ClimbDonePayload): ()
    for index = #active_attempts, 1, -1 do
        local attempt = active_attempts[index]
        if attempt.request == ev.request then
            if attempt.actor ~= ev.body or attempt.support ~= ev.support then
                return
            end
            local onto = attempt.onto
            local landed = ev.onto
            if onto ~= nil and (landed == nil or not same_tile(onto, landed)) then
                return
            end
            table.remove(active_attempts, index)
            if ev.outcome == "completed" then
                local key = if onto ~= nil
                    then "lunatic/tfs:lib.climbing.completed_step"
                    else "lunatic/tfs:lib.climbing.completed"
                send(ev.body, key)
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
