-- Paper folds into a plane (content/lib/paper_plane.luau): a folded sheet
-- thrown over an open hole glides twice the levels it drops, a flat sheet
-- drops straight, a glide into a wall falls straight with a refusal row,
-- and over a hot cell the plane stays aloft, is shoved on, and burns up
-- when the air is hot enough.
local UPPER = 1
local LOWER = 0

local function level_rows(): number
    return #t.ledger_rows("level_changed")
end

local function fold(p: number, x: number, y: number): ()
    t.use_item(p, assert(t.target_at(p, x, y, "paper"), "a sheet lies at the tile"), "alt_primary")
    t.run_ticks(2)
end

local function pick_up(p: number, x: number, y: number): ()
    t.click(p, x, y, t.target_at(p, x, y, "paper"))
    t.run_ticks(2)
    assert(t.hands(p).held == "paper", "the sheet is in hand")
end

t.world(
    [==[(
    name: "paper plane glide",
    tags: ["terrestrial"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
    },
    levels: [
        (
            rows: [
                "#########",
                "#.......#",
                "#.......#",
                "#.......#",
                "#...#...#",
                "#.......#",
                "#########",
            ],
            structures: [],
        ),
        (
            rows: [
                "#########",
                "#..o....#",
                "#.......#",
                "#..o....#",
                "#.......#",
                "#.......#",
                "#########",
            ],
            structures: [(1, 1, "player_spawn")],
            items: [(1, 1, "paper"), (2, 1, "paper"), (1, 2, "paper")],
        ),
    ],
)]==],
    0,
    "free_build"
)

local p = t.join()
t.run_ticks(4)

-- 1. Fold, then unfold by using the plane in hand: the same sheet either way.
fold(p, 1, 1)
local sheet = assert(t.item_at(1, 1, "paper"), "the sheet is still there")
assert(sheet.state == "folded" and sheet.sprite == "paperplane", "folded, it is a plane")
pick_up(p, 1, 1)
t.use_self(p)
t.run_ticks(2)
t.drop(p)
t.run_ticks(2)
sheet = assert(t.item_at(1, 1, "paper"), "the sheet was dropped back")
assert(sheet.state == "flat", "using the plane unfolds it, got " .. tostring(sheet.state))

-- 2. A folded plane thrown at the hole (3, 1) glides two tiles on along the
-- throw and lands on the level below, beyond the hole.
fold(p, 1, 1)
pick_up(p, 1, 1)
t.throw(p, 3, 1)
t.run_seconds(3)
local falls = level_rows()
assert(falls == 1, "the plane fell once, got " .. falls)
assert(#t.items_at(3, 1, UPPER) == 0, "nothing is left over the hole")
assert(#t.items_at(3, 1, LOWER) == 0, "it did not drop straight")
local landed = t.items_at(5, 1, LOWER)
assert(#landed == 1 and landed[1] == "paper", "it landed two tiles beyond, on the level below")

-- 3. A flat sheet thrown at the same hole drops straight down.
pick_up(p, 2, 1)
t.throw(p, 3, 1)
t.run_seconds(3)
assert(level_rows() == falls + 1, "the flat sheet fell too")
landed = t.items_at(3, 1, LOWER)
assert(#landed == 1 and landed[1] == "paper", "the flat sheet lies right under the hole")
assert(#t.items_at(5, 1, LOWER) == 1, "the plane is where it landed")

-- 4. A glide the lower level's wall at (4, 4) blocks falls straight, on the record.
local refusals = #t.ledger_rows("script_error")
fold(p, 1, 2)
pick_up(p, 1, 2)
t.throw(p, 3, 3)
t.run_seconds(3)
assert(level_rows() == falls + 2, "the blocked plane fell")
landed = t.items_at(3, 3, LOWER)
assert(#landed == 1 and landed[1] == "paper", "it drops straight under the hole")
assert(#t.items_at(5, 5, LOWER) == 0, "it did not reach the far side of the wall")
local refused = false
for _, row in ipairs(t.ledger_rows("script_error")) do
    refused = refused or row.file == "item-fall"
end
assert(#t.ledger_rows("script_error") > refusals and refused, "the refused glide is on the record")

-- Air under a hole: a corridor with one hole, hot air painted beneath it.
local HOT_WORLD = [==[(
    name: "paper plane updraft",
    tags: ["terrestrial"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), atmosphere: Exact(true)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
    },
    levels: [
        (
            rows: [
                "##########",
                "#........#",
                "##########",
            ],
            structures: [],
            painted: [(3, 1, "hot_air")],
        ),
        (
            rows: [
                "##########",
                "#..o.....#",
                "##########",
            ],
            structures: [(1, 1, "player_spawn")],
            items: [(1, 1, "paper")],
        ),
    ],
    blends: { "hot_air": (
        rows: [("n2", 20.0)], temperature_k: %.1f, amount: per_m3,
    ) },
)]==]

local function throw_plane_over_heat(kelvin: number): ()
    t.world(string.format(HOT_WORLD, kelvin), 0, "free_build")
    local player = t.join()
    t.run_ticks(4)
    fold(player, 1, 1)
    pick_up(player, 1, 1)
    t.throw(player, 3, 1)
end

-- 5. Warm air below, well short of ignition: the plane stays aloft and is
-- shoved on past the hole along its heading.
throw_plane_over_heat(480)
t.run_seconds(3)
assert(level_rows() == 0, "the plane never fell")
assert(#t.ledger_rows("item_fall_stayed") >= 1, "it stayed aloft over the hole")
assert(#t.items_at(3, 1, UPPER) == 0, "it was shoved off the hole")
local ridden = false
for x = 4, 8 do
    ridden = ridden or #t.items_at(x, 1, UPPER) == 1
end
assert(ridden, "it rests further along on the upper level")
for x = 1, 8 do
    assert(#t.items_at(x, 1, LOWER) == 0, "nothing reached the level below")
end

-- 6. Scorching air below: the plane catches fire and burns to nothing.
throw_plane_over_heat(750)
t.run_seconds(2)
assert(level_rows() == 0, "a burning plane does not fall")
local burning = assert(t.item_at(3, 1, "paper"), "the plane burns over the hole")
assert(burning.state == "onfire", "it is alight, got " .. tostring(burning.state))
t.run_seconds(5)
assert(#t.items_at(3, 1, UPPER) == 0, "it burned away")
assert(t.count_items("paper") == 0, "no sheet is left anywhere")
