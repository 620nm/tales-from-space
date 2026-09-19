local physical_profiles = require("@lib/physical_profiles")
local blast = require("@lib/blast")
local residue_kinds = require("@lib/residue_kinds")

-- The frag grenade: tg's `/obj/item/grenade/frag`
-- (code/game/objects/items/grenades/syndieminibomb.dm:29-36) off the
-- base grenade's arming gesture (`_grenade.dm`). The flight is tg's
-- own (throw_speed 3, throw_range 7, `_grenade.dm:14-15`), the handling
-- pair is tg's (`_grenade.dm:20-21`), the arm click is tg's
-- (`grenade_arm_sound`, `_grenade.dm:29,163`), and the fuse is tg's
-- five seconds (`det_time`, `_grenade.dm:36`).
--
-- The divergences are deliberate. The fuse is fixed: no screwdriver or
-- multitool retiming (`_grenade.dm:222-270`) while a timer has no other
-- reader. There is no disarm and no second arming: an armed grenade
-- answers a second pin-pull with a refusal, and the only thing that
-- stops the fuse is the grenade coming apart first. The blast is the
-- pack's own two bands plus an engine volley (lib/blast.luau), not
-- tg's explosion radii, and the residue is dust and ash
-- (lib/residue_kinds.luau).
local FUSE_SECONDS = 5

local content = {
    id = "frag_grenade",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    interaction_labels = {
        self = { label = "lunatic/tfs:ui.affordance.arm_grenade" },
    },
    name_label = "lunatic/tfs:entity.frag_grenade.name",
    name = "frag grenade",
    sprite = "frag",
    states = { "idle", "armed" },
    state = "idle",
    state_sprites = { idle = "frag", armed = "frag_active" },
    throw_speed = 3,
    throw_range = 7,
    pickup_sound = "grenade_pickup",
    drop_sound = "grenade_drop",
    category = "weapons",
    examine = {
        flavor = "A ribbed steel egg with a pull ring through its top. "
            .. "It is heavier than it looks.",
    },
}

if sim ~= nil then
    sim.define("script_var", "lunatic/tfs:armed", { replicate = "server" })

    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- Where the blast goes off: the grenade's own tile, read live at
    -- detonation, not where it was armed. A grenade in a hand or a bag
    -- carries no tile of its own, so a tile-less grenade bursts where
    -- its armer stands -- which is where it is, unless it changed hands
    -- mid-fuse. Nothing left to stand on and nobody left holding it is
    -- nowhere at all, and the blast below is skipped for it.
    local function live_tile(self: Handle, user: Handle): TileAddress?
        local ok, at = pcall(function(): TileAddress
            return self.tile
        end)
        if ok and at ~= nil then
            return at
        end
        local user_ok, user_at = pcall(function(): TileAddress
            return user.tile
        end)
        if user_ok and user_at ~= nil then
            return user_at
        end
        return nil
    end

    -- In order: the grenade is gone first, then what it leaves -- ash
    -- and dust on the tile, the direct blast, the volley, and the part
    -- the room sees. Every mutation but the last is an attributed
    -- ledger row; the last rides the FOV-filtered lanes.
    local function detonate(self: Handle, user: Handle): ()
        local at = live_tile(self, user)
        if at == nil then
            sim.entity.despawn({ entity = self })
            return
        end
        sim.entity.despawn({ entity = self })
        sim.matter.deposit({
            owner = at.matter,
            substance = "ash",
            moles = residue_kinds.ash_moles,
            temp_k = residue_kinds.ash_temp_k,
        })
        sim.volley_residue_deposit(at.x, at.y, residue_kinds.dust_per_blast)
        blast.apply(at)
        blast.burst(at)
        blast.cast(at)
    end

    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        if self.vars["armed"] then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.frag_grenade.already_primed", {}),
            })
            return true
        end
        self.vars["armed"] = true
        sim.appearance.set_state({ entity = self, state = "armed" })
        sim.sound.play({ asset = "lunatic/tfs:sound/grenade_arm", at = user.tile })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.frag_grenade.you_prime_the_frag_grenade", {}),
        })
        -- The fuse is a sleep, not a vigil: nothing interrupts it, and
        -- the item-scoped task follows the grenade's live site, so the
        -- blast below reads where it IS, thrown or carried or dropped.
        -- A grenade that comes apart mid-fuse cancels its own resume.
        sim.spawn_task(self, function()
            sim.sleep(sim.ticks(FUSE_SECONDS))
            detonate(self, user)
        end)
        return true
    end)
end

return content
