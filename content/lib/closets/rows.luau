-- The clicks a closet's handler answers, as its `actions`: `closet.attach`'s
-- and the cadaver chamber's.
local data = require("@lib/closets/data")

type Row = { [string]: any }

local rows = {}

local function bare_hand(id: string, label: string, target: Row): Row
    return {
        id = id,
        gesture = "primary",
        route = "receiver",
        label = label,
        target = target,
        held = { fact = "held.present", value = "false" },
    }
end

local function state_is(state: string): Row
    return { fact = "target.state", value = state }
end

-- The open and close rows, for an empty hand, and the last row, which shows
-- nothing, for any other.
local function append_door(list: { Row }, shut: Row): ()
    table.insert(list, bare_hand("open", "lunatic/tfs:action.open", shut))
    table.insert(list, bare_hand("close", "lunatic/tfs:action.close", state_is(data.open_state)))
    local reach_handler: Row = {
        id = "reach_handler",
        gesture = "primary",
        route = "receiver",
        label = "lunatic/tfs:action.open",
        held = { fact = "held.present", value = "true" },
        visible = false,
    }
    table.insert(list, reach_handler)
end

-- The door alone, for a closet with no weld or lock. `lit_states` are its
-- scripted shut states, which open as `closed` does.
function rows.door_actions(lit_states: { string }): { Row }
    local shut: { Row } = { state_is(data.closed_state) }
    for _, state in ipairs(lit_states) do
        table.insert(shut, state_is(state))
    end
    local list: { Row } = {}
    append_door(list, { any = shut })
    return list
end

-- `secure` names the variant an ID locks. Declared rows gate the handler, which
-- climbs, knocks off and refuses, so every hand needs a row.
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
    append_door(list, state_is(data.closed_state))
    return list
end

return rows
