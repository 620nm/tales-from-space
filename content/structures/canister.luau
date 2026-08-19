-- A gas canister is PORTABLE, and that is the whole of what this file
-- says (tg's portable/canister.dm: `/obj/machinery/portable_atmospherics`
-- starts unanchored, and a wrench fastens it to a connector port).
--
-- What the engine keeps is the gas: 2000 L of premix, the release
-- setpoint, and the tg release arithmetic that charges the run under it
-- (sim/vents.rs). What lives here is everything a player can see and
-- decide -- that it fastens to a port, that a wrench does it both ways,
-- and what it says while it happens.
--
-- The port is a real thing, and it is the ONLY thing this fastens to:
-- tg's connector is a pipe fitting that must itself be wrenched onto a
-- run before it hosts anything (structures/connector_port.luau), so
-- plumbing a canister in is two decisions, not one. A wrench swung at a
-- canister standing on bare deck -- or on a bare distribution main with
-- no socket on it -- does nothing, which is tg's "Nothing happens."
--
-- It takes NO TIME either way. tg's `wrench_act` on a portable atmos
-- device has no do_after anywhere in it: you fasten it, or you take it
-- off, and the ratchet is the whole ceremony. Laying the port is the
-- slow work; putting a bottle on the socket is not. `secs` omitted is
-- the schema's instant, and an instant step raises no progress bar.
--
-- An unfastened canister with an open valve does not stop releasing: it
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
    -- Fastened first, so a mapper who draws a canister on a port gets
    -- one that is feeding the run at roundstart.
    states = { "anchored", "displaced" },
    -- Nothing holds a loose canister down, so a walker can shove it, a
    -- crewman can take hold of it and drag it, and a decompression can
    -- take it away -- with its air, every time.
    --
    -- No `drag_slowdown`, deliberately: tg's
    -- `/obj/machinery/portable_atmospherics` sets none, so wheeling a
    -- bottle down the hall costs a tg crewman nothing and costs one
    -- here nothing either. Closets and flatpacks are what that field is
    -- for, and neither exists yet.
    loose = { "displaced" },
    -- tg's `can-connector`, which a canister wears for exactly as long
    -- as `connected_port` is set: you can tell across the room whether
    -- the supply is actually plumbed in.
    state_sprites = {
        anchored = "canister_connected",
        displaced = "canister",
    },
    transitions = {
        {
            at = "anchored",
            tool = "wrench",
            to = "displaced",
            done = "You unfasten the canister from the port.",
        },
        {
            at = "displaced",
            tool = "wrench",
            -- The socket, and nothing else.
            over = "fitting",
            to = "anchored",
            done = "You fasten the canister to the port.",
        },
    },
}
