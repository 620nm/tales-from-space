-- Typing is a discrete held-tool interaction with a networked target.
t.world([==[(
    name: "laptop network bench",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#######", "#.....#", "#.....#", "#.....#", "#######"],
    spawns: [(2, 2)],
    items: [(2, 2, "laptop"), (2, 2, "screwdriver")],
    structures: [(3, 2, "access_point"), (5, 2, "access_point")],
)]==], 0)
local p = t.join()
t.run_ticks(3)
local laptop = t.target_at(2, 2, "laptop")
local near = t.target_at(3, 2)
local far = t.target_at(5, 2)
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
assert(t.ui(p) and t.ui(p).script and t.ui(p).script.data.powered, "self-use powered the held laptop")
t.sounds(p)
t.click(p, 3, 2, near)
t.run_ticks(2)
assert(#keyboards() == 1, "an open powered laptop types once on a networked device")

t.click(p, 5, 2, far)
t.run_ticks(2)
assert(#keyboards() == 0, "a distant networked device does not accept the held tool")
t.click(p, 2, 2, t.target_at(2, 2, "screwdriver"))
t.run_ticks(2)
assert(#keyboards() == 0, "a nonnetworked item cannot trigger typing")

t.ui_act(p, "power")
t.run_ticks(2)
assert(t.ui(p) and t.ui(p).data and not t.ui(p).data.powered,
    "desktop power switches off the held laptop")
t.sounds(p)
t.click(p, 3, 2, near)
t.run_ticks(2)
assert(#keyboards() == 0, "an open powered-off laptop cannot type")
t.ui_act(p, "power")
t.run_ticks(2)
t.use_item(p, laptop, "alt")
t.run_ticks(2)
t.sounds(p)
t.click(p, 3, 2, near)
t.run_ticks(2)
assert(#keyboards() == 0, "closing an active laptop disables typing")
