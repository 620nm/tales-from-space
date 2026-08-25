-- The refusal codes and the two-party guard (docs/SURGERY.md §6.3). A
-- surgical tool with nothing to do is refused rather than swung, and the
-- reason — not_lying / obstructed / nothing_to_do — reaches the tool's
-- own `attack.swing`, which speaks it. And a parked operation ends the
-- instant either party moves out from under it.

local ARENA = [==[(
    name: "ward",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "#####", "#...#", "#####" ],
    spawns: [(1, 1), (2, 1)],
    items: [ (1, 1, "scalpel"), (1, 1, "retractor") ],
)]==]

t.world(ARENA, 0)
local surgeon = t.join()
local patient = t.join()
t.run_ticks(3)
local PX, PY = 2, 1
local pid = t.body_id(patient)

local function said(who, needle)
    return (" " .. table.concat(t.messages(who), " || ") .. " "):find(needle, 1, true) ~= nil
end
local function hold(id)
    if t.hands(surgeon).held then t.drop(surgeon); t.tick() end
    t.click(surgeon, 1, 1, t.target_at(1, 1, id)); t.run_ticks(2)
end

-- ---- obstructed: lying, but the chest is covered ----------------------
-- A scalpel would incise a bare chest, so the only thing in the way is
-- the jumpsuit, and the refusal names it.
t.rest(patient, true)
t.run_ticks(2)
assert(t.worn(patient).uniform ~= nil, "still in the jumpsuit")
hold("scalpel")
t.click(surgeon, PX, PY, pid)
t.run_ticks(2)
assert(said(surgeon, "covered"), "a covered chest: obstructed")

-- ---- not_lying: bare, but standing ------------------------------------
t.unequip(patient, "uniform")
t.rest(patient, false)
t.run_ticks(2)
assert(t.body(patient).posture == "standing", "on their feet")
t.click(surgeon, PX, PY, pid)
t.run_ticks(2)
assert(said(surgeon, "lying down"), "a standing patient: not_lying")

-- ---- nothing_to_do: bare, lying, but the wrong tool -------------------
t.rest(patient, true)
t.run_ticks(2)
hold("retractor") -- a retractor needs a cut to retract; the skin is whole
t.click(surgeon, PX, PY, pid)
t.run_ticks(2)
assert(said(surgeon, "nothing to retract"), "no incision yet: nothing_to_do")
-- And nothing was cut: the retractor never touched the patient.
assert(t.parts(patient).chest.states.skin_cut ~= true, "a refusal is not a swing")

-- ---- the two-party guard: the patient stands up -----------------------
-- Now everything is right (bare, lying, a scalpel), so this parks. Part
-- way through, the patient gets up and the attempt ends with no cut.
hold("scalpel")
t.click(surgeon, PX, PY, pid)
t.run_ticks(20) -- the incise do_after is 80 ticks; interrupt it early
local parked = #t.ledger_rows("DoAfterStarted")
assert(parked > 0, "the incision parked")
-- One operation in flight per surgeon (tg DOAFTER_SOURCE_SURGERY): a
-- second click while parked is refused, and no second do_after starts.
t.click(surgeon, PX, PY, pid)
t.run_ticks(2)
assert(#t.ledger_rows("DoAfterStarted") == parked, "one in flight: the second click parked nothing")
assert(said(surgeon, "already operating"), "and the surgeon is told they are busy")
t.rest(patient, false) -- they sit up
t.run_ticks(3)
assert(#t.ledger_rows("DoAfterInterrupted") > 0, "the patient stood: interrupted")
assert(t.parts(patient).chest.states.skin_cut ~= true, "no cut landed")

-- ---- the two-party guard: the surgeon drops the tool ------------------
t.rest(patient, true)
t.run_ticks(2)
local before = #t.ledger_rows("DoAfterInterrupted")
t.click(surgeon, PX, PY, pid)
t.run_ticks(20)
t.drop(surgeon) -- the scalpel leaves the hand
t.run_ticks(3)
assert(#t.ledger_rows("DoAfterInterrupted") > before, "the tool left the hand: interrupted")
assert(t.parts(patient).chest.states.skin_cut ~= true, "and still no cut")

print("refusal: not_lying, obstructed, nothing_to_do; guard interrupts on both parties")
