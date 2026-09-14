-- Declarative primary gestures share selectors with the content that owns them.
export type Selector =
    boolean
    | { fact: string, value: string }
    | { all: { Selector } }
    | { any: { Selector } }
    | { ["not"]: Selector }
export type Action = {
    id: string,
    gesture: string,
    route: string,
    label: string,
    target: Selector,
    held: Selector?,
    uses_held: boolean?,
}

local rules = {}

function rules.fact(name: string, value: string | number | boolean): Selector
    return { fact = name, value = tostring(value) }
end

function rules.kind(kind: string): Selector
    return rules.fact("target.kind", kind)
end

function rules.deck(...: string): Selector
    local turfs: { Selector } = {}
    for _, id in ipairs({ ... }) do
        table.insert(turfs, rules.fact("target.turf", id))
    end
    return { all = { rules.kind("turf"), { any = turfs } } }
end

function rules.exposed_deck(carrier: string): Selector
    if carrier ~= "cable" and carrier ~= "pipe" then
        error("exposed_deck: carrier must be \"cable\" or \"pipe\"", 2)
    end
    return { all = { rules.kind("turf"), rules.fact("target.subfloor_" .. carrier .. "_exposed", true) } }
end

function rules.network(kind: string): Selector
    return {
        any = {
            rules.kind(kind),
            { all = { rules.kind("turf"), rules.fact("target.has_" .. kind, true) } },
        },
    }
end

function rules.primary(id: string, target: Selector, held: Selector?): Action
    return {
        id = id,
        gesture = "primary",
        route = "held",
        label = "lunatic/tfs:ui.affordance." .. id,
        target = target,
        held = held,
    }
end

function rules.attack(id: string, held: Selector?, label: string?): Action
    local action = rules.primary(id, rules.kind("player"), held)
    action.route = "attack"
    action.uses_held = true
    if label then
        action.label = "lunatic/tfs:ui.affordance." .. label
    end
    return action
end

return rules
