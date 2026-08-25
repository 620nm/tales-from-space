-- The organ threshold edges, read from the crew side (docs/BIOLOGY.md
-- §5). `content/items/organ_brain.luau` and `organ_eyes.luau` each
-- register a `body.threshold.done` handler; this is the spec that says
-- those handlers RUN, rather than sitting in the pack as text nothing
-- ever dispatches.
--
-- Every number below is the organ file's own. Brain: max_health 200,
-- low 45, high 120, decay 0.000555/s of the pool — 0.111 damage a
-- second, so 45 damage is about 405 seconds and 120 is about 1081.
-- Eyes: max_health 50, high 30, decay 0.00111/s — 0.0555 a second, so
-- 30 damage is about 540 seconds and failure is about 900.
--
-- A living body HEALS its organs, so the only thing in the game today
-- that drives a pool up on its own is a corpse going off: kill the
-- crewman, let the shift run, and read what the handlers said.
local ARENA = [==[(
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
    spawns: [(1, 1), (2, 1), (3, 1)],
)]==]

t.world(ARENA, 0)
local p = t.join()
t.tick()

assert(t.organ_damage(p, "brain") == 0, "a crewman arrives with a whole brain")
assert(t.organ_damage(p, "eyes") == 0, "and whole eyes")

t.set_health(p, { brute = 400 })
assert(not t.body(p).animate, "four hundred brute is a body")

-- Past the brain's low edge (45) and nothing else: the eyes are still
-- short of their high edge (30) at this point, and the brain of its
-- own (120).
t.run_seconds(420)
local said = table.concat(t.messages(p), "\n")
assert(said:find("Your head swims.", 1, true),
    "the brain's low edge reached its handler: " .. said)
assert(not said:find("You cannot hold a thought.", 1, true),
    "and only that edge: " .. said)

-- Far enough for the eyes to blur, then fail, and for the brain to
-- cross its own high edge.
-- `t.messages` drains what a session has read, so the second window is
-- the second window and the first line has to be carried forward.
local first = said
t.run_seconds(700)
said = table.concat(t.messages(p), "\n")
assert(said:find("Your vision blurs and swims.", 1, true),
    "the eyes' high edge reached its handler: " .. said)
assert(said:find("Everything goes dark.", 1, true),
    "and so did their failure: " .. said)
assert(said:find("You cannot hold a thought.", 1, true),
    "and the brain's high edge: " .. said)

-- An edge fires ONCE per crossing (§5): the pool keeps climbing past
-- 45 for another eleven hundred seconds and says nothing more about it.
local _, low_count = (first .. "\n" .. said):gsub("Your head swims%.", "")
assert(low_count == 1, "one low edge, not one a pass: " .. low_count)
