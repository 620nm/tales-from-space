-- The reaction chamber, from the outside: put a beaker in it, dial a
-- temperature, and the thing in the beaker gets there and STOPS there.
--
-- Everything here is a click or a window act -- the two surfaces a
-- crewman actually has -- and every reading is `t.holder_k`, which is
-- the derived temperature and never a stored field (invariant I2). A
-- spec about heating equipment can only be written against that.
--
-- What is deliberately NOT asserted is the joule book. The heater is a
-- virtual heat bath: its energy comes off the mains, so the beaker
-- gains joules that came from nowhere in the matter world's terms
-- (sim/holder/heat.rs states the doctrine, and the temperature
-- control unit's file states it at length). What IS assertable is the
-- shape of the approach and the arrest at the dial, from both sides.
local T20C = 293.15

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function row(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r
        end
    end
    return nil
end

t.world([==[(
    name: "chem bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#######",
        "#o.a#g#",
        "#######",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "beaker_libital")],
    machines: [(2, 1, "chem_heater")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3),
    ],
)]==], 0)

local p = t.join()
t.tick()

local heater = t.target_at(2, 1)
assert(heater ~= nil, "a chamber stands on the bench")

-- ---------------------------------------------------------------
-- AN EMPTY HAND ASKS; A FULL ONE LOADS.
-- ---------------------------------------------------------------
t.click(p, 2, 1, heater)
t.tick()
local ui = t.ui(p)
assert(ui, "an empty hand opens the panel")
assert(ui.kind == "thermostat_over_dock", "which is this machine's own")
assert(row(ui, "vessel").value == "empty", "and it says there is nothing in it")
near(ui.setpoints[1].value, 300.0, 1e-9, "the dial opens at tg's 300 K")
t.ui_close(p)

local beaker = t.target_at(1, 1, "beaker_libital")
t.click(p, 1, 1, beaker)
t.tick()
assert(t.hands(p).held == "beaker_libital", "the beaker is in hand")
near(t.holder_k(beaker), T20C, 0.01, "at room temperature, as everything ships")

t.click(p, 2, 1, heater)
t.tick()
assert(t.hands(p).held == nil, "clicking the chamber with it puts it IN")
assert(t.contents(beaker) ~= nil, "the same entity, with the same contents")
assert(t.ledger_has("Docked", "beaker"), "the dock is on the record")

-- ---------------------------------------------------------------
-- SWITCHED OFF, IT IS FURNITURE.
-- ---------------------------------------------------------------
t.click(p, 2, 1, heater)
t.tick()
ui = t.ui(p)
assert(row(ui, "vessel").value == "beaker (libital)", "the panel names what is in it")
assert(ui.toggles[1].on == false, "and it is switched off out of the crate")
t.run_seconds(20)
-- A tenth of a kelvin of slack, not a hundredth: the beaker is open,
-- and evaporation into its own headspace carries a little latent heat
-- away with it (Effort G). It is a fraction of the deck coupling's
-- half-kelvin deadband, which is why nothing pulls it back.
near(t.holder_k(beaker), T20C, 0.1, "a chamber nobody switched on moves nothing")

-- ---------------------------------------------------------------
-- THE APPROACH, AND THE ARREST.
--
-- tg's arithmetic closes a fixed FRACTION of the remaining gap every
-- pass (chem_heater.dm:172), so what a spec can pin is that the
-- temperature only ever climbs, that it gets there, and that it stops
-- -- not a number per tick.
-- ---------------------------------------------------------------
t.ui_act(p, "set", '{"field":"temperature","value":350}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.ui(p).toggles[1].on == true, "the element is on")
near(t.ui(p).setpoints[1].value, 350.0, 1e-9, "and the dial is where it was put")

local last = t.holder_k(beaker)
for _ = 1, 12 do
    t.run_seconds(1)
    local now = t.holder_k(beaker)
    assert(now > last, "it climbs every pass: " .. last .. " -> " .. now)
    assert(now <= 350.0 + 1e-9, "and never crosses the dial: " .. now)
    last = now
end
t.run_seconds(120)
near(t.holder_k(beaker), 350.0, 0.5, "given long enough it arrives")
t.run_seconds(60)
near(t.holder_k(beaker), 350.0, 0.5, "and then it sits there")
assert(row(t.ui(p), "temperature").tone == "idle", "the panel says the vessel is on the dial")

-- ---------------------------------------------------------------
-- ...AND THE SAME MACHINE COMING BACK DOWN.
--
-- tg's chem heater is a heater by name and a THERMOSTAT by arithmetic:
-- the same line with a negative gap cools. Dialling under the beaker
-- is the whole test.
-- ---------------------------------------------------------------
t.ui_act(p, "set", '{"field":"temperature","value":310}')
t.run_ticks(2)
assert(row(t.ui(p), "temperature").tone == "on", "the vessel is over the dial now")
last = t.holder_k(beaker)
for _ = 1, 12 do
    t.run_seconds(1)
    local now = t.holder_k(beaker)
    assert(now < last, "it falls every pass: " .. last .. " -> " .. now)
    assert(now >= 310.0 - 1e-9, "and never crosses the dial from above: " .. now)
    last = now
end
t.run_seconds(150)
near(t.holder_k(beaker), 310.0, 0.5, "arriving from above, and arresting there")

-- ---------------------------------------------------------------
-- AND YOU GET IT BACK.
-- ---------------------------------------------------------------
local warm = t.holder_k(beaker)
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
assert(t.hands(p).held == "beaker_libital", "the eject button hands it back")
near(t.holder_k(beaker), warm, 0.5, "still carrying the heat it was given")
assert(t.ledger_has("Undocked", "beaker"), "and the eject is on the record too")
assert(row(t.ui(p), "vessel").value == "empty", "the panel agrees there is nothing in it")

-- ...and a vessel IN A HAND is a vessel you are insulating: the deck
-- coupling is for things lying on the deck (sim/holder/heat.rs), so
-- carrying a hot beaker around costs it nothing THE ROOM could take.
-- What it does still lose is its own latent heat: an open beaker is
-- evaporating, faster the warmer it is, and twenty seconds of that is
-- a few hundredths of a kelvin (Effort G). A tenth of a kelvin of
-- slack keeps the claim -- no deck coupling in a hand -- while telling
-- the truth about the vapour.
t.run_seconds(20)
near(t.holder_k(beaker), warm, 0.1, "carried, it keeps every joule the room could take")

-- Put it down and the room gets to work on it. tg has no ambient
-- coupling at all; this is the deliberate departure that makes a beaker
-- left standing about behave like a beaker left standing about.
t.drop(p)
t.run_seconds(20)
assert(t.holder_k(beaker) < warm - 1.0,
    "on the deck it cools towards the room: " .. t.holder_k(beaker))
assert(t.holder_k(beaker) > T20C, "though not instantly: " .. t.holder_k(beaker))
