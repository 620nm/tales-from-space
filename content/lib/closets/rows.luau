-- The clicks `closet.attach`'s handler answers, as a closet's `actions`.
local data = require("@lib/closets/data")

type Row = { [string]: any }

local rows = {}

local function bare_hand(id: string, label: string, state: string): Row
    return {
        id = id,
        gesture = "primary",
        route = "receiver",
        label = label,
        target = { fact = "target.state", value = state },
        held = { fact = "held.present", value = "false" },
    }
end

-- `secure` names the variant an ID locks. Declared rows gate the handler, which
-- climbs, knocks off and refuses, so every hand needs one: the open and close
-- rows take an empty hand and the last row, which shows nothing, any other.
function rows.actions(secure: string?): { Row }
    local list: { Row } = {
        {
            id = "weld",
            gesture = "primary",
            route = "receiver",
            label = "lunatic/tfs:ui.verb.welder",
            held = { fact = "held.proto", value = data.welder_prototype },
            uses_held = true,
            suggest_implement = { item = data.welder_prototype },
        },
    }
    if secure ~= nil then
        local ids = {}
        for _, id in ipairs(data.id_prototypes) do
            table.insert(ids, { fact = "held.proto", value = id })
        end
        local toggle_lock: Row = {
            id = "toggle_lock",
            gesture = "primary",
            route = "receiver",
            label = "lunatic/tfs:ui.affordance.toggle_lock",
            target = {
                all = {
                    { fact = "target.proto", value = secure },
                    { fact = "target.state", value = data.closed_state },
                },
            },
            held = { any = ids },
            uses_held = true,
            suggest_implement = { item = data.id_prototypes[1] },
        }
        table.insert(list, toggle_lock)
    end
    table.insert(list, bare_hand("open", "lunatic/tfs:action.open", data.closed_state))
    table.insert(list, bare_hand("close", "lunatic/tfs:action.close", data.open_state))
    local reach_handler: Row = {
        id = "reach_handler",
        gesture = "primary",
        route = "receiver",
        label = "lunatic/tfs:action.open",
        held = { fact = "held.present", value = "true" },
        visible = false,
    }
    table.insert(list, reach_handler)
    return list
end

return rows
