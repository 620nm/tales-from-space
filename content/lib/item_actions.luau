-- Possession-scoped action documents; docs/pack-ui/server.md.
local function attach(definition, spec, use)
    definition:handle("inventory.present", { kind = "react" }, function(ev)
        local active = nil
        if spec.state == "flame" then active = ev.flame end
        if spec.state == "supply" then active = ev.supply end
        local state = "ready"
        if active ~= nil then state = active and "on" or "off" end
        local request = {
            viewer = ev.actor,
            owner = ev.subject,
            channel = "actions",
            view = {
                presentation = "actions",
                groups = {{
                    id = "equipment",
                    label = { id = "lunatic/tfs:ui.actions.equipment" },
                    actions = {{
                        id = "activate",
                        label = { id = spec.label },
                        sprite = spec.sprite,
                        state = state,
                        pinned = true,
                    }},
                }},
            },
            actions = { activate = 0 },
        }
        if ev.initial then
            request.possession = true
            request.presentation_key = "item-actions/" .. spec.id
            ui.open(request)
        else
            ui.update(request)
        end
    end)
    definition:handle("interaction.act", { kind = "replace", route = "act" }, function(ev)
        if ev.channel ~= "actions" or ev.action ~= "activate" then return false end
        return use(ev)
    end)
end

local function internals(ev)
    sim.toggle_internals(ev.actor, ev.subject)
    ui.open({ viewer = ev.actor, owner = ev.subject })
    return true
end

return { attach = attach, internals = internals }
