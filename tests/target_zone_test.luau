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

-- =====================================================================
-- THE NUMBERED KEYS. A browser never sends a key: it reads the doll
-- roster the server pushed, finds the row sitting on the number that
-- was pressed, and claims that row's id
-- (`crates/lunatic-client/src/doll.rs::zone_for_slot`, which is unit
-- tested there against ids that mean nothing). `t.doll` is that same
-- roster, so this section presses Numpad 2 the way a browser does.
--
-- 2 is tg's groin key (`target_body_groin`,
-- code/datums/keybinding/mob.dm:217-222) and this plan hangs its pelvis
-- there.
-- =====================================================================
local function zone_for_slot(who, slot)
    for _, row in ipairs(t.doll(who)) do
        if row.slot == slot then return row.id end
    end
    return nil
end

assert(zone_for_slot(surgeon, 2) == "pelvis", "Numpad 2 aims at the pelvis")
assert(zone_for_slot(surgeon, 5) == "chest", "and 5 is still the chest")
assert(zone_for_slot(surgeon, 7) == nil, "7 is tg's eyes and this plan has none")

-- The doll rectangle the pelvis owns is tg's own groin band -- icon_y
-- 10..13, icon_x 12..20 (get_zone_at, screen_objects.dm:764-800) -- and
-- a click in the middle of it is what a mouse does with that number.
for _, row in ipairs(t.doll(surgeon)) do
    if row.id == "pelvis" then
        assert(math.abs(row.rect[2] - 19 / 32) < 1e-6,
            "the band starts where tg's does: " .. row.rect[2])
        assert(math.abs(row.rect[4] - 4 / 32) < 1e-6,
            "and is four pixels deep: " .. row.rect[4])
    end
end

-- ...and the key is an AIM, so the next cut lands there. The jumpsuit
-- came off at the top of this file, which is what makes the pelvis
-- reachable at all (tg jumpsuits are body_parts_covered CHEST|GROIN|
-- LEGS|ARMS, clothing/under/_under.dm:8).
assert(t.set_zone(surgeon, zone_for_slot(surgeon, 2)), "the plan declares a pelvis")
t.drop(surgeon)
t.tick()
t.click(surgeon, 1, 1, t.target_at(1, 1, "scalpel"))
t.run_ticks(2)
t.click(surgeon, PX, PY, pid)
t.run_ticks(math.ceil(1.6 * 20) + 3)

parts = t.parts(patient)
assert(has(parts.pelvis.states, "skin_cut"), "the pelvis was cut: that is where the aim was")
assert(not has(parts.chest.states, "skin_cut"), "and the chest above it was not")

-- =====================================================================
-- COMBAT. A swung toolbox aims where the doll points
-- (`content/items/toolbox.luau` passes `sim.zone(user)` as `aim`), and
-- an aim is a TRY: the pack declares 80%, +10 against a body that is
-- down (`content/part_tree.luau`), and the rest of the time the blow
-- lands wherever the hit weights send it. So this section is
-- seed-pinned — the assertion is that the aimed zone is where the
-- damage concentrates, which is only a statement about a fixed roll.
-- =====================================================================
local BRAWL = [==[(
    name: "brawl",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "#####", "#...#", "#####" ],
    spawns: [(1, 1), (2, 1)],
    items: [ (1, 1, "toolbox") ],
)]==]

t.world(BRAWL, 7)
local attacker = t.join()
local victim = t.join()
t.run_ticks(3)
local vid = t.body_id(victim)

t.click(attacker, 1, 1, t.target_at(1, 1, "toolbox"))
t.run_ticks(2)

local function brute(zone) return t.parts(victim)[zone].brute or 0 end
local function swing()
    t.click(attacker, 2, 1, vid)
    t.run_ticks(4)
end

-- Aimed at the head, most of ten swings land on the head. The count is
-- what the seed above produces; it is above the 5 a hit-weight-only
-- roll would give the head (weight 1 of 15), which is the whole point.
assert(t.set_zone(attacker, "head"), "the plan declares a head")
for _ = 1, 10 do swing() end
local head, elsewhere = brute("head"), 0
for _, zone in ipairs({ "chest", "pelvis", "l_arm", "r_arm", "l_leg", "r_leg" }) do
    elsewhere = elsewhere + brute(zone)
end
assert(head + elsewhere == 100, "ten swings of 10 brute all landed somewhere: " .. head + elsewhere)
assert(head >= 70, "the aimed zone took the bulk of it, not a hit-weight share: " .. head)

-- Move the aim and the damage moves with it. A shorter volley here:
-- an arm caps at 50 brute (`content/items/human_l_arm.luau`, tg's
-- LIMB_MAX_HP_DEFAULT) where the head takes 200, and damage past a
-- part's ceiling is discarded — so ten more swings would measure the
-- clamp rather than the aim. Four, and the assertion is on the SHARE
-- each zone gained, which is what "the aim moved" actually means.
local ZONES = { "head", "chest", "pelvis", "l_arm", "r_arm", "l_leg", "r_leg" }
local before = {}
for _, zone in ipairs(ZONES) do before[zone] = brute(zone) end

assert(t.set_zone(attacker, "l_arm"), "the plan declares a left arm")
for _ = 1, 4 do swing() end

local gained, worst, worst_zone = {}, -1, nil
for _, zone in ipairs(ZONES) do
    gained[zone] = brute(zone) - before[zone]
    if zone ~= "l_arm" and gained[zone] > worst then
        worst, worst_zone = gained[zone], zone
    end
end
assert(gained.l_arm >= 30,
    "the second volley followed the aim to the arm: " .. gained.l_arm)
assert(gained.l_arm > worst,
    "and the arm took more than any other zone (" .. worst_zone .. " took " .. worst .. ")")
