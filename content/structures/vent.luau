-- An air vent: the regulator on the end of a distribution main, and
-- the machine every habitable room on the station has one of.
--
-- tg's `/obj/machinery/atmospherics/components/unary/vent_pump`
-- (components/unary_devices/vent_pump.dm). One mouth on a pipe run, one
-- tile of room in front of it, and a fan that runs BOTH WAYS.
--
-- WHAT MAKES IT NOT AN INJECTOR. This is the sentence air_injector.luau
-- names itself against: a vent has a dead band. Below 0.99 atmospheres
-- it releases into the room; above 1.08 it siphons the room back down
-- the main it came up; between those two lines it does nothing at all.
-- That is why you can bolt one in a corridor and walk away, and why you
-- cannot build a gas chamber out of one -- it will not fill a room past
-- one atmosphere however long you leave it, and it will not empty one
-- either. tg keeps both bounds live on the same machine
-- (`external_pressure_bound` and `internal_pressure_bound`), and so do
-- we.
--
-- WHAT IT HOLDS: nothing. A vent is a fan on the end of a pipe and the
-- air it blows is the pipe's air, so every mole it hands a room started
-- in a canister somebody filled. A vent with no run under it does
-- nothing at all, which is tg's `if(!nodes[1]) set_on(FALSE)`.
--
-- NO DIALS. tg's vent pump has bounds you can set, but nobody sets them
-- at the machine -- they are driven from an area's air alarm, and there
-- is no air alarm here yet. A settings window on this thing would be a
-- control surface invented rather than ported, so it has none, and the
-- defaults above are the whole of its configuration.
--
-- Powered, and firmly (tg's `use_power = IDLE_POWER_USE`,
-- vent_pump.dm:9). When the breaker goes a vent is a grille: no
-- coasting, no reserve, no trickle. That is the crisis the whole
-- atmospherics kit exists for, and its passive twin is what you plumb a
-- station with if you would rather not have it.
return {
    id = "vent",
    name = "air vent",
    sprite = "vent_off",
    dense = false,
    -- THREE positions, like the scrubber's and for the same reason: a
    -- fan running the wrong way is not a fan that is merely on. tg
    -- draws `vent_[pump_direction ? "out" : "in"]` and someone walking
    -- past a room being emptied should be able to tell at a glance.
    --
    -- The names are what the machine is DOING, because that is what the
    -- picture shows -- a vent has no switch for anybody to have thrown.
    states = { "off", "blowing", "siphoning" },
    -- One picture per state and no facings. tg's art is directional and
    -- ours is baked south-only (tfs/assets/sprites/10-*.ron): a grille
    -- in the deck reads the same from every side, unlike a scrubber,
    -- whose body has a visible front.
    state_sprites = {
        off = "vent_off",
        blowing = "vent_on",
        siphoning = "vent_siphon",
    },
    -- The fan coming up to speed and winding down, which is the whole
    -- of what a blackout looks like from across a room. tg flicks these
    -- on the power edges (`flick("vent_out-starting")`,
    -- vent_pump.dm:214) and the lengths are the animations' own:
    -- unary_devices.dmi draws the starting state in 12 frames totalling
    -- 1.05s and the shutdown in 16 totalling 1.45s.
    --
    -- Four rows because there are four edges: a vent that lost power
    -- while siphoning comes back up siphoning, and it should spin up
    -- rather than snap on. Neither art is directional, so the four
    -- compass entries are one name each.
    moving_sprites = {
        {
            from = "off",
            to = "blowing",
            secs = 1.05,
            north = "vent_starting",
            south = "vent_starting",
            east = "vent_starting",
            west = "vent_starting",
        },
        {
            from = "off",
            to = "siphoning",
            secs = 1.05,
            north = "vent_starting",
            south = "vent_starting",
            east = "vent_starting",
            west = "vent_starting",
        },
        {
            from = "blowing",
            to = "off",
            secs = 1.45,
            north = "vent_shutdown",
            south = "vent_shutdown",
            east = "vent_shutdown",
            west = "vent_shutdown",
        },
        {
            from = "siphoning",
            to = "off",
            secs = 1.45,
            north = "vent_shutdown",
            south = "vent_shutdown",
            east = "vent_shutdown",
            west = "vent_shutdown",
        },
    },
    atmos = {
        device = "vent",
        -- LAYER 3, the distribution layer, which is where tg puts
        -- supply vents and where every dispenser hands out plain pipe.
        -- The scrubber's layer 2 is the other half of that convention:
        -- a supply main and a waste main share a corridor without ever
        -- becoming one body of gas.
        --
        -- On out of the crate, and that is not a preset -- it is the
        -- machine. A vent has no handle in tg either; `on = TRUE` is
        -- the mapped default on every one of them, and the only thing
        -- that stops one is the breaker.
        on = true,
        positions = { "off", "blowing", "siphoning" },
    },
    build = {
        on = { "floor", "plating" },
        from_item = "vent_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the air vent down.",
        done = "The air vent is bolted to the deck, grille upward.",
    },
    transitions = {
        {
            -- No state guard. tg's vent inherits the family's flat
            -- `can_unwrench`, and unlike the scrubber there is no
            -- position it could be in that makes coming up dangerous:
            -- what a vent is holding back is one atmosphere of
            -- distribution main, which is what the room already has.
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { vent_fitting = 1 },
            start = "You start unfastening the air vent.",
            done = "The air vent comes up off the deck.",
        },
    },
}
