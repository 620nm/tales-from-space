local analyzer_pathogens = {}

local contagion = require("@lib/medical/contagion")
local host_illness = require("@lib/medical/host_illness")
local illnesses = require("@lib/medical/illnesses")

local function send_none(user: Handle): ()
    sim.message.send({
        recipient = user,
        message = sim.msg("lunatic/tfs:lib.analyzer_pathogens.none", {}),
    })
end

local function report_body(user: Handle, target: Handle): boolean
    local found = false
    for _, infection in ipairs(host_illness.snapshot(target)) do
        local definition = illnesses.get(infection.index)
        if definition ~= nil and definition.id == infection.id then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:lib.analyzer_pathogens.rhinovirus_body", {
                    name = definition.name,
                    stage = infection.stage,
                    max_stages = infection.max_stages,
                }),
            })
            found = true
        end
    end
    return found
end

local function report_vessel(user: Handle, target: Handle): boolean
    local found = false
    for _, index in ipairs(contagion.indices(target)) do
        local definition = illnesses.get(index)
        if definition ~= nil then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:lib.analyzer_pathogens.rhinovirus_vessel", {
                    name = definition.name,
                }),
            })
            found = true
        end
    end
    return found
end

function analyzer_pathogens.report(user: Handle, target: Handle, kind: "body" | "vessel"): ()
    local found = false
    if kind == "body" then
        found = report_body(user, target)
    else
        found = report_vessel(user, target)
    end
    if not found then
        send_none(user)
    end
end

return analyzer_pathogens
