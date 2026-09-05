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
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.tv.reruns_of_space_cops_again", {}),
            })
        else
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.tv.the_screen_is_dark_it", {}),
            })
        end
        return true
    end)
end

return content
