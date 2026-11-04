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
-- twice: the magazine's `load_row` refuses the wrong caliber before the
-- engine stows it, and the reload below only feeds rounds the table
-- names. A round clicked onto a FLOOR magazine slips past the first
-- gate natively; the second still starves it.
local firearm = {}

-- Magazine id to the round ids it feeds. tg's C-20r takes the 24-round
-- .45 stick and nothing else (automatic.dm:43, smg.dm:77-86); the 9mm
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

-- The magazine's loading row: any held thing is offered, the rounds it feeds
-- fall through to the engine's stow, and anything else is refused here,
-- before that stow. An empty hand fails the row and picks the magazine up.
function firearm.load_row(mag_id: string): { [string]: any }
    local rounds = {}
    local first: string? = nil
    for round_id in COMPATIBLE[mag_id] or {} do
        table.insert(rounds, { fact = "held.proto", value = round_id })
        first = first or round_id
    end
    local holding = { fact = "held.present", value = "true" }
    local feeds = if #rounds == 1 then rounds[1] else { any = rounds }
    return {
        id = "load_round",
        gesture = "primary",
        route = "receiver",
        label = "lunatic/tfs:ui.affordance.load_round",
        held = holding,
        uses_held = true,
        suggest = true,
        suggest_implement = { item = first },
        refuse = {
            {
                when = { all = { holding, { ["not"] = feeds } } },
                label = "lunatic/tfs:lib.firearm.wrong_caliber",
            },
        },
    }
end

-- One trigger pull at `primary`, or the reason it stays holstered.
-- Always claims: a ranged claim is terminal, and silence reads as a
-- broken gun.
function firearm.fire(subject: Handle, actor: Handle, primary: Handle?): ()
    if primary == nil or sim.body.read(primary) == nil then
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
        cooldown_seconds = SHOT_SECONDS,
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
    sim.sound.play({ sound = "smg_rack", at = actor.tile })
    tell(actor, "lunatic/tfs:lib.firearm.reloaded")
end

return firearm
