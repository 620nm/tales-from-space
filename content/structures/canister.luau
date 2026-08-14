-- A gas canister is PORTABLE, and that is the whole of what this file
-- says (tg's portable/canister.dm: `/obj/machinery/portable_atmospherics`
-- starts unanchored, a wrench bolts it down, and only a bolted one over
-- a connector joins the pipeline).
--
-- What the engine keeps is the gas: 2000 L of premix, the release
-- setpoint, and the tg release arithmetic that charges the run under it
-- (sim/vents.rs). What lives here is everything a player can see and
-- decide -- that it has bolts, that a wrench turns them both ways, how
-- long that takes, and what it says while it happens.
--
-- The bolts ARE the plumbing, and there is no separate port object: in
-- tg the connector is itself a pipe fitting (a unary component under the
-- floor whose only trick is adding the device's air to the pipeline), so
-- the run under the tile is the port here. Bolting the canister down
-- over laid pipe joins it to the loop; unbolting takes it back off.
-- Wrenching where there is no pipe does nothing, which is tg's
-- "Nothing happens." -- there is no such thing as a portable atmos
-- machine that is bolted down but plumbed to nothing.
--
-- An unbolted canister with an open valve does not stop releasing: it
-- fills the ROOM instead (tg's `location.return_air()`). That is why
-- shoving a live one somewhere it should not be is a decision.
return {
    id = "canister",
    name = "gas canister",
    sprite = "canister",
    -- Claims the map glyph: 'c' still spawns the engine's canister, and
    -- this file dresses it (docs: structures/parse.rs "Fixture entries").
    fixture = "Canister",
    dense = true,
    -- Bolted first, so a mapper who draws a canister on a distribution
    -- run gets one that is feeding it at roundstart.
    states = { "anchored", "displaced" },
    -- Nothing holds a displaced canister down, so a walker can shove it
    -- and a decompression can drag it away -- with its air.
    loose = { "displaced" },
    transitions = {
        {
            at = "anchored",
            tool = "wrench",
            secs = 2.0,
            to = "displaced",
            start = "You start unbolting the canister.",
            done = "The canister comes off its bolts.",
        },
        {
            at = "displaced",
            tool = "wrench",
            secs = 2.0,
            -- The run under the tile is the connector port.
            over = "pipe",
            to = "anchored",
            start = "You start bolting the canister down.",
            done = "The canister is bolted to the deck.",
        },
    },
}
