-- BLOOD HARMONY: what a body does about its own blood, once a pass.
--
-- The engine holds blood as moles of the `blood` substance in the
-- chest's bloodstream and does exactly one thing to it: it bleeds
-- (docs/biology/blood.md). Everything else a tg body does about blood is
-- here, bound to the human plan's `mob.life` on the `lifecycle` route,
-- which the engine fires once per ANIMATE body per metabolism pass. A
-- stopped body hears nothing, so a body the pack stopped because it bled
-- out does not climb back over the line on its own.
--
-- Two jobs, in order:
--
-- 1. Harmony. Below the plan's normal blood the body makes more, at tg's
--    regeneration rate scaled by how well its heart works; above normal
--    (a transfusion, a dose of blood) the excess is drawn back out in one
--    pass, by choice: the pack settles a transfusion at the next body
--    cadence rather than metabolizing it down over time. Only the `blood`
--    substance is touched: a dose riding in the same bloodstream is never
--    taken.
-- 2. The missing-blood oxygen cost, tg's own rule.
--
-- Every tg unit here is a centilitre and 0.025 mol
-- (docs/chemistry/tg-bridge.md), so each tg figure is carried x 0.025.
local blood_identity = require("@lib/blood_identity")

local blood_harmony = {}

-- 1 tg-u := 0.025 mol.
local U = 0.025

-- The substance a plan's `blood` block names; the TfS plan names this one.
local BLOOD = "blood"

-- BLOOD_REGEN_FACTOR 0.25 u per second (code/__DEFINES/mobs.dm:28), the
-- first term of the restore at code/modules/mob/living/blood.dm:172-173,
-- scaled by the heart (:164) and capped at normal (:173).
local REGEN_PER_S = 0.25 * U

-- BODYTEMP_NORMAL (code/__DEFINES/atmospherics/atmos_mob_interaction.dm:53),
-- the figure the bloodstream holder is declared at.
local BLOOD_TEMP_K = 310.15

-- code/modules/mob/living/blood.dm:261: `round(0.01 * (BLOOD_VOLUME_NORMAL
-- - modified_blood_volume), 0.25)`, a second. 0.01 oxygen loss per missing
-- unit is 0.01 / 0.025 = 0.4 per missing mole.
local OXY_PER_MISSING_MOLE = 0.01 / U
-- ...rounded to the quarter that call names.
local OXY_QUANTUM = 0.25
-- OXYLOSS_PASSOUT_THRESHOLD (code/__DEFINES/mobs.dm:14): past this much
-- of the blood gone, an unconscious bleeder keeps paying (blood.dm:259).
local OXYLOSS_PASSOUT_THRESHOLD = 50

-- Bring the blood toward the plan's normal. Returns the blood the body
-- will hold once this pass's effects land, for the oxygen rule.
local function restore(body: Handle, blood: number, normal: number, seconds: number): number
    if blood < normal then
        local circulation = sim.capacity(body, "blood") or 0
        local gain = math.min(normal - blood, REGEN_PER_S * circulation * seconds)
        if gain > 0 then
            sim.matter.deposit({
                owner = body,
                substance = BLOOD,
                moles = gain,
                temp_k = BLOOD_TEMP_K,
            })
        end
        return blood + math.max(gain, 0)
    elseif blood > normal then
        sim.matter.extract({
            owner = body,
            amount = blood - normal,
            phases = { "liquid" },
            substance = BLOOD,
        })
        return normal
    end
    return blood
end

-- code/modules/mob/living/blood.dm:253-262. Missing blood costs air up to
-- the share of oxygen capacity it accounts for (:254, :259); a body that
-- has blacked out keeps paying past that line once half its blood is gone.
local function pay_for_missing_blood(
    body: Handle,
    state: { [any]: any },
    blood: number,
    normal: number,
    seconds: number
)
    local target = math.max((1 - blood / normal) * 100, 0)
    if target <= 0 then
        return
    end
    -- `sim.body` flattens the declared pools onto the row.
    local oxy: number = state.oxy or 0
    if oxy < target or (target >= OXYLOSS_PASSOUT_THRESHOLD and not state.conscious) then
        local per_second = math.floor(OXY_PER_MISSING_MOLE * (normal - blood) / OXY_QUANTUM + 0.5)
            * OXY_QUANTUM
        if per_second > 0 then
            sim.damage.apply({ target = body, amounts = { oxy = per_second * seconds } })
        end
    end
end

-- The body cadence handler. A plan with no blood has nothing to keep.
function blood_harmony.on_life(ev: MobLifePayload): ()
    local body = ev.entity
    local state = sim.body(body)
    if state == nil or not state.animate then
        return
    end
    local blood, normal = state.blood, state.blood_normal
    if blood == nil or normal == nil or normal <= 0 then
        return
    end
    -- First the type, then the arithmetic: the one writer stamps the
    -- body's blood on its first pass here, and the restore below only
    -- ever moves blood that is already typed.
    blood_identity.stamp(body)
    local after = restore(body, blood, normal, ev.elapsed_seconds)
    pay_for_missing_blood(body, state, after, normal, ev.elapsed_seconds)
end

return blood_harmony
