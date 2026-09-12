-- Space Station admits a ready cohort together. Preparation is a lobby
-- policy: drafts are editable until ready, the first ready player starts a
-- 120-second countdown, and the station does not age while it waits.
local MAP = [==[(
    name: "preparation bay",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    structures: [(1, 1, "player_spawn"), (2, 1, "player_spawn"), (3, 1, "player_spawn")],
)]==]

local TICKS_PER_SECOND = 20
local COUNTDOWN = 120

local function status()
    return t.round_status()
end

local function job_rows()
    local out = {}
    for _, row in ipairs(t.ledger_rows("joined_job")) do
        out[row.job] = (out[row.job] or 0) + 1
    end
    return out
end

-- No one ready means no countdown progress, even after several seconds of
-- host pulses. This also exercises the bodyless connect seam.
t.world(MAP, 7, "space_station")
local idle = t.connect()
local idle_status = status()
assert(idle_status.phase == "preparing", "the station opens at the preparation board")
assert(idle_status.remaining_seconds == COUNTDOWN, "the board starts at 120 seconds")
assert(idle_status.ready == 0 and idle_status.waiting, "an empty board waits")
t.preparation_steps(10 * TICKS_PER_SECOND)
idle_status = status()
assert(idle_status.phase == "preparing", "no ready player leaves the station preparing")
assert(idle_status.remaining_seconds == COUNTDOWN, "no ready player does not spend the countdown")

-- The first ready player starts the full countdown. The accepted name is
-- trimmed before admission and remains on the Mind that receives the body.
local first = t.prepare(idle, {
    name = "  Ada Lovelace  ",
    ranked_jobs = { "engineer" },
    fallback = false,
})
assert(first.draft.name == "Ada Lovelace", "the accepted draft trims its name")
assert(first.revision == 1, "accepting a draft advances its revision")
first = t.ready(idle)
assert(first.ready and first.can_edit == false, "ready locks the accepted draft")
local started = status()
assert(started.ready == 1 and started.remaining_seconds == COUNTDOWN, "the first ready player starts at 120")

t.preparation_steps(COUNTDOWN * TICKS_PER_SECOND - 1)
local before_cutover = status()
assert(before_cutover.phase == "preparing", "the cohort stays in preparation until zero")
assert(before_cutover.remaining_seconds == 1, "one second remains before cutover")
t.preparation_steps(1)
local playing = status()
assert(playing.phase == "playing", "zero starts the admitted cohort")
local named = t.ledger_rows("mind_named")
assert(#named == 1 and named[1].name == "Ada Lovelace", "the draft name commits at admission")
assert(job_rows().engineer == 1, "the selected role is admitted")

-- An empty preference list cannot ready without explicit fallback consent.
-- With consent, the mode's assistant fallback supplies the role.
t.world(MAP, 7, "space_station")
local fallback = t.connect()
local empty = t.prepare(fallback, {
    name = "Fallback Pilot",
    ranked_jobs = {},
    fallback = false,
})
empty = t.ready(fallback)
assert(not empty.ready and empty.issue == "invalid_draft", "empty choices need fallback consent")
empty = t.prepare(fallback, {
    name = "Fallback Pilot",
    ranked_jobs = {},
    fallback = true,
})
assert(empty.issue == nil and empty.draft.fallback, "fallback consent is part of the draft")
empty = t.ready(fallback)
assert(empty.ready, "a consented fallback draft can ready")
t.preparation_steps(COUNTDOWN * TICKS_PER_SECOND)
assert(status().phase == "playing", "a consented fallback cohort starts")
assert(job_rows().assistant == 1, "consent selects the mode fallback job")

-- Rank passes keep one shuffled candidate order. Two candidates compete for
-- one captain and one engineer; both preferences are honored before the
-- opted-in fallback candidate is considered.
t.world(MAP, 19, "space_station")
local a = t.connect()
local b = t.connect()
local c = t.connect()
t.prepare(a, { name = "A", ranked_jobs = { "captain", "engineer" }, fallback = false })
t.prepare(b, { name = "B", ranked_jobs = { "captain", "engineer" }, fallback = false })
t.prepare(c, { name = "C", ranked_jobs = {}, fallback = true })
t.ready(a)
t.ready(b)
t.ready(c)
local cohort = status()
assert(cohort.ready == 3, "all three drafts are in the ready cohort")
t.preparation_steps(COUNTDOWN * TICKS_PER_SECOND)
assert(status().phase == "playing", "the competing cohort starts")
local jobs = job_rows()
assert(jobs.captain == 1, "the single captain slot is allocated once")
assert(jobs.engineer == 1, "the second rank receives the remaining engineer slot")
assert(jobs.assistant == 1, "the opted-in candidate receives assistant fallback")
