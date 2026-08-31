-- The two facts, and who decides them (docs/BIOLOGY.md §3.4).
--
-- The engine holds `controllable` and `animate` and reaches neither: it
-- latches which side of each line `content/bodies/human.luau` declared
-- the body is on, and that file's own handler answers. Everything below
-- is read through the seam a client uses, so what it pins is what a
-- player would see — and every word in it is Tales from Space's, because
-- there is no other kind left.
local WARD = [==[(
    name: "ward",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "######",
    ],
    spawns: [(1, 1), (2, 1)],
    items: [(3, 1, "toolbox")],
)]==]

-- ---------------------------------------------------------------
-- The `crit` line: the pack takes the wheel away and leaves the body
-- running. Nothing about that is an engine verdict — the line is
-- declared in `human.luau` and its handler is what answers.
-- ---------------------------------------------------------------
t.world(WARD, 0)
local p = t.join()
t.tick()
local _ = t.messages(p)

-- HEALTH_THRESHOLD_CRIT is 0 of a 100-point bar, so a hundred of brute
-- puts a crewman exactly on the line and no further.
t.set_health(p, { brute = 100 })
local crit = t.body(p)
assert(not crit.controllable, "past `crit` the session no longer steers it")
assert(crit.animate, "but the body itself is still running")
assert(crit.label == "Critical", "and the pack, not the engine, named it")
assert(crit.posture == "lying", "a body nobody is steering is on the deck")

local said = table.concat(t.messages(p), "\n")
assert(said:find("You black out", 1, true),
    "and the plan's own sentence reached them: " .. said)

-- An unsteerable body cannot pick anything up: `controllable` is what
-- every interaction gate asks.
t.click(p, 3, 1, t.target_at(3, 1, "toolbox"))
t.tick()
assert(t.hands(p).held == nil, "and it cannot reach for anything")

-- ...and back over the line, the pack hands the wheel back.
t.set_health(p, { brute = 0 })
local up = t.body(p)
assert(up.controllable and up.animate, "healed back over it, they are theirs again")
assert(up.label == "", "with nothing left to call them")
assert(#up.thresholds == 0, "and no line latched")
said = table.concat(t.messages(p), "\n")
assert(said:find("You come to", 1, true), "and they are told: " .. said)

-- ---------------------------------------------------------------
-- The `dead` line: the pack stops the body outright.
-- ---------------------------------------------------------------
t.world(WARD, 0)
local q = t.join()
t.tick()
local _ = t.messages(q)

-- HEALTH_THRESHOLD_DEAD is -1 of the same bar.
t.set_health(q, { brute = 400 })
local gone = t.body(q)
assert(not gone.animate, "past `dead` the body's own processes stop")
assert(not gone.controllable, "and its session is not steering it")
assert(gone.label == "Dead", "in the pack's words")
assert(gone.posture == "lying", "and it is on the deck")
said = table.concat(t.messages(q), "\n")
assert(said:find("You have died", 1, true), "and it says so: " .. said)

-- Both lines are latched, and the engine reports the SET — which is what
-- lets one handler settle the facts from all of it rather than from the
-- edge that happened to wake it.
local latched = {}
for _, id in ipairs(gone.thresholds) do
    latched[id] = true
end
assert(latched.crit and latched.dead, "four hundred brute crosses both lines")
-- ...and a third, one step removed: crossing `dead` stops the heart
-- (content/bodies/human.luau), the heart is `vital`, and a failing vital
-- organ is exactly what the engine's `viability` port reads. That is the
-- LATCH -- healing these four hundred brute away clears `crit` and
-- `dead` and leaves `undone` standing, which is why a tended corpse
-- stays a corpse (tests/heart_life_test.luau).
assert(latched.undone, "and the stopped heart crosses the viability line too")

-- ---------------------------------------------------------------
-- A faint is not a crossing. Out cold at oxy 60 — past tg's
-- OXYLOSS_PASSOUT_THRESHOLD of 50 (mobs.dm:14) and nowhere near the
-- `crit` line — the crewman keeps breathing and comes back up, which is
-- the knockout-never-death guarantee read from the crew side.
-- ---------------------------------------------------------------
t.world(WARD, 0)
local r = t.join()
t.tick()

t.set_health(r, { oxy = 60 })
local out = t.body(r)
assert(not out.conscious, "past fifty they are out cold")
assert(out.controllable and out.animate,
    "but no declared line was crossed, so the pack was never asked")
assert(#out.thresholds == 0, "and nothing is latched")
assert(out.label == "", "and nothing calls them anything")

-- Breathing is the `breathing` role, and a plain knockout does not touch
-- it: give them a minute of the room's own air and the oxy comes down.
local before = t.health(r).oxy
t.run_seconds(60)
local after = t.health(r).oxy
assert(after < before,
    "a faint in good air recovers its breaths: " .. before .. " -> " .. after)
assert(t.body(r).animate, "and never suffocates to death")
assert(t.body(r).conscious, "and comes round on its own")
assert(t.body(r).posture == "standing", "and gets up")
