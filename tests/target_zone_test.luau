-- The target selector: what the HUD doll and the numbered target keys
-- choose, and what a surgeon's hands then reach (docs/SURGERY.md §6.3,
-- docs/BIOLOGY.md §9).
--
-- `t.set_zone` is the real wire claim (`ClientMsg::SetTargetZone`), so
-- everything below is the path a browser takes: the pack declares which
-- parts exist and where they sit on the doll, the engine grades the word
-- against the AIMER's own plan, and the operation lands on whatever
-- survived that. A zone this body has not got changes nothing at all.

local ARENA = [==[(
    name: "ward",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "#####", "#...#", "#####" ],
    spawns: [(1, 1), (2, 1)],
    structures: [(2, 1, "optable")],
    items: [ (1, 1, "scalpel"), (1, 1, "retractor") ],
)]==]

local function has(states, name) return states[name] == true end

t.world(ARENA, 0)
local surgeon = t.join()
local patient = t.join()
t.run_ticks(3)
t.rest(patient, true)
-- Bare the torso and limbs: the jumpsuit `covers` them and a covered
-- part is not operable, so the aim could not be shown to matter while
-- only the head was reachable.
t.unequip(patient, "uniform")
t.run_ticks(2)
local PX, PY = 2, 1
local pid = t.body_id(patient)

-- =====================================================================
-- A word the plan never declared is refused, and the aim does not move.
-- =====================================================================
assert(t.set_zone(surgeon, "head"), "the plan declares a head")
assert(not t.set_zone(surgeon, "tail"), "this body has no tail to aim at")
assert(not t.set_zone(surgeon, "HEAD"), "the id is the id, not a spelling of it")
assert(not t.set_zone(surgeon, ""), "and the empty word names nothing")

-- =====================================================================
-- The chosen zone is where the hands land. Aim at the head, cut, and it
-- is the HEAD that is open.
-- =====================================================================
t.click(surgeon, 1, 1, t.target_at(1, 1, "scalpel"))
t.run_ticks(2)
t.click(surgeon, PX, PY, pid)
t.run_ticks(math.ceil(1.6 * 20) + 3)

local parts = t.parts(patient)
assert(has(parts.head.states, "skin_cut"), "the head was cut: that is where the aim was")
assert(not has(parts.chest.states, "skin_cut"), "and nowhere else was")

-- =====================================================================
-- Switching the aim switches the site: the same tool, the same click,
-- a different part opened.
-- =====================================================================
assert(t.set_zone(surgeon, "l_arm"), "the plan declares a left arm")
t.click(surgeon, PX, PY, pid)
t.run_ticks(math.ceil(1.6 * 20) + 3)

parts = t.parts(patient)
assert(has(parts.l_arm.states, "skin_cut"), "the arm was cut once the aim moved there")
assert(not has(parts.r_arm.states, "skin_cut"), "the other arm is a different zone")

-- =====================================================================
-- ...and a refused zone leaves the aim where it was, so the NEXT click
-- still lands on the last part that was legally chosen rather than on
-- the plan's default.
-- =====================================================================
assert(not t.set_zone(surgeon, "wing"), "no wing on this plan")
t.drop(surgeon)
t.tick()
t.click(surgeon, 1, 1, t.target_at(1, 1, "retractor"))
t.run_ticks(2)
t.click(surgeon, PX, PY, pid)
t.run_ticks(math.ceil(2.4 * 20) + 3)

parts = t.parts(patient)
assert(has(parts.l_arm.states, "skin_open"),
    "the aim stayed on the arm: a refused claim moves nothing, not even to the default")
assert(not has(parts.chest.states, "skin_cut"), "the default zone was never fallen back to")
