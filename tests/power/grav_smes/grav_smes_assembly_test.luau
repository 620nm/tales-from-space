local bench = require("@helpers/grav_bench")

-- Building the gravity battery: eight anchored parts facing the center,
-- one torch weld, clamps, a coil of cable, nine pipes, the casing, and a
-- glass panel on the south cell. The pack chose every count (the machine
-- has no tg twin); the steps work from any cell of the machine.

-- Every part is placed anchored and facing in; the player stands south of the
-- machine, in reach of its bottom row only.
bench.world(
    '(5, 6, "player_spawn"), ' .. bench.part_rows(),
    '(4, 6, "metal"), (4, 6, "glass"), (6, 6, "cable_coil"), (6, 6, "welder"), '
        .. '(5, 7, "pipe"), (5, 7, "crowbar")'
)
local p = t.join()
t.tick()

local NEAR = { { 4, 6 }, { 6, 6 }, { 5, 7 }, { 5, 6 }, { 4, 7 }, { 6, 7 } }

-- One assembly step: hold the thing, click a cell, wait, expect the state.
local function step(held: string, x: number, y: number, seconds: number, want: string)
    bench.hold(p, held, NEAR)
    t.click(p, x, y, t.target_at(p, x, y, "grav_smes"))
    t.run_seconds(seconds)
    local body = assert(t.structure_at(5, 4), "the machine stands")
    local state = tostring(body.state)
    assert(body.id == "grav_smes" and body.state == want, held .. " made it " .. state)
end

-- Eight loose parts stand around an empty center.
bench.assert_standing({ "n", "e", "s", "w", "nw", "ne", "se", "sw" })
assert(t.structure_at(5, 4) == nil, "the center is bare floor")

-- A lit torch on an anchored emitter fuses the lot.
bench.hold(p, "welder", NEAR)
t.use_self(p)
t.run_ticks(2)
t.click(p, 5, 5, t.target_at(p, 5, 5, "grav_emitter"))
t.run_seconds(7)
local welded = assert(t.structure_at(5, 4), "the weld left a machine on the center")
assert(
    welded.id == "grav_smes" and welded.state == "welded",
    "one welded machine: " .. tostring(welded.state)
)
for dy = -1, 1 do
    for dx = -1, 1 do
        local cell = t.structure_at(5 + dx, 4 + dy)
        assert(cell ~= nil and cell.id == "grav_smes", "every cell of the 3x3 is the machine")
    end
end

-- Welded joints do not come apart under the torch.
local _ = t.messages(p)
t.click(p, 5, 5, t.target_at(p, 5, 5, "grav_smes"))
t.run_ticks(4)
assert(
    bench.told(p, "The welds hold the machine as one piece; there is no cutting it apart."),
    "the torch says why not"
)
assert(assert(t.structure_at(5, 4)).state == "welded", "and the machine is still welded")

-- Metal clamps, a coil of cable, nine pipes, metal casing: each from a
-- different cell of the bottom row.
step("metal", 4, 5, 5, "clamped")
step("cable_coil", 6, 5, 7, "wired")
assert(t.count_items("cable_coil") == 0, "thirty lengths of cable went into the machine")
-- `count_items` counts stacks, not lengths, so the pipe is weighed by its
-- stack count before and after (dropped back where the player stands).
local pipes = t.stack_count(assert(t.target_at(p, 5, 7, "pipe"), "the pipe stack lies south"))
step("pipe", 5, 5, 7, "piped")
t.drop(p)
t.run_ticks(2)
local left = t.target_at(p, 5, 6, "pipe")
local remaining = if left ~= nil then t.stack_count(left) else 0
assert(remaining == pipes - 9, ("nine pipes went in: %d of %d left"):format(remaining, pipes))
step("metal", 4, 5, 9, "cased")

-- Glass fits the south cell alone. Sheets are weighed as the pipes are:
-- by stack count, dropped where the player stands.
local function sheets_at(x: number, y: number): number
    local stack = t.target_at(p, x, y, "glass")
    return if stack ~= nil then t.stack_count(stack) else 0
end
local function drop_held()
    if t.hands(p).held ~= nil then
        t.drop(p)
        t.run_ticks(2)
    end
end
local glass = sheets_at(4, 6)
_ = t.messages(p)
bench.hold(p, "glass", NEAR)
t.click(p, 4, 5, t.target_at(p, 4, 5, "grav_smes"))
t.run_seconds(4)
assert(
    bench.told(p, "Wrong Section"),
    "a corner cell refuses the glass"
)
assert(assert(t.structure_at(5, 4)).state == "cased", "the machine is still cased")
drop_held()
assert(sheets_at(5, 6) == glass, "no glass was spent")
bench.hold(p, "glass", NEAR)
t.click(p, 5, 5, t.target_at(p, 5, 5, "grav_smes"))
t.run_seconds(4)
local finished = assert(t.structure_at(5, 4))
-- A standing machine wears a status glyph, so its state is `standby` or a
-- `standby_<status>` dress.
assert(
    string.find(tostring(finished.state), "^standby") ~= nil,
    "the south cell takes the glass: " .. tostring(finished.state)
)
assert(
    finished.sprite == "grav_smes_standby_1_1",
    "the standing machine wears its picture: " .. tostring(finished.sprite)
)
drop_held()
assert(sheets_at(5, 6) == glass - 1, "one sheet of glass was spent")

-- The panel comes back out with a crowbar and hands the sheet back.
bench.hold(p, "crowbar", NEAR)
t.click(p, 5, 5, t.target_at(p, 5, 5, "grav_smes"))
t.run_seconds(4)
assert(assert(t.structure_at(5, 4)).state == "cased", "the crowbar pries the glass out")
local back = sheets_at(5, 6) + sheets_at(5, 4)
assert(back == glass, ("and the sheet is back: %d of %d"):format(back, glass))
