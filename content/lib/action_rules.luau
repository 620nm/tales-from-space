-- Declarative primary gestures share selectors with the content that owns them.
local rules = {}

function rules.fact(name, value)
    return { fact = name, value = tostring(value) }
end

function rules.kind(kind)
    return rules.fact("target.kind", kind)
end

function rules.deck(...)
    local turfs = {}
    for _, id in ipairs({ ... }) do
        table.insert(turfs, rules.fact("target.turf", id))
    end
    return { all = { rules.kind("turf"), { any = turfs } } }
end

function rules.exposed_deck()
    return { all = { rules.kind("turf"), rules.fact("target.subfloor_exposed", true) } }
end

function rules.network(kind)
    return { any = {
        rules.kind(kind),
        { all = { rules.kind("turf"), rules.fact("target.has_" .. kind, true) } },
    } }
end

function rules.primary(id, target, held)
    return {
        id = id, gesture = "primary", route = "held",
        label = "lunatic/tfs:ui.affordance." .. id,
        target = target, held = held,
    }
end

function rules.attack(id, held, label)
    local action = rules.primary(id, rules.kind("player"), held)
    action.route = "attack"
    action.uses_held = true
    if label then action.label = "lunatic/tfs:ui.affordance." .. label end
    return action
end

return rules
