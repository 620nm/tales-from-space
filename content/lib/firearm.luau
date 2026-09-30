-- THE FIREARM, written once: what a trigger pull and a reload do.
--
-- A shot is the engine's aimed attack, pack-resolved: the handler names
-- its primary, calls the candidate read, and fires one round for 30
-- brute at the shooter's aimed zone. Loaded ammo is the weapon's own
-- charges (`uses`): the engine spends the SOURCE's charge, never a
-- nested round, so a reload moves rounds into charges one refill at a
-- time, each spending its round atomically. The muzzle flash and the
-- shot ride the ranged claim's native delivery, which only a
-- committed attack draws — a refused shot stays dark and silent.
--
-- Which round a magazine takes is the table below, pack data enforced
-- twice: the magazine's own `interaction.use` claims the wrong caliber
-- before the engine stows it, and the reload below only feeds rounds
-- the table names. A round clicked onto a FLOOR magazine slips past
-- the first gate natively; the second still starves it.
local firearm = {}

-- Magazine id to the round ids it feeds. tg's C-20r takes the 24-round
-- .45 stick and nothing else (automatic.dm:44, smg.dm:77-86); the 9mm
-- round below has no magazine yet and fits none.
local COMPATIBLE: { [string]: { [string]: boolean } } = {
    smg_mag = { round_c45 = true },
}

-- tg's .45 slug (projectile/bullets/smg.dm:3-5).
local BULLET_BRUTE = 30
-- tg's full-auto cadence (datums/components/fullauto.dm:12).
local SHOT_SECONDS = 0.3
-- Sight range: the pack's own view radius (mod.toml), past which no
-- target is disclosed and none can be named.
local RANGE = 7
-- tg's 24-round stick (smg.dm:86). Mirrors the SMG's `uses` and the
-- magazine's `storage`; the three change together.
local MAG_ROUNDS = 24
local COOLDOWN_GROUP = "smg"

local function tell(actor: Handle, key: string): ()
    sim.message.send({ recipient = actor, message = sim.msg(key, {}) })
end

-- Whether `round_id` feeds `mag_id`.
function firearm.accepts(mag_id: string, round_id: string): boolean
    local rounds = COMPATIBLE[mag_id]
    return rounds ~= nil and rounds[round_id] == true
end

-- The magazine's loading gate: claim the pair (blocking the stow)
-- when the implement is no round this magazine feeds, decline it
-- otherwise so the engine seats it.
function firearm.gate(mag: Handle, implement: Handle?, actor: Handle): boolean
    local rounds = COMPATIBLE[mag.prototype or ""]
    if rounds == nil then
        return false
    end
    -- An empty hand takes the magazine; only an offered round is gated.
    if implement == nil then
        return false
    end
    local round_id = implement.prototype or ""
    if rounds[round_id] == true then
        return false
    end
    tell(actor, "lunatic/tfs:lib.firearm.wrong_caliber")
    return true
end

-- One trigger pull at `primary`, or the reason it stays holstered.
-- Always claims: a ranged claim is terminal, and silence reads as a
-- broken gun.
function firearm.fire(subject: Handle, actor: Handle, primary: Handle?): ()
    if primary == nil or sim.body(primary) == nil then
        tell(actor, "lunatic/tfs:lib.firearm.no_target")
        return
    end
    if (subject.uses or 0) <= 0 then
        tell(actor, "lunatic/tfs:lib.firearm.clicked_empty")
        return
    end
    local ok, found = pcall(sim.aimed_attack.targets, {
        source = subject,
        primary = primary,
        reach = RANGE,
        radius = 0,
    })
    local listed = false
    if ok and type(found) == "table" then
        for _, candidate in ipairs(found) do
            if candidate == primary then
                listed = true
                break
            end
        end
    end
    if not listed then
        tell(actor, "lunatic/tfs:lib.firearm.no_target")
        return
    end
    sim.aimed_attack.fire({
        source = subject,
        primary = primary,
        reach = RANGE,
        radius = 0,
        cooldown_group = COOLDOWN_GROUP,
        cooldown_ticks = sim.ticks(SHOT_SECONDS),
        ammo_cost = 1,
        targets = {
            {
                target = primary,
                hit = true,
                amounts = { brute = BULLET_BRUTE },
                aim = sim.zone(actor),
            },
        },
        report = { fired = true },
    })
end

-- Top the weapon up from the actor's carried magazines, each round a
-- one-charge refill spending that round. Refills past a full weapon
-- refuse natively without spending, so the count below only bounds
-- the loop; a floor magazine is simply not in the actor's graph.
function firearm.reload(weapon: Handle, actor: Handle): ()
    local have = weapon.uses
    if have == nil then
        return
    end
    if have >= MAG_ROUNDS then
        tell(actor, "lunatic/tfs:lib.firearm.already_loaded")
        return
    end
    local fed = 0
    for _, row in ipairs(sim.inventory(actor)) do
        local rounds = COMPATIBLE[row.item.prototype or ""]
        if rounds ~= nil then
            for _, round in ipairs(row.item.contents or {}) do
                if rounds[round.prototype or ""] == true and have + fed < MAG_ROUNDS then
                    sim.item.refill({ item = weapon, amount = 1, source = round })
                    fed += 1
                end
            end
        end
    end
    if fed == 0 then
        tell(actor, "lunatic/tfs:lib.firearm.no_magazine")
        return
    end
    sim.sound.play({ asset = "lunatic/tfs:sound/smg_rack", at = actor.tile })
    tell(actor, "lunatic/tfs:lib.firearm.reloaded")
end

return firearm
