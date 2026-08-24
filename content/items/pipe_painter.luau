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
-- THE ROSTER. tg's twelve, in tg's own order and with tg's own hex
-- values (`GLOB.pipe_paint_colors`,
-- code/_globalvars/lists/piping_colors_lists.dm:2-15, resolving through
-- code/__DEFINES/colors.dm). The engine never sees a colour NAME -- it
-- takes `#RRGGBB` and compares values -- so this list is the whole
-- vocabulary, and a station that wants a thirteenth paint adds a line
-- here and nothing anywhere else.
local COLORS = {
    -- Omni grey is both a paint you can pick and the one every other
    -- paint joins (ATMOS_COLOR_OMNI). Painting a run omni is how you
    -- strip it back to joining everything, which is why it leads.
    { name = "omni", hex = "#EEEEEE" },
    { name = "green", hex = "#00FF00" },
    { name = "blue", hex = "#0000FF" },
    { name = "red", hex = "#FF0000" },
    { name = "orange", hex = "#FFA62B" },
    { name = "cyan", hex = "#00FFFF" },
    { name = "dark", hex = "#454545" },
    { name = "yellow", hex = "#FFFF00" },
    { name = "brown", hex = "#BA9F6D" },
    { name = "pink", hex = "#FF3CC8" },
    { name = "purple", hex = "#800080" },
    { name = "violet", hex = "#6927C5" },
}

local content = {
    id = "pipe_painter",
    name = "pipe painter",
    -- tg's own art: the label gun off the bureaucracy sheet
    -- (`icon_state = "labeler1"`, pipe_painter.dm:6).
    sprite = "pipe_painter",
    -- Twelve settings, and it opens on the first one. tg ships
    -- `paint_color = "grey"` (pipe_painter.dm:8), which is not a key in
    -- its own roster -- the entry is called "omni" -- so a painter out
    -- of the crate there paints `null` until somebody sets it. That is
    -- a typo, not a design, and what it was reaching for is the grey
    -- one: omni. So this opens on omni, which is also the setting that
    -- cannot accidentally divide a station.
    modes = 12,
    mode = 0,
    -- tg picks the colour from a `tgui_input_list` on attack_self. We
    -- have no list prompt, so the dial cycles instead -- the same
    -- mechanism the length of pipe uses for its piping layer, and the
    -- same in-hand key.
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = sim.mode(self)
        local next_index = (dial.index + 1) % dial.count
        sim.set_mode(self, next_index)
        sim.message.send({ recipient = user, message = "Pipe painter set to " .. COLORS[next_index + 1].name .. "." })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        -- Pipe lives under the deck, so a run under a covered one is a
        -- run you cannot see -- and painting by memory is how a
        -- technician cuts the wrong main. Asked first, so every covered
        -- tile answers the same way.
        if not sim.subfloor_exposed(x, y) then
            sim.message.send({ recipient = user, message = "The floor is in the way. Pry the tile up first." })
            return true
        end
        -- A MACHINE takes no paint. tg spells this out on the sharpest
        -- case -- the colour adapter is `paintable = FALSE`
        -- (color_adapter.dm:16), because a thing whose whole job is to
        -- join every colour has no colour to be -- and here it holds for
        -- the whole family: a device's ports bind to whatever run they
        -- reach regardless of its paint (pipes/paint.rs), so there is
        -- nothing on one for a stripe to do. Said out loud rather than
        -- silently done, because a painter that changed nothing and
        -- claimed otherwise is the worst of both.
        local machine = sim.machine(x, y)
        if machine then
            sim.message.send({ recipient = user, message = "The " .. machine.name .. " takes no paint." })
            return true
        end
        -- Whatever is laid here, on every layer at once: the painter has
        -- one dial and it is spent on the colour. (tg paints the pipe
        -- object you clicked, which carries its own layer; the effect
        -- takes a layer mask, so a painter that grows a layer dial later
        -- needs no engine change.)
        local layers = sim.pipe(x, y)
        if layers == 0 then
            sim.message.send({ recipient = user, message = "There is no pipe under the floor here." })
            return true
        end
        local paint = COLORS[sim.mode(self).index + 1]
        sim.paint_pipe(x, y, layers, paint.hex)
        sim.sound.play({ asset = "lunatic/tfs:sound/click", at = ev.at })
        sim.message.send({ recipient = user, message = "You paint the pipe " .. paint.name .. "." })
        return true
    end)
end

return content
