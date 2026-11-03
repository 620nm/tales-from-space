-- Paper folds into a plane (content/lib/paper_plane.luau): a folded sheet
-- thrown over an open hole glides twice the levels it drops, a flat sheet
-- drops straight, a glide into a wall falls straight with an
-- `fall_glide_refused` row (no script error),
-- and over a hot cell the plane stays aloft, is shoved on, and burns up
-- when the air is hot enough.
-- A plane over heat surfs a hole once, then falls (or burns) in bounded time.
-- Play is on ground level 0 (where `t.item_at` looks); the hole drops to -1.
local ui_controls = require("@helpers/ui_controls")

local UPPER = 0
local LOWER = -1

local function level_rows(): number
    return #t.ledger_rows("level_changed")
end

local function fold(p: number, x: number, y: number): ()
    t.use_item(p, assert(t.target_at(p, x, y, "paper"), "a sheet lies at the tile"), "alt_primary")
    t.run_ticks(2)
end

local NOTE = "folded and unfolded, still written"

-- The writing window's committed fragments, joined (the seam of
-- tests/games/writing_test.luau).
local function committed_text(p: number): string
    local window = ui_controls.record(t.ui(p, "writing"))
    local data = ui_controls.record(ui_controls.record(window.script).data)
    local text = {}
    for _, fragment in ipairs(ui_controls.rows(data.committed or {})) do
        table.insert(text, fragment.text)
    end
    return table.concat(text)
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
    levels_below_ground: 1,
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
            items: [(1, 1, "paper"), (2, 2, "four_color_pen"), (2, 1, "paper"), (1, 2, "paper")],
        ),
    ],
)]==],
    0,
    "free_build"
)

local p = t.join()
t.run_ticks(4)

-- 1. Write on the sheet, fold it, then unfold by using the plane in hand:
-- the same sheet either way, with its writing.
pick_up(p, 1, 1)
local pen = assert(t.target_at(p, 2, 2, "four_color_pen"), "a pen lies beside the player")
t.click(p, 2, 2, pen)
t.run_ticks(2)
if t.hands(p).held ~= "four_color_pen" then
    t.swap_hands(p)
    t.run_ticks(2)
end
assert(t.hands(p).held == "four_color_pen", "the pen is held beside the sheet")
t.use_on_other(p)
t.run_ticks(2)
local address = assert(t.ui_document(p, "writing"), "the writing address is disclosed")
local prefix = "doc/" .. address.document .. "/" .. address.generation .. "/paper"
t.ui_edit(p, prefix .. "/draft", NOTE)
t.ui_press(p, prefix .. "/commit")
t.run_ticks(2)
assert(committed_text(p) == NOTE, "the note is on the sheet, got " .. committed_text(p))
t.drop(p)
t.run_ticks(2)
t.swap_hands(p)
t.drop(p)
t.run_ticks(2)
fold(p, 1, 1)
local sheet = assert(t.item_at(1, 1, "paper"), "the sheet is still there")
assert(sheet.state == "folded" and sheet.sprite == "paperplane", "folded, it is a plane")
pick_up(p, 1, 1)
assert(committed_text(p) == NOTE, "the plane keeps its writing")
t.use_self(p)
t.run_ticks(2)
assert(committed_text(p) == NOTE, "the unfolded sheet keeps its writing")
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

-- 4. A glide the lower level's wall at (4, 4) blocks falls straight, on the
-- record: a world-state refusal row, not a script error.
local refusals = #t.ledger_rows("fall_glide_refused")
fold(p, 1, 2)
pick_up(p, 1, 2)
t.throw(p, 3, 3)
t.run_seconds(3)
assert(level_rows() == falls + 2, "the blocked plane fell")
landed = t.items_at(3, 3, LOWER)
assert(#landed == 1 and landed[1] == "paper", "it drops straight under the hole")
assert(#t.items_at(5, 5, LOWER) == 0, "it did not reach the far side of the wall")
assert(#t.ledger_rows("fall_glide_refused") == refusals + 1, "the refused glide is on the record")
assert(#t.script_errors() == 0, "a refused glide is not a script error")

-- Air under a hole: a corridor with one hole, hot air painted beneath it.
local HOT_WORLD = [==[(
    name: "paper plane updraft",
    tags: ["terrestrial"],
    levels_below_ground: 1,
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

-- A hole against a wall, the whole corridor below it hot so the lift outlasts
-- one shove: the surf's shove has nowhere to go.
local WALL_WORLD = [==[(
    name: "paper plane wall",
    tags: ["terrestrial"],
    levels_below_ground: 1,
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), atmosphere: Exact(true)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [],
            painted: [(1, 1, "hot_air"), (2, 1, "hot_air"), (3, 1, "hot_air")],
        ),
        (
            rows: [
                "#####",
                "#..o#",
                "#####",
            ],
            structures: [(1, 1, "player_spawn")],
            items: [(1, 1, "paper")],
        ),
    ],
    blends: { "hot_air": (
        rows: [("n2", 20.0)], temperature_k: %.1f, amount: per_m3,
    ) },
)]==]

-- The player, with a folded plane thrown at the hole (3, 1).
local function throw_plane_over_heat(world: string, kelvin: number): number
    t.world(string.format(world, kelvin), 0, "free_build")
    local player = t.join()
    t.run_ticks(4)
    fold(player, 1, 1)
    pick_up(player, 1, 1)
    local _ = t.messages(player)
    t.throw(player, 3, 1)
    return player
end

local function count_said(player: number, phrase: string): number
    local said = 0
    for _, message in ipairs(t.messages(player)) do
        if string.find(message, phrase, 1, true) ~= nil then
            said += 1
        end
    end
    return said
end

-- 5. Warm air below, well short of ignition: the plane stays aloft and is
-- shoved on past the hole along its heading.
local flier = throw_plane_over_heat(HOT_WORLD, 480)
t.run_seconds(3)
assert(count_said(flier, "rides the rising warm air") == 1, "it rode the air once")
assert(level_rows() == 0, "the plane never fell")
assert(#t.ledger_rows("fall_stayed") >= 1, "it stayed aloft over the hole")
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
throw_plane_over_heat(HOT_WORLD, 750)
t.run_seconds(2)
assert(level_rows() == 0, "a burning plane does not fall")
local burning = assert(t.item_at(3, 1, "paper"), "the plane burns over the hole")
assert(burning.state == "onfire", "it is alight, got " .. tostring(burning.state))
t.run_seconds(5)
assert(#t.items_at(3, 1, UPPER) == 0, "it burned away")
assert(t.count_items("paper") == 0, "no sheet is left anywhere")
assert((t.matter_totals().substances["ash"] or 0) > 0, "it left ash")

-- 7. A hole against a wall, over a whole corridor of air short of ignition:
-- the shove is spent against the wall and the plane settles back on the hole
-- it surfed while the heat still lifts. It surfs that hole once (one stay,
-- one broadcast, one shove), then falls instead of looping on the heat.
local walled = throw_plane_over_heat(WALL_WORLD, 590)
t.run_seconds(4)
assert(count_said(walled, "rides the rising warm air") == 1, "the hole was surfed once")
assert(#t.ledger_rows("fall_stayed") == 1, "it stayed aloft once")
assert(level_rows() == 1, "then it fell")
assert(#t.items_at(3, 1, UPPER) == 0, "the plane does not hover over the hole")
assert(#t.items_at(3, 1, LOWER) == 1, "it lies under the hole")
