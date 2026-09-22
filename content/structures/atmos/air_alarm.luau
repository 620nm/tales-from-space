-- Wall-mounted endpoint hub; membership is explicit, not proximity-derived.
-- Endpoint classes and the join action constrain its roster (docs/ATMOS.md).
return {
    id = "air_alarm",
    visual_layer = "fixture",
    energy_network = "power",
    -- tg's AREA_USAGE_ENVIRON, _air_alarm.dm:10 (docs/POWER.md).
    load_class = "environment",
    name_label = "lunatic/tfs:entity.air_alarm.name",
    name = "air alarm",
    sprite = "air_alarm",
    mount = true,
    corded = true,
    -- The sentence a crewman gets for touching it, which is the only
    -- part of this box that is not mechanism (fixtures/air_alarm.luau).
    script = "air_alarm",
    -- `link` is the network half -- the address, the lock, the roster,
    -- what it could take. `reach` is the atmospherics half: one section
    -- per machine joined to it, drawn from that machine's own module.
    -- `parts` is the socket the card sits in.
    ui = { modules = { "link", "reach", "parts", "files", "editor" } },
    files = { capacity = 65536, files = 16 },
    drive = { reads = { "disl" }, accepts = { "floppy" } },
    program_slots = { "controller" },
    -- WHAT IT LOOKS LIKE IS WHAT IT IS DOING. tg draws this box shut
    -- (`alarmp`) with a teal lamp laid over it, and draws NO lamp at
    -- all while it is unpowered, broken or shorted
    -- (_air_alarm.dm:557, :526-527). The two states this engine can
    -- derive land on exactly those two pictures: a live box on a live
    -- segment shows the lamp, a dead cord or a box off the air shows
    -- the same panel dark. `offline` and `unpowered` are the same cell
    -- on purpose -- tg draws one picture for "not working" and so does
    -- this. The yellow and red faces are baked and named by nothing
    -- yet; they want a threshold pass over the room's mix
    -- (assets/sprites/73-network.ron).
    --
    -- No entry-wide `appearance.mounted`: every row here carries its
    -- own four faces, which is what a mount needs and what lets the
    -- picture change without losing the wall it hangs on
    -- (docs/content-schema/appearance.md).
    appearance = {
        device = {
            online = {
                sprite = "air_alarm_lit",
                mounted = {
                    north = "air_alarm_lit_n",
                    south = "air_alarm_lit_s",
                    east = "air_alarm_lit_e",
                    west = "air_alarm_lit_w",
                },
            },
            offline = {
                sprite = "air_alarm",
                mounted = {
                    north = "air_alarm_n",
                    south = "air_alarm_s",
                    east = "air_alarm_e",
                    west = "air_alarm_w",
                },
            },
            unpowered = {
                sprite = "air_alarm",
                mounted = {
                    north = "air_alarm_n",
                    south = "air_alarm_s",
                    east = "air_alarm_e",
                    west = "air_alarm_w",
                },
            },
        },
    },
    category = "atmospherics",
    parts = { slots = { "network" } },
    link = {
        role = "hub",
        radius = 17,
        socket = "network",
        locked = true,
        accepts = { "atmos", "control_button" },
    },
    examine = {
        flavor = "A flat panel with a lamp on it, wired into the room's "
            .. "plumbing. Every fan in here is set from this box.",
    },
    transitions = {
        -- The crowbar, and the assembly with it: the board's one length
        -- of cable plus the wall frame's five, which is the access
        -- point's arithmetic and for the same reason
        -- (structures/access_point.luau).
        --
        -- The network card is NOT listed. A `yields` list cannot know
        -- which card this box was built around, and the roster in front
        -- of it can (docs/CONTENT-SCHEMA.md §1.10b), so the card that
        -- comes back out is the card that went in -- address, joins and
        -- every vent in the room still bound to it.
        {
            sound = "smash",
            tool = "crowbar",
            secs = 4.0,
            gone = true,
            leaves = "wall_frame",
            yields = {
                ["machine_board.air_alarm"] = 1,
                cable_coil = 6,
            },
            start = "You start prying the air alarm apart.",
            done = "The air alarm comes apart, leaving its frame on the wall.",
        },
    },
}
