-- Light crosses levels as sight does (`capabilities.levels.light`): through a
-- hole or a floor window and not through a solid floor. Plain glass passes it
-- whole; plasma glass tints it to its material colour #ff80f4 (alloys.dm:98),
-- an owner ruling since tg tints no light. The lamp is the pack's ceiling
-- tube set white, on the same corridor power as tests/power/lights_test.luau.
local BASEMENT = -1
local GROUND = 0

-- The powered level: lamp at (2, 1), an outlet and generator behind it.
local function cables(skip_hole: boolean): string
    local out = ""
    for _, tile in ipairs({ { 1, 1 }, { 2, 1 }, { 3, 1 }, { 1, 2 }, { 2, 2 }, { 3, 2 } }) do
        if not (skip_hole and tile[1] == 2 and tile[2] == 2) then
            for _, channel in ipairs({ "l1", "l2" }) do
                out ..= `(x: {tile[1]}, y: {tile[2]}, network: "power", channel: "{channel}", kind: "cable", facing: 15),`
            end
        end
    end
    return out
end

local LEGEND = [==[
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'l': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Light), light: Some("#FFFFFF")),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'G': (composition: (substrate: Open, components: [(component: "glass_floor")])),
        'P': (composition: (substrate: Open, components: [(component: "plasma_glass_floor")])),
        'H': (composition: (substrate: Open)),
]==]

local function world(name: string, lower: string, upper: string)
    t.world(
        `(name: "{name}", tags: ["terrestrial"], levels_below_ground: 1,`
            .. ` environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),`
            .. ` legend: \{\n{LEGEND}\n    }, levels: [{lower}, {upper}])`,
        7
    )
end

local POWERED = `(rows: ["#####", "#alo#", "#..g#", "#####"], structures: [(1, 1, "apc")], networks: [{cables(false)}])`

-- (a), (c), (d): the lamp is in the basement, the viewer on the ground above
-- plain glass (2, 1), plasma glass (3, 1) and solid floor (1, 2).
world(
    "lamp below",
    POWERED,
    `(rows: ["#####", "#.GP#", "#...#", "#####"], structures: [(1, 1, "player_spawn")])`
)
local viewer = t.join()
t.run_seconds(3)

-- (a) The band seen through the glass is lit by the lamp below it.
local seen = t.received_light(viewer, 2, 1, BASEMENT)
assert(seen ~= nil and seen[1] > 0 and seen[2] > 0 and seen[3] > 0, "the lamp lights the tile seen through the glass")

-- Plain glass passes white light white; plasma glass passes it tinted.
local plain = assert(t.received_light(viewer, 2, 1, GROUND), "light reaches the plain glass floor")
assert(plain[1] > 0 and math.abs(plain[2] / plain[1] - 1) < 0.05, "plain glass keeps white light white")
local plasma = assert(t.received_light(viewer, 3, 1, GROUND), "light reaches the plasma glass floor")
assert(plasma[1] > 0, "red passes plasma glass")
assert(
    math.abs(plasma[2] / plasma[1] - 0.502) < 0.06,
    "green is held to half of red, got " .. plasma[2] / plasma[1]
)
assert(plasma[3] / plasma[1] > 0.9, "blue is nearly as strong as red, got " .. plasma[3] / plasma[1])

-- (d) A solid floor passes nothing up; the viewer cannot see the tile under it.
assert(t.received_light(viewer, 1, 2, GROUND) == nil, "a closed floor passes no light")

-- (b) The lamp is on the ground, over a hole; the viewer stands in the basement beneath it.
world(
    "lamp above",
    `(rows: ["#####", "#...#", "#...#", "#####"], structures: [(2, 2, "player_spawn")])`,
    `(rows: ["#####", "#alo#", "#.Hg#", "#####"], structures: [(1, 1, "apc")], networks: [{cables(true)}])`
)
viewer = t.join()
t.run_seconds(3)
local under = t.received_light(viewer, 2, 2, BASEMENT)
assert(under ~= nil and under[1] > 0, "the lamp above lights the tile under the hole")
