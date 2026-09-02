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
-- THE DIALS, AND WHERE THEY ARE. tg's vent pump has four things worth
-- setting -- a direction, a `pressure_checks` selector and two bounds
-- (vent_pump.dm:24-30) -- and nobody sets any of them at the machine:
-- they are written by an area's AIR ALARM. There is no air alarm here,
-- so a vent with no panel is a machine nobody can set at all, and this
-- one has three numbers a station's air is tuned by. The panel is that
-- console, on the machine, until there is a wall to hang one on
-- (docs/ATMOS.md section 8).
--
-- What it does NOT offer is tg's `NO_BOUND`. A vent with no ceiling on
-- what it pushes is an injector, and the injector is the machine on the
-- other end of the loop (air_injector.luau). The dead band is what this
-- machine IS; a switch that removed it would be a different one.
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
    -- The panel above: a switch and the three pressures. Same module
    -- shape the scrubber declares, and the two share every row they
    -- have in common (the switch, the room, the mains, the line behind
    -- them) rather than keeping two copies of it.
    ui = { modules = { "vent" } },
    -- ON THE ROOM'S NETWORK. An endpoint carries its own address and
    -- joins one hub, which is how an air alarm comes to draw this
    -- machine's settings instead of a crewman kneeling at it. The class
    -- word is what stops the alarm adopting the comms box next to it,
    -- and it is spelled out rather than shared because `lib/` is not
    -- published into the structure registry's sandbox
    -- (structures/air_alarm.luau, docs/content-schema/link.md).
    link = {
        network_interface = true,
        role = "endpoint",
        class = "atmos",
    },
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
        -- THE THREE PRESSURES, and the whole of what a vent is.
        --
        -- `target_kpa` is the line both directions work TO: tg's
        -- `external_pressure_bound`, which is `ONE_ATMOSPHERE` out of
        -- the crate (vent_pump.dm:28) and is one atmosphere here.
        target_kpa = 101.325,
        -- ...and the two lines of the DEAD BAND, which are where each
        -- direction starts. These are NOT tg's and cannot be: tg's vent
        -- runs one way at a time, told which by an alarm, so it has no
        -- band at all. Ours runs both ways off one switch, and a
        -- machine that both fills and empties toward a single number
        -- would hunt around it forever.
        --
        -- The low line IS the setpoint: the vent feeds until the room
        -- reaches an atmosphere, which is tg's releasing vent exactly.
        -- It is the number the whole station's air loop is tuned
        -- against: a scrubber's floor is 100 kPa, just under it, so
        -- every room sits in the band between the two and neither
        -- machine ever idles (docs/ATMOS.md section 8). The high one,
        -- 1.08 of an atmosphere, is a long way off, because a room
        -- drifting up a little is not worth spending a fan on -- what
        -- it catches is a room somebody is FILLING.
        release_below_kpa = 101.325,
        siphon_above_kpa = 109.431,
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
