-- A sheet of paper folded into a plane: what it does over an open hole.
--
-- Folding follows tg's alt-click (tgstation/code/modules/paperwork/paper.dm:
-- 393-416, `make_plane`) and the plane's own sprites and unfolding
-- (paperplane.dm:4-6, :53, :71-81); the glide and the updraft below are
-- this pack's own design, not a tg rule. A plane is the same sheet in a
-- different appearance state, so it keeps its writing.
local residue_kinds = require("@lib/residue_kinds")

local paper_plane = {}

export type TileStep = { x: number, y: number }
export type Updraft = { below_k: number, here_k: number }
-- The facts a heading is read from, shared by the ask and its completion.
export type FallFacts = {
    item: Handle,
    cause: ItemFallCause,
    direction_x: number?,
    direction_y: number?,
}

paper_plane.PAPER_ID = "paper"
paper_plane.FLAT_STATE = "flat"
paper_plane.FOLDED_STATE = "folded"
paper_plane.ONFIRE_STATE = "onfire"
-- Script vars holding the heading a plane surfed off with (0, 0 = none).
paper_plane.HEADING_X_VAR = "plane_heading_x"
paper_plane.HEADING_Y_VAR = "plane_heading_y"
-- Script var listing the holes ("x:y:z", plane-absolute) this plane has
-- surfed since it last rested from a throw, drop or support loss.
paper_plane.SURFED_VAR = "plane_surfed"

-- Tiles a falling plane glides per level it would drop.
local GLIDE_PER_LEVEL = 2
-- Warmer air below the hole than at the plane lifts it (kelvin).
local THERMAL_RISE_K = 40
-- Air this hot below the hole sets the plane alight (kelvin).
local IGNITION_K = 600
-- The updraft's shove along the heading: impulse in N*s on a 1 kg sheet,
-- for this long, carries it a few tiles (the engine's docs/luau-api/forces.md).
local PUSH_STRENGTH = 4
local PUSH_SECONDS = 1
-- How long a burning plane lasts, and the ash it leaves (moles).
local BURN_SECONDS = 3
local ASH_MOLES = 0.05
-- tg's view radius (mod.toml `[view]`): what a crewman sees.
local VISIBLE_RADIUS = 7

local NO_GLIDE: TileStep = { x = 0, y = 0 }

local function sign(n: number): number
    if n > 0 then
        return 1
    elseif n < 0 then
        return -1
    end
    return 0
end

-- The 8-way step a delta mostly points along; nil for no delta.
local function dominant_step(dx: number, dy: number): TileStep?
    local ax, ay = math.abs(dx), math.abs(dy)
    if ax == 0 and ay == 0 then
        return nil
    elseif ay * 2 <= ax then
        return { x = sign(dx), y = 0 }
    elseif ax * 2 <= ay then
        return { x = 0, y = sign(dy) }
    end
    return { x = sign(dx), y = sign(dy) }
end

-- A throw carries its own direction; a slide has none, so it reads the
-- heading the plane stored when it last surfed.
local function heading(facts: FallFacts): TileStep?
    if facts.cause == "throw_land" then
        local dx, dy = facts.direction_x, facts.direction_y
        if dx == nil or dy == nil then
            return nil
        end
        return dominant_step(dx, dy)
    elseif facts.cause == "slide" then
        local vars = facts.item.vars
        local dx, dy = vars[paper_plane.HEADING_X_VAR], vars[paper_plane.HEADING_Y_VAR]
        if type(dx) ~= "number" or type(dy) ~= "number" then
            return nil
        end
        return dominant_step(dx, dy)
    end
    return nil
end

function paper_plane.is_folded(item: Handle): boolean
    return (item.base or item.prototype) == paper_plane.PAPER_ID
        and item.state == paper_plane.FOLDED_STATE
end

-- How far a folded plane carries along its heading: twice the levels it
-- would drop. Anything else, or a plane with no heading, drops straight.
function paper_plane.glide(ev: ItemFallPayload): TileStep
    if not paper_plane.is_folded(ev.item) then
        return NO_GLIDE
    end
    local step = heading(ev)
    if step == nil then
        return NO_GLIDE
    end
    local reach = GLIDE_PER_LEVEL * ev.levels
    return { x = step.x * reach, y = step.y * reach }
end

-- The air in the cell under the hole against the air at the plane. Air at
-- ignition heat counts whatever the air at the plane, so a plane over an
-- already-hot hole still catches fire: tg's plane burns whenever it is set
-- alight (paperplane.dm:38, `burn_on_item_ignition`), with no difference test.
function paper_plane.updraft(at: TileAddress): Updraft?
    local lower = sim.map_tile(at, at.x, at.y, at.z - 1)
    if lower == nil then
        return nil
    end
    local below = sim.matter_read(lower.matter)
    local here = sim.matter_read(at.matter)
    if below == nil or here == nil then
        return nil
    end
    local rises = below.temp_k - here.temp_k > THERMAL_RISE_K
    if not rises and below.temp_k < IGNITION_K then
        return nil
    end
    return { below_k = below.temp_k, here_k = here.temp_k }
end

local function hole_key(at: TileAddress): string
    return at.absolute_x .. ":" .. at.absolute_y .. ":" .. at.z
end

local function has_surfed(item: Handle, at: TileAddress): boolean
    local surfed = item.vars[paper_plane.SURFED_VAR]
    if type(surfed) ~= "table" then
        return false
    end
    local key = hole_key(at)
    for _, held in ipairs(surfed) do
        if held == key then
            return true
        end
    end
    return false
end

-- A throw, drop or support loss starts a fresh surf; a slide extends it.
local function mark_surfed(item: Handle, at: TileAddress, cause: ItemFallCause): ()
    local held = item.vars[paper_plane.SURFED_VAR]
    local surfed = {}
    if cause == "slide" and type(held) == "table" then
        for _, key in ipairs(held) do
            table.insert(surfed, key)
        end
    end
    table.insert(surfed, hole_key(at))
    item.vars[paper_plane.SURFED_VAR] = surfed
end

-- A folded plane over rising warm air stays aloft instead of falling, but a
-- slide that settles it on a hole it already surfed (a wall or a bounce
-- brought it back) ends the surf: it falls, so heat cannot loop it.
function paper_plane.rides_thermal(ev: ItemFallPayload): boolean
    if not paper_plane.is_folded(ev.item) or paper_plane.updraft(ev.at) == nil then
        return false
    end
    return not (ev.cause == "slide" and has_surfed(ev.item, ev.at))
end

local function say(at: TileAddress, key: string): ()
    sim.message.broadcast({
        at = at,
        radius = VISIBLE_RADIUS,
        message = sim.msg(key, {}),
    })
end

local function set_heading(item: Handle, x: number, y: number): ()
    local vars = item.vars
    if vars[paper_plane.HEADING_X_VAR] ~= x or vars[paper_plane.HEADING_Y_VAR] ~= y then
        vars[paper_plane.HEADING_X_VAR] = x
        vars[paper_plane.HEADING_Y_VAR] = y
    end
end

-- Forget the heading and the holes surfed: a plane picked up starts over.
function paper_plane.forget(item: Handle): ()
    set_heading(item, 0, 0)
    if item.vars[paper_plane.SURFED_VAR] ~= nil then
        item.vars[paper_plane.SURFED_VAR] = nil
    end
end

-- Alight: the flame picture, then ash on the tile it burns out over.
local function ignite(item: Handle, at: TileAddress): ()
    set_heading(item, 0, 0)
    sim.appearance.set_state({ entity = item, state = paper_plane.ONFIRE_STATE })
    say(at, "lunatic/tfs:lib.paper_plane.ignites")
    sim.spawn_task(item, function()
        sim.sleep(sim.ticks(BURN_SECONDS))
        local rest = if item.alive then item.tile else nil
        -- Picked up or stowed meanwhile: there is no tile to burn out over.
        if rest == nil then
            return
        end
        sim.matter.deposit({
            owner = rest.matter,
            substance = "ash",
            moles = ASH_MOLES,
            temp_k = residue_kinds.ash_temp_k,
        })
        sim.entity.despawn({ entity = item })
        say(rest, "lunatic/tfs:lib.paper_plane.burns_out")
    end)
end

-- `item.fall.done` on the paper definition: a plane that stayed on an
-- updraft is shoved on along its heading (and keeps it for the next ask),
-- or burns when the air below is hot enough. Every other outcome forgets
-- the heading. The shove and its broadcast happen once per hole surfed.
function paper_plane.on_fall_done(ev: ItemFallDonePayload): ()
    local item = ev.item
    local lift = if not ev.fell and paper_plane.is_folded(item)
        then paper_plane.updraft(ev.at)
        else nil
    if lift == nil then
        paper_plane.forget(item)
        return
    end
    if lift.below_k >= IGNITION_K then
        ignite(item, ev.at)
        return
    end
    -- A refused fall also stays: it is not a surf, so no second shove.
    local step = heading(ev)
    if step == nil or (ev.cause == "slide" and has_surfed(item, ev.at)) then
        return
    end
    set_heading(item, step.x, step.y)
    mark_surfed(item, ev.at, ev.cause)
    say(ev.at, "lunatic/tfs:lib.paper_plane.rides")
    sim.force.directed({
        target = item,
        direction_x = step.x,
        direction_y = step.y,
        strength = PUSH_STRENGTH,
        duration_seconds = PUSH_SECONDS,
    })
end

return paper_plane
