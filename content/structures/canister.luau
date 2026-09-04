-- A canister is PORTABLE, and that is the whole of what this file
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
    name = "canister",
    sprite = "canister",
    -- The shell is GREYSCALE art with a colour multiplied over it, the
    -- way tg draws every canister (`greyscale_config`, canister.dm) --
    -- so one baked picture is every canister on the station and a
    -- placement may say which one it is. This is tg's own
    -- `greyscale_colors` for a premixed-air bottle, "#c6c0b5", which is
    -- also what the atlas bakes the cell's default at
    -- (assets/sprites/21-atmos-thermal-room-and-canisters.ron): a
    -- canister nobody has painted looks exactly as it always did.
    --
    -- A MAP may name another per placement (`color` in the property
    -- sheet), which is how a rack of bottles reads as oxygen, nitrogen
    -- and plasma at a glance instead of as three identical drums.
    color = "#C6C0B5",
    ui = { modules = { "canister" } },
    -- Claims the canister MECHANISM: the gas, the release arithmetic
    -- and the gauge are per-pass engine work, so the engine keeps a
    -- component for them and this file says which entry gets one
    -- (docs/CONSTRUCTION.md, "the structure half"). Everything a player
    -- sees or decides is below.
    --
    -- It arrives EMPTY with the valve shut. What is in a bottle is a
    -- fact about the station, so a map says it per placement --
    -- `{ "blend": "canister_air", "open": true }` -- rather than tg's
    -- twenty pre-charged subtypes.
    fixture = "Canister",
    dense = true,
    -- Fastened first, so a mapper who draws a canister on a port gets
    -- one that is feeding the run at roundstart.
    states = { "anchored", "displaced", "broken" },
    -- Nothing holds a loose canister down, so a walker can shove it, a
    -- crewman can take hold of it and drag it, and a decompression can
    -- take it away -- with its air, every time.
    --
    -- No `drag_slowdown`, deliberately: tg's
    -- `/obj/machinery/portable_atmospherics` sets none, so wheeling a
    -- bottle down the hall costs a tg crewman nothing and costs one
    -- here nothing either. Closets and flatpacks are what that field is
    -- for, and neither exists yet.
    -- A broken one is loose too: `canister_break` sets `density =
    -- FALSE` (canister.dm:487), and a split shell nobody bolted down
    -- is a thing the wind is welcome to take.
    loose = { "displaced", "broken" },
    -- tg's `can-connector`, which a canister wears for exactly as long
    -- as `connected_port` is set: you can tell across the room whether
    -- the supply is actually plumbed in.
    state_sprites = {
        anchored = "canister_connected",
        displaced = "canister",
        -- tg's own `broken` overlay over the shell (canister.dm:361),
        -- baked into one picture because the canister's overlay slot
        -- is spoken for by the gauge (21-atmos-thermal-room-and-
        -- canisters.ron says the same thing about `can-connector`).
        broken = "canister_broken",
    },
    -- WHAT HAPPENS WHEN SOMEBODY FILLS ONE PAST WHAT IT IS RATED TO.
    -- tg's portable-atmospherics ladder, verbatim: 500 000 kPa on the
    -- sticker (`pressure_limit`, code/modules/atmospherics/machinery/
    -- portable/portable_atmospherics.dm:32), rolled up to 20% higher
    -- per bottle at spawn so two off the same line do not go at the
    -- same breath (`pressure_limit * (1 + 0.2 * rand())`,
    -- portable/canister.dm:73-74); past it, damage of
    -- `clamp(pressure / limit, 5, 50)` per pass (`take_atmos_damage`,
    -- portable_atmospherics.dm:147,153).
    --
    -- 300 integrity, and at 40% of it the thing gives (canister.dm:
    -- 17-18). A canister does NOT leak and it does NOT explode: it
    -- hands over everything it is holding at once, stops being solid,
    -- and stands there wearing its broken picture (`canister_break`,
    -- canister.dm:479-496). That is the whole of it in tg and the
    -- whole of it here -- the most dangerous thing on the station
    -- fails by emptying itself into the room you are standing in,
    -- which is quite dangerous enough.
    --
    -- There is no way back. tg repairs one with a welder
    -- (portable_atmospherics.dm's welder act); a repair verb is a
    -- construction step nobody has authored yet, so a broken canister
    -- stays broken for the shift and the transitions below leave it
    -- alone -- a wrench on a split shell fastens nothing.
    failure = {
        integrity = 300,
        break_at = 0.4,
        limit_kpa = 500000,
        jitter = 0.2,
        damage_min = 5,
        damage_max = 50,
        on_break = "dump",
        broken_state = "broken",
        -- tg's own noise for it (`playsound(src.loc,
        -- 'sound/effects/spray.ogg', 10, TRUE, -3)`, canister.dm:488).
        sound = "spray",
        message = "The canister splits open!",
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
