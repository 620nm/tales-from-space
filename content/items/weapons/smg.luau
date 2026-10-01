local physical_profiles = require("@lib/physical_profiles")
local firearm = require("@lib/firearm")

-- The C-20r SMG: tg's `/obj/item/gun/ballistic/automatic/c20r`
-- (code/modules/projectiles/guns/ballistic/automatic.dm:37-51) off the
-- automatic's handling (fire and rack clips, pickup and drop, :10-16).
-- One pull is one round downrange at tg's full-auto cadence
-- (0.3 s, datums/components/fullauto.dm:12), not tg's three-round
-- burst: the trigger is semi, the finger is fast. Loaded ammo is the
-- weapon's own 24 charges, tg's 24-round stick (smg.dm:86); a reload
-- feeds carried magazines into them a round at a time (`lib/firearm`).
local content = {
    id = "smg",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    interaction_labels = {
        self = { label = "lunatic/tfs:ui.affordance.reload_smg" },
    },
    name_label = "lunatic/tfs:entity.smg.name",
    name = "C-20r SMG",
    sprite = "smg",
    inhand_sprite = { "held_smg_l", "held_smg_r" },
    pickup_sound = "smg_pickup",
    drop_sound = "smg_drop",
    category = "weapons",
    uses = 24,
    gestures = { "middle" },
    ranged_use = {
        range = 7,
        effect = "muzzle_bullet",
        visual_layer = "effects",
        -- Zero leaves the cadence to the aimed attack's own cooldown:
        -- an empty trigger pull must not eat the next shot's window.
        cooldown_seconds = 0,
        launch_interval_seconds = 0,
        sound = "smg_shot",
    },
    examine = {
        flavor = "A bullpup .45 submachine gun, designated 'C-20r'. "
            .. "It has a 'Scarborough Arms - Per falcis, per pravitas' buttstamp.",
    },
}

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- In the hand: top up from the carrier's magazines.
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        firearm.reload(ev.subject, ev.actor)
        return true
    end)

    -- Downrange: one round at the named body. The claim names the
    -- clicked entity; the target is the fallback, as with the spray
    -- bottle's stream.
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local primary = ev.target
        if ev.claim ~= nil and ev.claim.entity ~= nil then
            primary = ev.claim.entity
        end
        firearm.fire(ev.subject, ev.actor, primary)
        return true
    end)
end

return content
