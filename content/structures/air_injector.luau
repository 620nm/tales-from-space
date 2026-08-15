-- An air injector: the scrubber's opposite number, and the only thing
-- in the kit with no notion of "enough".
--
-- tg's `/obj/machinery/atmospherics/components/unary/outlet_injector`
-- (components/unary_devices/outlet_injector.dm). One mouth on a pipe
-- run, one tile of room in front of it, and gas goes OUT: a fixed
-- volume per second, into whatever is standing there.
--
-- WHAT MAKES IT NOT A VENT. A vent is a regulator -- it works its room
-- towards one atmosphere and then stops, which is what you want
-- everywhere people live. An injector has no setpoint and no ceiling.
-- It keeps going until its supply runs out, and that is the entire
-- reason it exists: you cannot fill a chamber past one atmosphere with
-- a vent, and gas storage, burn chambers and every deliberate
-- atmosphere on the station are built out of exactly that ability.
--
-- tg's own file is blunt about the other use. Its resistance flags are
-- fire-proof and acid-proof with the comment "really helpful in
-- building gas chambers for xenomorphs", which is a polite way of
-- saying that one of these plumbed into an occupied room is a weapon
-- rather than an accident. Nothing here clamps that, deliberately --
-- tg's `process_atmos` has no pressure test in it at all, and an
-- injector that quietly refused at some pressure would be a different
-- machine wearing this one's sprite.
--
-- The rate is litres per second of its OWN run, so what it delivers
-- depends on what is behind it: a charged main injects fast, a spent
-- one injects slowly, off one number and with no special case for
-- either. Fifty out of the crate (tg's `volume_rate = 50`), and the
-- dial goes to two hundred.
return {
    id = "air_injector",
    name = "air injector",
    sprite = "injector_off_n",
    dense = false,
    states = { "off", "injecting" },
    facing_sprites = {
        off = {
            north = "injector_off_n",
            south = "injector_off_s",
            east = "injector_off_e",
            west = "injector_off_w",
        },
        injecting = {
            north = "injector_on_n",
            south = "injector_on_s",
            east = "injector_on_e",
            west = "injector_on_w",
        },
    },
    atmos = {
        device = "injector",
        positions = { "off", "injecting" },
        -- tg's `volume_rate = 50` (outlet_injector.dm:19), and the
        -- family's `MAX_TRANSFER_RATE` on the dial.
        rate_lps = 50.0,
        max_rate_lps = 200.0,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "air_injector_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the air injector down.",
        done = "The air injector is bolted to the deck, nozzle upward.",
    },
    transitions = {
        {
            -- Off first. An injector running into the room you are
            -- kneeling in is not one to unbolt.
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { air_injector_fitting = 1 },
            start = "You start unfastening the air injector.",
            done = "The air injector comes up off the deck.",
        },
    },
}
