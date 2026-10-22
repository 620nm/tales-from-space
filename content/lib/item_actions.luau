-- Possession-scoped action documents; docs/pack-ui/server.md.
type ActorSubject = { actor: Handle, subject: Handle }
export type Spec = { id: string, label: string, sprite: string, state: string? }

local function attach(definition: Definition, spec: Spec, use: (InteractionActPayload) -> boolean)
    definition:handle("inventory.present", { kind = "react" }, function(ev: InventoryPresentPayload)
        local active: boolean? = nil
        if spec.state == "flame" then
            active = ev.flame
        end
        if spec.state == "supply" then
            active = ev.supply
        end
        local state = "ready"
        if active ~= nil then
            state = active and "on" or "off"
        end
        local request: UiUpdateCommand = {
            viewer = ev.actor,
            owner = ev.subject,
            channel = "actions",
            view = {
                presentation = "actions",
                groups = {
                    {
                        id = "equipment",
                        label = { id = "lunatic/tfs:ui.actions.equipment" },
                        actions = {
                            {
                                id = "activate",
                                label = { id = spec.label },
                                sprite = spec.sprite,
                                state = state,
                                pinned = true,
                            },
                        },
                    },
                },
            },
            actions = { activate = 0 },
        }
        if ev.initial then
            ui.open({
                viewer = request.viewer,
                owner = request.owner,
                channel = request.channel,
                view = request.view,
                actions = request.actions,
                possession = true,
                presentation_key = "item-actions/" .. spec.id,
            })
        else
            ui.update(request)
        end
    end)
    definition:handle(
        "interaction.act",
        { kind = "replace", route = "act" },
        function(ev: InteractionActPayload)
            if ev.channel ~= "actions" or ev.action ~= "activate" then
                return false
            end
            return use(ev)
        end
    )
end

local function internals(ev: ActorSubject): boolean
    sim.toggle_internals(ev.actor, ev.subject)
    ui.open({ viewer = ev.actor, owner = ev.subject })
    return true
end

return { attach = attach, internals = internals }
