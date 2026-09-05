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

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = sim.mode(self)
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
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        -- Pipe lives under the deck, so a run under a covered one is a
        -- run you cannot see -- and painting by memory is how a
        -- technician cuts the wrong main. Asked first, so every covered
        -- tile answers the same way.
        if not sim.subfloor_exposed(x, y) then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.pipe_painter.the_floor_is_in_the", {}),
            })
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
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.pipe_painter.no_paint", {
                    machine = machine.name,
                }),
            })
            return true
        end
        -- Whatever is laid here, on every layer at once: the painter has
        -- one dial and it is spent on the colour. (tg paints the pipe
        -- object you clicked, which carries its own layer; the effect
        -- takes a layer mask, so a painter that grows a layer dial later
        -- needs no engine change.)
        local layers = sim.pipe(x, y)
        if layers == 0 then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.pipe_painter.there_is_no_pipe_under", {}),
            })
            return true
        end
        -- Nor does a length with a colour of its own -- heat-exchanging
        -- pipe is fixed at tg's `#404040` outright (he_pipes.dm:15), and
        -- the engine refuses the stripe. Asked here for the machine's
        -- reason above: the wrong reply is worse than none.
        local fixed = 0
        local mask = 1
        for _ = 1, 5 do
            if layers % (mask * 2) >= mask then
                local kind = sim.pipe_kind(x, y, mask)
                if kind ~= nil and FIXED_COLOUR[kind] then
                    fixed = fixed + mask
                end
            end
            mask = mask * 2
        end
        if fixed == layers then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.pipe_painter.that_pipe_has_a_colour", {}),
            })
            return true
        end
        local paint = COLORS[sim.mode(self).index + 1]
        sim.paint_pipe(x, y, layers - fixed, paint.hex)
        sim.sound.play({ asset = "lunatic/tfs:sound/click", at = ev.at })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.pipe_painter.painted", { color = paint.name }),
        })
        return true
    end)
end

return content
