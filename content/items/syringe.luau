-- The syringe: fifteen millilitres of glass with a needle on it, and
-- the only thing on the station that reaches INTO somebody. tg's
-- `/obj/item/reagent_containers/syringe`
-- (code/modules/reagents/reagent_containers/syringes.dm:1-24,49-144).
--
-- Two gestures, and they are the same transfer with the ends swapped
-- (docs/LUAU-API.md 8.2). What you pointed at may be a vessel or a
-- crewman, because a bloodstream is a vessel like any other
-- (docs/BENCH.md 2), so there is no second code path for blood -- but
-- there ARE two WORDS, because pushing a dose through a needle into
-- somebody is not the same thing to have done as filling a beaker. The
-- inject direction is `sim.matter.inject` into a body and
-- `sim.matter.pour` into a vessel; the row on the record says which,
-- and an admin reading a shift back can tell them apart. Drawing is
-- the generic `sim.matter.transfer` in both directions: a syringe
-- SUCKS, which is not one of the five gestures and is not pretending
-- to be.
--
-- WHICH WAY ROUND is a per-instance dial rather than a second mouse
-- button. tg splits the directions across primary and secondary click
-- (`interact_with_atom` injects at syringes.dm:49,
-- `interact_with_atom_secondary` draws at :109); this engine hands
-- content ONE click, so the direction is `modes = 2` -- the same
-- anonymous dial the cable coil picks its layer with -- flipped by
-- activating the syringe in hand, and said out loud when it flips. It
-- is not on the examine pane because there is no examine hook to put
-- it there (docs/WIKI.md 3.1); the sentence when you turn it is the
-- whole announcement.
--
-- A PATIENT WHO IS NOT YOU IS A WAIT. tg holds the user still for
-- `CHEM_INTERACT_DELAY(3 SECONDS)` before either direction lands on
-- anybody but themselves (syringes.dm:78,124) and asks nothing about
-- whether that patient is awake, so neither does this. The wait is the
-- engine's `do_after`, whose guard rechecks every tick that the user is
-- alive, still holding this syringe and still in reach of the tile the
-- gesture started on -- and reach to the PATIENT is rechecked here
-- after the yield as well, because that guard watches a tile and a
-- crewman walks.
local U = 0.025

-- Where the dial's two positions point. 0 is the mint, because an empty
-- syringe has nothing to inject and filling it is the first thing
-- anybody does with one.
local DRAW, INJECT = 0, 1

local content = {
    id = "syringe",
    name = "syringe",
    sprite = "syringe",
    inhand_sprite = { "held_syringe_l", "held_syringe_r" },
    examine = {
        flavor = "A glass barrel with a plunger and a very fine needle. "
            .. "Fifteen millilitres, and every one of them goes somewhere "
            .. "that matters.",
    },
    -- tg's `volume = 15` (syringes.dm:12). The barrel is the shell and
    -- the shell is the whole of what it holds (docs/MATTER.md 5).
    volume_ml = 15,
    -- A needle is not a mouth. tg's syringe carries no OPENCONTAINER
    -- flag, so nothing evaporates out of one standing on a bench and
    -- nothing condenses into it; what is drawn stays drawn until it is
    -- pushed somewhere.
    sealed = true,
    -- A needle is a sharp thing, and `sim.matter.inject` will not push
    -- a dose through anything that is not one (docs/LUAU-API.md 8.2).
    -- It carries no force, so no operation whose implement filter asks
    -- for one admits it (docs/SURGERY.md 6.2).
    sharp = "pointy",
    modes = 2,
    mode = DRAW,
    -- What the barrel shows. tg draws the fill from the shared fill
    -- sheet by ABSOLUTE units -- `"syringe[get_rounded_vol()]"` over
    -- the stops 0, 1, 5, 10, 15 (syringes.dm:172-176) -- and this
    -- engine's ladder is per cent of the shell, so tg's four pictures
    -- land at 1/15, 5/15, 10/15 and 15/15 of fifteen millilitres.
    fill_sprites = {
        { 1, "syringe_fill_1" },
        { 33, "syringe_fill_5" },
        { 66, "syringe_fill_10" },
        { 100, "syringe_fill_15" },
    },
    -- Clicking another loose vessel has to reach this hook rather than
    -- picking it up: drawing is a thing you do TO the thing you named.
    acts_on_items = true,
}

-- One stroke of the plunger: tg's `amount_per_transfer_from_this = 5`
-- (syringes.dm:11) through the documented dose bridge of
-- 1 u = 0.025 mol (docs/CHEMISTRY.md 4).
local STROKE = 5 * U

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- Both questions come off the one reading every body of matter
    -- answers (docs/LUAU-API.md 7): how much is in it, and how much room
    -- is left. `headspace_l` is the shell minus what the condensed
    -- phases actually take up, so "full" is a VOLUME fact and never a
    -- count of moles -- capacity is geometry (D2). Word for word what
    -- every other vessel asks, so they are asked in one place
    -- (`lib/vessel.luau`); the syringe's GESTURE stays its own, because
    -- a stroke with a direction is not a pour.
    local moles_in, free_l = vessel.moles, vessel.headspace_l

    -- The one transfer, pointed whichever way the dial says, and said
    -- with the word the far end deserves: `into_body` is true when what
    -- was pointed at is a crewman. Answers false with the refusal
    -- already spoken.
    local function stroke(self, user, other, mode, into_body)
        if mode == DRAW then
            if (free_l(self) or 0) <= 1e-9 then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.syringe.the_syringe_is_full", {}),
                })
                return false
            end
            if (moles_in(other) or 0) < 1e-9 then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.syringe.there_is_nothing_there_to", {}),
                })
                return false
            end
            sim.matter.transfer({
                from = other,
                to = self,
                amount = STROKE,
                phases = { "liquid", "solid" },
            })
            return true
        end
        assert(mode == INJECT, "the dial has two positions")
        if (moles_in(self) or 0) < 1e-9 then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.syringe.the_syringe_is_empty", {}),
            })
            return false
        end
        if (free_l(other) or 0) <= 1e-9 then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.syringe.there_is_no_room_in", {}),
            })
            return false
        end
        if into_body then
            -- Through the needle, which is this syringe: `by` is what
            -- the engine checks for a declared sharpness.
            sim.matter.inject({ from = self, into = other, by = self, amount = STROKE })
        else
            sim.matter.pour({ from = self, to = other, amount = STROKE })
        end
        return true
    end

    -- Activating it in hand turns the dial round: tg's two mouse
    -- buttons as one keypress, the way cable_coil.luau flattens tg's
    -- radial layer menu.
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = sim.mode(self)
        local next_index = (dial.index + 1) % dial.count
        sim.set_mode(self, next_index)
        if next_index == DRAW then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.syringe.you_set_the_syringe_to", {}),
            })
        else
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.syringe.you_set_the_syringe_to_2", {}),
            })
        end
        return true
    end)

    -- A vessel you pointed at: draw out of it, or push into it.
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice, _target = x, y, choice, target
        if clicked == nil or clicked.entity == nil then
            return { replaced = false } -- bare deck is not a syringe's business
        end
        if sim.matter_read(clicked.entity) == nil then
            return { replaced = false } -- not something that holds anything
        end
        local mode = sim.mode(self).index
        if not stroke(self, user, clicked.entity, mode, false) then
            return true
        end
        if mode == DRAW then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.syringe.you_fill_the_syringe", {}),
            })
        else
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.syringe.you_empty_the_syringe_into", {}),
            })
        end
        return true
    end)

    -- A crewman you pointed at. A syringe is not a surgical tool and
    -- carries no force, so this arrives as an ordinary armed click on a
    -- mob (docs/LUAU-API.md 9, step 4) with `ev.refusal` empty -- and
    -- answering it here is exactly what stops the click becoming a
    -- swing.
    script_definition:handle("attack.swing", { kind = "replace", route = "attack" }, function(ev)
        local self, user = ev.implement, ev.actor
        local target, victim, item = ev.target, ev.target, ev.target
        local info = { surgery_refusal = ev.refusal }
        local _self, _target, _item, _info = self, target, item, info
        if victim == nil or sim.body(victim) == nil then
            return { replaced = false } -- not a body; let the click mean something else
        end
        local mode = sim.mode(self).index
        -- Yourself is immediate, which is the whole of tg's condition
        -- (`if(living_target != user)`, syringes.dm:77,122).
        if victim == user then
            if stroke(self, user, victim, mode, true) then
                if mode == DRAW then
                    sim.message.send({
                        recipient = user,
                        message = sim.msg("lunatic/tfs:items.syringe.you_draw_a_sample_from", {}),
                    })
                else
                    sim.message.send({
                        recipient = user,
                        message = sim.msg("lunatic/tfs:items.syringe.you_inject_yourself", {}),
                    })
                end
            end
            return true
        end
        -- Anybody else: refuse before the wait if the barrel cannot do
        -- the job at all, then hold still for three seconds.
        if mode == DRAW then
            if (free_l(self) or 0) <= 1e-9 then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.syringe.the_syringe_is_full_2", {}),
                })
                return true
            end
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.syringe.you_start_taking_a_sample", {}),
            })
        else
            if (moles_in(self) or 0) < 1e-9 then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.syringe.the_syringe_is_empty_2", {}),
                })
                return true
            end
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.syringe.you_line_the_needle_up", {}),
            })
        end
        sim.spawn_task(user, function()
            -- tg's `CHEM_INTERACT_DELAY(3 SECONDS)` (syringes.dm:78).
            if sim.do_after(user, sim.ticks(3.0), {}) == "interrupted" then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.syringe.the_needle_comes_away", {}),
                })
                return true
            end
            -- The guard watched the TILE this started on; the patient
            -- walks. Revalidate against where they are NOW, and that
            -- they are still a body at all.
            if sim.body(victim) == nil then
                return true
            end
            local ux, uy = user.tile.x, user.tile.y
            local vx, vy = victim.tile.x, victim.tile.y
            if math.abs(ux - vx) > 1 or math.abs(uy - vy) > 1 then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.syringe.they_are_out_of_reach", {}),
                })
                return true
            end
            if not stroke(self, user, victim, mode, true) then
                return true
            end
            if mode == DRAW then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.syringe.sampled", {
                        victim = victim.name,
                    }),
                })
            else
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.syringe.injected", {
                        victim = victim.name,
                    }),
                })
            end
            sim.message.send({
                recipient = victim,
                message = sim.msg("lunatic/tfs:items.syringe.you_feel_a_needle_go", {}),
            })
            return true
        end)
        return true
    end)
end

return content
