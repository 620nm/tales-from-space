-- What a client was told to draw on a tile, read through `t.seen_matter`
-- (the engine's docs/looks/matter.md section 7).
local matter_look = {}

-- The part of one look and rung at a tile, nil when that rung is not drawn.
function matter_look.find(player: number, x: number, y: number, look: string, rung: number): SpecSeenMatterPart?
    for _, part in ipairs(t.seen_matter(player, x, y)) do
        if part.look == look and part.rung == rung then
            return part
        end
    end
    return nil
end

-- The highest rung of one look drawn at a tile, 0 when the look draws nothing there.
function matter_look.top_rung(player: number, x: number, y: number, look: string): number
    local top = 0
    for _, part in ipairs(t.seen_matter(player, x, y)) do
        if part.look == look and part.rung > top then
            top = part.rung
        end
    end
    return top
end

-- A shell part's joins and quadrants, asserted present.
function matter_look.edges(part: SpecSeenMatterPart): (SpecSeenMatterJoins, SpecSeenMatterQuadrants)
    local joins = assert(part.joins, part.look .. " rung " .. part.rung .. " is a picture, not a shell")
    local quadrants = assert(part.quadrants, part.look .. " rung " .. part.rung .. " has no quadrants")
    return joins, quadrants
end

-- Every part of one look drawn at a tile, in the order the client draws them.
function matter_look.parts(player: number, x: number, y: number, look: string): { SpecSeenMatterPart }
    local found = {}
    for _, part in ipairs(t.seen_matter(player, x, y)) do
        if part.look == look then
            table.insert(found, part)
        end
    end
    return found
end

-- Millilitres of water as a blend row: 55.51 mol a litre.
function matter_look.water(ml: number): string
    return string.format('("water", %.4f)', ml * 0.05551)
end

export type Spill = { x: number, y: number, rows: string }

local ROOM = [==[(
    name: "matter look room",%s
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "###########",
                "#.........#",
                "#.........#",
                "#.........#",
                "#.........#",
                "#.........#",
                "###########",
            ],
            structures: [(1, 1, "player_spawn")],
            painted: [%s],
        ),
    ],
    blends: {%s},
)]==]

-- A sealed 9 x 5 room with each spill painted on its tile at 293.15 K, a
-- joined player at (1, 1), one tick run. `gravity` (m/s2) pins a planetary
-- environment, 0 making it weightless; nil keeps the pack's default.
function matter_look.room(spills: { Spill }, gravity: number?): number
    local environment = ""
    if gravity ~= nil then
        environment = string.format(
            '\n    tags: ["terrestrial"],\n    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(%.5f)),',
            gravity
        )
    end
    local painted: { string } = {}
    local blends: { string } = {}
    for index, spill in ipairs(spills) do
        local name = "spill" .. index
        table.insert(painted, string.format('(%d, %d, "%s")', spill.x, spill.y, name))
        table.insert(
            blends,
            string.format(
                '"%s": (rows: [%s, ("o2", 26.19), ("n2", 98.53)], temperature_k: 293.15, amount: total)',
                name,
                spill.rows
            )
        )
    end
    t.world(ROOM:format(environment, table.concat(painted, ", "), table.concat(blends, ", ")), 0)
    local player = t.join()
    t.tick()
    return player
end

return matter_look
