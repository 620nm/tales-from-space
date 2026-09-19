local action_rules = require("@lib/action_rules")
local vessel = require("@lib/vessel")

-- A refillable, sealed CO2 extinguisher. The 4 L shell starts with 2 kg
-- (45.4545 mol) explicitly in the liquid phase; the matter system supplies
-- the vapour-liquid equilibrium and latent cooling as it is discharged.
--
-- tg: code/game/objects/items/tools/extinguisher.dm:1-55,285-344. Safety starts
-- on, its normal burst reaches five tiles and five particles, and a use is
-- rate-limited. TfS uses CO2 instead of tg's water reagent so the same
-- pressurized-liquid model also gives a useful space propulsion tool.
local SAFE, READY = 0, 1
local content = {
    id = "fire_extinguisher",
    visual_layer = "item",
    name_label = "lunatic/tfs:entity.fire_extinguisher.name",
    name = "fire extinguisher",
    sprite = "fire_extinguisher",
    acts_on_items = true,
    modes = 2,
    mode = SAFE,
    states = { "safe", "ready" },
    state = "safe",
    state_sprites = {
        safe = "fire_extinguisher",
        ready = "fire_extinguisher_ready",
    },
    motion_response = {
        -- A filled extinguisher is a heavy loose item: 2 kg of CO2 plus a
        -- TfS 2 kg shell approximation, rather than the 1 kg loose-item
        -- default used by ordinary hand tools.
        mass = 4.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.25,
        public_contacts = true,
    },
    volume_ml = 4000,
    sealed = true,
    resealable = true,
    reactive = false,
    contents = {
        { substance = "co2:liquid", mol = 2000 / 44.0 },
    },
    -- A pressure-rated shell: normal CO2 vapour pressure is below the
    -- ladder, while a heated or overfilled shell still has a finite failure.
    failure = {
        integrity = 200,
        break_at = 0.5,
        leak_kpa = 80 * 101.325,
        rupture_kpa = 100 * 101.325,
        fragment_kpa = 115 * 101.325,
        on_break = "leak",
        sound = "spray",
        message = "lunatic/tfs:items.fire_extinguisher.pressure_leak",
    },
    -- The native ranged path owns sight, range, cooldown and parcel motion;
    -- pressure_discharge adds phase-aware CO2 transfer and recoil.
    ranged_use = {
        visual_layer = "effects",
        range = 5,
        effect = "spray_puff",
        sound = "spray",
        recoil_per_kg = 100,
    },
    pressure_discharge = {
        mass_kg = 0.2,
        cooldown_ticks = 24,
        particles = 5,
        recoil_per_kg = 100,
    },
}

content.actions = {
    action_rules.primary("charge_vessel", {
        all = {
            action_rules.kind("machine"),
            action_rules.fact("target.has_matter", true),
        },
    }),
    action_rules.primary("discharge", true),
}

local vessel_spec: vessel.Spec = {
    id = content.id,
    noun = "fire extinguisher",
}

if sim ~= nil then
    local definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self = ev.subject
        local next_mode = (assert(sim.mode(self)).index + 1) % 2
        sim.set_mode(self, next_mode)
        sim.appearance.set_state({
            entity = self,
            state = if next_mode == READY then "ready" else "safe",
        })
        sim.message.send({
            recipient = ev.actor,
            message = sim.msg(
                if next_mode == READY
                    then "lunatic/tfs:items.fire_extinguisher.ready"
                    else "lunatic/tfs:items.fire_extinguisher.safe",
                {}
            ),
        })
        return true
    end)

    definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, at = ev.subject, ev.actor, ev.at
        local clicked = ev.claim
        local user_at = user.tile
        if assert(sim.mode(self)).index == SAFE
            and math.max(math.abs(at.x - user_at.x), math.abs(at.y - user_at.y)) <= 1
            and clicked ~= nil
            and clicked.entity ~= nil
            and clicked.kind == "machine"
        then
            local source = sim.matter_read(clicked.entity)
            if source ~= nil then
                local co2 = source.contents.co2
                local uncontaminated = true
                for key, entry in pairs(source.contents) do
                    if key ~= "co2"
                        and (entry.gas or 0) + (entry.liquid or 0) + (entry.solid or 0) > 1e-9
                    then
                        uncontaminated = false
                        break
                    end
                end
                if not uncontaminated or co2 == nil or (co2.gas or 0) <= 0 then
                    sim.message.send({
                        recipient = user,
                        message = sim.msg("lunatic/tfs:items.fire_extinguisher.not_co2", {}),
                    })
                    return true
                end
                vessel.charge(vessel_spec, self, user, clicked.entity, at)
                return true
            end
        end
        if assert(sim.mode(self)).index == SAFE then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.fire_extinguisher.safety", {}),
            })
            return true
        end
        local target = at
        if clicked ~= nil and clicked.entity ~= nil then
            target = clicked.entity
        end
        sim.matter.discharge({ from = self, target = target })
        return true
    end)

    definition:handle("matter.rupture.done", { kind = "react", route = "rupture" }, function(ev)
        sim.sound.play({ asset = "lunatic/tfs:sound/spray", at = ev.at })
    end)
end

return content
