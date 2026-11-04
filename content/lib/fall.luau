-- What a body or a thing does over an open hole, in one place.
--
-- tg drops every living thing and every object onto the level below
-- (`/turf/proc/zFall`, tgstation/code/game/turfs/turf.dm:335-361: only a
-- non-living, non-object `falling` is refused, line 343). The engine asks
-- `motion.fall` once per arrival with its own guess prefilled (falls unless
-- held aloft) and this is the answer; `content/main.luau` binds it unscoped.
-- A body keeps the guess (`{}`); an item answers the rules below.
--
-- Divergence: tg also refuses an anchored mover (`can_z_move` without
-- ZMOVE_ALLOW_ANCHORED, tgstation/code/game/atoms_movable.dm:467). The
-- payload exposes no anchored fact, so an item the engine holds fast (a
-- non-`Movable` one) still falls here.
--
-- An item that carries on while it drops answers a nonzero `glide_x` /
-- `glide_y` from `glide_for`; a thing that stays aloft answers before it.
local fall_limits = require("@lib/fall_limits")
local paper_plane = require("@lib/paper_plane")

local fall = {}

export type FallAnswer = { fall: boolean?, glide_x: number?, glide_y: number? }

-- Never past `simulation.fall.glide_max` (`lib/fall_limits.luau`).
local function clamp_glide(n: number): number
    local max = fall_limits.glide_max_tiles
    return math.clamp(n, -max, max)
end

-- Where a falling item carries sideways, in tiles, never past the cap.
-- Per-prototype glides branch on `ev.entity.prototype` here.
local function glide_for(ev: MotionFallPayload): paper_plane.TileStep
    local glide = paper_plane.glide(ev)
    return { x = clamp_glide(glide.x), y = clamp_glide(glide.y) }
end

-- Bodies someone pulled as they went over the edge, by `tostring(handle)`:
-- a fall ends the pull before it lands, and tg spares a pulled body the
-- tumble (`can_fall_down_stairs`, stairs.dm:338). Each body's own next
-- `motion.fall` overwrites its entry, and its landing clears it.
local pulled_fallers: { [string]: true } = {}

function fall.answer(ev: MotionFallPayload): FallAnswer
    if ev.subject ~= "item" then
        pulled_fallers[tostring(ev.entity)] = if ev.entity.pulled_by ~= nil then true else nil
        return {}
    end
    if paper_plane.rides_thermal(ev) then
        return { fall = false }
    end
    local glide = glide_for(ev)
    if glide.x ~= 0 or glide.y ~= 0 then
        return { fall = true, glide_x = glide.x, glide_y = glide.y }
    end
    return { fall = true }
end

-- tg's view radius (mod.toml `[view]`): visible_message reaches what a
-- crewman sees.
local LANDING_MESSAGE_RADIUS = 7

-- A body that tumbles down a flight it fell onto (stairs.dm:347-354
-- `on_fall`). tg's paralysis is this pack's knockdown hold, as a closet's
-- is (`lib/closets/data.luau`), so AdjustParalyzed(2 SECONDS) (:348) lies
-- inside the 5 s knockdown and holds nothing of its own. Not ported: the
-- spin (:351, presentation) and the roll two tiles back (:353,
-- `move_towards`): no effect moves a body a step from a handler.
local TUMBLE_STAGGER_SECONDS = 2 -- adjust_staggered(2 SECONDS), :349
local TUMBLE_KNOCKDOWN_SECONDS = 5 -- AdjustKnockdown(5 SECONDS), :350
local TUMBLE_BRUTE_MIN = 4 -- rand(4, 8), :352
local TUMBLE_BRUTE_MAX = 8

-- tg's staggered status (code/datums/status_effects/debuffs/staggered.dm):
-- never on the dead (:17, :36), and while it runs each step costs
-- STAGGERED_SLOWDOWN_STRENGTH 0.85 deciseconds more (staggered.dm:21;
-- code/modules/movespeed/modifiers/mobs.dm:79-80; combat.dm:186). Not
-- ported: the sway animation (:41). The tick it ends on, by `tostring`.
local STAGGER_STEP_ADD_SECONDS = 0.085
local staggered_until: { [string]: number } = {}

local function animate(body: Handle): boolean
    local snapshot = sim.body(body)
    return snapshot ~= nil and snapshot.animate
end

-- tg `adjust_staggered`: the time adds to what is left
-- (`adjust_timed_status_effect`, code/__DEFINES/status_effects.dm:156).
local function stagger(body: Handle, seconds: number): ()
    if not animate(body) then
        return
    end
    local key = tostring(body)
    local now = sim.tick()
    staggered_until[key] = math.max(staggered_until[key] or now, now) + sim.ticks(seconds)
end

local function is_staggered(body: Handle): boolean
    local key = tostring(body)
    local until_tick = staggered_until[key]
    if until_tick == nil then
        return false
    end
    if until_tick <= sim.tick() or not animate(body) then
        staggered_until[key] = nil
        return false
    end
    return true
end

-- The seconds a staggered body's step costs more; 0 for anyone else.
function fall.stagger_step_add_s(mover: Handle): number
    return if is_staggered(mover) then STAGGER_STEP_ADD_SECONDS else 0
end

-- The flight of `structures/stairs/stairs.luau` standing at `at` itself,
-- never one whose top cell is there.
local function flight_at(at: TileAddress): Handle?
    for _, candidate in ipairs(sim.query.range(at, 0, { prototype = "stairs" })) do
        local tile = candidate.tile
        if candidate.alive and tile.x == at.x and tile.y == at.y and tile.z == at.z then
            return candidate
        end
    end
    return nil
end

-- Whether a body caught by a flight tumbles (`can_fall_down_stairs`,
-- stairs.dm:336-345): never one pulled as it fell (:338; nothing in this
-- pack buckles a body), else one out cold (:340, tg's unconscious is
-- `conscious` here) or one off balance (:342).
local function tumbles(body: Handle, pulled: boolean): boolean
    if pulled then
        return false
    end
    local snapshot = sim.body(body)
    if snapshot == nil then
        return false
    end
    return not snapshot.conscious or is_staggered(body)
end

-- A flight catches a one-level fall onto it (stairs.dm:324-334
-- `intercept_zImpact`): no landing line, and the body that tumbles falls
-- down it. Divergence: tg's catch also returns FALL_RETAIN_PULL (:334), so
-- a caught body keeps its puller; here the fall has already ended the pull.
local function caught_by_flight(ev: MotionLandDonePayload): boolean
    local key = tostring(ev.actor)
    local pulled = pulled_fallers[key] ~= nil
    pulled_fallers[key] = nil
    if ev.levels_fallen ~= 1 or flight_at(ev.at) == nil then
        return false
    end
    if ev.actor.kind ~= "body" or not tumbles(ev.actor, pulled) then
        return true
    end
    sim.message.send({ recipient = ev.actor, message = sim.msg("lunatic/tfs:lib.fall.down_stairs", {}) })
    ev.actor:hold_posture("knockdown", TUMBLE_KNOCKDOWN_SECONDS)
    stagger(ev.actor, TUMBLE_STAGGER_SECONDS)
    local span = TUMBLE_BRUTE_MAX - TUMBLE_BRUTE_MIN + 1
    local brute = TUMBLE_BRUTE_MIN + math.floor(sim.random("stairs.tumble") * span)
    sim.damage.apply({ target = ev.actor, amounts = { brute = brute } })
    return true
end

-- An item that fell lands: "[src] crashes into [turf]!" for everyone near
-- (tgstation/code/game/atoms_movable.dm:354-358, `onZImpact`, called per
-- faller at tgstation/code/game/turfs/turf.dm:383), unless a flight caught
-- it. A body's landing says nothing; a flight may tumble it.
-- Omitted from tg: "[mover] falls through [prev_turf]!" from the turf above
-- (turf.dm:376); and the landing text is fixed ("the floor") where tg names
-- the impacted turf (atoms_movable.dm:358).
function fall.on_land(ev: MotionLandDonePayload): ()
    if ev.outcome ~= "completed" or caught_by_flight(ev) or ev.actor.kind ~= "item" then
        return
    end
    sim.message.broadcast({
        at = ev.at,
        radius = LANDING_MESSAGE_RADIUS,
        message = sim.msg("lunatic/tfs:lib.fall.landed", { item = ev.actor.name or ev.actor.prototype or "?" }),
    })
end

return fall
