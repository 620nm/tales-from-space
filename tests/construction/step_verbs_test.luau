local bench = require("@helpers/grav_bench")

-- A step with no name of its own reads the pack's verb for its tool or slot
-- (`interactions.verbs`, content/capabilities.luau), never "Interact", and
-- so do the native clicks that open, close and place.

bench.world(
    '(5, 6, "player_spawn"), (5, 5, "machine_frame", "wired"), (6, 5, "table")',
    '(5, 6, "wirecutters"), (5, 6, "machine_board")'
)
local p = t.join()
t.tick()

local function row(key: string, target: any?): any
    target = target or assert(t.target_at(p, 5, 5, "machine_frame"), "the frame stands")
    for _, hint in ipairs(t.action_hints(p, target)) do
        if hint.label.key == key then
            return hint
        end
    end
    return nil
end

bench.hold(p, "wirecutters", { { 5, 6 } })
assert(row("lunatic/tfs:ui.verb.cutters") ~= nil, "cutters read their verb")

bench.hold(p, "machine_board", { { 5, 6 } })
local board = assert(row("lunatic/tfs:ui.verb.board"), "a board reads its slot's verb")
assert((board.label.args.item or "") ~= "", "and names what it fits")

local table_target = assert(t.target_at(p, 6, 5, "table"), "the table stands")
local place = assert(row("lunatic/tfs:ui.verb.place", table_target), "a table takes the board")
assert(place.implement ~= nil, "and pictures it")
