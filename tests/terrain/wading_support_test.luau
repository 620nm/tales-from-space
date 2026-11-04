-- A catwalk over deep sea holds a body out of the water (content/lib/wading.luau
-- `RAISED_SUPPORTS`): the pier is walked at land pace and lying on it does not
-- drown; the same sea beside it is swum at swimming pace and drowns.
--
-- Column 0 is sand; columns 1-9 are 1.5 m sea, a catwalk laid over row 0's.
-- The crewman starts on the sand at row 0, walks the pier, then the open sea.
t.world(
    [==[(
    name: "wading_support",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(293.15)),
    legend: {
        'a': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'w': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sea_water"), components: [])),
        'p': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sea_water"), components: [(component: "catwalk")])),
    },
    levels: [
        (
            rows: [
                "appppppppp",
                "awwwwwwwww",
            ],
            structures: [(0, 0, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)

local LAST_X = 9
local BASE_MS = 200 -- content/bodies/human.luau `pace`
local SWIM_S = 0.8

local function ticks_for(ms: number): number
    return math.ceil(ms * t.tick_hz() / 1000 - 1e-9)
end

local function step_ticks(add_s: number): number
    return math.floor(ticks_for(BASE_MS) + add_s * t.tick_hz() + 0.5)
end

local function oxy(p: number): number
    return (assert(t.body(p)).oxy :: number?) or 0
end

local p = t.join()
t.run_ticks(4)
assert(t.pos(p) == 0, "the crewman starts on the sand")

-- Hold one direction until he stands on column `goal`; the landings' ticks.
local function walk_east(): { number }
    local landings: { number } = {}
    local x = t.pos(p)
    for tick = 1, 40 * step_ticks(SWIM_S) do
        if x >= LAST_X then
            break
        end
        t.move(p, "east")
        t.tick()
        local now = t.pos(p)
        if now ~= x then
            table.insert(landings, tick)
            x = now
        end
    end
    assert(x == LAST_X, "the crewman reached the far end, at " .. x)
    return landings
end

-- Every step after the first (off the sand) leaves a pier or sea tile.
local function gaps(landings: { number }): { number }
    local out: { number } = {}
    for i = 2, #landings - 1 do
        table.insert(out, landings[i + 1] - landings[i])
    end
    return out
end

local function lie_for(seconds: number): number
    t.rest(p, true)
    t.run_ticks(2)
    local before = oxy(p)
    t.run_seconds(seconds)
    return oxy(p) - before
end

-- The pier: land pace, and lying on it adds no oxygen loss.
for _, gap in ipairs(gaps(walk_east())) do
    assert(gap == step_ticks(0), `a step off a catwalk over deep sea takes {step_ticks(0)} ticks, took {gap}`)
end
assert(lie_for(11) <= 0, "lying on a catwalk over deep sea does not drown")
t.rest(p, false)
t.run_ticks(2)

-- The open sea beside it: back to the sand, one row down, and east again.
for _ = 1, 40 * step_ticks(SWIM_S) do
    if t.pos(p) == 0 then
        break
    end
    t.move(p, "west")
    t.tick()
end
assert(t.pos(p) == 0, "the crewman is back on the sand")
for _ = 1, 40 * step_ticks(SWIM_S) do
    t.move(p, "south")
    t.tick()
    local _, y = t.pos(p)
    if y == 1 then
        break
    end
end
for _, gap in ipairs(gaps(walk_east())) do
    assert(gap == step_ticks(SWIM_S), `a step off open deep sea takes {step_ticks(SWIM_S)} ticks, took {gap}`)
end
assert(lie_for(11) >= 15, "lying in the open deep sea drowns")
