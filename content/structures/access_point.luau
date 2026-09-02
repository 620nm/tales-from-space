-- The access point: the box on the wall a segment of the station's
-- device network hangs off.
--
-- It is a HUB (docs/DEVICES.md §2), which is the middle of the three
-- roles and the only one that matters to somebody standing in a
-- corridor: devices join to it from within five tiles, and it may in
-- turn join a router. A hub with one device joined to it IS a network
-- -- nothing above it is required -- so a shift that has lost its
-- router still has as many small networks as it has access points.
--
-- FIVE TILES. Far enough to cover the room it is bolted in and the
-- doorway out of it, short enough that a second one is what covers the
-- next room. tg has no number to copy here: its telecomms machines
-- reach by z-level and its wall boxes reach by wire.
--
-- WHERE ITS ADDRESS COMES FROM. Nowhere, until somebody fits a card.
-- The `socket` says the address is whatever is in the network socket
-- (docs/DEVICES.md §5a), so an access point with an empty socket is on
-- no network at all, and pulling the card takes the whole segment off
-- the air without forgetting a single join.
--
-- WHAT ITS LOCK IS KEYED TO IS NOT WRITTEN HERE, and cannot be. A lock
-- names no claim in a file: it takes the placement's own `access` word,
-- the same row an airlock's placement carries, so one entry stands up a
-- rack of nodes keyed to different departments
-- (docs/CONTENT-SCHEMA.md §1.10c). One built by hand out of a wall
-- frame has no placement and therefore no key -- which is still a lock,
-- because it has to be worked by somebody standing at it, and the
-- engineer who screwed it together is exactly that somebody.
return {
    id = "access_point",
    name = "access point",
    sprite = "access_point",
    mount = true,
    corded = true,
    -- The one thing about this box that is a judgement rather than a
    -- mechanism is what it SAYS about itself, and that lives in
    -- fixtures/access_point.luau.
    script = "access_point",
    ui = { modules = { "link", "parts" } },
    -- WHAT IT LOOKS LIKE IS WHAT IT IS DOING, and tg has the art for
    -- it: this console drops to `[base_icon_state]_off` on NOPOWER
    -- (access_controller.dm:224-227) and otherwise draws standby
    -- (:228). The two states this engine derives take those two
    -- pictures -- and an EMPTY SOCKET lands on the dark one, which is
    -- the true thing to say about a box with no address at all.
    --
    -- Every row carries its own four faces, so no entry-wide
    -- `appearance.mounted` is needed and the picture can change without
    -- losing the wall it hangs on (docs/content-schema/appearance.md).
    appearance = {
        device = {
            online = { sprite = "access_point", mounted = {
                north = "access_point_n", south = "access_point_s",
                east = "access_point_e", west = "access_point_w",
            } },
            offline = { sprite = "access_point_off", mounted = {
                north = "access_point_off_n", south = "access_point_off_s",
                east = "access_point_off_e", west = "access_point_off_w",
            } },
            unpowered = { sprite = "access_point_off", mounted = {
                north = "access_point_off_n", south = "access_point_off_s",
                east = "access_point_off_e", west = "access_point_off_w",
            } },
        },
    },
    -- No `category`: the group derives from the `link` block below.
    parts = { slots = { "network" } },
    link = { role = "hub", radius = 5, socket = "network", locked = true },
    examine = {
        flavor = "A flat panel with one indicator on it. Whatever it is "
            .. "carrying, it carries quietly.",
    },
    transitions = {
        -- The crowbar, and the whole assembly with it. A `leaves`
        -- structure always stands up in its FIRST state, which for a
        -- wall frame is bare metal -- so the five lengths that wiring
        -- cost come back in this pile too. SIX here is the board's own
        -- one plus the frame's five, and the books balance exactly as
        -- the temperature control unit's do
        -- (structures/thermomachine.luau).
        --
        -- THE SOCKET SAYS WHAT COMES OUT, so the network card is NOT
        -- written here: a `yields` list is written once and cannot know
        -- which card this one was built around, while the roster in
        -- front of it can (docs/CONTENT-SCHEMA.md §1.10b). Naming a
        -- component here is a load error for that reason, and it is the
        -- reason worth wanting -- the card that comes back out is the
        -- card that was in it, address and joins and all.
        {
            tool = "crowbar",
            secs = 4.0,
            gone = true,
            leaves = "wall_frame",
            yields = {
                ["machine_board.access_point"] = 1,
                cable_coil = 6,
            },
            start = "You start prying the access point apart.",
            done = "The access point comes apart, leaving its frame on the wall.",
        },
    },
}
