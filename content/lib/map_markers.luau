-- Shared map-marker selection. The engine supplies structure enumeration,
-- tile addresses and mob spawning; this file owns the pack's policy.
local map_markers = {}

local MAX_WEIGHT = 1000000
local JOBS: { [string]: boolean } = {
    assistant = true,
    captain = true,
    security = true,
    engineer = true,
    medic = true,
}

-- A job's category, for markers that fit a family rather than one
-- job. Job declarations carry no category; this roster beside the
-- filter guard is the one list to widen when a job is added.
local JOB_CATEGORY: { [string]: string } = {
    assistant = "general",
    captain = "command",
    security = "security",
    engineer = "engineering",
    medic = "medical",
}

-- The tokens a marker's jobs list may name: jobs and categories.
local JOB_TOKENS: { [string]: boolean } = {}
for job in pairs(JOBS) do
    JOB_TOKENS[job] = true
end
for _, category in pairs(JOB_CATEGORY) do
    JOB_TOKENS[category] = true
end

local function trim(value: string): string
    return assert(value:match("^%s*(.-)%s*$"))
end

-- A malformed list is unusable as a filter. Returning nil makes the whole
-- marker ineligible, so a typo cannot silently widen a spawn pool.
local function parse_filter(value: unknown, known: { [string]: boolean }?): { string }?
    if type(value) ~= "string" then
        return nil
    end
    if value == "" then
        return {}
    end
    local result: { string } = {}
    local seen: { [string]: boolean } = {}
    for raw in (value .. ","):gmatch("([^,]*),") do
        local token = trim(raw)
        if token == "" then
            return nil
        end
        if not token:match("^[a-z0-9_]+$") then
            return nil
        end
        if known ~= nil and not known[token] then
            return nil
        end
        if seen[token] then
            return nil
        end
        seen[token] = true
        table.insert(result, token)
    end
    return result
end

local function matches(tokens: { string }?, value: unknown): boolean
    if tokens == nil or #tokens == 0 then
        return tokens ~= nil
    end
    if type(value) ~= "string" then
        return false
    end
    for _, token in ipairs(tokens) do
        if token == value then
            return true
        end
    end
    return false
end

local function weight(marker: Handle): number
    local value = marker.vars["marker_weight"]
    if value == nil then
        value = 1
    end
    if type(value) ~= "number" or value < 0 or value > MAX_WEIGHT then
        return 0
    end
    return value
end

-- Only markers on the round's join instance answer. A marker on a seam map
-- or a spec twin never does, and no join yet means no answer at all.
local function on_join(marker: Handle, join: MapInstance?): boolean
    local at = marker.tile
    return join ~= nil and at ~= nil and at.instance == join
end

-- Select one marker with one draw after summing eligible weights. Entity
-- enumeration is stable, so equal seeds and maps produce equal locations.
local function choose(
    definition: string,
    eligible: (Handle) -> boolean,
    stream: string
): TileAddress?
    local candidates: { { marker: Handle, weight: number } } = {}
    local total = 0
    local join = sim.join_instance()
    for _, marker in ipairs(sim.query.all(definition)) do
        local marker_weight = weight(marker)
        if marker_weight > 0 and on_join(marker, join) and eligible(marker) then
            total += marker_weight
            table.insert(candidates, { marker = marker, weight = marker_weight })
        end
    end
    if total <= 0 then
        return nil
    end

    local pick = sim.random(stream) * total
    for _, candidate in ipairs(candidates) do
        if pick < candidate.weight then
            return candidate.marker.tile
        end
        pick -= candidate.weight
    end
    return candidates[#candidates].marker.tile
end

-- Whether the mapper marked this spawn as the general fallback:
-- the point a joiner lands on when nothing better fits.
function map_markers.is_fallback(marker: Handle): boolean
    return marker.vars["marker_fallback"] == true
end

-- Whether any player_spawn marker on the join instance can answer:
-- what a joiner with no body was missing, in the pack's own terms.
function map_markers.any_player_spawn(): boolean
    local join = sim.join_instance()
    for _, marker in ipairs(sim.query.all("player_spawn")) do
        if weight(marker) > 0 and on_join(marker, join) then
            return true
        end
    end
    return false
end

-- Tiles already given out this round, by absolute address: an
-- unused point beats a used one at the same tier, whenever one
-- remains. Candidates are join-instance scoped, so the address
-- alone names the point.
local used: { [string]: boolean } = {}

local function tile_key(tile: TileAddress): string
    return string.format("%d,%d,%d", tile.absolute_x, tile.absolute_y, tile.z)
end

-- One weighted draw among same-tier candidates, unused first. The
-- draw math is choose()'s, so equal seeds keep equal locations.
local function draw(candidates: { { marker: Handle, weight: number } }, stream: string): TileAddress?
    local fresh: { { marker: Handle, weight: number } } = {}
    local fresh_total = 0
    local total = 0
    for _, candidate in ipairs(candidates) do
        total += candidate.weight
        if not used[tile_key(candidate.marker.tile)] then
            fresh_total += candidate.weight
            table.insert(fresh, candidate)
        end
    end
    local pool = #fresh > 0 and fresh or candidates
    local pool_total = #fresh > 0 and fresh_total or total
    if pool_total <= 0 then
        return nil
    end
    local pick = sim.random(stream) * pool_total
    for _, candidate in ipairs(pool) do
        if pick < candidate.weight then
            used[tile_key(candidate.marker.tile)] = true
            return candidate.marker.tile
        end
        pick -= candidate.weight
    end
    local last = pool[#pool]
    used[tile_key(last.marker.tile)] = true
    return last.marker.tile
end

-- Scored choice: a marker naming the ask's role outranks every job
-- tier (an antagonist is a role), then exact job, job category,
-- general; the fallback-attributed marker answers only when no
-- tier fits. A marker whose filters do not parse never answers.
function map_markers.player_spawn(ev: RoundSpawnPayload, default_role: string): { at: TileAddress? }
    local role: unknown = default_role
    if ev.mind ~= nil then
        role = ev.mind.vars["spawn_role"] or default_role
    end
    local category = if type(ev.job) == "string" then JOB_CATEGORY[ev.job] else nil
    local join = sim.join_instance()
    local best: { { marker: Handle, weight: number } } = {}
    local best_score = -1
    local fallbacks: { { marker: Handle, weight: number } } = {}
    for _, marker in ipairs(sim.query.all("player_spawn")) do
        local marker_weight = weight(marker)
        if marker_weight <= 0 or not on_join(marker, join) then
            continue
        end
        if map_markers.is_fallback(marker) then
            table.insert(fallbacks, { marker = marker, weight = marker_weight })
        end
        local marker_jobs = parse_filter(marker.vars["marker_jobs"] or "", JOB_TOKENS)
        local marker_roles = parse_filter(marker.vars["marker_roles"] or "")
        if marker_jobs == nil or marker_roles == nil then
            continue
        end
        if #marker_roles > 0 and not matches(marker_roles, role) then
            continue
        end
        local job_tier: number? = nil
        if #marker_jobs == 0 then
            job_tier = 1
        elseif matches(marker_jobs, ev.job) then
            job_tier = 3
        elseif category ~= nil and matches(marker_jobs, category) then
            job_tier = 2
        end
        if job_tier == nil then
            continue
        end
        local score = job_tier + if #marker_roles > 0 then 10 else 0
        if score > best_score then
            best_score = score
            best = { { marker = marker, weight = marker_weight } }
        elseif score == best_score then
            table.insert(best, { marker = marker, weight = marker_weight })
        end
    end
    local chosen = draw(best, "map_markers.player_spawn")
    if chosen == nil then
        chosen = draw(fallbacks, "map_markers.player_spawn")
    end
    if chosen == nil then
        return {}
    end
    ev.at = chosen
    return { at = chosen }
end

function map_markers.threat_location(): TileAddress?
    return choose("threat_spawn", function(_marker)
        return true
    end, "map_markers.threat_spawn")
end

-- A marker keeps its own entity so later round/gameplay handlers can enumerate
-- it. The handler is intentionally present: marker prototypes are scriptable
-- at map initialization even when their current policy needs no setup.
function map_markers.initialize(_ev: EntityInitializeDonePayload): () end

function map_markers.spawn_threat(definition: unknown): boolean
    if type(definition) ~= "string" or definition == "" then
        return false
    end
    local at = map_markers.threat_location()
    if at == nil then
        return false
    end
    sim.body.spawn({ plan = definition, at = at })
    return true
end

return map_markers
