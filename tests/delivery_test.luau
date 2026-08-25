-- Delivery: how a finished solution gets out of the beaker and into
-- somebody. Three gestures, all of them a click a crewman could make --
-- a syringe drawn out of a vessel and pushed into a crewman, a packager
-- turning a beaker into pills, and a pill swallowed.
--
-- Everything here rides the ONE transfer (docs/LUAU-API.md 8.2). What
-- makes a syringe a syringe rather than a beaker is which way round the
-- ends are and how much moves; what makes a bloodstream a legal end is
-- that a body is a vessel like any other (docs/CHEMISTRY.md 9). So the
-- assertions are all the same shape: this much left there, that much
-- arrived here, and nothing was invented on the way.
--
-- The libital beaker ships holding 0.20 water and 0.15 libital, so
-- every proportional draw below is four sevenths water to three
-- sevenths libital, and each number is that ratio times the stroke.

local STROKE = 0.125 -- tg's 5 u at 1 u = 0.025 mol (syringes.dm:11)
local SHIPS = 0.35 -- what a beaker_libital arrives holding
local PILLS = 5 -- what the packager prints in one gesture

t.world([==[(
    name: "ward",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#############",
        "#o.......a#g#",
        "#############",
    ],
    spawns: [(3, 1), (7, 1)],
    items: [
        (3, 1, "syringe"),
        (3, 1, "beaker_libital"),
        (4, 1, "beaker"),
        (5, 1, "beaker_libital"),
        (6, 1, "beaker_libital"),
    ],
    machines: [(2, 1, "chem_packager")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3),
        (6, 1, 3), (7, 1, 3), (8, 1, 3), (9, 1, 3), (10, 1, 3),
        (11, 1, 3),
    ],
)]==], 0)

local medic = t.join()
local patient = t.join()
t.run_ticks(3)

local packager = t.target_at(2, 1)
local syringe = t.target_at(3, 1, "syringe")
local source = t.target_at(3, 1, "beaker_libital")
local empty = t.target_at(4, 1, "beaker")
local first = t.target_at(5, 1, "beaker_libital")
local second = t.target_at(6, 1, "beaker_libital")
local pid = t.body_id(patient)
assert(packager ~= nil and syringe ~= nil, "the bench is laid out")

local function said(who, needle)
    return (" " .. table.concat(t.messages(who), " || ") .. " "):find(needle, 1, true) ~= nil
end
local function total(handle)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    local n = 0
    for _, moles in pairs(contents) do
        n = n + moles
    end
    return n
end
-- What is actually POURABLE: the condensed phases only, which is what
-- the packager divides and what a pill can carry. `t.contents` collapses
-- every phase together, and over an open beaker of water the difference
-- is real -- a few micromoles standing as vapour in the headspace.
local function condensed(handle)
    local v = t.vessel(handle)
    assert(v ~= nil, "that is a vessel")
    local n = 0
    for _, phases in pairs(v.contents) do
        n = n + (phases.liquid or 0) + (phases.solid or 0)
    end
    return n
end
local function close(got, want, what)
    assert(math.abs(got - want) < 1e-9, ("%s: wanted %g, got %g"):format(what, want, got))
end
local function near(got, want, slack, what)
    assert(math.abs(got - want) < slack, ("%s: wanted %g, got %g"):format(what, want, got))
end
local function take(p, x, y, id)
    if t.hands(p).held ~= nil then
        t.drop(p)
        t.tick()
    end
    t.click(p, x, y, id)
    t.run_ticks(2)
end
local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(3)
end

-- ---------------------------------------------------------------
-- THE DIAL. A syringe off the shelf is set to DRAW, because an empty
-- one has nothing to inject; activating it in hand turns it round, and
-- the refusal is what proves which way it was pointing.
-- ---------------------------------------------------------------
take(medic, 3, 1, syringe)
assert(t.hands(medic).held == "syringe", "the syringe is in hand")
close(total(syringe), 0, "and it ships empty")

t.use_self(medic)
t.run_ticks(2)
assert(said(medic, "set the syringe to inject"), "one press turns it round")

local before = total(source)
t.click(medic, 3, 1, source)
t.run_ticks(2)
assert(said(medic, "The syringe is empty."), "an empty barrel has nothing to push")
close(total(source), before, "and the refusal moved nothing")

t.use_self(medic)
t.run_ticks(2)
assert(said(medic, "set the syringe to draw"), "and back again")

-- ---------------------------------------------------------------
-- DRAW: one stroke out of a beaker, proportional and exact.
-- ---------------------------------------------------------------
t.click(medic, 3, 1, source)
t.run_ticks(2)
assert(said(medic, "You fill the syringe."), "the plunger comes back")
close(total(syringe), STROKE, "one stroke is tg's five units")
close(total(source), SHIPS - STROKE, "and the beaker is down by exactly that")
local drawn = t.contents(syringe)
close(drawn.water, 0.20 * (STROKE / SHIPS), "water came in proportion")
close(drawn.libital, 0.15 * (STROKE / SHIPS), "libital came in proportion")

-- ---------------------------------------------------------------
-- INJECT: a crewman who is not you is three seconds of standing still
-- (tg's CHEM_INTERACT_DELAY, syringes.dm:78), and then the bloodstream
-- is the far end of the same call.
-- ---------------------------------------------------------------
t.use_self(medic)
t.run_ticks(2)
assert(said(medic, "set the syringe to inject"), "pointed at the patient")
walk(medic, "east")
walk(medic, "east")
walk(medic, "east")
local mx = t.pos(medic)
assert(mx == 6, "the medic is standing beside the patient, at " .. mx)

local blood_before = t.blood(patient).libital or 0
t.click(medic, 7, 1, pid)
t.run_ticks(2)
assert(said(medic, "You line the needle up"), "the gesture parks rather than lands")
close(total(syringe), STROKE, "and nothing has moved yet")
assert(#t.ledger_rows("DoAfterStarted") > 0, "it parked as a do_after")

t.run_ticks(62) -- tg's three seconds, at twenty ticks to the second
assert(said(medic, "You inject"), "the needle goes in")
-- A stroke pushes the CONDENSED phases, so what stays behind is the
-- vapour that saturated the barrel's own headspace while it was full --
-- micromoles of water, and the honest answer rather than a rounding.
near(total(syringe), 0, 1e-5, "the barrel is empty but for its own vapour")
-- The bloodstream got the whole stroke. It is measured with slack
-- rather than to the mole because a body BURNS what is in it: libital
-- declares `metabolism_rate = 0.003` and the metabolism has run since
-- the transfer landed.
local gained = (t.blood(patient).libital or 0) - blood_before
near(gained, 0.15 * (STROKE / SHIPS), 5e-3, "the libital arrived in the blood")
assert(gained > 0, "and it is the patient who has it")
-- ---------------------------------------------------------------
-- THE PACKAGER. Two pours make half a mole in one beaker; one click
-- against the extruder turns it into five pills.
-- ---------------------------------------------------------------
t.drop(medic)
t.tick()
take(medic, 6, 1, second)
walk(medic, "west")
t.click(medic, 4, 1, empty)
t.run_ticks(2)
close(total(empty), 0.25, "one pour is a quarter mole")
take(medic, 5, 1, first)
t.click(medic, 4, 1, empty)
t.run_ticks(2)
close(total(empty), 0.5, "two pours are half of one")

t.drop(medic)
t.tick()
walk(medic, "west")
take(medic, 4, 1, empty)
walk(medic, "west")
assert(t.pos(medic) == 3, "the medic is at the extruder")
assert(t.hands(medic).held == "beaker", "with half a mole in hand")

near(condensed(empty), 0.5, 1e-3, "half a mole, less what stands in the headspace")
t.click(medic, 2, 1, packager)
t.run_ticks(2)
assert(said(medic, "You hold it against the extruder."), "the print is ordered")
t.run_ticks(90) -- five pills at tg's 0.75 s each, plus slack
assert(said(medic, "The extruder clicks and stops."), "and it finishes")

assert(t.count_items("pill") == PILLS, "five pills, no more and no less")
near(condensed(empty), 0, 1e-9, "and the beaker gave up every drop of it")

-- Each pill is a fifth of the beaker to within micromoles, and the five
-- of them are the beaker. It is micromoles rather than nothing because
-- the source is an OPEN vessel and the print takes four seconds: it
-- breathes with the room throughout (docs/CHEMISTRY.md 9), so tg's own
-- arithmetic -- a per-container dose computed ONCE off the buffer as it
-- stood when the print was ordered (chem_master.dm:514) -- comes up a
-- few micromoles short by the last pill. The shortfall is in the room,
-- not in the accounting.
local dose, printed = 0, 0
t.drop(medic)
t.tick()
for _ = 1, PILLS do
    local one = t.target_at(2, 1, "pill")
    assert(one ~= nil, "another pill is on the tray")
    dose = total(one)
    near(dose, 0.5 / PILLS, 1e-4, "each pill is a fifth of the beaker")
    printed = printed + dose
    take(medic, 2, 1, one)
    assert(t.hands(medic).held == "pill", "and it comes off the tray")
    walk(medic, "east")
    t.drop(medic)
    t.run_ticks(2)
    walk(medic, "west")
end
near(printed, 0.5, 1e-3, "and the five of them are the beaker")

-- ---------------------------------------------------------------
-- SWALLOWING. One click on your own tile, everything moves, and the
-- pill itself is spent rather than left lying about empty.
-- ---------------------------------------------------------------
local last = t.target_at(4, 1, "pill")
assert(last ~= nil, "the pills are stacked on the next tile")
local mine = t.blood(medic).libital or 0
take(medic, 4, 1, last)
assert(t.hands(medic).held == "pill", "the pill is in hand")
t.click(medic, 3, 1)
t.run_ticks(2)
assert(said(medic, "You swallow the pill."), "down it goes")
assert(t.count_items("pill") == PILLS - 1, "and the pill is gone with it")
near((t.blood(medic).libital or 0) - mine, 0.15 * (dose / SHIPS), 5e-3,
    "a fifth of the beaker landed in the medic")

-- ---------------------------------------------------------------
-- THE OTHER REFUSAL: a barrel with no room left in it. Capacity is
-- geometry (D2), so "full" is fifteen millilitres of solution and never
-- a count of moles -- two strokes of the mix this bench is making fill
-- it, and the plunger will not go back a third time.
-- ---------------------------------------------------------------
walk(medic, "east")
walk(medic, "east")
walk(medic, "east")
take(medic, 6, 1, syringe)
assert(t.hands(medic).held == "syringe", "the syringe again")
walk(medic, "west")
walk(medic, "west")
walk(medic, "west")
t.use_self(medic)
t.run_ticks(2)
assert(said(medic, "set the syringe to draw"), "pointed at the beaker again")
t.click(medic, 3, 1, source)
t.run_ticks(2)
t.click(medic, 3, 1, source)
t.run_ticks(2)
near(t.vessel(syringe).headspace_l, 0, 1e-6, "two strokes fill the barrel to the brim")
t.click(medic, 3, 1, source)
t.run_ticks(2)
assert(said(medic, "The syringe is full."), "and a third stroke is refused")
