-- Wading and swimming (content/lib/wading.luau). A step off dry sand costs
-- the plan's own 200 ms; off the sea's 0.5 m shallows 0.1 s more, tg's
-- water slowdown; off its 1.5 m deep water 0.8 s more, with tg's deep
-- swimming modifier on top. A crewman standing in deep water keeps his head
-- out; lying in it he drowns, 2 oxy a second (swimming_tile.dm:166).
--
-- Columns 0-3 are sand, 4-7 shallows, 8-13 sea, under the `warm_outdoors`
-- sky; the crewman starts on the sand and walks east into the sea.
t.world(
    [==[(
    name: "wading",
    tags: ["terrestrial", "warm_outdoors"],
    environment: (kind: Exact(terrestrial)),
    legend: {
        'a': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        's': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sea_shallows"), components: [])),
        'w': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sea_water"), components: [])),
    },
    levels: [
        (
            rows: [
                "aaaasssswwwwww",
                "aaaasssswwwwww",
                "aaaasssswwwwww",
            ],
            structures: [(0, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)

local LAST_X = 13
local BASE_MS = 200 -- content/bodies/human.luau `pace`
local WADE_S = 0.1
local SWIM_S = 0.8

local function ticks_for(ms: number): number
    return math.ceil(ms * t.tick_hz() / 1000 - 1e-9)
end

-- Settlement rounds the base cooldown plus the band's add once.
local function step_ticks(add_s: number): number
    return math.floor(ticks_for(BASE_MS) + add_s * t.tick_hz() + 0.5)
end

local function oxy(p: number): number
    return (assert(t.body(p)).oxy :: number?) or 0
end

local p = t.join()
t.run_ticks(4)
local start_x = t.pos(p)
assert(start_x == 0, "the crewman starts on the sand, at " .. start_x)

-- Hold east every tick; each landing's tick and the column it left.
local landings: { { tick: number, from: number } } = {}
local x = start_x
for tick = 1, 40 * step_ticks(SWIM_S) do
    if x >= LAST_X then
        break
    end
    t.move(p, "east")
    t.tick()
    local now = t.pos(p)
    if now ~= x then
        table.insert(landings, { tick = tick, from = x })
        x = now
    end
end
assert(x == LAST_X, "the crewman walked into the sea, reached " .. x)

-- A step's cooldown is the gap to the next landing, priced by the tile it left.
local seen: { [string]: number } = { dry = 0, wade = 0, swim = 0 }
for i = 1, #landings - 1 do
    local from = landings[i].from
    local gap = landings[i + 1].tick - landings[i].tick
    local zone, add = "dry", 0
    if from >= 8 then
        zone, add = "swim", SWIM_S
    elseif from >= 4 then
        zone, add = "wade", WADE_S
    end
    seen[zone] += 1
    local want = step_ticks(add)
    assert(gap == want, `a step off column {from} ({zone}) takes {want} ticks, took {gap}`)
end
assert(seen.dry >= 3 and seen.wade == 4 and seen.swim >= 4, "every band was walked")
assert(step_ticks(0) < step_ticks(WADE_S) and step_ticks(WADE_S) < step_ticks(SWIM_S), "deeper is slower")

-- Standing in deep water the head stays out: no oxygen loss.
t.run_seconds(12)
assert(oxy(p) == 0, "a crewman standing in deep water does not drown, oxy " .. oxy(p))

-- Lying down in it, he drowns: two swim passes put at least 20 oxy on him,
-- and past tg's 50 he passes out (OXYLOSS_PASSOUT_THRESHOLD, mobs.dm:14).
t.rest(p, true)
assert(assert(t.body(p)).posture == "lying", "resting lays him in the water")
t.run_seconds(11)
assert(oxy(p) >= 15, "lying in deep water drowns, oxy " .. oxy(p))
t.run_seconds(30)
assert(oxy(p) >= 50, "and keeps drowning, oxy " .. oxy(p))
assert(not assert(t.body(p)).conscious, "until he passes out")
