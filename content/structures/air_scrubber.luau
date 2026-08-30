-- An air scrubber: the half of the air loop that runs backwards.
--
-- tg's `/obj/machinery/atmospherics/components/unary/vent_scrubber`
-- (components/unary_devices/vent_scrubber.dm) -- "has a valve and pump
-- attached to it", which is tg being modest about the machine that
-- makes a sealed station habitable.
--
-- Everything else in the kit moves gas between two pipes. This moves it
-- between a ROOM and a pipe, the unpopular way: out of the corridor the
-- crew is standing in and into a waste main. A vent supplies; this
-- takes away; between them a station's atmosphere is a loop instead of
-- a bottle slowly emptying.
--
-- ONE POSTURE, TWO DIALS. The gases the roster NAMES come out to the
-- last mole, always -- carbon dioxide out of the crate, which is what
-- the crew exhale. The WHOLE-AIR setting is the bulk draw, and the
-- floor is where it stops: whole air over a floor is the return
-- grille, whole air with the floor at zero is the siphon, emptied to
-- vacuum. There is no separate direction switch any more -- tg needed
-- one because its scrubber could not otherwise spell "take
-- everything", and these two dials already do. The emergency still
-- reads from the corridor, but as a JUDGMENT: the purge picture goes
-- up when a pass sees whole air leaving a room below the safe line,
-- never on a switch's word.
--
-- THE FLOOR, WHICH IS NOT tg's. The named gases come out regardless;
-- whole air comes back as well while the room is over `target_kpa`,
-- stopping there. tg has no such dial, and
-- does not need one -- a tg hull does not lose heat, so its air loop
-- only ever carries gases away. This one RADIATES, and a room left
-- alone goes from shirtsleeves to freezing in about fifty minutes, so
-- the loop that keeps a station habitable is a HEATING loop and this
-- machine is its return grille. The floor is what makes the failure
-- mode of a return grille "the room got cold" rather than "the room got
-- emptied".
--
-- What this file ships is what a placed one is: carbon dioxide always,
-- five litres a second, and whole air back down to a floor just under
-- the vent's release line (docs/ATMOS.md §8). Zero on the floor is tg
-- exactly -- a machine that only ever carries its named gases away.
--
-- WHAT STOPS IT. Fifty atmospheres in its own waste line and the fan
-- gives up (tg's `ATMOS_PUMP_MAX_PRESSURE`). A scrubber is not a
-- compressor: if nothing is emptying the waste main at the other end,
-- the main fills and every scrubber on it quietly stops. That is the
-- fault an atmospherics technician is supposed to find, and the panel
-- says "FULL" rather than leaving them to guess.
--
-- Powered, and firmly (tg's `use_power = IDLE_POWER_USE`): a scrubber
-- that kept working through a blackout would make the one crisis this
-- whole kit exists for survivable by accident.
return {
    id = "air_scrubber",
    name = "air scrubber",
    sprite = "scrubber_off_n",
    ui = { modules = { "scrubber" } },
    dense = false,
    -- THREE positions, which is one more than most machines have. The
    -- third picture is the JUDGED emergency: a pass that sees whole
    -- air leaving a room below the safe line paints it, so someone
    -- walking past a room actually being emptied can tell at a
    -- glance. A map may still stand one down in "siphoning" -- that
    -- state is shorthand for whole air with no floor.
    states = { "off", "scrubbing", "siphoning" },
    facing_sprites = {
        off = {
            north = "scrubber_off_n",
            south = "scrubber_off_s",
            east = "scrubber_off_e",
            west = "scrubber_off_w",
        },
        scrubbing = {
            north = "scrubber_on_n",
            south = "scrubber_on_s",
            east = "scrubber_on_e",
            west = "scrubber_on_w",
        },
        siphoning = {
            north = "scrubber_purge_n",
            south = "scrubber_purge_s",
            east = "scrubber_purge_e",
            west = "scrubber_purge_w",
        },
    },
    atmos = {
        device = "scrubber",
        -- LAYER 2, which is where tg puts scrubbers and very nearly
        -- only where: counted across every map file it ships,
        -- `vent_scrubber/on/layer2` appears 1860 times and every other
        -- layer once. Supply is layer 4 by the same count, and the two
        -- conventions together are what let a supply main and a waste
        -- main share a corridor without becoming one body of gas. A
        -- scrubber on the default layer would join the distro it is
        -- supposed to be the return half of.
        layer = 2,
        -- Off, running, and the judged emergency. The third slot is
        -- what tg's `scrub_purge` is for -- and naming it on a
        -- placement means "whole air, no floor" from the first tick.
        positions = { "off", "scrubbing", "siphoning" },
        -- Five litres a second out of the crate, against tg's
        -- `volume_rate = 200` (vent_scrubber.dm:26), which is the dial's
        -- CEILING here. A grille at 200 empties a small room's excess in
        -- one pass and outruns the main that feeds it; at five it keeps
        -- pace with a supply vent and a whole department's grilles do
        -- not drain one distribution main between them. The panel goes
        -- to 200 for a technician who wants tg's machine.
        rate_lps = 5.0,
        max_rate_lps = 200.0,
        -- tg's `filter_types = list(/datum/gas/carbon_dioxide)`
        -- (vent_scrubber.dm:24): what the crew breathe out, and the
        -- only thing a scrubber needs to be set to on an ordinary day.
        filter = { "co2" },
        -- The FLOOR, in kPa. The gases named above come out to the
        -- last mole regardless; the floor is where the machine stops
        -- taking WHOLE air back as well. 100 kPa: just under the supply
        -- vent's release line of one atmosphere, so the room sits in
        -- the band between them and the loop circulates -- see the
        -- note at the top. Zero is tg's scrubber, which never returns
        -- whole air at all.
        target_kpa = 100.0,
        -- The SERVICE FACTOR ships at 1 -- one grille, its own tile,
        -- tg's machine. The panel offers 4 (the cardinals too) and 8
        -- (the whole ring, tg's widenet), each billed at that many
        -- times the idle draw.
        service = 1,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "air_scrubber_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the air scrubber down.",
        done = "The air scrubber is bolted to the deck, grille upward.",
    },
    transitions = {
        {
            -- Only while it is off. tg's scrubber inherits the family
            -- `can_unwrench`, and a running one is drawing a room's air
            -- into a charged main -- not something to interrupt with a
            -- wrench.
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { air_scrubber_fitting = 1 },
            start = "You start unfastening the air scrubber.",
            done = "The air scrubber comes up off the deck.",
        },
    },
}
