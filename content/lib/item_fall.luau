-- What an item does over an open hole, in one place.
--
-- tg drops every living thing and every object onto the level below
-- (`/turf/proc/zFall`, tgstation/code/game/turfs/turf.dm:335-361: only a
-- non-living, non-object `falling` is refused, line 343), so an item
-- over an Open tile falls. The engine asks once per item (`item.fall`) and
-- this is the answer; `content/main.luau` binds it unscoped.
--
-- An item that carries on while it drops answers a nonzero `glide_x` /
-- `glide_y` from `glide_for`; a thing that stays aloft answers before it.
local paper_plane = require("@lib/paper_plane")

local item_fall = {}

export type ItemFallAnswer = { fall: boolean, glide_x: number?, glide_y: number? }

-- Where a falling item carries sideways, in tiles. The per-prototype hook:
-- branch on `ev.item.prototype` here.
local function glide_for(ev: ItemFallPayload): { x: number, y: number }
    return paper_plane.glide(ev)
end

function item_fall.answer(ev: ItemFallPayload): ItemFallAnswer
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
function item_fall.on_land(ev: MotionLandDonePayload): ()
    if ev.outcome ~= "completed" or ev.actor.kind ~= "item" then
        return
    end
    sim.message.broadcast({
        at = ev.at,
        radius = LANDING_MESSAGE_RADIUS,
        message = sim.msg("lunatic/tfs:lib.item_fall.landed", { item = ev.actor.name or ev.actor.prototype or "?" }),
    })
end

return item_fall
