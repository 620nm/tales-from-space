-- The two Commons displays at their player seam: both arrive on their
-- wall brackets, the status board starts blank, its two bounded fields
-- become uppercase ScriptVars, bad text changes nothing, and Clear
-- returns it to the blank state. Clock digit composition, status line
-- layout, and the native one-second refresh cadence are engine tests;
-- no per-tick Luau runs here.

t.world([==[(
    name: "display bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "######",
    ],
    spawns: [(4, 1)],
    structures: [
        (2, 1, "digital_clock"),
        (3, 1, "status_display"),
    ],
    mounts: [
        (2, 1, North),
        (3, 1, North),
    ],
)]==], 0)

local p = t.join()
t.tick()

local clock = t.structure_at(2, 1)
assert(clock and clock.id == "digital_clock", "the map stands up the shift clock")
assert(clock.sprite == "digital_clock_n", "the clock faces its north wall")
assert(#clock.overlays == 0, "clock digits are client-derived, not scripted overlays")

local status = t.structure_at(3, 1)
assert(status and status.id == "status_display", "the map stands up the message board")
assert(status.sprite == "status_display_n", "the board faces its north wall")
assert(#status.overlays == 0, "status text is client-derived, not scripted overlays")
assert(status.vars["lunatic/tfs:display_line1"] == nil
    and status.vars["lunatic/tfs:display_line2"] == nil,
    "a new status display is blank")

t.click(p, 3, 1, t.target_at(3, 1, "status_display"))
t.tick()
local panel = t.ui(p)
assert(panel and panel.document == "modules" and panel.presentation == "modules",
    "clicking the board opens its declared controls")
assert(#panel.labels == 2, "the panel offers one input for each line")
assert(panel.labels[1].row == "input" and panel.labels[1].action == "line1"
    and panel.labels[1].max_length == 40, "the top line is bounded to forty characters")
assert(panel.labels[2].row == "input" and panel.labels[2].action == "line2"
    and panel.labels[2].max_length == 40, "the bottom line is bounded to forty characters")

t.ui_act(p, "action", '{"action":"line1","value":"shift #3: go! @ 00:30"}')
t.tick()
status = t.structure_at(3, 1)
assert(status.vars["lunatic/tfs:display_line1"] == "SHIFT #3: GO! @ 00:30",
    "the top line is stored in the uppercase form the face draws")
assert(status.vars["lunatic/tfs:display_line2"] == nil,
    "programming one line leaves the other blank")

t.ui_act(p, "action", '{"action":"line2","value":"- eta -"}')
t.tick()
status = t.structure_at(3, 1)
assert(status.vars["lunatic/tfs:display_line2"] == "- ETA -",
    "the lower line preserves the delimiters used for short-header emphasis")

local forty = "0123456789012345678901234567890123456789"
t.ui_act(p, "action", '{"action":"line1","value":"' .. forty .. '"}')
t.tick()
assert(t.structure_at(3, 1).vars["lunatic/tfs:display_line1"] == forty,
    "forty characters fit exactly")

local forty_one = forty .. "0"
t.ui_act(p, "action", '{"action":"line1","value":"' .. forty_one .. '"}')
t.tick()
assert(t.structure_at(3, 1).vars["lunatic/tfs:display_line1"] == forty,
    "the native input boundary refuses a forty-first character")

-- The grammar starts with tg's command-console `reject_bad_text`
-- boundary (`code/game/machinery/computer/communications.dm:386-392`):
-- slashes, backslashes, angle brackets, non-ASCII text, and all-whitespace
-- strings cannot reach the bitmap face. These controls are single-line,
-- so they intentionally reject tab/newline and every other control too.
local bad_inputs = {
    [==[{"action":"line1","value":"NO/ENTRY"}]==],
    [==[{"action":"line1","value":"NO\\ENTRY"}]==],
    [==[{"action":"line1","value":"NO<ENTRY"}]==],
    [==[{"action":"line1","value":"NO>ENTRY"}]==],
    [==[{"action":"line1","value":"NO\nENTRY"}]==],
    [==[{"action":"line1","value":"CAFÉ"}]==],
    [==[{"action":"line1","value":"   "}]==],
}
for _, payload in ipairs(bad_inputs) do
    t.ui_act(p, "action", payload)
    t.tick()
    assert(t.structure_at(3, 1).vars["lunatic/tfs:display_line1"] == forty,
        "unrenderable status text changes nothing: " .. payload)
end

t.ui_act(p, "toggle", '{"field":"action","option":"clear"}')
t.tick()
status = t.structure_at(3, 1)
assert(status.vars["lunatic/tfs:display_line1"] == nil
    and status.vars["lunatic/tfs:display_line2"] == nil,
    "Clear restores the status display's blank state")
