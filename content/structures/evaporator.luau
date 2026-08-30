-- The evaporator: a vessel slot bolted to a pipe run, so what boils in
-- the glass goes down the line instead of into the room.
--
-- Ported from Baystation12
-- (`Baystation12/code/modules/reagents/Chemistry-Sublimator.dm:34-48`)
-- -- "an advanced machine that converts liquid or solid reagents into
-- gasses". tgstation has no such machine at all: its chemistry and its
-- atmospherics never touch, and this is the one fixture that makes them
-- one system here.
--
-- THREE OF BAY'S NUMBERS ARE MISSING, AND THAT IS THE PORT. Bay boils a
-- flat twenty units a tick (`sublimated_units_per_tick = 20`, `:45`),
-- divides them by a hardcoded `REAGENT_GAS_EXCHANGE_FACTOR` to get
-- moles (`:150`), and writes the result's temperature from an
-- `output_temperature` var (`:48`, `:155`) -- three constants it needs
-- because it keeps reagents and gases in two registries and has to
-- invent a gas for each reagent as it goes (`:1-32`). There is one
-- registry here and one Mixture (../lunatic/docs/MATTER.md): water in a
-- beaker and water in a pipe are the same substance on the same phase
-- curve. So the rate is the vessel's own boil, the moles are the moles,
-- and the gas leaves at the temperature it boiled at. What is left of
-- Bay is the SHAPE -- a docked vessel, a mouth on a run, a heater under
-- it -- and the mechanism is the stationary tank's: the vessel and the
-- net it reaches pool every atmos pass, split by volume, both ways
-- (../lunatic/docs/ATMOS.md §9).
--
-- BOTH WAYS is the part Bay cannot do. Its machine merges into
-- `air_contents` and never draws from it (`:156`). Here a cold line
-- with condensate standing in it hands some of that back up into the
-- bottle, which is not a second feature -- it is the same sentence read
-- from the other end.
--
-- IT DRAWS POWER while its thermostat is on. Bay's is
-- `POWER_USE_IDLE` on the type and climbs to `POWER_USE_ACTIVE` while
-- it works (`:40`, `:98`), stopping dead when `inoperable()`
-- (`:127-131`); this is the same pair, billed off the equipment channel
-- like every other machine standing in a run.
--
-- NOT A FITTING. Like the temperature control unit beside it, this is a
-- frame, a board and three stock parts -- Bay's board asks for a
-- micro-laser, a capacitor and a matter bin
-- (`items/weapons/circuitboards/machinery/chemistry.dm:21-25`), which
-- are this pack's `laser`, `capacitor` and `bin` sockets. The laser is
-- the one that moves a number, exactly as it does on the reaction
-- chamber: how hard the element drives.
return {
    id = "evaporator",
    name = "evaporator",
    sprite = "evaporator",
    ui = { modules = { "line_dock", "parts" } },
    dense = true,
    examine = {
        flavor = "A boxed element with a cradle for one vessel and a "
            .. "pipe stub out of its back. Whatever boils in the glass "
            .. "leaves down the line.",
    },
    chem = {
        device = "line_dock",
        -- Water's boiling point at one atmosphere, which is the round
        -- number an operator would dial for "drive it until something
        -- happens". Bay has no dial at all -- its machine is a switch --
        -- so this is the reaction chamber's thermostat, said again on a
        -- machine with somewhere for the vapour to go.
        target_k = 373.15,
        -- The built machine's, exactly as the reaction chamber's is
        -- (tg `chem_heater.dm:86-90`): the file's number is what neutral
        -- parts give and the socket below moves it.
        coeff = 0.1,
        -- Ours, not Bay's: Bay's machine has no setpoint to cap. A
        -- thousand kelvin clears the boiling point of everything this
        -- pack defines.
        max_k = 1000,
        sprite_loaded = "evaporator_loaded",
        sprite_running = "evaporator_on",
        sprite_running_loaded = "evaporator_on_loaded",
    },
    atmos = {
        device = "line_dock",
        -- The distribution main, because what comes out of this machine
        -- is meant to be delivered somewhere. A mapper who wants it on
        -- the waste line says so on the placement.
        layer = 3,
    },
    parts = {
        slots = { "laser", "capacitor", "bin" },
        scale = {
            -- The same clamp the reaction chamber carries, and the same
            -- pair of tg bookends: 0.05 is an unassembled chamber
            -- (`chem_heater.dm:17`) and 0.4 is what tg's own debug unit
            -- calls upgraded (`:390`). The capacitor and the bin are
            -- build requirements with nothing to move -- Bay's machine
            -- reads neither, and inventing a number for them would be
            -- this file making a mechanism up.
            coeff = { by = "laser", law = "multiply", clamp = { 0.05, 0.4 } },
        },
    },
    transitions = {
        {
            tool = "crowbar",
            secs = 4.0,
            gone = true,
            leaves = "machine_frame",
            -- The frame stands back up bare, so the five coils its
            -- wiring cost come back in the pile with the board's one --
            -- the temperature control unit's books, kept
            -- (`thermomachine.luau`). The three sockets say what else
            -- comes out, at the tiers actually fitted, so no component
            -- is named here.
            yields = {
                ["machine_board.evaporator"] = 1,
                cable_coil = 6,
                glass = 1,
            },
            start = "You start prying the evaporator apart.",
            done = "The evaporator comes apart, leaving its frame standing.",
        },
    },
}
