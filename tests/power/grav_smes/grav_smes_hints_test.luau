local bench = require("@helpers/grav_bench")

-- What the gravity battery's tooltips say at every step, and that they
-- follow the parts around them. `grav_smes_assembly_test` drives the clicks;
-- this reads only what a player sees before clicking.

bench.world(
    '(5, 6, "player_spawn"), ' .. bench.part_rows({ s = { state = "displaced" } }),
    '(4, 6, "metal"), (4, 6, "glass"), (6, 6, "cable_coil"), (6, 6, "welder"), '
        .. '(5, 7, "pipe"), (5, 7, "crowbar"), (5, 7, "wrench")'
)
local p = t.join()
t.tick()

local NEAR = { { 4, 6 }, { 6, 6 }, { 5, 7 }, { 5, 6 }, { 4, 7 }, { 6, 7 } }

local function text_of(label: any): string
    return label.text or label.key
end

-- The row a target shows under `label`, or nil.
local function row(x: number, y: number, id: string, label: string): any
    local target = assert(t.target_at(p, x, y, id), `a {id} target at {x}, {y}`)
    for _, hint in ipairs(t.action_hints(p, target)) do
        if text_of(hint.label) == label then
            return hint
        end
    end
    return nil
end

local function reason_of(hint: any): string
    return if hint.detail ~= nil then text_of(hint.detail) else "none"
end

local INCOMPLETE = "lunatic/tfs:lib.grav_smes.weld_incomplete"
local WELD = "lunatic/tfs:ui.affordance.weld_assembly"
local WRONG_SECTION = "lunatic/tfs:lib.grav_smes.glass_wrong_cell"

-- A part with one loose beside it offers the weld and says it cannot yet.
bench.hold(p, "welder", NEAR)
t.use_self(p)
t.run_ticks(2)
local RING = "grav_supermagnet_ring"
local waiting = assert(row(6, 5, RING, WELD), "the ring offers the weld")
assert(not waiting.available, "with a part loose it cannot run")
assert(reason_of(waiting) == INCOMPLETE, "and says why: " .. reason_of(waiting))

-- The loose part is bolted down: the ring's tooltip follows it.
bench.hold(p, "wrench", NEAR)
t.click(p, 5, 5, t.target_at(p, 5, 5, "grav_emitter"))
t.run_seconds(2)
bench.hold(p, "welder", NEAR)
local ready = assert(row(6, 5, RING, WELD), "the ring still offers the weld")
assert(ready.available, "the whole assembly is ready: " .. reason_of(ready))

-- Unlit, the same row says so.
t.use_self(p)
t.run_ticks(2)
local unlit = assert(row(5, 5, "grav_emitter", WELD), "the row survives the flame")
assert(not unlit.available, "an unlit torch cannot weld")
assert(reason_of(unlit) == "lunatic/tfs:lib.grav_smes.torch_unlit", reason_of(unlit))
t.use_self(p)
t.run_ticks(2)

t.click(p, 5, 5, t.target_at(p, 5, 5, "grav_emitter"))
t.run_seconds(7)
assert(assert(t.structure_at(5, 4)).state == "welded", "the weld made a machine")

-- Welded: the next step is offered unheld, the dead end says why.
local cut = assert(row(5, 5, "grav_smes", "Cut Welds"), "the torch's row is there")
assert(not cut.available, "welds do not cut")
assert(reason_of(cut) == "lunatic/tfs:lib.grav_smes.welded_fast", reason_of(cut))
local clamps = assert(row(5, 5, "grav_smes", "Fit Clamps"), "the next step suggests itself")
assert(clamps.group == "suggestion", "unheld, it is a suggestion: " .. clamps.group)
assert(clamps.implement ~= nil and clamps.implement.sprite ~= "", "it pictures the metal")

local function step(held: string, seconds: number, want: string)
    bench.hold(p, held, NEAR)
    t.click(p, 5, 5, t.target_at(p, 5, 5, "grav_smes"))
    t.run_seconds(seconds)
    -- A standing machine wears a status glyph: `standby_<status>`.
    local state = tostring(assert(t.structure_at(5, 4)).state)
    assert(string.find(state, "^" .. want) ~= nil, held .. " made it " .. state)
end

step("metal", 5, "clamped")
assert(row(5, 5, "grav_smes", "Wire") ~= nil, "clamped offers the wiring")
assert(row(5, 5, "grav_smes", "Remove Clamps") ~= nil, "and the way back")
step("cable_coil", 7, "wired")
assert(row(5, 5, "grav_smes", "Run Pipes") ~= nil, "wired offers the pipes")
assert(row(5, 5, "grav_smes", "Cut Wiring") ~= nil, "and the way back")
assert(
    row(5, 5, "grav_smes", "lunatic/tfs:ui.affordance.view_interface") ~= nil,
    "the click that opens its panel is named"
)
step("pipe", 7, "piped")
assert(row(5, 5, "grav_smes", "Fit Casing") ~= nil, "piped offers the casing")
assert(row(5, 5, "grav_smes", "Unbolt Pipes") ~= nil, "and the way back")
step("metal", 9, "cased")

-- Cased: the screen fits one cell of nine, and every other cell says so.
bench.hold(p, "glass", NEAR)
for y = 3, 5 do
    for x = 4, 6 do
        -- The center is the empty well, so a pointer finds nothing there.
        if x ~= bench.CENTER_X or y ~= bench.CENTER_Y then
            local screen =
                assert(row(x, y, "grav_smes", "Install Screen"), "every cell has the row")
            if x == 5 and y == 5 then
                assert(screen.available, "the south cell takes the glass: " .. reason_of(screen))
            else
                assert(not screen.available, "another cell does not")
                assert(reason_of(screen) == WRONG_SECTION, reason_of(screen))
            end
        end
    end
end
assert(row(5, 5, "grav_smes", "Pry Off Casing") ~= nil, "cased offers the way back")

step("glass", 4, "standby")
