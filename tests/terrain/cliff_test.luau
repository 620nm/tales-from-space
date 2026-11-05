-- A cliff is ground: a band of `half` steps (content/terrain.luau), blocks
-- half a tile high laid by the map's solid overrides. It draws the stepped
-- face in its rock's colour, joined to the cliff beside it, and sight passes
-- it as tg's open /turf/open/cliff (cliff.dm:5, no opacity). A body's walk
-- up onto it is refused and becomes tg's 2 s climb (climbable.dm:13); along
-- its top and down off it the body walks. A boulder (tg
-- /obj/structure/flora/rock, flora.dm:1027-1041) is dense and lets sight
-- pass as well.
t.world(
    [==[(
    name: "cliff",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), surface_temperature_k: Exact(259.15)),
    legend: {
        'a': (composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'c': (composition: ()),
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
            solid: [
                (2, 0, StepOf("half", Blend("basalt_ground"))),
                (3, 0, StepOf("half", Blend("basalt_ground"))),
                (2, 1, StepOf("half", Blend("basalt_ground"))),
                (3, 1, StepOf("half", Blend("basalt_ground"))),
                (2, 2, StepOf("half", Blend("basalt_ground"))),
                (3, 2, StepOf("half", Blend("basalt_ground"))),
            ],
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

local function said(): string
    local lines = t.messages(p)
    return lines[#lines] or ""
end

-- The face: the step's cliff look in basalt's colour, joined to cliff only.
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

-- A walk up onto it is refused and starts the climb; two seconds on, the
-- body stands on top.
t.messages(p)
step("east")
at(1, 1, "a cliff stops a walk")
assert(said() == "You start climbing.", "the refused walk starts a climb: " .. said())
t.run_seconds(2.5)
at(2, 1, "the body climbs onto the cliff")
assert(said() == "You climb up onto the ledge.", "and is told so: " .. said())

-- Along its top and down off it, the body walks.
step("east")
at(3, 1, "the body walks along the cliff top")
step("east")
at(4, 1, "and steps down off it onto the sand")

-- A boulder stops a body, and sight passes it.
step("south")
step("south")
at(4, 3, "the walk to the boulder")
local boulder = assert(t.structure_at(3, 3), "a boulder stands at (3, 3)")
assert(boulder.id == "outcrop" and boulder.sprite == "prop_rough_outcrop_2", "the outcrop prototype")
step("west")
at(4, 3, "a boulder stops a body")
assert(#t.seen_ground(p, 2, 3) == 1, "the tile past the boulder is in view")
