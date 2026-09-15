local action_rules = require("@lib/action_rules")
local pipe_paints = require("@lib/pipe_paints")

-- The pipe painter: tg's `/obj/item/pipe_painter`
-- (code/game/objects/items/devices/pipe_painter.dm).
--
-- It is the atmospherics technician's labelling gun, and on this station
-- it is more than that, because colour is not a label here: two pipe
-- ends only join when their paint agrees or one of them is omni (tg's
-- `is_connectable`, atmosmachinery.dm:335-354, ported in
-- crates/lunatic-server/src/pipes/paint.rs). So a stripe of the wrong
-- colour across a distribution main CUTS it, and the line still looks
-- whole. Paint carefully.
--
-- The shared roster is also the RPD's dial and the map editor's
-- variants (`lib/pipe_paints.luau`). Keeping one list means adding the
-- TfS white paint cannot leave one of those three selectors behind.
local COLORS = pipe_paints.colors

-- The kinds of length that carry a colour of their own and so take no
-- stripe, the way the colour adapter takes none: tg fixes
-- heat-exchanging pipe at `#404040` in `Initialize`
-- (heat_exchange/he_pipes.dm:15).
local FIXED_COLOUR = { he_pipe = true }

local content = {
    id = "pipe_painter",
    visual_layer = "entities",
    held_visual_layer = "held",
    name_label = "lunatic/tfs:entity.pipe_painter.name",
    name = "pipe painter",
    -- tg's own art: the label gun off the bureaucracy sheet
    -- (`icon_state = "labeler1"`, pipe_painter.dm:6).
    sprite = "pipe_painter",
    -- One setting per shared paint, and it opens on the first one. tg ships
    -- `paint_color = "grey"` (pipe_painter.dm:8), which is not a key in
    -- its own roster -- the entry is called "omni" -- so a painter out
    -- of the crate there paints `null` until somebody sets it. That is
    -- a typo, not a design, and what it was reaching for is the grey
    -- one: omni. So this opens on omni, which is also the setting that
    -- cannot accidentally divide a station.
    modes = #COLORS,
    mode = 0,
    -- tg picks the colour from a `tgui_input_list` on attack_self. We
    -- have no list prompt, so the dial cycles instead -- the same
    -- mechanism the length of pipe uses for its piping layer, and the
    -- same in-hand key.
}

content.actions = { action_rules.primary("paint_pipe", action_rules.network("pipe")) }

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = assert(sim.mode(self))
        local next_index = (dial.index + 1) % dial.count
        sim.set_mode(self, next_index)
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.pipe_painter.set", {
                color = COLORS[next_index + 1].name,
            }),
        })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local target = ev.claim
        local _x, _y, _choice = x, y, choice
        if target == nil or target.kind ~= "network" then
            return { replaced = false }
        end
        local network = sim.network(x, y, target.instance)
        if network == nil or network.network ~= "pipe" or not sim.network_accessible(x, y, target.instance) then
            return { replaced = false }
        end
        if FIXED_COLOUR[network.kind] then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.pipe_painter.that_pipe_has_a_colour", {}),
            })
            return true
        end
        local paint = COLORS[assert(sim.mode(self)).index + 1]
        sim.paint_network(x, y, target.instance, paint.name)
        sim.sound.play({ asset = "lunatic/tfs:sound/click", at = ev.at })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.pipe_painter.painted", { color = paint.name }),
        })
        return true
    end)
end

return content
