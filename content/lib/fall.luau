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

function fall.answer(ev: MotionFallPayload): FallAnswer
    if ev.subject ~= "item" then
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

-- An item that fell lands: "[src] crashes into [turf]!" for everyone near
-- (tgstation/code/game/atoms_movable.dm:354-358, `onZImpact`, called per
-- faller at tgstation/code/game/turfs/turf.dm:383). Bodies are not spoken for
-- here: the same anchor fires for them and this line is the item's.
-- Omitted from tg: "[mover] falls through [prev_turf]!" from the turf above
-- (turf.dm:376); and the landing text is fixed ("the floor") where tg names
-- the impacted turf (atoms_movable.dm:358).
function fall.on_land(ev: MotionLandDonePayload): ()
    if ev.outcome ~= "completed" or ev.actor.kind ~= "item" then
        return
    end
    sim.message.broadcast({
        at = ev.at,
        radius = LANDING_MESSAGE_RADIUS,
        message = sim.msg("lunatic/tfs:lib.fall.landed", { item = ev.actor.name or ev.actor.prototype or "?" }),
    })
end

return fall
