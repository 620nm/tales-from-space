-- The television: furniture with opinions. Powered through its cord
-- like the vendor; the programming is beyond anyone's control.
local content = {
    id = "tv",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local self, user, x, y = ev.subject, ev.actor, ev.at.x, ev.at.y
        if sim.is_powered(self) then
            sim.message.send({ recipient = user, message = "Reruns of Space Cops. Again." })
        else
            sim.message.send({ recipient = user, message = "The screen is dark. It needs a powered outlet nearby." })
        end
        return true
    end)
end

return content
