-- The area power controller: the box on the wall that decides what the
-- room it serves is allowed to draw, and the only thing bridging the
-- backbone to a room's own branch (docs/POWER.md).
--
-- The engine owns the store, the gates and the ports, because moving
-- charge through a graph is per-tick arithmetic; the `store` and
-- `bridge` blocks below are what make this box one. This file and
-- fixtures/apc.luau own the ladder: how full the cell is when a room
-- loses equipment, then lighting, then everything, and when the alarm
-- goes up. The station's numbers, not the engine's.
--
-- IT IS ALSO THE ROOM'S HUB, and that is the second thing it is. A
-- device drawing power through this panel is a device this panel
-- feeds, and the engine sews exactly that edge every electrical pass:
-- the fittings on its lighting circuit, the fans on its wire, and
-- anything on a cord into a utility outlet port it stands behind, all
-- of them children of it without an engineer joining a single one
-- (docs/devices/joining.md). A room's plant is on a network because a
-- room's plant is plugged in, which is the whole argument -- there is
-- no gesture to forget and no roster to keep.
--
-- SEVENTEEN TILES, which is the air alarm's number and its argument
-- exactly (structures/air_alarm.luau): a Chebyshev seventeen covers
-- the shipped station from anywhere near the middle of it, so the
-- radius is a ceiling rather than a room measurement. It matters less
-- here than there, because the edges this box makes are made by the
-- cable and skip the radius outright; what it bounds is the joins an
-- engineer makes BY HAND at the panel.
--
-- NO `accepts`, deliberately. An alarm holds plumbing and refuses
-- everything else because somebody chose which fans belong to which
-- room. A panel holds whatever is on the far end of its own wire, and
-- a room contains what a room contains -- a class filter here would be
-- this file deciding that a vendor is not really plugged in.
--
-- WHERE ITS ADDRESS COMES FROM is the access point's answer: a card in
-- the network socket, and nothing until somebody fits one
-- (structures/access_point.luau). A panel with an empty socket still
-- bridges power perfectly well and simply carries no network, which is
-- the true thing to say about a box with no address at all. Its lock
-- is keyed to the placement's own `access` word, same as every other
-- locked box on the station.
--
-- A map may tell one which way each cable layer runs, which of its
-- output layers it keeps fed off its own cell in a blackout, and label
-- it with the room it serves:
--
--   (12, 5, "apc", { "l2": "input", "l1_reserve": true }),
--   labels: [(12, 5, "The Commons")]
return {
    id = "apc",
    visual_layer = "fixture",
    energy_network = "power",
    default_props = { l1 = "output", l2 = "input", l3 = "output" },
    name_label = "lunatic/tfs:entity.apc.name",
    name = "APC",
    sprite = "apc",
    -- The bridge's own three modules, then the network half: the
    -- address, the roster and the candidates, and the socket the card
    -- sits in.
    ui = { modules = { "store", "gates", "ports", "link", "parts" } },
    -- The sentence a crewman is told, the ladder, the alarm, and the
    -- flag it raises when it drops to its reserve (fixtures/apc.luau).
    script = "apc",
    -- THE CELL. STANDARD_BATTERY_CHARGE, 1 MJ (tg power.dm:32,
    -- battery.dm:17): tg's own APC ships the 2.5 MJ upgraded cell
    -- (battery.dm:29, apc_main.dm:43); this station fits the plain
    -- one. It charges at 1% of itself a second (CHARGELEVEL,
    -- apc_main.dm:9, :708), and `report` is what hands the ladder its
    -- charge every pass.
    store = { capacity_j = 1000000, charge_w = 10000, report = true },
    -- Gated: a master switch and one gate per load class
    -- (compositions.luau), which is what the ladder throws.
    bridge = { gates = true },
    -- The label a map gives it is the name of the room it stands in.
    names_room = true,
    mount = true,
    appearance = {
        mounted = {
            north = "apc_n",
            south = "apc_s",
            east = "apc_e",
            west = "apc_w",
        },
        -- tg's overlay stack, bottom first (apc_appearance.dm:49-61):
        -- the cover lock, the charge screen, then one lamp per load
        -- class, which the engine hides whole while the master is off.
        -- One lock picture for both states: the atlas has only tg's
        -- `apcox-0` (assets/sprites/10-turf-fixtures-and-tools.ron).
        states = {
            locked = "apcov_lock",
            unlocked = "apcov_lock",
            store_idle = "apcov_chg0",
            store_charging = "apcov_chg1",
            store_full = "apcov_chg2",
            equipment_on = "apcov_eq_on",
            equipment_off = "apcov_eq_off",
            lighting_on = "apcov_lt_on",
            lighting_off = "apcov_lt_off",
            environment_on = "apcov_env_on",
            environment_off = "apcov_env_off",
        },
    },
    category = "power",
    parts = { slots = { "network" } },
    link = { role = "hub", radius = 17, socket = "network", locked = true },
    examine = {
        flavor = "A wall box with a row of indicator lamps. It takes the "
            .. "station's power and decides how much of it this room gets.",
    },
}
