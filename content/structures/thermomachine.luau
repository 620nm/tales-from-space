-- The temperature control unit: the machine a cold room is made of.
--
-- tg's `/obj/machinery/atmospherics/components/unary/thermomachine`
-- (components/unary_devices/thermomachine.dm) -- "heats or cools gas in
-- connected pipes", which is tg being brisk about the only machine in
-- the kit that can put a pipe below the temperature of everything
-- around it.
--
-- The rest of the thermal family MOVES heat. A temperature pump takes
-- it from one line and gives it to another; a pair of plates share it
-- between two; neither can take a chamber past the coldest thing you
-- can plumb into it. This one is a THERMOSTAT with a heat bath behind
-- it: set a number, and the gas standing in its single mouth is driven
-- to that number from either side. What pays for it is the equipment
-- channel, which is why this is the one thermal machine that stops dead
-- in a blackout.
--
-- NOT A FITTING, AND THAT IS THE WHOLE OF ITS CONSTRUCTION STORY. Every
-- other machine in the kit is a part you drop and wrench (tg's
-- `construction_type`); this one is a FRAME, a board and four stock
-- parts, because tg says so twice over -- `circuit =
-- /obj/item/circuitboard/machine/thermomachine` (thermomachine.dm:18)
-- and not one hit in the RPD's dispenser list. Build a machine frame,
-- wire it, seat the board, feed it what the board asks for, screw it
-- together. The reverse is the crowbar below.
--
-- THE RANGE IS THE PARTS. tg computes it in `RefreshParts`
-- (thermomachine.dm:85-96) from the tiers of what is inside:
--   min = max(T0C - (170 + lasers*15), TCMB) = 73.15 K
--   max = T20C + 140*lasers                  = 573.15 K
--   heat capacity = 5000 * (bins - 1)^2      = 5000 J/K
-- with two tier-1 micro-lasers and two tier-1 matter bins, which is
-- what this pack's board asks for and all it can ask for -- there are
-- no part TIERS here. So the arithmetic's answers are written down as
-- the three numbers below, each with the sum that produced it.
--
-- COLOUR. tg tints the whole machine by its setpoint through GAGS
-- (thermomachine.dm:98-117: violet, blue, cyan, lime, yellow, orange,
-- red as the target climbs), which is a runtime recolour this engine's
-- baked atlas has no equivalent for. The art is baked at the default
-- setpoint's colour, `COLOR_VIBRANT_LIME` (thermomachine.dm:25) --
-- see tfs/assets/sprites/71-thermomachine.ron.
return {
    id = "thermomachine",
    name = "temperature control unit",
    sprite = "thermo_off",
    dense = true,
    -- Two positions, and the words are the ones the panel's switch
    -- wears and the ones a refusal says out loud.
    states = { "off", "running" },
    state_sprites = {
        off = "thermo_off",
        running = "thermo_on",
    },
    atmos = {
        device = "thermomachine",
        positions = { "off", "running" },
        -- tg's `target_temperature = T20C` out of the crate
        -- (thermomachine.dm:31): a unit somebody has only switched on
        -- holds the pipe at room temperature, which is a safe thing for
        -- an unattended machine to do.
        target_k = 293.15,
        min_k = 73.15,
        max_k = 573.15,
        -- tg's `heat_capacity`, two tier-1 matter bins
        -- (thermomachine.dm:90). The bath the port's gas is equalised
        -- against: bigger bins close the gap faster, which is what the
        -- upgrade path buys in tg and what this number would carry here.
        heat_j_per_k = 5000.0,
    },
    transitions = {
        {
            -- tg refuses the screwdriver on a running unit ("turn
            -- off!", thermomachine.dm:200-203) before it will open the
            -- panel, and the panel has to be open before anything comes
            -- apart. One state guard says the same thing here: while it
            -- is running, a crowbar earns "must be off first" rather
            -- than silence.
            at = "off",
            tool = "crowbar",
            secs = 4.0,
            gone = true,
            leaves = "machine_frame",
            -- tg's deconstruction drops the board and every component
            -- and leaves the frame WIRED (_machinery.dm:934-948,
            -- 970-985). A `leaves` structure always stands up in its
            -- first state, which for a machine frame is bare metal, so
            -- the five coils that wiring cost come back in the pile
            -- too: six reels here is the board's one plus the frame's
            -- five, and the books balance exactly as tg's do.
            yields = {
                thermomachine_board = 1,
                matter_bin = 2,
                micro_laser = 2,
                cable_coil = 6,
                glass = 1,
            },
            start = "You start prying the temperature control unit apart.",
            done = "The unit comes apart, leaving its frame standing.",
        },
    },
}
