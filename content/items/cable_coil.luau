-- Repairs what the wirecutters undo, one PIECE at a time, on whichever
-- of the station's three power lines you have the coil set to.
--
-- A reel is 30 lengths, tg's coil size. That count is what lets a
-- machine frame ask for five of them: wiring an assembly is a
-- structure transition, and transitions spend stacks.
--
-- Laying cable is NOT a structure transition -- there is nothing on the
-- tile that owns the answer -- so it stays an interaction.use hook, which the
-- interpreter falls through to when no table names this item.
--
-- Cable goes UNDER the deck, so the tile has to be open -- the same rule
-- pipe.luau states, and for the same tg reason (a covered turf hides its
-- contents: code/game/turfs/turf.dm:503-506). Unlike the cutters, this
-- refusal SPEAKS: you are placing something you are holding onto a floor
-- you can see, so the message describes the floor and gives away nothing
-- about what may already be buried.
--
-- THE LINES. tg has three cable colours and they are the real thing:
-- two pieces join only when their colours match, so three runs can share
-- a tile and be three separate circuits. tg's own names for them are
-- "Red/Yellow/Blue Power Line" (__DEFINES/power.dm:5,8,11), and its coil
-- recolours itself to match whichever you picked
-- (cable.dm:596,602,608).
--
-- THE GESTURE is tg's, and it is two procs which this one hook is both
-- of: `place_turf` (a click on open deck) and `cable_join` (a click on a
-- piece already down) -- old `code/modules/power/cable.dm:593-700` at
-- 65e9888fa60^, kept alive today as
-- `code/modules/power/pipecleaners.dm:311-440`. One rule runs under
-- both: A PIECE POINTS AT ITS ELECTRICIAN. Every piece a click lays runs
-- towards where you are standing, so walking a corridor and clicking the
-- tile ahead draws the wire out behind you, and clicking the same piece
-- a second time walks it onto your own tile.
local LINES = {
    { mask = 1, name = "the red power line" },
    { mask = 2, name = "the yellow power line" },
    { mask = 4, name = "the blue power line" },
}

local function line_of(mask)
    for _, line in ipairs(LINES) do
        if line.mask == mask then
            return line
        end
    end
    return nil
end

-- BYOND's direction bits, the alphabet a piece is spelled in and the art
-- is named for (docs/POWER.md). A diagonal is the two halves OR'd
-- together, which is why turning one around costs nothing.
local N, S, E, W = 1, 2, 4, 8

local function has(mask, bit)
    return mask % (bit * 2) >= bit
end

-- tg's REVERSE_DIR: north and south trade places, east and west trade
-- places, and every diagonal falls out of the pair.
local function reverse(d)
    local out = 0
    if has(d, N) then out = out + S end
    if has(d, S) then out = out + N end
    if has(d, E) then out = out + W end
    if has(d, W) then out = out + E end
    return out
end

-- BYOND's `get_dir(from, to)`: the eight-way bearing from one tile to
-- another, and 0 for the same tile. North is -y, the way the map is
-- indexed and the way tg's art names survive the port.
local function get_dir(fx, fy, tx, ty)
    local d = 0
    if ty < fy then
        d = d + N
    elseif ty > fy then
        d = d + S
    end
    if tx > fx then
        d = d + E
    elseif tx < fx then
        d = d + W
    end
    return d
end

local function piece_at(x, y, colour, d1, d2)
    for _, piece in ipairs(sim.cable_segments(x, y)) do
        if piece.colour == colour and piece.d1 == d1 and piece.d2 == d2 then
            return true
        end
    end
    return false
end

-- Any piece of this colour with an END pointing `d`, knot or length --
-- tg's `LC.d1 == fdirn || LC.d2 == fdirn` guard (pipecleaners.dm:395).
-- Two pieces reaching for one edge would be one wire drawn twice.
local function reaches(x, y, colour, d)
    for _, piece in ipairs(sim.cable_segments(x, y)) do
        if piece.colour == colour and (piece.d1 == d or piece.d2 == d) then
            return true
        end
    end
    return false
end

local ALREADY = "There's already a cable at that position."

-- What this click WOULD do, read off the live sim: one action, or one
-- refusal to say out loud. Asked twice -- once to decide whether the job
-- is worth starting, once when the second it takes is up -- so nothing
-- about the world is remembered across the wait.
local function plan(self, user, x, y, claim)
    local line = LINES[sim.mode(self).index + 1]
    local ux, uy = user.tile.x, user.tile.y
    local on_top = ux == x and uy == y
    local aimed = claim ~= nil and claim.kind == "cable" and claim.d2 ~= nil

    -- tg `cable_join`: a click on a piece under your own feet implies no
    -- direction at all, so it falls straight through to `place_turf` and
    -- the facing decides (pipecleaners.dm:371-373).
    if aimed and not on_top then
        if not piece_at(x, y, claim.layer, claim.d1, claim.d2) then
            return nil, "The cable you were working on is gone."
        end
        local dirn = get_dir(x, y, ux, uy)
        if claim.d1 == dirn or claim.d2 == dirn then
            -- The piece points AT YOU, so tg grows the run one tile
            -- closer: a knot on your own tile facing back at it
            -- (pipecleaners.dm:383-405). A NEW piece, so the dial says
            -- what it is made of.
            local back = reverse(dirn)
            if not sim.subfloor_exposed(ux, uy) then
                return nil, "The floor under your feet is in the way. Pry that tile up first."
            end
            if reaches(ux, uy, line.mask, back) then
                return nil, ALREADY
            end
            return { x = ux, y = uy, colour = line.mask, name = line.name, d1 = 0, d2 = back }
        end
        if claim.d1 == 0 then
            -- A KNOT GROWS INTO A LENGTH: its edge and your bearing
            -- become the two ends, smallest first
            -- (pipecleaners.dm:408-437). tg edits the clicked object, so
            -- the piece keeps ITS colour and the dial gets no say -- a
            -- yellow coil extending a red knot would otherwise part a
            -- red circuit and hand back a yellow one.
            local nd1, nd2 = claim.d2, dirn
            if nd1 > nd2 then
                nd1, nd2 = nd2, nd1
            end
            if piece_at(x, y, claim.layer, nd1, nd2) then
                return nil, ALREADY
            end
            local grown = line_of(claim.layer)
            return {
                x = x,
                y = y,
                colour = claim.layer,
                name = grown ~= nil and grown.name or line.name,
                d1 = nd1,
                d2 = nd2,
                cut = claim.d2,
            }
        end
        -- A length that neither points at you nor is a knot. tg stops
        -- here and the click is dead; this falls through to the knot the
        -- same click on open deck would lay, so aiming at a wire is
        -- never worse than aiming beside it.
    end

    -- tg `place_turf` (pipecleaners.dm:311-351): on your own tile the
    -- piece runs the way you are facing, and anywhere else it runs back
    -- towards you.
    local dirn = on_top and user.facing or get_dir(x, y, ux, uy)
    if dirn == nil or dirn == 0 then
        return nil, nil
    end
    -- tg refuses only a KNOT already reaching that way: a length
    -- crossing the tile does not stop you tying one down beside it,
    -- which is how a run that merely passes under a socket is given the
    -- node that feeds it (docs/POWER.md).
    if piece_at(x, y, line.mask, 0, dirn) then
        return nil, ALREADY
    end
    return { x = x, y = y, colour = line.mask, name = line.name, d1 = 0, d2 = dirn }
end

local content = {
    id = "cable_coil",
    name = "cable coil",
    sprite = "coil",
    inhand_sprite = { "held_coil_l", "held_coil_r" },
    stack = 30,
    -- This IS the station's cable: what a run under the deck is made
    -- of, and therefore what cutting one hands back. One field, both
    -- directions -- the engine floods the powernet and never learns
    -- that the thing you lay it with is called a coil.
    subfloor = "cable",
    -- Three settings, minted on the second: tg's coil defaults to
    -- CABLE_LAYER_2 (cable.dm:513), which is the line the shipped
    -- station runs its backbone on.
    modes = 3,
    mode = 1,
    -- tg's "Use it in hand to change the layer you are placing on"
    -- (cable.dm:529). tg pops a radial menu there (cable.dm:589); we
    -- have no radial widget, so this cycles and says where it landed,
    -- which is the same information in one keypress instead of two.
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = sim.mode(self)
        local next_index = (dial.index + 1) % dial.count
        sim.set_mode(self, next_index)
        sim.message.send({ recipient = user, message = "You set the coil to " .. LINES[next_index + 1].name .. "." })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        -- Asked first, so every covered tile answers the same way and
        -- the reply is not a probe for what is already buried. Open
        -- deck, not "plating": the map decides per tile.
        if not sim.subfloor_exposed(x, y) then
            sim.message.send({ recipient = user, message = "The floor is in the way. Pry the tile up first." })
            return true
        end
        local action, refusal = plan(self, user, x, y, target)
        if action == nil then
            if refusal ~= nil then
                sim.message.send({ recipient = user, message = refusal })
            end
            return { replaced = false }
        end
        sim.message.send({ recipient = user, message = "You start laying cable..." })
        sim.spawn_task(user, function()
            if sim.do_after(user, sim.ticks(1.0), {}) == "interrupted" then
                sim.message.send({ recipient = user, message = "You stop laying cable." })
                return true
            end
            -- The whole question again at the end, never the answer from
            -- the start: while you worked, another engineer may have
            -- cabled that tile or cut the piece you aimed at, and
            -- nothing stopped you turning the dial either.
            if not self.alive then
                return true
            end
            local again, why = plan(self, user, x, y, target)
            if again == nil then
                if why ~= nil then
                    sim.message.send({ recipient = user, message = why })
                end
                return true
            end
            if again.cut ~= nil then
                -- The knot comes up and the longer piece goes down. tg
                -- reshapes the object in place; the engine's cut hands a
                -- length back for what it lifts, so the old knot lands
                -- at your feet as a one-length coil.
                sim.cut_cable(again.x, again.y, again.colour, 0, again.cut)
            end
            sim.lay_cable(again.x, again.y, again.colour, again.d1, again.d2)
            -- tg's `use(1)`: one length per piece, whether the piece is
            -- new or the longer replacement for a knot.
            self:consume()
            if again.cut ~= nil then
                sim.message.send({ recipient = user, message = "You run " .. again.name .. " out across the deck." })
            else
                sim.message.send({ recipient = user, message = "You lay cable on " .. again.name .. "." })
            end
        end)
        return true
    end)
end

return content
