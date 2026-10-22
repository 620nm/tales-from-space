-- Player gestures shared by the rhinovirus behavior specs.
local clock = require("@helpers/clock")

local actions = {}

function actions.take(actor: number, x: number, y: number, id: string): SpecObservedTarget
    if t.hands(actor).held ~= nil then
        t.drop(actor)
        t.tick()
    end
    local target = assert(t.target_at(actor, x, y, id), "the " .. id .. " is there")
    t.click(actor, x, y, target)
    t.run_ticks(2)
    return target
end

function actions.flip_syringe(actor: number): ()
    t.use_self(actor)
    t.run_ticks(2)
end

function actions.draw_from_vessel(actor: number, x: number, y: number, vessel: SpecObservedTarget): ()
    t.click(actor, x, y, vessel)
    t.run_ticks(2)
end

local function body_needle(actor: number, patient: number): ()
    local x, y = t.pos(patient)
    t.click(actor, x, y, t.body_target(actor, patient))
    if actor == patient then
        t.run_ticks(2)
    else
        t.run_ticks(clock.deadline_ticks(3) + 2)
    end
end

function actions.draw_from_body(actor: number, patient: number): ()
    body_needle(actor, patient)
end

function actions.inject_into_body(actor: number, patient: number): ()
    body_needle(actor, patient)
end

function actions.has_illness(target: number | SpecObservedTarget, index: number): boolean
    for _, row in ipairs(t.riders(target) or {}) do
        if row.id == "contagion" then
            local raw = row.fields.illnesses
            if type(raw) == "table" then
                for _, carried in ipairs(raw :: { number }) do
                    if carried == index then
                        return true
                    end
                end
            end
        end
    end
    return false
end

return actions
