-- The steam generator: an evaporator that accepts water and nothing
-- else, so what leaves it down the line is steam.
--
-- Ported from Baystation12's water-only subtype
-- (`Baystation12/code/modules/reagents/Chemistry-Sublimator.dm:184-192`)
-- -- "a top of the line electric heater - it accepts water, and
-- produces steam. Wow!" (`:186`). Three lines of its own in Bay and
-- four fields of its own here, which is the point: the mechanism is
-- the evaporator's entirely and this file adds a sieve to it.
--
-- A FILE rather than a `variants` row, and Bay draws the same line: it
-- is a subtype with an `icon_set` of its own (`:188`) and a circuit
-- board of its own, and a variant may change neither what a thing is
-- made of nor the mechanism block that decides what it does
-- (../lunatic/docs/CONTENT-SCHEMA.md 1.1a). Two entries, four
-- pictures each, one board apiece.
--
-- ITS ALLOW-LIST IS A SIEVE RATHER THAN A SHUTDOWN. Bay's
-- `reagent_whitelist` is enforced by refusing to run at all -- one
-- unlisted reagent in the container and the machine "pings rapidly and
-- powers down" (`:134-140`) -- which means a beaker somebody rinsed
-- badly stops the machine. Here the roster is a filter on the mouth:
-- water crosses, everything else stays in the glass. Same promise
-- (nothing but steam reaches the line), no tantrum.
--
-- ITS DIAL OPENS WARM RATHER THAN BOILING. Bay hands its steam over at
-- `T0C+40` (`output_temperature`, `:190`), which is the one number in
-- the subtype that is a number; there is no output temperature here
-- (the gas leaves at the temperature it boiled at), so it lands on the
-- thermostat instead -- 313.15 K, a machine set to make a room humid
-- and warm rather than to boil a beaker dry.
return {
    id = "steam_generator",
    name = "steam generator",
    sprite = "steam_generator",
    ui = { modules = { "line_dock", "parts" } },
    dense = true,
    examine = {
        flavor = "A vented box with a cradle for one vessel. It takes "
            .. "water and gives the line back steam, and it is smug "
            .. "about it.",
    },
    chem = {
        device = "line_dock",
        -- Bay's `T0C+40` (`:190`), read onto the dial: see the header.
        target_k = 313.15,
        coeff = 0.1,
        max_k = 1000,
        -- Bay's `reagent_whitelist = list(/datum/reagent/water)`
        -- (`:189`), and the whole difference between this machine and
        -- the evaporator.
        roster = { "water" },
        sprite_loaded = "steam_generator_loaded",
        sprite_running = "steam_generator_on",
        sprite_running_loaded = "steam_generator_on_loaded",
    },
    atmos = {
        device = "line_dock",
        -- The distribution main, like the vent it is meant to feed.
        layer = 3,
    },
    parts = {
        slots = { "laser", "capacitor", "bin" },
        scale = {
            coeff = { by = "laser", law = "multiply", clamp = { 0.05, 0.4 } },
        },
    },
    transitions = {
        {
            tool = "crowbar",
            secs = 4.0,
            gone = true,
            leaves = "machine_frame",
            yields = {
                ["machine_board.steam_generator"] = 1,
                cable_coil = 6,
                glass = 1,
            },
            start = "You start prying the steam generator apart.",
            done = "The generator comes apart, leaving its frame standing.",
        },
    },
}
