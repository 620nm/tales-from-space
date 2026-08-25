-- The scripted vending machine from docs/LUAU-API.md's shipped-content
-- list: sim.sleep demonstrates a plain suspension (no revalidation),
-- sim.spawn_item a script-created entity with Script-actor provenance
-- in the shift ledger.
local content = {
    id = "vendor",
    name = "Robust Softdrinks vending machine",
    sprite = "vendor",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local self, user = ev.subject, ev.actor
        if not sim.is_powered(self) then
            sim.message.send({ recipient = user, message = "The machine is dark and silent." })
            return true
        end
        -- Clicking the machine opens its content-declared clean-room
        -- shelf; dispensing happens through its exact action envelopes.
        ui.open({ viewer = user, owner = self })
        return true
    end)
    script_definition:handle("move.bump", { kind = "replace", route = "bump" }, function(ev)
        local self, user = ev.target, ev.mover
        sim.message.send({ recipient = user, message = "The vending machine wobbles. Nothing falls out." })
        return true
    end)
end

return content
