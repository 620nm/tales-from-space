-- Player-facing crate and freezer containers: native toggles, dense-open
-- movement, loose-item custody, pulling, and department art.

local function move_and_settle(
    player: number,
    direction: "north" | "south" | "east" | "west"
): ()
    t.move(player, direction)
    -- Human steps take 200 ms; add one 20 Hz settlement tick.
    t.run_seconds(0.25)
end

local function has_sound(sounds: { string }, wanted: string): boolean
    for _, sound in ipairs(sounds) do
        if sound == wanted then
            return true
        end
    end
    return false
end

t.world(
    [==[(
    name: "crate corridor",
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "##########",
                "#....#####",
                "#.########",
                "#....#####",
                "#.########",
                "#....#####",
                "#.########",
                "#........#",
                "##########",
            ],
            items: [
                (4, 5, "headset"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
                (4, 5, "wrench"),
            ],
            structures: [
                (2, 1, "player_spawn"),
                (4, 1, "crate"),
                (4, 3, "freezer"),
                (4, 5, "crate"),
                (2, 7, "crate.medical"),
                (3, 7, "crate.engineering"),
                (4, 7, "crate.science"),
                (5, 7, "crate.hydroponics"),
                (6, 7, "crate.internals"),
                (7, 7, "crate.secure"),
            ],
        ),
    ],
)]==],
    0
)

local p = t.join()
t.tick()
assert(t.hands(p).held == nil, "the player starts empty-handed")

local shut_crate = assert(t.structure_at(4, 1))
assert(
    shut_crate.state == "closed" and shut_crate.sprite == "crate",
    "the base crate starts closed in its authored art"
)
move_and_settle(p, "east")
move_and_settle(p, "east")
local x, y = t.pos(p)
assert(x == 3 and y == 1, "the closed crate blocks its wall-pinned corridor")

local _ = t.sounds(p)
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "crate")))
t.tick()
local open_crate = assert(t.structure_at(4, 1))
assert(
    open_crate.state == "open" and open_crate.sprite == "crate_open",
    "an empty-hand click opens the crate in its authored art"
)
assert(#t.items_at(4, 1) == 0, "the empty foundation stock stays empty")
assert(has_sound(t.sounds(p), "crate_open"), "opening plays the crate sound")
move_and_settle(p, "east")
x, y = t.pos(p)
assert(x == 3 and y == 1, "the open crate remains solid")

local _ = t.sounds(p)
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "crate")))
t.tick()
local closed_crate = assert(t.structure_at(4, 1))
assert(
    closed_crate.state == "closed" and closed_crate.sprite == "crate",
    "an empty-hand click closes the crate in its authored art"
)
assert(has_sound(t.sounds(p), "crate_close"), "closing plays the crate sound")

local pulled_crate = assert(t.target_at(p, 4, 1, "crate"))
t.pull(p, 4, 1, pulled_crate)
t.tick()
t.move(p, "west")
t.run_ticks(6)
assert(
    t.same_target(assert(t.target_at(p, 3, 1, "crate")), pulled_crate),
    "the loose crate follows into the tile the player left"
)
assert(#t.ledger_rows("PullStarted") == 1, "pulling the crate is recorded")
t.stop_pull(p)
t.tick()

move_and_settle(p, "west")
move_and_settle(p, "south")
move_and_settle(p, "south")
move_and_settle(p, "east")
move_and_settle(p, "east")
x, y = t.pos(p)
assert(x == 3 and y == 3, "the player reaches the freezer corridor")
move_and_settle(p, "east")
x, y = t.pos(p)
assert(x == 3 and y == 3, "the closed freezer blocks its wall-pinned corridor")

assert(t.hands(p).held == nil, "the freezer actions also use an empty hand")
local _ = t.sounds(p)
t.click(p, 4, 3, assert(t.target_at(p, 4, 3, "freezer")))
t.tick()
local open_freezer = assert(t.structure_at(4, 3))
assert(
    open_freezer.state == "open" and open_freezer.sprite == "freezer_open",
    "an empty-hand click opens the freezer in its authored art"
)
assert(#t.items_at(4, 3) == 0, "the freezer's foundation stock stays empty")
assert(has_sound(t.sounds(p), "crate_open"), "opening the freezer plays the crate sound")
move_and_settle(p, "east")
x, y = t.pos(p)
assert(x == 3 and y == 3, "the open freezer remains solid")

local _ = t.sounds(p)
t.click(p, 4, 3, assert(t.target_at(p, 4, 3, "freezer")))
t.tick()
local closed_freezer = assert(t.structure_at(4, 3))
assert(
    closed_freezer.state == "closed" and closed_freezer.sprite == "freezer",
    "an empty-hand click closes the freezer in its authored art"
)
assert(has_sound(t.sounds(p), "crate_close"), "closing the freezer plays the crate sound")

local pulled_freezer = assert(t.target_at(p, 4, 3, "freezer"))
t.pull(p, 4, 3, pulled_freezer)
t.tick()
t.move(p, "west")
t.run_ticks(6)
assert(
    t.same_target(assert(t.target_at(p, 3, 3, "freezer")), pulled_freezer),
    "the loose freezer follows into the tile the player left"
)
t.stop_pull(p)
t.tick()

move_and_settle(p, "west")
move_and_settle(p, "south")
move_and_settle(p, "south")
move_and_settle(p, "east")
move_and_settle(p, "east")
t.click(p, 4, 5, assert(t.target_at(p, 4, 5, "crate")))
t.tick()
assert(assert(t.structure_at(4, 5)).state == "open", "the capacity crate opens")
assert(#t.items_at(4, 5) == 31, "opening exposes the thirty-one loose fixture items")
t.click(p, 4, 5, assert(t.target_at(p, 4, 5, "crate")))
t.tick()
assert(assert(t.structure_at(4, 5)).state == "closed", "the capacity crate closes")
assert(#t.items_at(4, 5) == 1, "closing stores thirty items and preserves the overflow")
t.click(p, 4, 5, assert(t.target_at(p, 4, 5, "crate")))
t.tick()
local returned = t.items_at(4, 5)
local headsets = 0
local wrenches = 0
for _, item in ipairs(returned) do
    if item == "headset" then
        headsets += 1
    elseif item == "wrench" then
        wrenches += 1
    end
end
assert(
    #returned == 31 and headsets == 1 and wrenches == 30,
    "reopening returns the same thirty items and leaves the overflow"
)

local variants = {
    { x = 2, id = "crate.medical", sprite = "crate_medical" },
    { x = 3, id = "crate.engineering", sprite = "crate_engineering" },
    { x = 4, id = "crate.science", sprite = "crate_science" },
    { x = 5, id = "crate.hydroponics", sprite = "crate_hydroponics" },
    { x = 6, id = "crate.internals", sprite = "crate_internals" },
    { x = 7, id = "crate.secure", sprite = "crate_secure" },
}
for _, variant in ipairs(variants) do
    local placed = assert(t.structure_at(variant.x, 7))
    assert(
        placed.state == "closed" and placed.sprite == variant.sprite,
        variant.id .. " loads closed with its expected art"
    )
end

local opened = t.ledger_rows("container_opened")
local closed = t.ledger_rows("container_closed")
assert(#opened == 4 and #closed == 3, "all crate and freezer toggles reach the ledger")
for _, row in ipairs(opened) do
    assert(row.actor.kind == "player", "opening is attributed to the acting player")
end
for _, row in ipairs(closed) do
    assert(row.actor.kind == "player", "closing is attributed to the acting player")
end
