-- Item capabilities follow possession and invoke the same behavior as self-use.
t.world([==[(
    name: "action controls",
    legend: { '#': (turf: Wall), '.': (turf: Floor) },
    rows: ["#######", "#.....#", "#######"],
    structures: [(1, 1, "player_spawn"), (5, 1, "player_spawn")],
    items: [(1, 1, "welder"), (1, 1, "rpd"),
        (1, 1, "breath_mask"), (1, 1, "oxygen_tank")],
)]==], 7)

local p, q = t.join(), t.join()
t.tick()
assert(t.ui(p, "actions") == nil, "empty hands have no item actions")

local function pickup(id)
    t.click(p, 1, 1, t.target_at(p, 1, 1, id))
    t.tick()
end
local function action()
    local view = t.ui(p, "actions")
    assert(view and view.document == "script", "a held item grants its own action document")
    assert(view.data.presentation == "actions", "the pack selects the action surface")
    assert(view.actions[1].id == "activate", "the disclosed action is an explicit capability")
    return view.data.groups[1].actions[1]
end
local function activate()
    local group = assert(t.ui(p, "actions")).data.groups[1]
    local base = "actions/" .. group.id .. "/buttons"
    if not ui_controls.find(p, base .. "/search") then
        ui_controls.press(p, base .. "/more")
    end
    local address = assert(t.ui_document(p, "actions"))
    ui_controls.press(p, "action/" .. address.document .. "/" .. address.generation .. "/" .. group.actions[1].id)
    t.tick()
end

pickup("welder")
assert(action().state == "off", "an unlit welder starts off")
assert(t.ui(q, "actions") == nil, "other viewers receive no held-item controls")
local _, pushes = t.last_ui(p, "actions")
t.run_ticks(5)
local _, unchanged = t.last_ui(p, "actions")
assert(pushes == unchanged, "unchanged inventory does not poll a Luau action provider")
activate()
assert(action().state == "on", "the HUD action lights the real welder")
t.use_self(p)
t.tick()
assert(action().state == "off", "ordinary self-use refreshes the same HUD state")
t.drop(p)
t.tick()
assert(t.ui(p, "actions") == nil, "dropping revokes controls even beside the player")
pickup("welder")
assert(action().state == "off", "taking it again grants a fresh control")
t.drop(p)
t.tick()

pickup("rpd")
assert(action().state == "ready", "the construction device exposes its real interface action")
activate()
assert(t.ui(p) ~= nil, "the action opens the normal device document")
assert(action().state == "ready", "device and action documents coexist")
t.ui_close(p)
t.drop(p)
t.tick()
assert(t.ui(p, "actions") == nil, "dropping also revokes interface actions")

if not t.worn(p).mask then
    pickup("breath_mask")
    t.equip(p)
    t.tick()
end
pickup("oxygen_tank")
assert(t.hands(p).held == "oxygen_tank", "the supply is the active self-use item")
assert(action().state == "off", "the supply starts disconnected")
activate()
assert(action().state == "on", "the HUD reports the actual native supply connection")
t.use_self(p)
t.tick()
assert(action().state == "off", "native self-use disconnects the same supply")
t.drop(p)
t.tick()
assert(t.ui(p, "actions") == nil, "the supply action goes away with the tank")
