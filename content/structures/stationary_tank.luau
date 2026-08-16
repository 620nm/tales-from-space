-- The stationary pressure tank: 2500 litres of gas bolted to the deck,
-- with a mouth on each cardinal and no valve on any of them (tg's
-- /obj/machinery/atmospherics/components/tank, code/modules/
-- atmospherics/machinery/components/tank.dm).
--
-- "A large vessel containing pressurized gas." It is the only machine
-- in the atmospherics kit that STORES rather than moves: no dial, no
-- switch, no setpoint, and in tg no interface at all. Every pass its
-- contents and every pipe net its ports reach settle into one body of
-- gas split by volume (`custom_reconcilation`, tank.dm:23, through
-- `reconcile_air`) -- so an empty run welded to a full tank fills, and
-- a run somebody pumps up past the tank drains back into it. The ports
-- ARE the valves; you change what a tank is doing with a wrench and a
-- length of pipe.
--
-- WHY IT IS HERE: mega-canisters for atmos debugging. A canister is
-- 2000 L at 45 atm and gets walked away; this is 2500 L rated to 46 000
-- kPa that does not move, which is what a department needs when it is
-- trying to reproduce something in a pipe run rather than run a shift.
--
-- WHAT IS IN ONE is not this file's business, and deliberately so. tg
-- ships twenty named subtypes -- /tank/oxygen, /tank/nitrogen,
-- /tank/plasma, ... (tank.dm:477-555) -- each differing by one variable,
-- and that ladder is an anti-pattern this pack refuses. A vessel is one
-- noun; what somebody filled it with is a fact about a STATION, so a
-- map says it per placement: `(x, y, "stationary_tank", "anchored",
-- ("o2", 23000.0))` fills this one with oxygen at half its rating,
-- which is tg's own `starting_pressure_percent = 0.5` (tank.dm:43).
-- Unfilled -- and one a player has just welded shut -- it is empty,
-- exactly as tg's own base type is (`gas_type = null`, tank.dm:41).
--
-- PORTS, v1. tg has four TOGGLEABLE ports: you stand on the side you
-- want and wrench, 3 seconds, and that side opens or closes
-- (`wrench_act` -> `get_dir(src, user)`, tank.dm:379-390); a mapped
-- tank opens only the one its `dir` faces. Here all four are open,
-- always. The engine's tool seam carries no SIDE -- a transition is
-- "this tool, on this thing", with no direction from the actor
-- anywhere in the click path, the refusal, the do-after or the ledger
-- -- so per-side toggling is a new directional-act mechanism rather
-- than a field, and that is a great deal more engine than a debug
-- reservoir is worth. Four open mouths is the strictly more permissive
-- reading of tg's default, which is what a debug tank wants; the mask
-- is the deferred half, and the knobs below are drawn on all four
-- sides so the picture does not lie about it.
--
-- ALSO DEFERRED, all three of them tg's and none of them a debug
-- tank's problem (they are noted in the engine beside the fields that
-- would carry them, crates/lunatic-server/src/structures/atmos.rs):
--   * the MERGER -- tg pools tanks standing next to each other into one
--     mixture of their combined volume (tank.dm:270-306), and draws the
--     47 smoothing states this file's sprite deliberately skips;
--   * the DAMAGE STACK -- over-pressure brute damage past the rating,
--     a gas_leaker below 90% integrity, crack overlays, and the
--     volatile_gas_storage explosion at 20% (tank.dm:96-98, 165-168);
--   * MATERIAL-SCALED INTEGRITY -- tg rescales the pressure rating by
--     the plating material's strength (`refresh_pressure_limit`,
--     tank.dm:147-149). One material here, so one rating.
--
-- NOT PRINTABLE, and that is tg parity rather than an omission: the
-- tank appears in no RPD category, no pipe dispenser and no lathe --
-- the plasteel stack recipe is its only route in tg, and the metal
-- stack recipe on the frame beside this file is its only route here.
return {
    id = "stationary_tank",
    name = "pressure tank",
    sprite = "stationary_tank",
    dense = true,
    -- One state. A sealed vessel is not an assembly -- cutting it open
    -- does not put it back in a state, it ends it and leaves the frame
    -- standing (tg's `on_deconstruction`, tank.dm:433-450).
    states = { "anchored" },
    -- tg's stack, bottom first: the shell, the window in its side
    -- (tank.dm:321, 358-361), then one knob per open port
    -- (tank.dm:322-326). All four knobs, because all four ports are
    -- open -- see the ports note above; the picture is not allowed to
    -- imply a mask the sim does not keep.
    state_sprites = {
        anchored = {
            "stationary_tank",
            "stationary_tank_window",
            "stationary_tank_knob_n",
            "stationary_tank_knob_s",
            "stationary_tank_knob_e",
            "stationary_tank_knob_w",
        },
    },
    atmos = {
        device = "tank",
        -- tg's PIPING_LAYER_DEFAULT, the run every dispenser hands out.
        layer = 3,
        -- tg's `volume = 2500` and `max_pressure = 46000` (tank.dm:37,
        -- 39). The rating is the number on its holographic sticker
        -- (tank.dm:140) and the denominator of the contents gauge.
        volume_l = 2500.0,
        rated_kpa = 46000.0,
    },
    transitions = {
        -- tg's `welder_act_secondary`: 4 seconds, and the vessel is
        -- opened (tank.dm:409-431). tg doubles the time and flings you
        -- across the room when the thing is still pressurised
        -- (`unsafe_pressure_release`); here the gas simply goes where
        -- tg's `on_deconstruction` puts it -- into the room, all of it,
        -- through the engine's one vessel-spill seam -- which is quite
        -- enough consequence for cutting open a full plasma tank with
        -- the door shut.
        --
        -- What is left standing is the frame, ready to be plated again.
        -- tg leaves it PLATED (`frame.construction_state =
        -- TANK_PLATING_UNSECURED`, tank.dm:439-440) and makes you
        -- crowbar the sheets back off; a `leaves` here spawns a
        -- structure in its OPENING state and cannot name a later one,
        -- so this hands the twelve sheets straight back instead. Same
        -- books, one tool step shorter, and the frame that stands is
        -- the re-platable one either way.
        {
            tool = "welder",
            secs = 4.0,
            fuel = 2.0,
            gone = true,
            leaves = "stationary_tank_frame",
            yields = { metal = 12 },
            start = "You start cutting the tank open.",
            done = "The tank comes open, and its gas goes everywhere.",
        },
    },
}
