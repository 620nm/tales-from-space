-- Wading and swimming (content/lib/wading.luau). A step off dry sand costs
-- the plan's own 200 ms; off the sea's 0.5 m shallows 0.1 s more, tg's
-- water slowdown; off its 1.5 m deep water 0.8 s more, with tg's deep
-- swimming modifier on top. A crewman standing in deep water keeps his head
-- out; lying in it he drowns, 2 oxy a second (swimming_tile.dm:166), unless
-- he is on internals, and the pass ends when he leaves the deep water.
--
-- Columns 0-3 are sand, 4-7 shallows, 8-13 sea, under the `warm_outdoors`
-- sky; the crewman starts on the sand and walks east into the sea. Last, a
-- second crewman falls through a hole into deep sea: a fall runs no
-- `move.cross`, so its landing (`motion.land.done`) starts the swim.
t.world(
    [==[(
    name: "wading",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(293.15)),
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

local function lie(down: boolean): ()
    t.rest(p, down)
    t.run_ticks(2)
    local posture = assert(t.body(p)).posture
    assert((posture == "lying") == down, "resting sets his posture, " .. tostring(posture))
end

-- Hold one direction until he stands on column `goal`; every step lands.
local function walk_to(goal: number): ()
    local dir = if goal > t.pos(p) then "east" else "west"
    for _ = 1, 40 * step_ticks(SWIM_S) do
        if t.pos(p) == goal then
            return
        end
        t.move(p, dir)
        t.tick()
    end
    error(`the crewman walked to column {goal}, reached {t.pos(p)}`)
end

-- Lying down in it, he drowns: two swim passes put at least 20 oxy on him.
lie(true)
t.run_seconds(11)
local drowned = oxy(p)
assert(drowned >= 15, "lying in deep water drowns, oxy " .. drowned)

-- Out on the sand the pass ends: lying there two passes long adds nothing.
lie(false)
walk_to(0)
lie(true)
t.run_seconds(11)
assert(oxy(p) <= drowned, `lying on dry sand does not drown, oxy {drowned} -> {oxy(p)}`)

-- On internals he lies in the sea and breathes (swimming_tile.dm:164).
local function bottle_row(): number
    for index, id in ipairs(t.stored(p, "back")) do
        if id == "emergency_tank.oxygen" then
            return index
        end
    end
    error("the crewman carries a pocket oxygen tank")
end
lie(false)
t.take_from(p, "back", bottle_row())
t.run_ticks(2)
t.use_self(p)
t.run_ticks(2)
assert(assert(t.vitals(p)).tank ~= nil, "the valve is open")
walk_to(LAST_X)
lie(true)
local tanked = oxy(p)
t.run_seconds(11)
assert(oxy(p) <= tanked, `internals keep him from drowning, oxy {tanked} -> {oxy(p)}`)

-- Letting go of the bottle shuts it, and the running pass drowns him: past
-- tg's 50 he passes out (OXYLOSS_PASSOUT_THRESHOLD, mobs.dm:14).
t.drop(p)
t.run_ticks(2)
assert(assert(t.vitals(p)).tank == nil, "dropping the bottle shuts it")
t.run_seconds(11)
-- A breath that lands between passes takes some back, so one pass net.
assert(oxy(p) >= tanked + 5, `without internals he drowns again, oxy {tanked} -> {oxy(p)}`)
t.run_seconds(30)
assert(oxy(p) >= 50, "and keeps drowning, oxy " .. oxy(p))
assert(not assert(t.body(p)).conscious, "until he passes out")

-- A fall into deep water swims too. A deck on level 1 over the sea has a
-- hole east of the spawn; the diver steps in, lands in the sea, stands with
-- his head out, then lies down and drowns as a walker in would.
t.world(
    [==[(
    name: "wading fall",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), surface_temperature_k: Exact(293.15)),
    legend: {
        'w': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sea_water"), components: [])),
        '.': (outdoors: true, composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (outdoors: true, composition: (substrate: Open)),
    },
    levels: [
        (
            rows: [
                "wwww",
                "wwww",
                "wwww",
            ],
        ),
        (
            rows: [
                "oooo",
                ".ooo",
                "oooo",
            ],
            structures: [(0, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)

local diver = t.join()
t.run_ticks(4)
t.move(diver, "east")
t.run_seconds(3)
local falls = t.ledger_rows("level_changed")
assert(#falls == 1 and falls[1].via == "fall", "the diver fell into the sea, got " .. #falls .. " rows")
local dx, dy = t.pos(diver)
assert(dx == 1 and dy == 1, `the diver lies under the hole, at ({dx}, {dy})`)
t.run_seconds(12)
assert(oxy(diver) == 0, "standing in the sea he keeps his head out, oxy " .. oxy(diver))
t.rest(diver, true)
t.run_ticks(2)
assert(assert(t.body(diver)).posture == "lying", "the diver lies down")
t.run_seconds(11)
assert(oxy(diver) >= 15, "the fall started his swim: lying in it drowns, oxy " .. oxy(diver))
