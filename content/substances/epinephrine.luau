-- Epinephrine: the crash cart in a bottle. It does nothing at all to a
-- crewman who is standing up, and it is the difference between a
-- crewman on the deck and a corpse -- which is tg's own design and the
-- reason its four legs are the longest chain this bench has
-- (reactions/epinephrine.luau).
--
-- WHERE THE NUMBERS COME FROM. The bridge is spelled out in
-- substances/multiver.luau. Epinephrine is not a c2: it metabolizes at
-- `0.25 x REAGENTS_METABOLISM` (medicine_reagents.dm:1018), so its
-- `metabolization_ratio` is 0.25 and a tg line of the form
-- `X x ratio x spt` is `X / 2` per two-second tick.
--
-- tg's line is
--   if(health <= crit_threshold)
--     heal = -1 x ratio x spt          applied to tox, brute, fire, oxy
-- (medicine_reagents.dm:1026-1040): half a point off each of the four
-- pools a tick, and ONLY past the crit line. The rest of tg's hook is
-- stun resistance, `losebreath` and stamina, none of which this engine
-- has a pool for; the healing is the half that ports.
--
-- The crit line is the pack's own, not the engine's: `content/bodies/
-- human.luau` declares a threshold with id `crit`, and the hook reads
-- the SET of crossed lines the same way the body's own handler does
-- (docs/BIOLOGY.md 8). A pack that declares no such line gets a
-- medicine that never fires, which is the right failure.
--
-- Real molar mass (C9H13NO3) and real density -- geometry reads the
-- density when it caps the reaction by the free shell volume (D16) --
-- with the shelf's flat heat capacity and an authored `unmodeled` rest
-- phase (D2, docs/CHEMISTRY.md).
-- tg: /datum/reagent/medicine/epinephrine (medicine_reagents.dm:1014).
local content = {
    id = "epinephrine",
    name = "epinephrine",
    molar_mass = 183.2,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    density = { liquid = 1.28 },
    -- tg's 0.25 x REAGENTS_METABOLISM through this engine's own 0.005
    -- mol a tick: 0.00125. It lasts twice as long as a c2 medicine,
    -- which is what a stabiliser is for.
    metabolism_rate = 0.00125,
    -- What it looks like through glass (tg: medicine_reagents.dm:1017).
    color = "#D2FFFA",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for epinephrine: a cardiac drug, harmful misdosed.
    hazard = { health = 2, fire = 1, instability = 0 },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    -- `mob.life(ctx, self, user, moles)`: the metabolism hook hands
    -- the same mob twice, as the thing the hook is on and as the body
    -- it is happening to, and the moles metabolized this tick last.
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        local mob, _user, moles, _moles = ev.entity, ev.entity, ev.amount, ev.amount
        local down = false
        for _, id in ipairs(sim.body(mob).thresholds) do
            if id == "crit" then
                down = true
            end
        end
        if not down then
            return
        end
        sim.healing.apply({ target = mob, amounts = { brute = 0.5, burn = 0.5, oxy = 0.5, tox = 0.5 } })
        if math.random(1, 10) == 1 then
            sim.message.send({
                recipient = mob,
                message = sim.msg("lunatic/tfs:substances.epinephrine.your_heart_hammers", {}),
            })
        end
    end)
end

return content
