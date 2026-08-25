-- The bottle: fifty units with a neck on it. Same size as the beaker
-- and a different shape of thing to carry it in -- a beaker is what you
-- mix in and a bottle is what you put on a shelf afterwards.
--
-- The shell is tg's `volume = 50`, and the shell is the whole of what
-- it holds; the picture and the fill prefix are both tg's `bottle`
-- (bottle.dm:6-7; `volume = 50` at :12, `fill_icon_thresholds` at
-- :13).
--
-- The three gestures are the vessel's rather than the beaker's: your
-- own tile is a swig, another vessel within reach is a pour, the deck
-- is a spill. (Content files cannot `require` one another, so each one
-- spells them out; see card.luau on the same tradeoff.)
--
-- The FOURTH is the one only a corked vessel has: held against a
-- fixture that is standing full of gas, it charges instead of pouring.
-- That is where the permanent gases enter chemistry at all -- oxygen,
-- nitrogen, hydrogen and fluorine left the dispenser shelf when the
-- twins were folded, because a press of one over an open glass is a
-- press into the room (docs/BENCH.md 4) -- and it is what makes
-- the gas-share recipes reachable: carbon dioxide wants fifty
-- kilopascals of oxygen over its carbon, nitrous oxide a hundred over
-- its ammonia, and no beaker on the bench can carry either.
local U = 0.025

-- The gas constant, for the one sum this file does for itself: how
-- many moles it takes to stand this vessel's headspace up at the
-- pressure the line is holding (PV = nRT). Everything else about the
-- transfer -- the reach, the trim against what is actually there, the
-- proportional draw, the energy that travels with it and the row --
-- is the engine's (docs/LUAU-API.md 8.2).
local R_J_PER_MOL_K = 8.314462618

-- ONE STROKE of the valve. Nothing on the station is anywhere near big
-- enough to want this much -- fifty millilitres at twenty atmospheres
-- is four hundredths of a mole -- so it is a bound on the GESTURE
-- rather than a dial anybody turns: whatever vessel gets authored
-- next, one click cannot walk off with a canister.
local STROKE_MOL = 2.0

-- When the two gauges are close enough to call level. One kilopascal
-- is a hundredth of an atmosphere and under the resolution of anything
-- a crewman reads.
local LEVEL_KPA = 1.0

local content = {
    id = "bottle",
    name = "bottle",
    sprite = "bottle",
    examine = {
        flavor = "Glass with a neck on it, made for carrying rather than "
            .. "mixing. What ends up on the shelf.",
    },
    -- tg's bottle: `volume = 50` (cups/bottle.dm:12), the cup base's
    -- own figure. One unit is one millilitre.
    volume_ml = 50,
    -- A neck has a stopper in it. What a shelf keeps is corked, so what
    -- is in it stays in it: a bottle does not breathe with the room the
    -- way an open beaker does, and what ferments inside one builds a
    -- pressure of its own (docs/BENCH.md 2). Pouring, drinking and
    -- spilling are all you pulling the cork, and none of them asks
    -- about the lid -- the seal is what the bottle does while nobody is
    -- handling it.
    sealed = true,
    fill_sprites = {
        { 1, "bottle_fill_1" },
        { 20, "bottle_fill_20" },
        { 40, "bottle_fill_40" },
        { 60, "bottle_fill_60" },
        { 80, "bottle_fill_80" },
        { 100, "bottle_fill_100" },
    },
    acts_on_items = true,
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- CHARGING OFF THE LINE, which is a pour with the ends swapped and
    -- a different phase named: `phases = { "gas" }` out of the fixture
    -- and into the neck. A canister is a body of matter like any other
    -- (docs/CHEMISTRY.md 1), so there is no second code path here and
    -- no new ledger row -- what lands is the ordinary `poured` the two
    -- owners decide.
    --
    -- Nothing here names a canister. What tells a pour from a charge is
    -- the click's own `kind`, which is the engine's word for what got
    -- pointed at: an `item` is a vessel somebody is carrying and a
    -- `machine` is a fixture bolted to the deck. A stationary tank
    -- answers the same click the same way, because the question this
    -- asks is "does that thing hold gas at a pressure", never "is that
    -- the bottle I had in mind".
    --
    -- THE DEPARTURE FROM TG, stated: tg's canister has no gesture like
    -- this. It takes a GAS TANK into a holding slot and meters into it
    -- through the release valve (`/obj/machinery/portable_atmospherics`
    -- and its window, portable/canister.dm), and tg's chemistry never
    -- touches a canister at all because tg's oxygen is a dispenser
    -- button. One id per molecule takes that button away, so a bottle
    -- has to reach the gas somewhere; holding it against the valve is
    -- the shortest honest way to say so, with no slot, no window and no
    -- second machine to build.
    local function charge(self, user, source, at)
        local line = sim.matter_read(source)
        local mine = sim.matter_read(self)
        if line == nil or mine == nil then
            return { replaced = false }
        end
        -- An open mouth is refused in the dispenser's own words: what
        -- landed would leave through it on the next exchange, and the
        -- honest answer is to say so rather than to bill a mole nothing
        -- can account for a tick later (docs/BENCH.md 4).
        if not mine.sealed then
            sim.message.send({
                recipient = user,
                message = "That would only escape: seal a vessel first.",
            })
            return true
        end
        -- A valve does not chase the last pascal. Level is level, and
        -- saying so is better than hissing a micromole across every
        -- time somebody clicks -- the two gauges never agree exactly,
        -- because the parcel arrives at the line's temperature and the
        -- vessel settles to its own.
        local head_kpa = line.pressure_kpa - mine.pressure_kpa
        if head_kpa <= LEVEL_KPA then
            sim.message.send({
                recipient = user,
                message = "The bottle is already at the line's pressure.",
            })
            return true
        end
        local want = head_kpa
            * 1000.0
            * (mine.headspace_l / 1000.0)
            / (R_J_PER_MOL_K * line.temp_k)
        sim.matter.transfer({
            from = source,
            to = self,
            amount = math.min(want, STROKE_MOL),
            phases = { "gas" },
        })
        sim.sound.play({ asset = "lunatic/tfs:sound/spray", at = at })
        sim.message.send({
            recipient = user,
            message = "You hold the bottle to the valve until it stops hissing.",
        })
        return true
    end

    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        -- What is in it, in moles: the reading's own total, which is
        -- the same sum over the same mixture (sim/owner.rs, `reading`).
        -- `nil` for a thing with no inside at all.
        local function total(obj)
            local read = sim.matter_read(obj)
            return read and read.moles
        end

        if clicked ~= nil and clicked.entity ~= nil then
            if total(clicked.entity) == nil then
                return { replaced = false }
            end
            -- A fixture with an inside is a CHARGE and not a pour: you
            -- do not tip a bottle into the station's plumbing.
            if clicked.kind == "machine" then
                return charge(self, user, clicked.entity, ev.at)
            end
            if (total(self) or 0) < 0.001 then
                sim.message.send({ recipient = user, message = "The bottle is empty." })
                return true
            end
            -- tg's cup default `amount_per_transfer_from_this = 10`
            -- (_cup.dm:4), which is also the beaker's gesture.
            sim.matter.transfer({
                from = self,
                to = clicked.entity,
                amount = 10 * U,
                phases = { "liquid", "solid" },
            })
            sim.message.send({ recipient = user, message = "You pour from the bottle." })
            return true
        end

        local px, py = user.tile.x, user.tile.y
        if x == px and y == py then
            if (total(self) or 0) < 0.001 then
                sim.message.send({ recipient = user, message = "The bottle is empty." })
                return true
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/drink", at = ev.at })
            sim.matter.transfer({
                from = self,
                to = user,
                amount = 2 * U,
                phases = { "liquid", "solid" },
            })
            sim.message.send({ recipient = user, message = "You drink from the bottle." })
            return true
        end

        local turf = sim.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" then
            return { replaced = false }
        end
        if (total(self) or 0) < 0.001 then
            sim.message.send({ recipient = user, message = "The bottle is empty." })
            return true
        end
        sim.matter.transfer({
            from = self,
            to = ev.at.matter,
            amount = "all",
            phases = { "liquid", "solid" },
        })
        sim.message.send({ recipient = user, message = "You tip the bottle out onto the deck." })
        return true
    end)
end

return content
