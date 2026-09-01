-- A status display is programmed directly from its panel. The panel
-- owns validation and the forty-character bound; this handler owns the
-- two lines it means, their uppercase presentation, and blanking both.
-- tg's communications console runs both lines through `reject_bad_text`
-- (`code/game/machinery/computer/communications.dm:386-392`), whose
-- printable-ASCII and four-character exclusions are defined at
-- `code/__HELPERS/text.dm:81-106`.
local content = {
    id = "status_display",
}

if sim ~= nil then
    sim.define("script_var", "lunatic/tfs:display_line1", { replicate = "sight" })
    sim.define("script_var", "lunatic/tfs:display_line2", { replicate = "sight" })

    local behavior = sim.define(
        "behavior",
        "lunatic/tfs:" .. content.id,
        { prototype = content.id }
    )

    local function display_text(value)
        if value == nil or string.match(value, "%S") == nil then
            return nil
        end
        for index = 1, #value do
            local byte = string.byte(value, index)
            if byte < 32 or byte > 126
                or byte == 47 or byte == 60 or byte == 62 or byte == 92
            then
                return nil
            end
        end
        return string.upper(value)
    end

    behavior:handle("interaction.act", { kind = "replace", route = "act" }, function(ev)
        local display = ev.subject
        if ev.action == "line1" then
            local text = display_text(ev.value)
            if text == nil then
                return true
            end
            display.vars.display_line1 = text
            return true
        end
        if ev.action == "line2" then
            local text = display_text(ev.value)
            if text == nil then
                return true
            end
            display.vars.display_line2 = text
            return true
        end
        if ev.action == "clear" then
            display.vars.display_line1 = nil
            display.vars.display_line2 = nil
            return true
        end
        return { replaced = false }
    end)
end

return content
