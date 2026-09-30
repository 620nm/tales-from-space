local clock = require("@helpers/clock")
local ui_controls = require("@helpers/ui_controls")

local function script_data(panel: ui_controls.Record): ui_controls.Record
    local script = panel.script
    return ui_controls.record(if script then ui_controls.record(script).data else panel.data)
end

local function control(player: number, channel: string, suffix: string)
    local address = assert(t.ui_document(player, channel), "document address is available")
    return "doc/" .. address.document .. "/" .. address.generation .. suffix
end

-- The power fails between pages of a three-page batch. The pages already made
-- stay made and charged; the next page finds the copier dark, so the job
-- stops, unlocks its slot and leaves a failure on the panel.
t.world(
    [==[(
    name: "copy room",
    legend: { '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])), 'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)), 'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), 'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)) },
    rows: ["#######", "#Gao..#", "#.....#", "#.....#", "#######"],
    structures: [(4, 2, "player_spawn"), (0, 0, "apc"), (1, 0, "apc"), (2, 0, "apc"), (3, 0, "apc"), (4, 0, "apc"), (5, 0, "apc"), (6, 0, "apc"), (0, 1, "apc"), (1, 1, "apc"), (2, 1, "apc"), (4, 1, "apc"), (5, 1, "apc"), (6, 1, "apc"), (0, 2, "apc"), (1, 2, "apc"), (2, 2, "apc"), (3, 2, "apc"), (4, 2, "apc"), (5, 2, "apc"), (6, 2, "apc"), (0, 3, "apc"), (1, 3, "apc"), (2, 3, "apc"), (3, 3, "apc"), (4, 3, "apc"), (5, 3, "apc"), (6, 3, "apc"), (0, 4, "apc"), (1, 4, "apc"), (2, 4, "apc"), (3, 4, "apc"), (4, 4, "apc"), (5, 4, "apc"), (6, 4, "apc")],
    machines: [(4, 1, "photocopier")],
    items: [(4, 2, "paper"), (3, 2, "four_color_pen")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
)]==],
    0
)

local p = t.join()
t.run_ticks(3)

-- Write the source through the real writer, then dock it.
local paper = assert(t.target_at(p, 4, 2, "paper"), "a sheet is available")
t.click(p, 4, 2, paper)
t.run_ticks(5)
t.ui_close(p, "writing")
local pen = assert(t.target_at(p, 3, 2, "four_color_pen"), "a writer is available")
t.click(p, 3, 2, pen)
t.run_ticks(2)
if t.hands(p).held ~= "four_color_pen" then
    t.swap_hands(p)
    t.run_ticks(1)
end
assert(t.hands(p).held == "four_color_pen", "the writer is held")
t.use_self(p)
t.run_ticks(1)
t.use_on_other(p)
t.run_ticks(2)
t.ui_edit(p, control(p, "writing", "/paper/draft"), "copy this")
t.ui_press(p, control(p, "writing", "/paper/commit"))
t.run_ticks(2)
t.drop(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
t.ui_close(p, "writing")
assert(t.hands(p).held == "paper", "the written source sheet is active")
local copier = assert(t.target_at(p, 4, 1, "photocopier"), "the copier is present")
t.drop(p)
t.run_ticks(1)
t.click(p, 4, 1, copier)
t.run_ticks(3)
local floor_paper = assert(t.target_at(p, 4, 2, "paper"), "the written sheet is on the floor")
t.click(p, 4, 2, floor_paper)
t.run_ticks(1)
t.click(p, 4, 1, copier)
t.run_ticks(2)
assert(t.hands(p).held == nil, "the source sheet is docked")

local count_control = control(p, "copier", "/count")
t.ui_edit(p, count_control, "3")
t.ui_press(p, count_control, "change")
t.run_ticks(1)
assert(script_data(ui_controls.state(p, "copier")).count == 3, "three pages are chosen")
local papers_before = t.count_items("paper")

t.ui_press(p, control(p, "copier", "/copy"))
t.run_ticks(clock.deadline_ticks(4.0))
assert(t.count_items("paper") == papers_before + 1, "page one lands at its 4 s deadline")

t.outage()
t.run_ticks(clock.deadline_ticks(8.0))
assert(t.count_items("paper") == papers_before + 1, "the dark copier makes no more pages")
local state = script_data(ui_controls.state(p, "copier"))
assert(state.busy ~= true, "the stopped job is no longer busy")
assert(state.failed == true, "the panel says the batch failed")
assert(state.reason == "offline", "and why: " .. tostring(state.reason))
assert(state.paper == 29 and state.toner == 29, "only the finished page was charged")
assert(#t.ledger_rows("script_error") == 0, "the stop is an outcome, not a script error")
