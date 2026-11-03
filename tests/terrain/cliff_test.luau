-- A cliff is a solid barrier, as tg's dense /turf/open/cliff (cliff.dm:5):
-- a body cannot step onto it, but sight passes, since tg's cliff is an open
-- turf with no opacity. It draws the stepped face in its rock's colour,
-- joined to the cliff beside it. A boulder (tg /obj/structure/flora/rock,
-- flora.dm:1027-1041) is dense and lets sight pass as well.
t.world(
    [==[(
    name: "cliff",
    tags: ["terrestrial"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        'a': (composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'c': (composition: (substrate: Named("cliff"), material: Named("basalt_cliff"), components: [])),
    },
    levels: [
        (
            rows: [
                "aaccaa",
                "aaccaa",
                "aaccaa",
                "aaaaaa",
            ],
            structures: [(1, 1, "player_spawn"), (3, 3, "outcrop")],
        ),
    ],
)]==],
    0,
    "free_build"
)
t.set_breathing(false)

local BASALT = "#5E626E" -- content/substances/ground/basalt.luau

local p = t.join()
t.run_ticks(4)

local function step(direction: "north" | "south" | "east" | "west")
    t.move(p, direction)
    t.run_seconds(0.5)
end

local function at(x: number, y: number, why: string)
    local px, py = t.pos(p)
    assert(px == x and py == y, why .. ": at " .. px .. "," .. py)
end

-- The face: the cliff profile's look in basalt's colour, joined to cliff only.
local parts = t.seen_ground(p, 2, 2)
assert(#parts == 1, "a cliff tile draws one ground part, got " .. #parts)
local face = parts[1]
assert(face.look == "cliff_shell", "the face is the cliff look, got " .. face.look)
assert(face.tint == BASALT, "in basalt's colour, got " .. face.tint)
local joins = assert(face.joins, "the face is a shell")
assert(joins.n and joins.e, "it joins the cliff north and east")
assert(not joins.s and not joins.w, "and not the sand south and west")
assert(t.seen_ground(p, 1, 1)[1].look == "ground_shell", "the sand beside it draws its own face")

-- Sight passes the cliff: the sand straight past it is disclosed.
assert(#t.seen_ground(p, 4, 1) == 1, "the tile past the cliff is in view")

-- A body cannot step onto it.
step("east")
at(1, 1, "a cliff stops a body")

-- A boulder stops a body too, and sight passes it.
step("south")
step("south")
step("east")
at(2, 3, "the walk to the boulder")
local boulder = assert(t.structure_at(3, 3), "a boulder stands at (3, 3)")
assert(boulder.id == "outcrop" and boulder.sprite == "prop_rough_outcrop_2", "the outcrop prototype")
step("east")
at(2, 3, "a boulder stops a body")
assert(#t.seen_ground(p, 4, 3) == 1, "the tile past the boulder is in view")
