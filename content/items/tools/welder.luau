local item_actions = require("@lib/item_actions")

-- A torch does not understand every single thing it is capable of
-- doing. It knows it is welding equipment and that it burns fuel to do
-- it; a wall knows what a torch does to a wall, a girder knows what one
-- does to a girder, and vacuum knows a torch closes it. Every one of
-- those answers lives with the thing that owns it, in
-- tfs/content/structures/.
local content = {
    id = "welder",
    visual_layer = "item",
    -- The ordinary self-use key remains available through `self`; the
    -- secondary pointer gesture makes the same toggle discoverable on a
    -- reachable tool lying in the world or held in either hand.
    gestures = { "secondary" },
    interaction_labels = {
        self = {
            label = "lunatic/tfs:ui.affordance.ignite",
            states = {
                lit = "lunatic/tfs:ui.affordance.extinguish",
            },
        },
        secondary = {
            label = "lunatic/tfs:ui.affordance.ignite",
            states = {
                lit = "lunatic/tfs:ui.affordance.extinguish",
            },
        },
    },
    name_label = "lunatic/tfs:entity.welder.name",
    name = "welding tool",
    sprite = "welder",
    inhand_sprite = { "held_welder_l", "held_welder_r" },
    -- tg weldingtool.dm:16-17.
    pickup_sound = "welder_pickup",
    drop_sound = "welder_drop",
    -- The torch supplies one capability and a naphtha reservoir;
    -- construction targets own the actions (docs/CONSTRUCTION.md).
    tool = "welder",
    fuel = { substance = "naphtha", capacity = 3.0 },
    -- Three moles occupy 449 mL at the pack's 112.22 g/mol and 0.75 g/mL
    -- convention, leaving headspace in this 550 mL tank.
    volume_ml = 550,
    -- The lit state is the heat signal used by surgery and construction;
    -- tg gives it a separate animated picture on every visible surface.
    flame = true,
    states = { "unlit", "lit" },
    -- tg weldingtool.dm:77-92 switches hands to welder1 and overlays
    -- welder-on over the base welder while the tool is lit.
    state_sprites = {
        lit = {
            world = "welder_lit",
            inhand = { "held_welder_lit_l", "held_welder_lit_r" },
        },
    },
    -- It is a closed reservoir refilled from a tank, not an open cup.
    sealed = true,
}

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    local function use(ev)
        local self: Handle = ev.subject
        local user: Handle = ev.actor
        if self.state == "lit" then
            sim.set_flame(self, false)
            sim.sound.play({ asset = "lunatic/tfs:sound/welder_deactivate", at = ev.at })
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.welder.you_extinguish_the_welder", {}),
            })
        else
            local contents = assert(sim.matter_read(self)).contents
            local fuel = contents[content.fuel.substance]
            local available = if fuel then (fuel.liquid or 0) + (fuel.gas or 0) + (fuel.solid or 0) else 0
            if available <= 0 then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.welder.no_fuel", {}),
                })
                return true
            end
            sim.set_flame(self, true)
            sim.sound.play({ asset = "lunatic/tfs:sound/welder_activate", at = ev.at })
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.welder.you_flip_the_welder_on", {}),
            })
        end
        return true
    end
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, use)
    item_actions.attach(script_definition, {
        id = content.id,
        sprite = content.sprite,
        state = "flame",
        label = "lunatic/tfs:ui.actions.welder",
    }, use)
end

return content
