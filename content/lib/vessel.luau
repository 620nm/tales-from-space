-- THE GESTURES A VESSEL HAS, written once.
--
-- A thing you can carry liquid in answers a click in one of four ways,
-- and which one is decided entirely by what the click named:
--
--   1. another vessel within reach -- POUR into it;
--   2. a fixture standing full of gas -- CHARGE off the line, if this
--      vessel is sealed, and a refusal in the dispenser's own words if
--      it is not (docs/BENCH.md 4);
--   3. your own tile -- a SWIG;
--   4. the deck beside you -- TIP IT OUT.
--
-- All four are THE SAME CALL with a different far end
-- (docs/LUAU-API.md 8.2): `sim.matter.transfer({ from, to, amount,
-- phases })`, where the far end is another vessel, a body's blood, or
-- the room over a tile. The trim against what is there and what fits,
-- the reach check, the proportional draw, the energy that travels with
-- the matter and the ledger row are all the engine's; what a vessel
-- decides is which owner is named, how much, and what it says.
--
-- So the only thing that differs from vessel to vessel is a handful of
-- numbers and nouns, which is what `vessel.attach` takes. Six files
-- used to spell this handler out and they had already drifted apart
-- (two of them had lost the sealed-vessel refusal); one implementation
-- cannot drift from itself.
--
-- This file is a `lib/` file: it publishes a table and declares nothing
-- (docs/SCRIPTING.md 1.6). The `sim.define` that binds a behaviour to a
-- prototype happens in the roster file that calls `attach`, so "which
-- file declared this" still answers with a name off the shelf.
local vessel = {}

-- 1 u = 0.025 mol, the documented unit bridge (docs/CHEMISTRY.md 4).
-- Every dose below is written in tg's units and converted here, because
-- every number they came from is a tg number.
local U = 0.025

-- Below this a vessel is empty for the purposes of a gesture: a
-- millimole is under what any glassware shows and under what a mouthful
-- would notice.
local DREGS_MOL = 0.001

-- And above this it is full: a millilitre of room left is under what any
-- gesture could put in it and under what the fill layer would draw.
local HEADSPACE_L = 0.001

-- The gas constant, for the one sum a vessel does for itself: how many
-- moles it takes to stand a headspace up at the pressure the line is
-- holding (PV = nRT).
local R_J_PER_MOL_K = 8.314462618

-- ONE STROKE of the valve. Nothing on the station is anywhere near big
-- enough to want this much -- fifty millilitres at twenty atmospheres is
-- four hundredths of a mole -- so it is a bound on the GESTURE rather
-- than a dial anybody turns: whatever vessel gets authored next, one
-- click cannot walk off with a canister.
local STROKE_MOL = 2.0

-- When the two gauges are close enough to call level. One kilopascal is
-- a hundredth of an atmosphere and under the resolution of anything a
-- crewman reads.
local LEVEL_KPA = 1.0

-- THE TWO READINGS every gesture asks for, off the one reading any body
-- of matter answers (docs/LUAU-API.md 7). Published as well as used
-- here, because a vessel with a gesture of its own -- the syringe --
-- asks the same two questions in the same words.
--
-- How much is in it, in moles: the reading's own total, which is the
-- same sum over the same mixture (sim/owner.rs, `reading`). `nil` for a
-- thing with no inside at all.
function vessel.moles(obj)
    local read = sim.matter_read(obj)
    return read and read.moles
end

-- How much room is left, in litres: the shell minus what the condensed
-- phases actually take up, so "full" is a VOLUME fact and never a count
-- of moles -- capacity is geometry.
function vessel.headspace_l(obj)
    local read = sim.matter_read(obj)
    return read and read.headspace_l
end

local total = vessel.moles

-- THE FOUR TRANSFERS, each behind one call. They are one line apiece on
-- purpose: the engine is growing a verb per gesture over the generic
-- `sim.matter.transfer`, and when it lands each of these becomes that
-- verb without a roster file noticing.
local function do_pour(self, target, amount, _phases)
    -- A pour's overflow is the deck under the far vessel (docs/LUAU-API.md 8.2).
    sim.matter.pour({ from = self, to = target, amount = amount })
end

local function do_sip(self, drinker, amount, _phases)
    sim.matter.drink({ from = self, who = drinker, amount = amount })
end

local function do_spill(self, _at, _phases)
    -- No `at`: a spill names the tile the gesture is happening on.
    sim.matter.spill({ from = self })
end

local function do_charge(self, source, amount)
    sim.matter.fill({ from = source, to = self, amount = amount })
end

-- CHARGING OFF THE LINE, which is a pour with the ends swapped and a
-- different phase named: gas out of the fixture and into the neck. A
-- canister is a body of matter like any other (docs/CHEMISTRY.md 1), so
-- there is no second code path here and no new kind of ledger row.
--
-- Nothing here names a canister. What tells a pour from a charge is the
-- click's own `kind`, which is the engine's word for what got pointed
-- at: an `item` is a vessel somebody is carrying and a `machine` is a
-- fixture bolted to the deck. Any stationary tank answers the same
-- click the same way, because the question this asks is "does that
-- thing hold gas at a pressure", never "is that the one I had in mind".
--
-- THE DEPARTURE FROM TG, stated: tg's canister has no gesture like
-- this. It takes a PORTABLE TANK into a holding slot and meters into it
-- through the release valve (`/obj/machinery/portable_atmospherics` and
-- its window, portable/canister.dm), and tg's chemistry never touches a
-- canister at all because tg's oxygen is a dispenser button. One id per
-- molecule takes that button away, so a vessel has to reach the gas
-- somewhere; holding it against the valve is the shortest honest way to
-- say so, with no slot, no window and no second machine to build.
--
-- WHICH VESSELS: every one of them, and the answer for most is no. A
-- mouth with no stopper in it lets the charge back out on the next
-- exchange, so an open vessel is refused in the same words the
-- dispenser uses over an open glass (docs/BENCH.md 4). The refusal
-- belongs here rather than in each file precisely because half the
-- files that needed it had not got it.
local function charge(spec, self, user, source, at)
    local line = sim.matter_read(source)
    local mine = sim.matter_read(self)
    if line == nil or mine == nil then
        return { replaced = false }
    end
    if not mine.sealed then
        sim.message.send({
            recipient = user,
            message = "That would only escape: seal a vessel first.",
        })
        return true
    end
    -- A valve does not chase the last pascal. Level is level, and saying
    -- so is better than hissing a micromole across every time somebody
    -- clicks -- the two gauges never agree exactly, because the parcel
    -- arrives at the line's temperature and the vessel settles to its
    -- own.
    local head_kpa = line.pressure_kpa - mine.pressure_kpa
    if head_kpa <= LEVEL_KPA then
        sim.message.send({
            recipient = user,
            message = "The " .. spec.noun .. " is already at the line's pressure.",
        })
        return true
    end
    local want = head_kpa * 1000.0 * (mine.headspace_l / 1000.0) / (R_J_PER_MOL_K * line.temp_k)
    do_charge(self, source, math.min(want, STROKE_MOL))
    sim.sound.play({ asset = "lunatic/tfs:sound/spray", at = at })
    sim.message.send({
        recipient = user,
        message = "You hold the " .. spec.noun .. " to the valve until it stops hissing.",
    })
    return true
end

-- Nothing left worth pouring. One sentence for all four gestures,
-- because a vessel is empty or it is not.
local function dregs(spec, self, user)
    if (total(self) or 0) >= DREGS_MOL then
        return false
    end
    sim.message.send({ recipient = user, message = "The " .. spec.noun .. " is empty." })
    return true
end

-- TAKING A PUDDLE UP, which is the tile's own matter drawn into a
-- vessel: the room over a tile is a body of matter like any other
-- (docs/luau-api/matter.md, `ev.at.matter`), so a mop is the transfer
-- with the ends swapped and only the liquid phase named. What fits is
-- the engine's -- the head takes what it takes and the rest stays on the
-- deck -- so the two refusals here are the two states a stroke can find:
-- a vessel with no room in it, and a deck with nothing on it.
local function soak(spec, self, user, at, soak_line, dry_line, full_line)
    if (vessel.headspace_l(self) or 0) <= HEADSPACE_L then
        sim.message.send({ recipient = user, message = full_line })
        return true
    end
    -- What is STANDING there, asked before anything is moved: an effect
    -- lands at the end of the transaction, so a gesture that measured
    -- itself by re-reading its own vessel would measure nothing at all.
    local deck = sim.matter_read(at.matter)
    local standing = 0
    if deck ~= nil then
        for _, entry in pairs(deck.contents) do
            standing = standing + (entry.liquid or 0)
        end
    end
    if standing < DREGS_MOL then
        sim.message.send({ recipient = user, message = dry_line })
        return true
    end
    sim.matter.transfer({ from = at.matter, to = self, amount = "all", phases = { "liquid" } })
    sim.message.send({ recipient = user, message = soak_line })
    return true
end

-- Attaches the gestures to one prototype and declares the behaviour that
-- carries them. `spec`:
--
--   id      the prototype id, which is also the behaviour's own name
--   noun    what the sentences call it ("beaker", "tube", "can")
--   phases  which phases a gesture moves; a dropper draws no solids
--   pour    { units, message? }  -- absent: clicks at things are not
--           this vessel's business, and neither is a charge; `units =
--           "all"` is a vessel that empties itself in one gesture
--   sip     { units, message?, taste? }
--   spill   { message? } or true -- absent: no tipping it out
--   soak    { message?, dry?, full? } -- the deck the OTHER way round:
--           take the liquid on that tile up into this vessel instead of
--           tipping this vessel onto it. Mutually exclusive with
--           `spill`, because a thing cannot both put down and pick up.
--
-- Every message defaults to the vessel's own noun in the sentence every
-- other vessel uses; a file names one only where it says something else.
function vessel.attach(spec)
    local definition = sim.define("behavior", "lunatic/tfs:" .. spec.id, { prototype = spec.id })
    local phases = spec.phases
    local pour_line = spec.pour and (spec.pour.message or ("You pour from the " .. spec.noun .. "."))
    -- A dose in tg's units, or the lot: a mop wrung into a bucket has no
    -- measured stroke, it has a head that comes out.
    local pour_amount = spec.pour and (spec.pour.units == "all" and "all" or spec.pour.units * U)
    local sip_line = spec.sip and (spec.sip.message or ("You drink from the " .. spec.noun .. "."))
    if spec.sip and spec.sip.taste then
        sip_line = sip_line .. " " .. spec.sip.taste
    end
    local spill_line = "You tip the " .. spec.noun .. " out onto the deck."
    if type(spec.spill) == "table" and spec.spill.message ~= nil then
        spill_line = spec.spill.message
    end
    local soak_line = spec.soak and (spec.soak.message
        or ("You take what is on the deck up into the " .. spec.noun .. "."))
    local dry_line = spec.soak and (spec.soak.dry or "There is nothing on the deck here.")
    local full_line = spec.soak and (spec.soak.full or ("The " .. spec.noun .. " will hold no more."))

    definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, at = ev.subject, ev.actor, ev.at
        local clicked = ev.claim

        -- 1 and 2. Something you pointed at.
        if spec.pour ~= nil and clicked ~= nil and clicked.entity ~= nil then
            if total(clicked.entity) == nil then
                return { replaced = false } -- not something that holds anything
            end
            -- A FIXTURE with an inside is a charge and not a pour: you
            -- do not tip a vessel into the station's plumbing.
            if clicked.kind == "machine" then
                return charge(spec, self, user, clicked.entity, at)
            end
            if dregs(spec, self, user) then
                return true
            end
            do_pour(self, clicked.entity, pour_amount, phases)
            sim.message.send({ recipient = user, message = pour_line })
            return true
        end

        -- 3. Your own tile: a swig.
        if spec.sip ~= nil and at.x == user.tile.x and at.y == user.tile.y then
            if dregs(spec, self, user) then
                return true
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/drink", at = at })
            do_sip(self, user, spec.sip.units * U, phases)
            sim.message.send({ recipient = user, message = sip_line })
            return true
        end

        -- 4. The deck beside you, in whichever direction this vessel
        -- goes: a mop takes the puddle up, everything else tips out.
        if spec.spill == nil and spec.soak == nil then
            return { replaced = false }
        end
        local turf = sim.turf(at.x, at.y)
        if turf ~= "floor" and turf ~= "plating" then
            return { replaced = false }
        end
        if spec.soak ~= nil then
            return soak(spec, self, user, at, soak_line, dry_line, full_line)
        end
        if dregs(spec, self, user) then
            return true
        end
        do_spill(self, at, phases)
        sim.message.send({ recipient = user, message = spill_line })
        return true
    end)

    -- A thrown open vessel tips itself out wherever it comes to rest.
    -- The native verb moves all and only condensed phases, conserves
    -- energy with them, validates the standable landing tile, and writes
    -- the attributed `Spilled` row. Every landing is an impact for this
    -- purpose; sealing is the content-visible way to prevent it.
    if spec.spill ~= nil then
        definition:handle("throw.land.done", { kind = "react", route = "land" }, function(ev)
            local reading = sim.matter_read(ev.entity)
            if reading ~= nil and not reading.sealed then
                sim.matter.spill({ from = ev.entity, at = ev.at })
            end
        end)
    end

    return definition
end

return vessel
