-- Staff step out of their body into an observer and back, as themselves:
-- the same Mind, name and memory ride both (the engine's
-- docs/control/seat.md). Who may is this pack's rule: staff holding
-- Control. Both modes bind it with `observe.install`; the observer plan
-- (`bodies/observer.luau`) answers its own spawn with `observe.on_spawned`.
--
-- Policy: a disconnect changes nothing, so a staff member who reconnects
-- while observing is offered the way back. A body left behind that is
-- gone, dead or ridden by someone else takes nobody back; the observer
-- stays, and the document says so.
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

-- Whether `body` is an observer this library spawned: its plan says so.
local function observing(body: Handle?): boolean
    local read = if body ~= nil then sim.body.read(body) else nil
    return read ~= nil and read.plan == observe.PLAN
end

local function left_of(mind: Mind): Handle?
    local ref = mind.vars[observe.LEFT]
    return if ref ~= nil then sim.resolve(ref) else nil
end

local function waiting(): { any }
    return (sim.var("mod", observe.WAITING) :: { any }?) or {}
end

local function leave(player: Player): ()
    local body = player.body
    local mind = if body ~= nil then body.mind else nil
    if body == nil or mind == nil or observing(body) or mind.vars[observe.LEFT] ~= nil then
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
    mind.vars[observe.LEFT] = nil
    -- The observer is ridden until the seat applies, so it goes a tick on.
    sim.spawn_task(observer, function()
        sim.sleep(sim.ticks(1 / sim.tick_hz()))
        if observer.mind == nil then
            sim.entity.despawn({ entity = observer })
        end
    end)
    offer(player, "leave", nil, false)
end

-- The observer plan's spawn answer: seat the Mind that asked first, or
-- clear its request and remove a body nobody can ride.
function observe.on_spawned(ev: EntitySpawnDonePayload): ()
    local queue = waiting()
    local asked = table.remove(queue, 1)
    sim.script_var.set({ scope = "mod", key = observe.WAITING, value = queue })
    local left = if asked ~= nil then sim.resolve(asked) else nil
    local mind = if left ~= nil then left.mind else nil
    local observer = ev.entity
    if mind ~= nil and observer ~= nil and ev.outcome == "completed" and sim.control.seat(mind, observer) then
        offer(mind.player, "return", nil, false)
        return
    end
    if observer ~= nil then
        sim.entity.despawn({ entity = observer })
    end
    if mind ~= nil then
        mind.vars[observe.LEFT] = nil
        offer(mind.player, "leave", "refused", false)
    end
end

-- Opened on every connect: what the player rides decides the offer. A
-- player still choosing a job is offered the way out for when they have
-- a body; pressed before then, it does nothing.
local function on_join(ev: ParticipantJoinDonePayload): ()
    local player = ev.participant
    if not may(player) then
        return
    end
    local body = player.body
    local mind = if body ~= nil then body.mind else nil
    local choice: Offer = "leave"
    if observing(body) then
        choice = "return"
    elseif mind ~= nil and mind.vars[observe.LEFT] ~= nil then
        choice = "none"
    end
    offer(player, choice, nil, true)
end

local function on_action(ev: UiActionPayload): ()
    if ev.channel ~= CHANNEL or not may(ev.participant) then
        return
    end
    if ev.action == "leave" then
        leave(ev.participant)
    elseif ev.action == "return" then
        come_back(ev.participant)
    end
end

function observe.install(behavior: Definition): ()
    behavior:handle("participant.join.done", { kind = "react" }, on_join)
    behavior:handle("ui.action", { kind = "react" }, on_action)
end

return observe
