-- The charter's floor rescue (docs/SURGERY.md §6.3): a crewman down in a
-- shaft, opened up on the bare deck with what a pocket holds — a glass
-- shard for the knife, wirecutters for the retractor and the hemostat, a
-- lit welder for the cautery. No operating table, no surgical kit. The
-- four steps are incise -> retract -> clamp -> close; each costs only
-- time when it fails, and the open chest bleeds while the surgeon works.
--
-- Every number here is the arithmetic of §6.3/§6.6, not a wall clock:
-- the per-attempt delays (4, 6, 6, 6 s at 32/77/20/12 % on the deck's
-- 2.0) and the bleed rates (1.5 then 0.2 per second, x0.75 lying) fall
-- out of `m = tool x location x patient`, and the total is the sum of
-- the attempts the seeded RNG actually took.

local ARENA = [==[(
    name: "shaft",
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
    spawns: [(1, 1), (2, 1)],
    items: [(1, 1, "shard"), (1, 1, "wirecutters"), (1, 1, "welder")],
)]==]

t.world(ARENA, 0)
local surgeon = t.join()
local patient = t.join()
t.tick()

-- The patient is down (a shaft does that); the surgeon kneels beside
-- them. B2 has no zone selector, so the chest is the default target. The
-- jumpsuit covers the chest, so the patient shrugs it off first (Strip
-- is B3; a patient bares their own chest here).
t.rest(patient, true)
t.unequip(patient, "uniform")
t.tick()
assert(t.body(patient).posture == "lying", "the patient is on the deck")
assert(t.worn(patient).uniform == nil, "the chest is bared")

local PX, PY = 2, 1
local pid = t.body_id(patient)
local TICK_HZ = 20

-- A part's `states` is a SET keyed by name (`states.skin_open == true`),
-- so membership is a lookup, never a loop.
local function has(states, name)
    return states[name] == true
end

-- Pick a tool up off the surgeon's own tile, dropping whatever was held.
local function hold(id)
    if t.hands(surgeon).held ~= nil then
        t.drop(surgeon)
        t.tick()
    end
    t.click(surgeon, 1, 1, t.target_at(1, 1, id))
    t.run_ticks(2)
    assert(t.hands(surgeon).held == id, "the surgeon holds the " .. id)
end

-- Click the patient until the targeted part reaches `done`, one attempt
-- per do_after. Returns attempts and the ticks they cost.
local function operate(done, step_secs)
    local step_ticks = math.ceil(step_secs * TICK_HZ) + 2
    local attempts, ticks = 0, 0
    for _ = 1, 40 do
        if done(t.parts(patient).chest.states) then break end
        t.click(surgeon, PX, PY, pid)
        t.run_ticks(step_ticks)
        attempts = attempts + 1
        ticks = ticks + step_ticks
    end
    assert(done(t.parts(patient).chest.states), "the step completed within 40 tries")
    return attempts, ticks
end

local total_ticks = 0
local failures = {}

-- 1. Incise with the shard: 1.6 s x min(4.5, 2.5) = 4 s per attempt,
--    32 % failure on the deck. Sets skin_cut + vessels_unclamped.
hold("shard")
local a1, t1 = operate(function(s) return has(s, "skin_cut") or has(s, "skin_open") end, 4.0)
total_ticks = total_ticks + t1
failures.incise = a1 - 1
assert(has(t.parts(patient).chest.states, "vessels_unclamped"),
    "the incision opened the vessels")
-- The open chest bleeds 1.5/s, x0.75 while lying = 1.125.
assert(math.abs(t.body(patient).bleed_rate - 1.125) < 0.01,
    "unclamped vessels bleed 1.5/s x0.75 lying: " .. t.body(patient).bleed_rate)

-- 2. Retract with the wirecutters: 6 s per attempt, 77 % failure.
hold("wirecutters")
local a2, t2 = operate(function(s) return has(s, "skin_open") end, 6.0)
total_ticks = total_ticks + t2
failures.retract = a2 - 1
assert(math.abs(t.body(patient).bleed_rate - 1.125) < 0.01,
    "still bleeding 1.125 with the skin open")

-- 3. Clamp with the wirecutters: 6 s per attempt, 20 % failure. Drops
--    the bleed to 0.2/s x0.75 = 0.15.
local a3, t3 = operate(function(s) return has(s, "vessels_clamped") end, 6.0)
total_ticks = total_ticks + t3
failures.clamp = a3 - 1
assert(math.abs(t.body(patient).bleed_rate - 0.15) < 0.01,
    "clamped vessels bleed 0.2/s x0.75 lying: " .. t.body(patient).bleed_rate)

-- 4. Close with the lit welder: 6 s per attempt, 12 % failure. Clears
--    every open state, and the bleeding stops.
hold("welder")
t.use_self(surgeon) -- strike the welder on; a lit flame is "hot"
t.tick()
local a4, t4 = operate(function(s) return not has(s, "skin_open") and not has(s, "skin_cut") end, 6.0)
total_ticks = total_ticks + t4
failures.close = a4 - 1
assert(t.body(patient).bleed_rate == 0, "the wound is closed and no longer bleeds")

-- Failure cost only time: the four generic movers do no damage, so the
-- chest is unhurt however many attempts it took.
assert(t.parts(patient).chest.brute == 0 and t.parts(patient).chest.burn == 0,
    "the generic steps never wound the chest")

-- The patient bled through the ordeal but is nowhere near death — about
-- forty units, on tg's 560 (docs/SURGERY.md §6.3 "never near BAD").
local left = t.body(patient).blood
assert(left < 560 and left > 460,
    "bled but survivable (started 560): " .. left)
assert(t.body(patient).state ~= "dead", "and still alive")

-- The whole ordeal is the sum of the attempts the seed took; report it.
print(string.format(
    "shaft: %d ticks (%.1f s); failures incise=%d retract=%d clamp=%d close=%d",
    total_ticks, total_ticks / TICK_HZ,
    failures.incise, failures.retract, failures.clamp, failures.close))
