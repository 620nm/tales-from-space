-- THE WOUND, written once: what a damaging blow does to a body that
-- has blood in it. `main.luau` subscribes `on_wound` to the damage
-- receipt; everything below is the one answer every weapon shares.
--
-- Three gates, in order. The receipt must have applied something; the
-- applied pools must include brute — burns, toxins and oxygen loss do
-- not open a bleeder; and the victim must HAVE blood, which is the
-- `blood` field's presence rather than any plan id (a plan with no
-- `blood` block has none, and the engine says so by absence).
--
-- What a wound then does, in order: bleed stacks on the worst-hurt
-- part while the victim is still alive on the receipt, the
-- flesh-impact sound on the victim's tile, the spilled blood as
-- matter on that tile, and the splatter mark over it. One instance
-- per (tile, decal), so repeated hits repaint rather than stack.
--
-- The receipt names no ZONE and no ATTACKER — target, pools and
-- outcome only — so both are derived. The zone is the part carrying
-- the most brute, ties broken toward the alphabetically first zone so
-- the choice is stable whatever order the rows arrive in. There is no
-- direction at all: the one anchor that carries an attacker,
-- `attack.hit.done`, fires only for thrown impacts (throwing.rs), and
-- pack melee goes straight to `sim.damage.apply`. The splatter lands
-- on the victim's tile until the receipt grows a `from`.
--
-- The knobs are module locals (the `blast.luau` precedent), not
-- `content/tuning.luau`: that file is the engine's native-knob schema
-- and no script can read it, so blood numbers there would be dead
-- text that looks live.
local bloodshed = {}

-- One stack per point of brute: a stack is one 2 s pass of bleeding
-- at 0.5 units/s, so a toolbox hit (10) costs 10 units over 20 s on
-- top of what the tile takes below. The engine clamps a part at 40.
local BRUTE_PER_STACK = 1.0
-- A tenth of a unit per point of brute: a toolbox hit spills 1 unit
-- (10 mL), one visible splash and its mark. tg spills splatter
-- decals liberally per hit; the pool is this engine's own matter.
local SPLATTER_UNITS_PER_BRUTE = 0.1
-- 1 tg-u := 0.025 mol (the engine's docs/chemistry/tg-bridge.md).
local U = 0.025
-- Blood leaves the body at body temperature: BODYTEMP_NORMAL
-- (code/__DEFINES/atmospherics/atmos_mob_interaction.dm:53), the same
-- figure the bloodstream holder is declared at.
local SPILL_TEMP_K = 310.15

-- Where the blow opened skin: the part carrying the most brute, or
-- nil when no part shows any. Deterministic under any row order.
local function wound_zone(target: Handle): string?
    local parts = sim.parts(target)
    if parts == nil then
        return nil
    end
    local best = ""
    local worst = -1
    for zone, row in pairs(parts) do
        local brute = row.brute
        if type(zone) == "string" and type(brute) == "number" and brute > 0 then
            if brute > worst or (brute == worst and zone < best) then
                best = zone
                worst = brute
            end
        end
    end
    if worst < 0 then
        return nil
    end
    return best
end

-- The whole wound: bleed, thump, pool, mark. `brute` is the applied
-- brute pool off the receipt, already gated positive by the caller.
-- `audible` is whether a live actor stands behind the receipt, and
-- `animate` whether the victim is still alive on it. The thump, the
-- pool and the mark are reach-scoped commands and ERROR with no actor
-- to scope to (`sim.sound.play`, `sim.matter.deposit`), so an
-- actorless wound — a spec precondition, a system blow — bleeds and
-- leaves no trace. The bleed itself needs a living body: the dead
-- don't bleed, which is what keeps a morgue cadaver's wounds shut.
function bloodshed.shed(target: Handle, brute: number, audible: boolean, animate: boolean): ()
    local zone = wound_zone(target)
    if animate and zone ~= nil then
        local stacks = math.max(1, math.floor(brute / BRUTE_PER_STACK + 0.5))
        sim.bleed(target, zone, stacks)
    end
    if not audible then
        return
    end
    local at = target.tile
    sim.sound.play({ asset = "lunatic/tfs:sound/punch", at = at })
    sim.matter.deposit({
        owner = at.matter,
        substance = "blood",
        moles = brute * SPLATTER_UNITS_PER_BRUTE * U,
        temp_k = SPILL_TEMP_K,
    })
    sim.place_decal(at.x, at.y, "blood", "blood", nil)
end

-- The receipt subscriber. `applied` is the whole-body pool map the
-- resolution landed; anything but `applied` is a receipt about a blow
-- that never happened.
function bloodshed.on_wound(ev: DamageResolvedDonePayload): ()
    if ev.outcome ~= "applied" then
        return
    end
    local brute = ev.applied.brute or 0
    if brute <= 0 then
        return
    end
    local body = sim.body(ev.target)
    if body == nil or body.blood == nil then
        return
    end
    bloodshed.shed(ev.target, brute, ev.actor_mind ~= nil, body.animate)
end

return bloodshed
