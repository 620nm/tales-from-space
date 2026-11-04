-- tg /obj/structure/stairs (stairs.dm:14-47): one flight whose facing is
-- the way up, over the open space it climbs through (stairs.dm:11). The
-- footprint is the NORTH shape: the flight, and the top one level up over
-- it, which draws nothing so the eye and a click reach the flight below.
--
-- Leaving the flight forward climbs to the tile ahead one level up
-- (`on_exit_stairs`, stairs.dm:181-191; `stair_ascend` checks the way up is
-- open and refuses an open landing, :274-283). A step onto the flight from
-- the tile ahead is refused (`Cross`, :269-271). Stepping back onto the top
-- walks down onto the flight. tg adds no time to the climb (`zMove` at
-- once, :283): each link costs the mover's own step. A fall onto the flight
-- is caught in content/lib/fall.luau (`intercept_zImpact`, :324-334).
-- Standing on the flight shows the landing ahead and puts it in reach
-- (`view_landing`; the engine's docs/sim/flight-view.md), beyond tg's arrow
-- (:196-221).
-- Not ported: merged art (:155-179), chained flights (:355-367), frames.
return {
    id = "stairs",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.stairs.name",
    name = "stairs",
    sprite = "stairs_n",
    dense = false,
    opaque = false,
    facings = { "north", "east", "south", "west" },
    footprint = {
        {
            at = { 0, 0, 0 },
            step_links = {
                { on = "leave", toward = "north", to = { 0, -1, 1 }, view_landing = true },
                { on = "block", toward = "south" },
            },
        },
        {
            at = { 0, 0, 1 },
            sprite = false,
            step_links = { { on = "enter", toward = "south", to = { 0, 0, -1 } } },
        },
    },
    -- One state, so each facing wears its own flight (tg draws `dir`,
    -- stairs.dm:14-18); the top cell draws nothing in any facing.
    states = { "standing" },
    state_sprites = {
        standing = {
            north = { "stairs_n", false },
            east = { "stairs_e", false },
            south = { "stairs_s", false },
            west = { "stairs_w", false },
        },
    },
}
