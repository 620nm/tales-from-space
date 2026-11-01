-- The RPD offers its breakdown by the `pipe_part` tag, and its use handler
-- breaks down what its shelf lists, so a shelf item without the tag could be
-- built and never offered back. The shelf is the roster: every row is walked,
-- each on a tile of its own since a pile shows only its top item.
local shelf = t.content_module("rpd_shelf")
local recipes = shelf.recipes :: { { item: string } }
assert(#recipes >= 12, "the whole shelf")

local items = `(1, 1, "rpd"),`
for index, recipe in ipairs(recipes) do
    items ..= `({index + 1}, 1, "{recipe.item}"),`
end
local wall = string.rep("#", #recipes + 3)

t.world(
    [==[(
    name: "rpd shelf",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "]==] .. wall .. [==[",
                "#]==] .. string.rep("o", #recipes + 1) .. [==[#",
                "]==] .. wall .. [==[",
            ],
            structures: [(1, 1, "player_spawn")],
            items: []==] .. items .. [==[],
        ),
    ],
)]==],
    7
)

local p = t.join()
t.tick()
t.click(p, 1, 1, t.target_at(p, 1, 1, "rpd"))
t.run_ticks(2)
assert(t.hands(p).held == "rpd", "the RPD is in hand")

for index, recipe in ipairs(recipes) do
    local item = assert(t.target_at(p, index + 1, 1, recipe.item), recipe.item .. " lies on its tile")
    local offered = false
    for _, action in ipairs(t.action_hints(p, item)) do
        offered = offered or action.id == "disassemble"
    end
    assert(offered, recipe.item .. " on the shelf carries the pipe_part tag")
    t.move(p, "east")
    t.run_ticks(5)
end
