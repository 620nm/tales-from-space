-- Staff step out of their body into an observer and back, as themselves:
-- the same Mind, name and memory ride both (the engine's
-- docs/control/seat.md). Who may is this pack's rule: staff holding
-- Control. Both modes bind it with `observe.install`; the observer plan
-- (`bodies/observer.luau`) answers its own spawn with `observe.on_spawned`.
--
-- Policy: a disconnect changes nothing. A body left behind that is gone,
-- dead or ridden takes nobody back; the observer stays, and the panel says
-- so. Revocation (docs/STAFF.md) sends home, or stops the observer.
local ui_label = require("@lib/ui_label")

local observe = {}

observe.PLAN = "observer"
local CHANNEL = "observe"
local REALM = "engine.staff"
local RULE = "engine.staff.control"
-- On the Mind: the body it left behind, from the request until it returns.
observe.LEFT = "lunatic/tfs:observe_left"
-- Mod scope: bodies left behind whose observer has not answered yet, in
-- request order; spawns answer in the order they were asked.
observe.WAITING = "lunatic/tfs:observe_waiting"
-- Mod scope: observers stopped for a revoked rider with no body to go
-- back to, removed by the sweep once nobody rides them.
observe.SPENT = "lunatic/tfs:observe_spent"

-- Which press the document offers: out, back, or none while on the way.
type Offer = "leave" | "return" | "none"

local function may(player: Player): boolean
    return sim.access.account(player, REALM):has(RULE)
end

local function offer(player: Player, choice: Offer, status: string?, opening: boolean): ()
    local actions: { [string]: number } = {}
    if choice ~= "none" then
        actions[choice] = 0
    end
    local view: { [string]: any } = {
        title = ui_label.pack("lunatic/tfs:observe.title"),
        labels = {
            leave = ui_label.pack("lunatic/tfs:observe.leave"),
            ["return"] = ui_label.pack("lunatic/tfs:observe.return"),
        },
    }
    if status ~= nil then
        view.note = ui_label.pack("lunatic/tfs:observe." .. status)
    end
    -- The view is free JSON, which the command types as an opaque object.
    local json: any = view
    if opening then
        ui.open_participant({ participant = player, channel = CHANNEL, view = json, actions = actions })
    else
        ui.update_participant({ participant = player, channel = CHANNEL, view = json, actions = actions })
    end
end

-- Whether `body` is a running observer this library spawned: its plan
-- says so, and it has not been stopped (`retire`).
local function observing(body: Handle?): boolean
    local read = if body ~= nil then sim.body.read(body) else nil
    return read ~= nil and read.plan == observe.PLAN and read.animate
end

local function left_of(mind: Mind): Handle?
    local ref = mind.vars[observe.LEFT]
    return if ref ~= nil then sim.resolve(ref) else nil
end

local function waiting(): { any }
    return (sim.var("mod", observe.WAITING) :: { any }?) or {}
end

local function spent(): { any }
    return (sim.var("mod", observe.SPENT) :: { any }?) or {}
end

-- What the document offers once a trip is over: the way out to those who
-- may take it, nothing (closed) to those who may not.
local function settle(player: Player, status: string?): ()
    if may(player) then
        offer(player, "leave", status, false)
    else
        ui.close_participant({ participant = player, channel = CHANNEL })
    end
end

-- A body one may step out of: a live, animate body that is no observer.
-- A bodiless viewpoint (the reconnect observer) and a corpse are not.
local function steppable(body: Handle): boolean
    local read = sim.body.read(body)
    return read ~= nil and read.animate and read.plan ~= observe.PLAN
end

local function leave(player: Player): ()
    local body = player.body
    local mind = if body ~= nil then body.mind else nil
    if body == nil or mind == nil or not steppable(body) or mind.vars[observe.LEFT] ~= nil then
        return
    end
    mind.vars[observe.LEFT] = body:ref()
    local queue = waiting()
    table.insert(queue, body:ref())
    sim.script_var.set({ scope = "mod", key = observe.WAITING, value = queue })
    sim.body.spawn({ plan = observe.PLAN, at = body.tile })
    offer(player, "none", nil, false)
end

local function come_back(player: Player): ()
    local observer = player.body
    local mind = if observer ~= nil then observer.mind else nil
    if observer == nil or mind == nil or not observing(observer) then
        return
    end
    local left = left_of(mind)
    if left == nil or not sim.control.seat(mind, left) then
        offer(player, "return", "stranded", false)
        return
    end
    -- LEFT holds until the observer is confirmed empty; until then the
    -- document still offers the way back.
    sim.spawn_task(observer, function()
        sim.sleep(sim.ticks(1 / sim.tick_hz()))
        if observer.mind ~= nil then
            -- Refused when the batch applied: still observing.
            offer(mind.player, "return", "stranded", false)
            return
        end
        mind.vars[observe.LEFT] = nil
        sim.entity.despawn({ entity = observer })
        settle(mind.player, nil)
    end)
end

-- The observer plan's spawn answer: seat the Mind that asked first, or
-- remove a body nobody can ride. A spawn whose asker already observes,
-- or whose request was cleared or replaced, is removed unridden.
function observe.on_spawned(ev: EntitySpawnDonePayload): ()
    local queue = waiting()
    local asked = table.remove(queue, 1)
    sim.script_var.set({ scope = "mod", key = observe.WAITING, value = queue })
    local left = if asked ~= nil then sim.resolve(asked) else nil
    local mind = if left ~= nil then left.mind else nil
    local current = mind ~= nil and mind.vars[observe.LEFT] == asked
    local observer = ev.entity
    if current and mind ~= nil and observer ~= nil and ev.outcome == "completed" and sim.control.seat(mind, observer) then
        offer(mind.player, "return", nil, false)
        return
    end
    if observer ~= nil then
        sim.entity.despawn({ entity = observer })
    end
    if current and mind ~= nil then
        mind.vars[observe.LEFT] = nil
        settle(mind.player, "refused")
    end
end

-- Opened on every connect: what the player rides decides the offer. A
-- player still choosing a job is offered the way out for when they have
-- a body; pressed before then, it does nothing. An observer whose grant
-- is gone is sent back at once; the way back never needs the grant.
local function on_join(ev: ParticipantJoinDonePayload): ()
    local player = ev.participant
    local body = player.body
    if observing(body) then
        offer(player, "return", nil, true)
        if not may(player) then
            come_back(player)
        end
        return
    end
    if not may(player) then
        return
    end
    local mind = if body ~= nil then body.mind else nil
    local choice: Offer = if mind ~= nil and mind.vars[observe.LEFT] ~= nil then "none" else "leave"
    offer(player, choice, nil, true)
end

-- Any press without the grant is a press of the way back.
local function on_action(ev: UiActionPayload): ()
    if ev.channel ~= CHANNEL then
        return
    end
    local player = ev.participant
    if ev.action == "return" or not may(player) then
        come_back(player)
    elseif ev.action == "leave" then
        leave(player)
    end
end

-- A revoked observer with no living body to go back to is stopped: the
-- observer becomes a dead body, so its rider is any dead player of the
-- mode (its lens, its respawn offer), with no panel left to act on.
local function retire(player: Player, mind: Mind, observer: Handle): ()
    mind.vars[observe.LEFT] = nil
    sim.set_body_facts(observer, { animate = false, controllable = false, label = "Dead" })
    ui.close_participant({ participant = player, channel = CHANNEL })
    local list = spent()
    table.insert(list, observer:ref())
    sim.script_var.set({ scope = "mod", key = observe.SPENT, value = list })
end

-- Remove stopped observers their rider has left (a respawn, a reconnect).
local function clear_spent(list: { any }): ()
    if #list == 0 then
        return
    end
    local kept = {}
    for _, ref in list do
        local observer = sim.resolve(ref)
        if observer ~= nil and observer.mind == nil then
            sim.entity.despawn({ entity = observer })
        elseif observer ~= nil then
            table.insert(kept, ref)
        end
    end
    sim.script_var.set({ scope = "mod", key = observe.SPENT, value = kept })
end

-- Seconds between sweeps for observers whose grant is gone.
local SWEEP_SECONDS = 2

-- A mode's `clock.second`: every sweep, an observer whose account lost the
-- grant is sent home, pressed or not, or stopped when home is gone.
function observe.on_second(ev: ClockSecondPayload): ()
    if math.floor(ev.elapsed_seconds) % SWEEP_SECONDS ~= 0 then
        return
    end
    -- Past `round.end` the round's vars are closed and its seconds still
    -- tick: the first read says so, and there is nothing left to sweep.
    local open, list = pcall(spent)
    if not open then
        return
    end
    for _, mind in sim.query.minds() do
        -- An earlier life of a player is listed too, and raises on `.player`.
        local live, player = pcall(function(): Player?
            return mind.player
        end)
        if live and player ~= nil and observing(player.body) and not may(player) then
            local left = left_of(mind)
            if left ~= nil and steppable(left) then
                come_back(player)
            else
                retire(player, mind, assert(player.body))
            end
        end
    end
    clear_spent(list)
end

function observe.install(behavior: Definition): ()
    behavior:handle("participant.join.done", { kind = "react" }, on_join)
    behavior:handle("ui.action", { kind = "react" }, on_action)
end

return observe
