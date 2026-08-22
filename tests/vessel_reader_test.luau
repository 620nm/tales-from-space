-- What is inside a thing, asked once for everything that has an
-- inside. `t.vessel` is content's `ctx.vessel`: one reading -- pressure,
-- temperature, volume, headspace, whether it is closed, how much is in
-- it and in which phase -- off a bottle of oxygen, a beaker of water
-- and a canister alike, because all three are one body of matter in a
-- known volume (docs/CHEMISTRY.md).
--
-- The reading is what a gauge and a pair of eyes could tell, in the
-- units an instrument prints: kPa and litres, never the sim's own
-- pascals and cubic metres. A crowbar is here to be told nothing about.

t.world([==[(
    name: "vessel bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'c': (turf: Plating, fixture: Some(Canister)),
    },
    rows: [
        "#######",
        "#.....#",
        "#....c#",
        "#######",
    ],
    spawns: [(1, 1)],
    items: [
        (2, 1, "oxygen_tank"),
        (3, 1, "beaker_libital"),
        (4, 1, "crowbar"),
        (5, 1, "beaker"),
    ],
)]==], 0)

local p = t.join()
t.tick()

local function near(got, want, tol, what)
    assert(got ~= nil, what .. ": nothing was answered")
    assert(math.abs(got - want) <= tol,
        ("%s: wanted %g, got %g"):format(what, want, got))
end

-- ---------------------------------------------------------------
-- The bottle on the shelf: seventy litres of oxygen at six
-- atmospheres, and every one of those numbers readable.
-- ---------------------------------------------------------------
local tank = t.vessel(t.target_at(2, 1, "oxygen_tank"))
assert(tank ~= nil, "a tank has an inside")
near(tank.pressure_kpa, 6 * 101.325, 1.0, "the bottle reads its fill pressure")
near(tank.volume_l, 70.0, 1e-9, "seventy litres of shell")
near(tank.headspace_l, 70.0, 1e-9, "all of it gas space -- nothing in it is wet")
near(tank.temp_k, 293.15, 0.5, "filled at room temperature")
assert(tank.moles > 0, "and it holds something: " .. tostring(tank.moles))
assert(tank.sealed, "a gas bottle is closed -- it has no mouth to breathe through")

-- Contents are PHASE-RESOLVED, and a phase nothing is standing in is
-- absent rather than zero. Oxygen in a bottle is gas and only gas.
assert(tank.contents.o2 ~= nil, "the bottle itemises its oxygen")
assert(tank.contents.o2.gas > 0, "as gas: " .. tostring(tank.contents.o2.gas))
assert(tank.contents.o2.liquid == nil, "none of it is liquid, so no liquid is reported")
assert(tank.contents.o2.solid == nil, "and none of it is ice")

-- ---------------------------------------------------------------
-- The beaker beside it: the same reading of a thing with a wet
-- bottom and an open top.
-- ---------------------------------------------------------------
local beaker = t.vessel(t.target_at(3, 1, "beaker_libital"))
assert(beaker ~= nil, "a beaker has an inside too")
assert(not beaker.sealed, "an open glass breathes, and says so")
assert(beaker.contents.water ~= nil, "there is water in it")
assert(beaker.contents.water.liquid > 0,
    "standing as liquid: " .. tostring(beaker.contents.water.liquid))
assert(beaker.contents.water.solid == nil, "nothing in it is frozen")
assert(beaker.headspace_l < beaker.volume_l,
    ("what is in it takes room: %g of %g litres left"):format(
        beaker.headspace_l, beaker.volume_l))
assert(beaker.headspace_l > 0, "but never all of it -- a full glass still has a top")

-- This one authors no `volume_ml`, so its shell is what is in it plus
-- the minimum headspace and nothing invented (docs/CHEMISTRY.md 9).
near(beaker.headspace_l / beaker.volume_l, 0.05 / 1.05, 1e-9,
    "an unmeasured vessel is its contents plus five per cent")

-- The empty beaker on the end of the bench is the other half of that
-- contract: fifty millilitres of authored glass, every drop of it free.
local empty = t.vessel(t.target_at(5, 1, "beaker"))
near(empty.volume_l, 0.05, 1e-9, "fifty millilitres of glass, as authored")
near(empty.headspace_l, 0.05, 1e-9, "and nothing in the way of it")
assert(empty.moles == 0, "it ships empty: " .. tostring(empty.moles))
assert(next(empty.contents) == nil, "so there is nothing to itemise")
assert(empty.pressure_kpa == 0, "and nothing pressing on anything")

-- The collapsed reading is still there and still agrees: `t.contents`
-- is the same water, summed over its phases.
local collapsed = t.contents(t.target_at(3, 1, "beaker_libital"))
near(collapsed.water,
    beaker.contents.water.liquid + (beaker.contents.water.gas or 0.0),
    1e-12, "one substance, two ways of counting it")
near(t.holder_kpa(t.target_at(3, 1, "beaker_libital")), beaker.pressure_kpa,
    1e-12, "and one pressure, two ways of asking")

-- ---------------------------------------------------------------
-- The canister in the corner: the vessel a station's air comes out
-- of, reading exactly what its own gauge reads.
-- ---------------------------------------------------------------
local canister = t.vessel(t.target_at(5, 2))
assert(canister ~= nil, "a canister has an inside")
near(canister.pressure_kpa, t.canister_pressure(5, 2), 1e-12,
    "one gauge, whichever way you ask for it")
assert(canister.sealed, "a canister keeps its pressure")
assert(canister.contents.o2.gas > 0 and canister.contents.n2.gas > 0,
    "and it is premixed air, itemised")

-- ---------------------------------------------------------------
-- And the refusal: nil is the type test, here as everywhere.
-- ---------------------------------------------------------------
assert(t.vessel(t.target_at(4, 1, "crowbar")) == nil,
    "a crowbar has no inside, and answering nothing is how it says so")
