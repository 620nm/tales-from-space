local physical_profiles = require("@lib/physical_profiles")
local action_rules = require("@lib/action_rules")
local blood_identity = require("@lib/blood_identity")
local analyzer_pathogens = require("@lib/medical/analyzer_pathogens")

-- One centiliter of the pack's blood is 0.025 mol (substances/blood.luau:6-12).
local BLOOD_MOLES_PER_CL = 0.025
-- tg SAFE/OKAY thresholds: code/__DEFINES/mobs.dm:20-22, health_analyzer.dm:376-400.
local LOW_BLOOD_FRACTION = 0.85
local CRITICAL_BLOOD_FRACTION = 0.70

type MessageArgs = { [string]: string | number | boolean | UnsafeMarkup }

local function send_line(user: Handle, suffix: string, args: MessageArgs): ()
    sim.message.send({
        recipient = user,
        message = sim.msg("lunatic/tfs:items.health_analyzer." .. suffix, args),
    })
end

local function play_scan_sound(user: Handle): ()
    sim.sound.play({ sound = "health_analyzer_scan", at = user.tile })
end

local function rounded(value: number): number
    return math.floor(value + 0.5)
end

local function subject_name(target: Handle): string
    return target.name or target.prototype or target.base or "?"
end

local function type_name(type_index: number?): string?
    if type_index == nil then
        return nil
    end
    return blood_identity.NAMES[type_index + 1]
end

local function compatible_donor_names(receiver: number): string
    local names = ""
    for _, donor in ipairs(blood_identity.donors_for(receiver)) do
        local name = blood_identity.NAMES[donor + 1]
        if name ~= nil then
            if names ~= "" then
                names = names .. ", "
            end
            names ..= name
        end
    end
    return names
end

local function report_body(user: Handle, target: Handle, state: { [any]: any }): ()
    send_line(user, "results", { subject = subject_name(target) })

    local animate: boolean? = state.animate
    if animate ~= true then
        send_line(user, "status_deceased", {})
    else
        local health: number? = state.health
        local max_health: number? = state.max_health
        if health ~= nil and max_health ~= nil and max_health > 0 then
            send_line(user, "status_healthy", {
                percent = rounded(health / max_health * 100),
            })
        end
    end

    -- tg: code/game/objects/items/devices/scanners/health_analyzer.dm:151-163 and :230-245.
    local brute: number? = state.brute
    local burn: number? = state.burn
    local tox: number? = state.tox
    local oxy: number? = state.oxy
    send_line(user, "damage", {
        brute = math.ceil(brute or 0),
        burn = math.ceil(burn or 0),
        tox = math.ceil(tox or 0),
        oxy = math.ceil(oxy or 0),
    })

    local blood: number? = state.blood
    local normal: number? = state.blood_normal
    if blood == nil or normal == nil or normal <= 0 then
        return
    end

    local fraction = blood / normal
    local percent = rounded(fraction * 100)
    local volume = string.format("%.6g", blood / BLOOD_MOLES_PER_CL)
    local band = "normal"
    if fraction <= CRITICAL_BLOOD_FRACTION then
        band = "critical"
    elseif fraction <= LOW_BLOOD_FRACTION then
        band = "low"
    end

    local blood_type = blood_identity.type_of(target)
    local name = type_name(blood_type)
    if name == nil then
        send_line(user, "blood_" .. band .. "_untyped", {
            percent = percent,
            volume = volume,
        })
    else
        send_line(user, "blood_" .. band .. "_typed", {
            percent = percent,
            volume = volume,
            type = name,
        })
        send_line(user, "compatible_donors", {
            types = compatible_donor_names(blood_type :: number),
        })
    end

    if band == "low" then
        send_line(user, "recommend_low", {})
    elseif band == "critical" then
        send_line(user, "recommend_critical", {})
    end
end

local function report_vessel(user: Handle, target: Handle, read: MatterRead): ()
    send_line(user, "results", { subject = subject_name(target) })

    local blood = read.contents.blood
    local moles = 0
    if blood ~= nil then
        moles = (blood.solid or 0) + (blood.liquid or 0) + (blood.gas or 0)
    end
    local volume = string.format("%.6g", moles / BLOOD_MOLES_PER_CL)
    local name = type_name(blood_identity.type_of(target))
    if name == nil then
        send_line(user, "vessel_untyped", { volume = volume })
    else
        send_line(user, "vessel_typed", { volume = volume, type = name })
    end

    analyzer_pathogens.report(user, target, "vessel")
end

local function in_body_reach(user: Handle, target: Handle): boolean
    -- This adds syringe's Chebyshev one-tile bound and rejects other planes
    -- (content/items/vessels/syringe.luau:310-324).
    local from, to = user.tile, target.tile
    return from.z == to.z and math.abs(from.x - to.x) <= 1 and math.abs(from.y - to.y) <= 1
end

local vessel_selector: action_rules.Selector = {
    all = {
        action_rules.kind("item"),
        action_rules.fact("target.has_matter", true),
    },
}
local vessel_action = action_rules.primary("scan_vessel", vessel_selector)

local self_action: action_rules.Action = {
    id = "scan_self",
    gesture = "self",
    route = "self_use",
    label = "lunatic/tfs:ui.affordance.scan_self",
    target = true,
}

local content = {
    id = "health_analyzer",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.health_analyzer.name",
    name = "health analyzer",
    sprite = "health_analyzer",
    inhand_sprite = { "held_health_analyzer_l", "held_health_analyzer_r" },
    acts_on_items = true,
    actions = {
        action_rules.attack("scan_body"),
        self_action,
        vessel_action,
    },
}

if sim ~= nil then
    local definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    definition:handle("attack.swing", { kind = "replace", route = "attack" }, function(ev)
        local user, target = ev.actor, ev.target
        if target == nil then
            return { replaced = false }
        end
        local state = sim.body.read(target)
        if state == nil then
            return { replaced = false }
        end
        if not in_body_reach(user, target) then
            send_line(user, "out_of_reach", {})
            return true
        end
        report_body(user, target, state)
        analyzer_pathogens.report(user, target, "body")
        play_scan_sound(user)
        return true
    end)

    definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local user = ev.actor
        local state = sim.body.read(user)
        if state == nil then
            return { replaced = false }
        end
        report_body(user, user, state)
        analyzer_pathogens.report(user, user, "body")
        play_scan_sound(user)
        return true
    end)

    definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local user = ev.actor
        local claim = ev.claim
        local target = claim and claim.entity or nil
        if target == nil then
            return { replaced = false }
        end
        local read = sim.matter_read(target)
        if read == nil then
            return { replaced = false }
        end
        report_vessel(user, target, read)
        play_scan_sound(user)
        return true
    end)
end

return content
