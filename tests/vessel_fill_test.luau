-- What the glass SHOWS, and when it shows it.
--
-- A beaker's level is a picture chosen off the ladder in
-- `content/items/beaker.luau` by how much of the shell the contents
-- fill. The bug this spec is written against is not which picture gets
-- chosen -- that is arithmetic, and the engine tests it against its own
-- fixture ladder -- it is WHEN: a picture that follows the contents
-- repaints on the tick they move, and a picture hung on a list of
-- gestures repaints on whichever gesture somebody remembered.
--
-- So both halves here are about a tick. A pour is two vessels changing
-- at once with nothing entering or leaving a hand; boiling a beaker dry
-- is contents leaving with no gesture at all. Neither is allowed to
-- need a stow-and-fetch to catch up.
local PRESS = 0.75

local function amount(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0
end

local function fill_of(handle)
    local worn = t.overlays(handle)
    return worn[1]
end

t.world([==[(
    name: "fill bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#oag#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 1)],
    items: [
        (1, 1, "beaker.water"),
        (2, 1, "beaker"),
        (3, 1, "beaker"),
    ],
    machines: [(1, 2, "chem_dispenser"), (3, 2, "chem_heater")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
    ],
)]==], 0)

local p = t.join()
t.tick()

local full = t.target_at(1, 1, "beaker.water")
local empty = t.target_at(3, 1, "beaker")

-- ---------------------------------------------------------------
-- ONE: A POUR SHOWS ON BOTH VESSELS, IN THE TICK IT LANDS.
-- ---------------------------------------------------------------
-- 0.60 mol of water is 10.8 mL in fifty of glass: 22%, which is the 20
-- stop. The bare beaker beside it wears nothing, because a vessel with
-- nothing in it is the picture it was minted as.
assert(fill_of(full) == "beaker_fill_20", "the water beaker shows its level")
assert(fill_of(empty) == nil, "and the bare one shows none at all")

t.click(p, 1, 1, full)
t.tick()
t.click(p, 3, 1, empty)
-- ONE tick. Not "eventually", and not after the beaker has been put
-- somewhere and taken back out: the pour landed, so the pictures moved.
t.tick()

assert(amount(empty, "water") > 0, "the pour moved water")
assert(
    fill_of(empty) == "beaker_fill_1",
    "what was poured INTO shows a level on the same tick: " .. tostring(fill_of(empty))
)
assert(
    fill_of(full) == "beaker_fill_1",
    "and what was poured OUT OF shows a lower one: " .. tostring(fill_of(full))
)
-- AND THE PANEL, which is the half a crewman is actually looking at.
-- The beaker being poured out of is in a hand: it has no tile and no
-- entity delta, so the inventory push is the only way its level reaches
-- its owner. Nothing entered or left a hand here.
assert(
    t.hud_fill(p)[1] == "beaker_fill_1",
    "the hand panel shows the new level too: " .. tostring(t.hud_fill(p)[1])
)

-- Tip the rest of it in. The far beaker has room, so the source ends
-- with nothing in it -- and a vessel with nothing in it shows nothing,
-- in the panel, on the tick it empties, without being stowed and taken
-- back out to force the question.
for _ = 1, 6 do
    if amount(full, "water") <= 0 then
        break
    end
    t.click(p, 3, 1, empty)
    t.tick()
end
assert(amount(full, "water") <= 0, "the source is empty: " .. amount(full, "water"))
assert(fill_of(full) == nil, "the emptied glass wears nothing: " .. tostring(fill_of(full)))
assert(
    t.hud_fill(p)[1] == nil,
    "and its panel row shows nothing either: " .. tostring(t.hud_fill(p)[1])
)

-- ---------------------------------------------------------------
-- TWO: A BEAKER BOILED DRY ENDS UP SHOWING NOTHING.
-- ---------------------------------------------------------------
-- Contents leaving with no gesture behind it at all: the chamber holds
-- the glass over water's boil, the vapour crosses the mouth into the
-- room (sim/holder/vent.rs), and what is left goes down asymptotically.
-- The picture has to follow it all the way to bare -- a beaker stuck on
-- its lowest rung forever is a beaker that reads as still having
-- something in it.
t.drop(p)
t.tick()

local dispenser = t.target_at(1, 2)
local heater = t.target_at(3, 2)
local beaker = t.target_at(2, 1, "beaker")

t.click(p, 2, 1, beaker)
t.tick()
t.click(p, 1, 2, dispenser)
t.tick()
t.click(p, 1, 2, dispenser)
t.tick()
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
-- A press, less whatever the open mouth has already breathed off into
-- the room by now: the glass has been standing in station air for the
-- whole of part one (sim/holder/vent.rs), so this is a press to within
-- a thousandth and not to the bit.
assert(math.abs(amount(beaker, "water") - PRESS) < 1e-3, "three quarters of a mole of water")
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)

t.click(p, 3, 2, heater)
t.tick()
t.click(p, 3, 2, heater)
t.tick()
t.ui_act(p, "set", '{"field":"temperature","value":600}')
t.run_ticks(2)
t.ui_act(p, "toggle", '{"field":"power"}')

-- Watch the PICTURE rather than the moles: the assertion is about what
-- a crewman sees, and the two only agree if the repaint follows the
-- contents. The vessel is sitting in a machine the whole time and is
-- never touched again, so nothing here can be mistaken for a gesture
-- forcing the question.
local bare = false
for _ = 1, 600 do
    t.run_ticks(5)
    if fill_of(beaker) == nil then
        bare = true
        break
    end
end

assert(
    bare,
    "the boiled-dry beaker went all the way to bare, not to its lowest rung: "
        .. tostring(fill_of(beaker))
        .. " over "
        .. amount(beaker, "water")
        .. " mol"
)
assert(t.holder_k(beaker) > 373.0, "the chamber held it over the boil the whole time")
