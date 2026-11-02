-- A plumbing bench: walled pockets of deck, water painted on them, a run on
-- layer 3 under the walls. Specs read a run's water as what left the rooms:
-- a spec has no reader for liquid in a pipe, and the world's water is booked.
local liquid_bench = {}

-- Water on painted deck, litres on a square metre.
liquid_bench.FILM_L = 3.317
liquid_bench.ONE_G = "environment: (gravity_m_s2: Exact(9.80665)),"
liquid_bench.ZERO_G = 'tags: ["space"],\n    environment: (kind: Exact(space), gravity_m_s2: Exact(0.0)),'

export type Tile = { x: number, y: number }
export type Pool = { x: number, y: number, litres: number }
export type Cable = { x: number, y: number, channel: string }
export type Bench = {
    environment: string,
    rows: { string },
    structures: string,
    items: string?,
    run: { Tile }?,
    cables: { Cable }?,
    pools: { Pool },
    job: string?,
}

local MAP = [==[(
    name: "plumbing bench",
    %s
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '_': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'z': (composition: (substrate: Named("ground"))),
    },
    levels: [
        (
            rows: [%s],
            structures: [%s],
            items: [%s],
            networks: [%s],
            painted: [%s],
        ),
    ],
    blends: {%s},
)]==]

-- Builds the bench, joins a player at its `player_spawn`, runs one tick.
function liquid_bench.world(bench: Bench): number
    local rows: { string } = {}
    for _, row in ipairs(bench.rows) do
        table.insert(rows, `"{row}"`)
    end
    local networks: { string } = {}
    for _, tile in ipairs(bench.run or {}) do
        table.insert(
            networks,
            `(x: {tile.x}, y: {tile.y}, network: "pipe", channel: "l3", kind: "standard", facing: 15)`
        )
    end
    for _, cable in ipairs(bench.cables or {}) do
        table.insert(
            networks,
            `(x: {cable.x}, y: {cable.y}, network: "power", channel: "{cable.channel}", kind: "cable", facing: 15)`
        )
    end
    local painted: { string } = {}
    local blends: { string } = {}
    for index, pool in ipairs(bench.pools) do
        table.insert(painted, `({pool.x}, {pool.y}, "pool{index}")`)
        table.insert(
            blends,
            string.format(
                '"pool%d": (rows: [("water", %.3f), ("o2", 26.19), ("n2", 98.53)], temperature_k: 293.15, amount: total)',
                index,
                pool.litres * 55.51
            )
        )
    end
    t.world(
        MAP:format(
            bench.environment,
            table.concat(rows, ", "),
            bench.structures,
            bench.items or "",
            table.concat(networks, ", "),
            table.concat(painted, ", "),
            table.concat(blends, ", ")
        ),
        7
    )
    local player = t.join(bench.job)
    t.tick()
    return player
end

-- Litres of water on one tile, 0 on a dry one.
function liquid_bench.standing(x: number, y: number): number
    local liquid = t.room_liquid(x, y)
    return (liquid and liquid.water) or 0
end

return liquid_bench
