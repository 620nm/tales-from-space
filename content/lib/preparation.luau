-- Round preparation policy: one seeded order, then fair preference passes.
-- The native edge supplies no identity or capacity decisions to content;
-- it supplies only the positional candidates and role availability. The
-- allocator returns one row per candidate (`docs/GAMEMODES.md`).
local preparation = {}

local function has_capacity(known, remaining, key)
    return known[key] == true and (remaining[key] == nil or remaining[key] > 0)
end

local function use_capacity(remaining, key)
    if remaining[key] ~= nil then
        remaining[key] -= 1
    end
end

local function shuffled_order(count)
    local order = {}
    for index = 1, count do
        order[index] = index
    end
    for index = count, 2, -1 do
        local pick = 1 + math.floor(sim.random("preparation.roles") * index)
        order[index], order[pick] = order[pick], order[index]
    end
    return order
end

local function ranked_jobs(candidate)
    return candidate.ranked_jobs
end

-- Allocate only declared preferences. The fallback is a separate pass and
-- requires the player's explicit consent, like tg's overflow job
-- (`code/controllers/subsystem/job.dm:557`).
function preparation.allocate(ev)
    local candidates = ev.candidates
    local jobs = ev.jobs
    local assignments = {}
    local known = {}
    local remaining = {}
    local max_rank = 0

    for index = 1, #candidates do
        assignments[index] = {}
        max_rank = math.max(max_rank, #ranked_jobs(candidates[index]))
    end
    for _, role in ipairs(jobs) do
        known[role.key] = true
        -- nil means an unlimited role in the native roster.
        remaining[role.key] = role.available
    end

    -- Shuffle once. Every rank pass keeps this same order, so a candidate's
    -- lower preference never gets an advantage from a second random draw.
    local order = shuffled_order(#candidates)
    for rank = 1, max_rank do
        for _, index in ipairs(order) do
            if assignments[index].job == nil then
                local key = ranked_jobs(candidates[index])[rank]
                if key ~= nil and has_capacity(known, remaining, key) then
                    assignments[index] = { job = key }
                    use_capacity(remaining, key)
                end
            end
        end
    end

    local fallback = ev.fallback_job
    if fallback ~= nil and has_capacity(known, remaining, fallback) then
        for _, index in ipairs(order) do
            if assignments[index].job == nil and candidates[index].fallback and has_capacity(known, remaining, fallback) then
                assignments[index] = { job = fallback }
                use_capacity(remaining, fallback)
            end
        end
    end

    return { assignments = assignments }
end

return preparation
