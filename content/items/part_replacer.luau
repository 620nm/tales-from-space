-- The rapid part exchange device: a bag you walk a machine's sockets
-- with (tg `code/modules/research/part_replacer.dm:2-26`).
--
-- Click a machine with it and every socket that the bag holds a better
-- component for gets one. What comes out goes back into the bag — that
-- is the engine's own rule for a swap whose part came out of a
-- container (`sim/parts/swap.rs`), and it is tg's: one pass leaves the
-- bag holding as many parts as it started with, so a tech can walk a
-- row of machines without stopping to tidy.
--
-- It names no component id and no machine id. `Handle.component` says
-- what a stored thing IS as a part, `Handle.components` says what the
-- machine's sockets hold, and the whole of "is this an upgrade for
-- that" is two numbers compared — which is what lets one tool serve the
-- pack's whole ladder, including rungs added after it.
--
-- No panel gating, deliberately: v1 does not ask you to unscrew a
-- machine first, and tg's bluespace RPED skips it too
-- (part_replacer.dm:70-74).
local content = {
    id = "part_replacer",
    name = "rapid part exchange device",
    examine = {
        flavor = "Special mechanical module made to store, sort, and apply "
            .. "standard machine parts.",
    },
    sprite = "part_replacer",
    -- tg's `/datum/storage/rped` is 50 slots of stock parts; seven is
    -- this pack's own bag size and every socket a station machine has
    -- fits inside it several times over.
    storage = 7,
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local claim = ev.claim
        if not claim or claim.kind ~= "machine" or not claim.entity then
            return { replaced = false } -- not a machine; let the click mean whatever else it means
        end
        local sockets = claim.entity.components
        if not sockets then
            return { replaced = false } -- nothing this one is built out of
        end
        local bag = ev.subject.contents or {}
        -- One part fits one socket: a bag holding a single better laser
        -- upgrades the first laser socket and not both of them.
        local spent = {}
        local fitted = 0
        for index, socket in ipairs(sockets) do
            local best, best_tier = nil, socket.tier
            for slot, held in ipairs(bag) do
                local part = held.component
                if not spent[slot] and part and part.kind == socket.kind and part.tier > best_tier then
                    best, best_tier = slot, part.tier
                end
            end
            if best then
                spent[best] = true
                fitted += 1
                sim.component.swap({ subject = claim.entity, slot = index, part = bag[best] })
            end
        end
        -- And then ask the machine what it is worth, whether or not a
        -- socket changed: tg calls `RefreshParts()` at the end of
        -- `exchange_parts` unconditionally (`_machinery.dm:1172`). The
        -- engine already re-asks after every swap, so this is the
        -- GESTURE's re-ask -- the one prompt in the pack that says
        -- "look at yourself again" to a machine nobody took apart, and
        -- the only caller `sim.component.refresh` has here.
        sim.component.refresh({ subject = claim.entity })
        if fitted == 0 then
            sim.message.send({
                recipient = ev.actor,
                message = sim.msg("lunatic/tfs:items.part_replacer.nothing_in_the_exchanger_is", {}),
            })
        else
            sim.sound.play({ asset = "lunatic/tfs:sound/part_swap", at = ev.at })
            sim.message.send({
                recipient = ev.actor,
                message = sim.msg("lunatic/tfs:items.part_replacer.swapped", {
                    count = fitted,
                }),
            })
        end
        return true
    end)
end

return content
