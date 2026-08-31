-- The defibrillator: the other way a stopped heart starts again
-- (docs/SURGERY.md §6.8; tg code/game/objects/items/tools/medical/
-- defib.dm).
--
-- Life in this pack is the heart organ (content/items/organ_heart.luau:
-- `vital = true`), and a heart that has stopped is a heart at
-- `max_health` -- FAILING, and unable to heal itself. There are exactly
-- two ways out of that: a new heart in the socket, which is surgery, and
-- this, which is not.
--
-- ONE REFUSAL IS DELIBERATELY INVERTED. tg refuses to shock a failing
-- heart (`DEFIB_FAIL_FAILING_HEART`, carbon.dm:812-822): there, a
-- failing heart is an organ too ruined to restart and the answer is
-- surgery. Here failing IS stopped -- it is the state death puts the
-- heart in -- so a failing heart is the only thing this shock has any
-- business fixing, and refusing it would mean refusing every patient.
-- The refusal tg spends on the heart is spent on the BRAIN instead
-- (`DEFIB_FAIL_FAILING_BRAIN`, :825-835), which is the organ still on a
-- decay clock and therefore the one that can be too far gone.
--
-- WHAT IS NOT PORTED, deliberately: tg's defibrillator is a back-worn
-- unit with detachable paddles you wield in both hands, a cell, a charge
-- meter, a safety, a cooldown and a combat mode (defib.dm:14-45,
-- :312-670). None of that is here. This is the plain gesture the engine
-- already has -- hold the thing, click the patient -- because the
-- paddle apparatus is a whole interaction of its own and is deferred.
-- What IS ported is the part that decides outcomes: `can_defib`'s
-- refusals (code/modules/mob/living/carbon/carbon.dm:784-835), the
-- 5-second charge-and-shock (defib.dm:564-568, 3 s + 2 s), and the
-- three clips that say which of the three things happened.
local content = {
    id = "defib",
    name = "defibrillator",
    sprite = "defib",
    force = 5,             -- defib.dm:16
    -- Not `surgical`: this is not an operation and must not be caught by
    -- the surgical-tool refusal (docs/SURGERY.md §6.3). A defibrillator
    -- with nothing to do is a swing, exactly as tg's is.
}

-- tg's `can_defib` in this pack's own words, in tg's own order
-- (carbon.dm:784-835). Returns nil when the shock should land, and the
-- sentence to say when it should not.
--
-- `DEFIB_FAIL_TISSUE_DAMAGE` (:798) is the one that reads differently
-- here and means the same thing: tg compares brute and burn against
-- MAX_REVIVE_BRUTE_DAMAGE / MAX_REVIVE_FIRE_DAMAGE 180
-- (code/__DEFINES/mobs.dm:554-555), and this plan already has a line
-- for "too hurt to be alive" -- `dead`. Restarting a heart under a body
-- still past that line would revive it into a corpse on the next
-- evaluation, so the refusal is the same refusal.
local function refusal(patient)
    local body = sim.body(patient)
    if body == nil then
        return nil -- not a body at all; the swing is somebody else's business
    end
    if body.animate then
        return "They do not need it: their heart is beating."      -- tg refuses the living
    end
    for _, id in ipairs(body.thresholds) do
        if id == "dead" then
            return "Their injuries are too severe to shock through. Treat them first."
        end
    end
    local heart, brain = nil, nil
    for _, part in pairs(sim.parts(patient)) do
        heart = heart or (part.organs and part.organs.heart or nil)
        brain = brain or (part.organs and part.organs.brain or nil)
    end
    if not heart then
        return "There is no heart in there to restart."             -- DEFIB_FAIL_NO_HEART
    end
    if not brain then
        return "There is nobody left in there to bring back."       -- DEFIB_FAIL_NO_BRAIN
    end
    -- DEFIB_FAIL_FAILING_BRAIN (carbon.dm:830-831), and the reason the
    -- cadaver chamber matters: a brain in a corpse DECAYS
    -- (content/items/organ_brain.luau, half the standard rate), and a
    -- drawer's `preserves` multiplies that decay. The revival window is
    -- therefore a real clock a mapper set, and a preserved cadaver has
    -- no clock at all.
    if sim.organ(brain).failing then
        return "Their brain is too far gone. There is nothing to shock back."
    end
    return nil
end

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("attack.swing", { kind = "replace", route = "attack" }, function(ev)
        local user, patient = ev.actor, ev.target
        if sim.body(patient) == nil then
            return { replaced = false }
        end
        local why = refusal(patient)
        if why ~= nil then
            sim.sound.play({ asset = "lunatic/tfs:sound/defib_failed", at = ev.at })
            sim.message.send({ recipient = user, message = why })
            return true
        end
        sim.message.send({ recipient = user, message = "You charge the defibrillator..." })
        -- `ev` belongs to the occurrence that spawned this task and does
        -- not survive into it (docs/SCRIPTING.md §6: each resume segment
        -- is a separate transaction), so every tile below comes off the
        -- surgeon's own live handle.
        sim.spawn_task(user, function()
            -- 3 s to place the paddles and 2 s of held charge, which is
            -- tg's five seconds end to end (defib.dm:564-568) minus the
            -- pause that exists so bystanders can step clear of the arc.
            -- The patient is the wait's SECOND party: a body effect is
            -- applied without a reach test, so without naming them here
            -- a medic could charge over a patient, have them dragged
            -- three rooms off or stowed in a drawer, and still land the
            -- shock. `options.subject` ends the wait the moment they
            -- stop being in front of the medic (docs/LUAU-API.md §6).
            if sim.do_after(user, sim.ticks(5), { subject = patient }) ~= "ok" then
                sim.sound.play({ asset = "lunatic/tfs:sound/defib_failed", at = user.tile })
                sim.message.send({ recipient = user, message = "The paddles slip." })
                return
            end
            -- Everything is revalidated: five seconds is long enough for
            -- the patient to have been moved, opened, or shocked by
            -- somebody else.
            local still = refusal(patient)
            if still ~= nil then
                sim.sound.play({ asset = "lunatic/tfs:sound/defib_failed", at = user.tile })
                sim.message.send({ recipient = user, message = still })
                return
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/defib_zap", at = user.tile })
            -- The shock itself: it takes the heart out of failure and
            -- nothing else. It does not heal a part, close a wound or
            -- clear a threshold -- if the body is otherwise fit to live,
            -- the engine's own `viability` says so on this write and the
            -- plan's hook says the word.
            for _, part in pairs(sim.parts(patient)) do
                if part.organs and part.organs.heart then
                    sim.heal_organ(patient, "heart", sim.organ(part.organs.heart).max)
                end
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/defib_success", at = user.tile })
            sim.message.send({ recipient = user, message = "The patient's heart restarts." })
        end)
        return true
    end)
end

return content
