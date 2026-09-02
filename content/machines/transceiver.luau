-- The radio transceiver: the tower that turns a handheld's few rooms
-- of reach into a station's.
--
-- The machine itself is three sockets and a cord. The network socket
-- is where its address comes from (items/network_card.luau) and what a
-- panel joins to an access point or a router -- towers on one tree
-- stretch each other's reach, which is the whole reason to network
-- them (lib/radio.luau). The two encryption sockets are where its
-- channels come from: a tower carries exactly the words the keys in it
-- are cut with, and a tower full of blank keys carries nothing
-- (items/encryption_key.luau). WHICH TOWERS SPEAK a line is decided
-- over the four relay stages this declaration signs it up for
-- (fixtures/transceiver.luau, lib/radio_relay.luau); WHO HEARS one is
-- `speech.radio`'s alone (lib/radio.luau).
--
-- tg's nearest thing is the telecomms bus mainframe
-- (code/game/machinery/telecomms/machines/bus.dm:9-16), ported in
-- spirit: one rack in a chain of six specialized ones there, the whole
-- chain here, because this pack models signal as DISTANCE and not as
-- subspace plumbing.
return {
    id = "transceiver",
    name = "radio transceiver",
    script = "transceiver",
    -- The running picture is a script var the fixture writes off the
    -- settled sockets; the engine draws `base` by itself whenever the
    -- cord is dead (docs/content-schema/appearance.md, the power gate), so
    -- "on" here means keyed, and dark means dark.
    sprite = {
        base = "transceiver_off",
        var = "lunatic/tfs:transceiver_look",
        states = { "transceiver_on" },
    },
    ui = { modules = { "link", "parts" } },
    -- What signs this rack up for the four relay stages: every powered,
    -- unsuspended one of these is walked once per `;` line
    -- (docs/content-schema/radio.md).
    radio = { relay = true },
    dense = true,
    corded = true,
    examine = {
        flavor = "A mighty rack of hardware built to throw a voice "
            .. "across a station. The keys in its sockets decide which "
            .. "voices those are.",
    },
    parts = { slots = { "network", "encryption", "encryption" } },
    -- No `locked` here: an endpoint holds no roster, so it has nothing
    -- for a lock to protect and the loader refuses one (docs/DEVICES.md
    -- §8 -- a lock refuses gestures aimed AT a node's roster).
    link = { role = "endpoint", socket = "network" },
    -- The two generic rungs every finished machine has: a screwdriver
    -- opens the panel, a crowbar pries it apart, and what is left
    -- standing is the frame it was screwed together from, holding the
    -- board and everything in the sockets (docs/CONSTRUCTION.md).
    teardown = {
        open = "screwdriver",
        remove = "crowbar",
        into = "machine_frame",
        state = "boarded",
    },
    -- The department issues: the same tower with its first key already
    -- cut. Placement beats variant beats prototype, so a map may still
    -- reseat the socket (docs/content-schema/variants.md). The words are
    -- spelled out rather than read off `lib/radio.luau` because machine
    -- files are evaluated in the bare data environment, before the
    -- shared tables exist; radio.channels is the roster of record and
    -- these must agree with it.
    variants = {
        common = {
            name = "radio transceiver (Common)",
            props = { encryption_1 = "encryption_key.common" },
        },
        engineering = {
            name = "radio transceiver (Wrench)",
            props = { encryption_1 = "encryption_key.engineering" },
        },
        medical = {
            name = "radio transceiver (Lifeline)",
            props = { encryption_1 = "encryption_key.medical" },
        },
        security = {
            name = "radio transceiver (Watchline)",
            props = { encryption_1 = "encryption_key.security" },
        },
        command = {
            name = "radio transceiver (Charter)",
            props = { encryption_1 = "encryption_key.command" },
        },
    },
}
