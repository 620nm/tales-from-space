local ui_controls = require("@helpers/ui_controls")

-- A network endpoint alone does not provide a laptop programming interface.
t.world(
    [==[(
    name: "laptop network bench",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#######", "#.....#", "#.....#", "#.....#", "#######"],
    items: [(2, 2, "laptop"), (2, 2, "screwdriver")],
    structures: [(2, 2, "player_spawn"), (3, 2, "airlock_button"), (5, 2, "airlock_button")],
)]==],
    0
)
local p = t.join()
t.run_ticks(3)
local laptop = t.target_at(p, 2, 2, "laptop")
local near = t.target_at(p, 3, 2)
local far = t.target_at(p, 5, 2)
t.click(p, 2, 2, laptop)
t.run_ticks(2)
assert(t.hands(p).held == "laptop", "the laptop is the active tool")

local function keyboards()
    local clips = {}
    for _, asset in ipairs(t.sounds(p)) do
        if string.sub(asset, 1, 16) == "keyboard_clicks_" then
            local index = tonumber(string.sub(asset, 17))
            assert(index and index >= 1 and index <= 7, "typing uses the seven imported clips")
            table.insert(clips, asset)
        end
    end
    return clips
end

t.click(p, 3, 2, near)
t.run_ticks(2)
assert(#keyboards() == 0, "a closed laptop cannot type")
t.use_self(p)
t.run_ticks(2)
-- Powered desktops compose their script view with the native file workspace.
local function desktop(): ui_controls.Record?
    local state = t.ui(p)
    if state == nil then
        return nil
    end
    local fields = ui_controls.record(state)
    local data = ui_controls.record(
        if fields.script then ui_controls.record(fields.script).data else fields.data
    )
    return if data ~= nil and data.kind == "desktop" then data else nil
end
assert(desktop() == nil, "the first self-use only raises the lid")
t.use_self(p)
t.run_ticks(2)
t.use_self(p)
t.run_ticks(2)
assert(
    assert(desktop()).powered,
    "lid, power and screen are three separate steps on the held laptop"
)
t.sounds(p)
t.click(p, 3, 2, near)
t.run_ticks(2)
assert(#keyboards() == 0, "a network endpoint has no dummy typing interaction")
assert(t.ui(p, "programming") == nil, "a target without a programming interface opens no workspace")

t.click(p, 5, 2, far)
t.run_ticks(2)
assert(#keyboards() == 0, "a distant networked device does not accept the held tool")
t.click(p, 2, 2, t.target_at(p, 2, 2, "screwdriver"))
t.run_ticks(2)
assert(#keyboards() == 0, "a nonnetworked item cannot trigger typing")

t.ui_close(p, "programming")
t.run_ticks(2)
ui_controls.press(p, "/power")
t.run_ticks(2)
assert(
    not ui_controls.record(ui_controls.state(p).data).powered,
    "desktop power switches off the held laptop"
)
t.sounds(p)
t.click(p, 3, 2, near)
t.run_ticks(2)
assert(#keyboards() == 0, "an open powered-off laptop cannot type")
ui_controls.press(p, "/power")
t.run_ticks(2)
t.ui_close(p)
t.run_ticks(2)
t.sounds(p)
t.click(p, 3, 2, near)
t.run_ticks(2)
assert(#keyboards() == 0, "closing an active laptop disables typing")
