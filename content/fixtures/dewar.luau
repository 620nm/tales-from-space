-- Handheld vessel pour-in for a liquid dewar (structures/atmos/dewar.luau).
-- Primary clicks fall through to wrench fastening, vessel reservoir drawing
-- (lib/vessel.luau), and the empty-hand canister inspector window.
local DREGS_MOL = 0.001
local HEADSPACE_L = 0.001

local content = { id = "dewar" }

if sim ~= nil then
    local definition = sim.define("behavior", "lunatic/tfs:dewar", { prototype = content.id })
    definition:handle(
        "interaction.use",
        { kind = "replace", route = "interact" },
        function(ev: InteractionUsePayload)
            if ev.gesture ~= "secondary" then
                return { replaced = false }
            end
            local dewar, user, held = ev.subject, ev.actor, ev.implement
            if held == nil or not held.alive or held == dewar then
                return { replaced = false }
            end
            local source = sim.matter_read(held)
            if source == nil then
                return { replaced = false }
            end
            if dewar.state == "broken" then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:structures.dewar.broken_refusal", {}),
                })
                return true
            end
            if source.sealed then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:lib.vessel.open_before_pouring", {}),
                })
                return true
            end
            local liquid_moles = 0
            for _, entry in pairs(source.contents) do
                liquid_moles = liquid_moles + (entry.liquid or 0)
            end
            if liquid_moles < DREGS_MOL then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:structures.dewar.source_empty", {}),
                })
                return true
            end
            local dest = sim.matter_read(dewar)
            if dest == nil or dest.headspace_l <= HEADSPACE_L then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:structures.dewar.full", {}),
                })
                return true
            end
            if
                sim.matter.transfer({
                    from = held,
                    to = dewar,
                    amount = "all",
                    phases = { "liquid" },
                }) ~= nil
            then
                return true
            end
            sim.sound.play({ sound = "slosh", at = ev.at })
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:structures.dewar.poured_in", {}),
            })
            return true
        end
    )
end

return content
