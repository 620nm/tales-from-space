-- Shared map-marker selection. The engine supplies structure enumeration,
-- tile addresses and mob spawning; this file owns the pack's policy.
local map_markers = {}

local MAX_WEIGHT = 1000000
local JOBS = {
    assistant = true,
    captain = true,
    security = true,
    engineer = true,
    medic = true,
}

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

-- A malformed list is unusable as a filter. Returning nil makes the whole
-- marker ineligible, so a typo cannot silently widen a spawn pool.
local function parse_filter(value, known)
    if type(value) ~= "string" then return nil end
    if value == "" then return {} end
    local result = {}
    local seen = {}
    for raw in (value .. ","):gmatch("([^,]*),") do
        local token = trim(raw)
        if token == "" then return nil end
        if not token:match("^[a-z0-9_]+$") then return nil end
        if known ~= nil and not known[token] then return nil end
        if seen[token] then return nil end
        seen[token] = true
        table.insert(result, token)
    end
    return result
end

local function matches(tokens, value)
    if tokens == nil or #tokens == 0 then return tokens ~= nil end
    if type(value) ~= "string" then return false end
    for _, token in ipairs(tokens) do
        if token == value then return true end
    end
    return false
end

local function weight(marker)
    local value = marker.vars["marker_weight"]
    if value == nil then value = 1 end
    if type(value) ~= "number" or value < 0 or value > MAX_WEIGHT then
        return 0
    end
    return value
end

-- Select one marker with one draw after summing eligible weights. Entity
-- enumeration is stable, so equal seeds and maps produce equal locations.
local function choose(definition, eligible, stream)
    local candidates = {}
    local total = 0
    for _, marker in ipairs(sim.query.all(definition)) do
        local marker_weight = weight(marker)
        if marker_weight > 0 and eligible(marker) then
            total += marker_weight
            table.insert(candidates, { marker = marker, weight = marker_weight })
        end
    end
    if total <= 0 then return nil end

    local pick = sim.random(stream) * total
    for _, candidate in ipairs(candidates) do
        if pick < candidate.weight then
            return candidate.marker.tile
        end
        pick -= candidate.weight
    end
    return candidates[#candidates].marker.tile
end

function map_markers.player_spawn(ev, default_role)
    local role = default_role
    if ev.mind ~= nil then
        role = ev.mind.vars["spawn_role"] or default_role
    end
    local chosen = choose("player_spawn", function(marker)
        local marker_jobs = parse_filter(marker.vars["marker_jobs"] or "", JOBS)
        local marker_roles = parse_filter(marker.vars["marker_roles"] or "")
        return matches(marker_jobs, ev.job)
            and matches(marker_roles, role)
    end, "map_markers.player_spawn")
    if chosen == nil then return {} end
    ev.at = chosen
    return { at = chosen }
end

function map_markers.threat_location()
    return choose("threat_spawn", function(_marker)
        return true
    end, "map_markers.threat_spawn")
end

-- A marker keeps its own entity so later round/gameplay hooks can enumerate
-- it. The hook is intentionally present: marker prototypes are scriptable
-- at map initialization even when their current policy needs no setup.
function map_markers.initialize(_ev)
end

function map_markers.spawn_threat(definition)
    if type(definition) ~= "string" or definition == "" then return false end
    local at = map_markers.threat_location()
    if at == nil then return false end
    sim.mob.spawn({ definition = definition, at = at })
    return true
end

return map_markers
