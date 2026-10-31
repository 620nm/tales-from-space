local composition = require("@helpers/composition")
local ui_controls = require("@helpers/ui_controls")

-- Shared setup for the ignition specs: a sealed room with ethanol spilled
-- on chosen tiles, every other floor tile painted with dry air, and
-- readers for the latch rows (`ColumnChanged` on `alight`) and the fire
-- rows (`IgnitionAt`, `ExtinguishedAt`). Specs cannot read a cell's
-- columns, so the ledger is the only witness of the latch.
local ignition_room = {}

-- A tile's worth of Earth air (3 m3 at 101.325 kPa, 293.15 K).
ignition_room.AIR_O2 = 26.191311343596351
ignition_room.AIR_N2 = 98.52921886400532
-- Two litres of ethanol: 789 g/L over 46.07 g/mol.
ignition_room.POOL_MOL = 34.25
-- Under the lib's half-mole oxygen floor a tile no longer burns.
ignition_room.OXYGEN_FLOOR_MOL = 0.5
ignition_room.FUEL_FLOOR_MOL = 0.01

export type Spill = {
    x: number,
    y: number,
    ethanol_mol: number,
    temperature_k: number?,
}

export type Room = {
    -- Map rows; '#' wall, ' ' space, any other glyph a floor tile.
    rows: { string },
    -- Extra legend entries, RON, each ending in a comma.
    legend: string?,
    -- Extra RON tuples, each ending in a comma.
    structures: string?,
    items: string?,
    networks: string?,
    spawn: { x: number, y: number },
    spills: { Spill },
    -- Oxygen on every floor tile; Earth air when absent.
    oxygen_mol: number?,
    seed: number?,
}

export type TileXY = { x: number, y: number }

local WORLD = [==[(
    name: "ignition room",
    tags: ["space"],
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        ' ': (composition: (), outdoors: true),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        %s
    },
    levels: [
        (
            rows: [%s],
            structures: [(%d, %d, "player_spawn"), %s],
            items: [%s],
            networks: [%s],
            painted: [%s],
        ),
    ],
    blends: {%s},
)]==]

local function key(x: number, y: number): string
    return string.format("%d:%d", x, y)
end

-- Builds the world, joins one player on the spawn tile, runs one tick.
function ignition_room.build(room: Room): number
    local spilled: { [string]: Spill } = {}
    for _, spill in ipairs(room.spills) do
        spilled[key(spill.x, spill.y)] = spill
    end
    local oxygen = room.oxygen_mol or ignition_room.AIR_O2
    local rows: { string } = {}
    local painted: { string } = {}
    local blends: { string } = {}
    for y, row in ipairs(room.rows) do
        table.insert(rows, string.format("%q", row))
        for x = 1, #row do
            local glyph = string.sub(row, x, x)
            if glyph ~= "#" and glyph ~= " " then
                local tile_x, tile_y = x - 1, y - 1
                local name = string.format("tile_%d_%d", tile_x, tile_y)
                local spill = spilled[key(tile_x, tile_y)]
                local fuel = ""
                local kelvin = 293.15
                if spill ~= nil then
                    fuel = string.format('("ethanol", %.4f), ', spill.ethanol_mol)
                    kelvin = spill.temperature_k or kelvin
                end
                table.insert(painted, string.format('(%d, %d, "%s")', tile_x, tile_y, name))
                table.insert(
                    blends,
                    string.format(
                        '"%s": (rows: [%s("o2", %.6f), ("n2", %.6f)], temperature_k: %.2f, amount: total)',
                        name,
                        fuel,
                        oxygen,
                        ignition_room.AIR_N2,
                        kelvin
                    )
                )
            end
        end
    end
    t.world(
        string.format(
            WORLD,
            room.legend or "",
            table.concat(rows, ", "),
            room.spawn.x,
            room.spawn.y,
            room.structures or "",
            room.items or "",
            room.networks or "",
            table.concat(painted, ", "),
            table.concat(blends, ", ")
        ),
        room.seed or 0
    )
    t.set_environment({ sink_k = 2.7, insolation = 0 })
    t.set_breathing(false)
    local player = t.join()
    t.tick()
    return player
end

-- The tile a ledger row names: `at` for fire rows, `pos` for the rest.
function ignition_room.tile_of(row: SpecLedgerRow): TileXY
    local fields: any = row
    local raw = fields.at or fields.pos
    local pair = ui_controls.array(raw)
    return { x = pair[1] :: number, y = pair[2] :: number }
end

-- Every write to the latch column, oldest first.
function ignition_room.latch_rows(): { SpecLedgerRow }
    local found = {}
    for _, row in ipairs(t.ledger_rows("ColumnChanged")) do
        local fields: any = row
        if fields.column == "alight" then
            table.insert(found, row)
        end
    end
    return found
end

-- The latch rows that set (`on`) or cleared (`not on`) a tile.
function ignition_room.latch_edges(on: boolean): { SpecLedgerRow }
    local found = {}
    for _, row in ipairs(ignition_room.latch_rows()) do
        local fields: any = row
        if (fields.to >= 0.5) == on then
            table.insert(found, row)
        end
    end
    return found
end

-- Tiles whose newest latch row set the latch, as "x:y" keys.
function ignition_room.latched_tiles(): { [string]: boolean }
    local state: { [string]: boolean } = {}
    for _, row in ipairs(ignition_room.latch_rows()) do
        local fields: any = row
        local tile = ignition_room.tile_of(row)
        state[key(tile.x, tile.y)] = fields.to >= 0.5
    end
    local lit: { [string]: boolean } = {}
    for tile, on in pairs(state) do
        if on then
            lit[tile] = true
        end
    end
    return lit
end

function ignition_room.tile_key(x: number, y: number): string
    return key(x, y)
end

function ignition_room.count(lit: { [string]: boolean }): number
    local n = 0
    for _ in pairs(lit) do
        n = n + 1
    end
    return n
end

function ignition_room.ethanol_gas(x: number, y: number): number
    local gas = t.room_gas(x, y)
    return (gas and gas.ethanol) or 0.0
end

function ignition_room.ethanol_liquid_ml(x: number, y: number): number
    local liquid = t.room_liquid(x, y)
    return ((liquid and liquid.ethanol) or 0.0) * 1000
end

function ignition_room.oxygen_gas(x: number, y: number): number
    local gas = t.room_gas(x, y)
    return (gas and gas.o2) or 0.0
end

-- Picks up the burner lying on (x, y), where the player stands, and
-- strikes it.
function ignition_room.take_lit_burner(player: number, x: number, y: number)
    t.click(player, x, y, assert(t.target_at(player, x, y, "burner"), "a burner lies here"))
    t.tick()
    assert(t.hands(player).held == "burner", "the burner is in hand")
    t.use_self(player)
    t.tick()
    assert(t.ledger_has("FuelBurnSet"), "the burner is struck and on the record")
end

-- A ground click on a tile within reach, and one tick for it to land.
function ignition_room.touch(player: number, x: number, y: number)
    composition.click_deck(player, x, y)
    t.tick()
end

-- Runs `step` seconds at a time, up to `limit`, until `done()` holds.
-- Returns the seconds run, or nil when the limit came first.
function ignition_room.run_until(limit: number, step: number, done: () -> boolean): number?
    local elapsed = 0.0
    while elapsed < limit do
        if done() then
            return elapsed
        end
        t.run_seconds(step)
        elapsed = elapsed + step
    end
    if done() then
        return elapsed
    end
    return nil
end

function ignition_room.said(player: number, needle: string): boolean
    return string.find(table.concat(t.messages(player), "\n"), needle, 1, true) ~= nil
end

return ignition_room
