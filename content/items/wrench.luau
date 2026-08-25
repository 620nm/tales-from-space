-- Anchors and unanchors. A girder bolts to the deck under it (4 s,
-- tg's rate) and comes loose the same way -- and a loose girder is one
-- a crewmate can shove across the room, which is the whole reason the
-- distinction is worth having.
--
-- The same wrench pulls plumbing. That is not a second job bolted on:
-- in tg a pipe IS wrenched down, so unwrenching it is the same motion,
-- and a length that comes up gives back a length you can lay again.
-- Anything the run was holding goes into the room you are standing in,
-- which is why an engineer opens the shutoff before touching a charged
-- line.
--
-- ONE PULL, ONE LENGTH -- the wirecutters' rule, for the same reason.
-- The client alpha-tests the actual stacked pipe art and appends the
-- selected layer to this hook. The server validates that exact length
-- before dispatch and again when applying the cut.
--
-- Structures claim a click before this hook ever runs, so a wrench on a
-- girder still bolts the girder; this only sees tiles nothing else
-- wanted.
--
-- And it only reaches plumbing the deck is not covering. A finished
-- floor tile hides its subfloor outright: in tg an intact turf's
-- levelupdate() sends COMSIG_OBJ_HIDE (code/game/turfs/turf.dm:503-506)
-- and the pipe sits at UNDERFLOOR_HIDDEN (code/__DEFINES/turfs.dm:50-54;
-- atmospherics registers for the signal in code/modules/atmospherics/
-- machinery/atmosmachinery.dm:135-145, `var/hide = TRUE` on line 38), so
-- the click never resolves against the pipe at all. Hence "pass" and NO
-- message: a run you cannot see is a run the game must not mention, and
-- "you can't reach the pipe" would be a probe for buried cable. Pry the
-- tile up and the same click works.
local content = {
    id = "wrench",
    name = "wrench",
    sprite = "wrench",
    inhand_sprite = { "held_wrench_l", "held_wrench_r" },
    stowed_sprite = "belt_wrench",
    -- tg wrench.dm:20-21.
    pickup_sound = "wrench_pickup",
    drop_sound = "wrench_drop",
    tool = "wrench",
    -- A named loose pipe is the wrench's target, not a request to pick it
    -- up. Anything else still returns "pass" and keeps the ordinary pickup
    -- behavior (tg `/obj/item/pipe/wrench_act`, construction.dm:268-312).
    acts_on_items = true,
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        -- Asked before the pipe question, so a covered tile answers the
        -- same whether or not anything runs under it. The deck being
        -- OPEN is the question, not the turf's name.
        if not sim.subfloor_exposed(x, y) then
            return { replaced = false }
        end
        if target ~= nil and target.kind == "item" then
            local pipe = target.entity
            if pipe.prototype ~= "pipe" then
                return { replaced = false }
            end
            local px, py = pipe.tile.x, pipe.tile.y
            if px ~= x or py ~= y then
                return { replaced = false }
            end
            local mode = sim.mode(pipe)
            if mode == nil then
                return { replaced = false }
            end
            local pipe_layer = 2 ^ mode.index
            if sim.pipe_occupancy(x, y) % (pipe_layer * 2) >= pipe_layer then
                sim.message.send({ recipient = user, message = "An atmospherics component already occupies that pipe layer." })
                return true
            end
            if sim.pipe(x, y) % (pipe_layer * 2) >= pipe_layer then
                return { replaced = false }
            end
            sim.message.send({ recipient = user, message = "You start fastening the pipe..." })
            sim.spawn_task(user, function()
                if sim.do_after(user, sim.ticks(1.0), {}) == "interrupted" then
                    sim.message.send({ recipient = user, message = "You stop fastening the pipe." })
                    return true
                end
                -- Revalidate this exact atom, not whichever pipe is now first
                -- on the tile. It may have been picked up or moved while the
                -- wrench was turning, and its per-instance layer may have
                -- changed too.
                if pipe.prototype ~= "pipe" then
                    return true
                end
                px, py = pipe.tile.x, pipe.tile.y
                if px ~= x or py ~= y then
                    return true
                end
                mode = sim.mode(pipe)
                if mode == nil then
                    return true
                end
                pipe_layer = 2 ^ mode.index
                if sim.pipe_occupancy(x, y) % (pipe_layer * 2) >= pipe_layer
                    or sim.pipe(x, y) % (pipe_layer * 2) >= pipe_layer
                then
                    return true
                end
                sim.fasten_pipe(pipe, x, y, "ratchet", "You fasten the pipe into place.")
            end)
            return true
        end
        if target == nil or target.kind ~= "pipe" then
            return { replaced = false }
        end
        local layer = target.layer
        if sim.pipe(x, y) % (layer * 2) < layer then
            return { replaced = false }
        end
        sim.message.send({ recipient = user, message = "You start unwrenching the pipe..." })
        sim.spawn_task(user, function()
            if sim.do_after(user, sim.ticks(1.0), {}) == "interrupted" then
                sim.message.send({ recipient = user, message = "You stop unwrenching." })
                return true
            end
            if sim.pipe(x, y) % (layer * 2) < layer then
                return true
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/ratchet", at = ev.at })
            sim.cut_pipe(x, y, layer)
            sim.message.send({ recipient = user, message = "The pipe comes free." })
        end)
        return true
    end)
end

return content
