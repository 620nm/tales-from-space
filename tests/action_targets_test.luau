-- The viewer's action rows describe the same exact targets that clicks use.
t.world([==[(
    name: "action targets",
    legend: { '.': (turf: Plating), 'f': (turf: Floor), '#': (turf: Wall) },
    rows: ["######", "#....#", "#....#", "#..f.#", "######"],
    spawns: [(2, 2), (3, 2)],
    items: [(2, 2, "wrench"), (2, 2, "wirecutters"), (2, 2, "toolbox"),
        (2, 2, "laptop"), (2, 2, "floppy_disk"), (2, 2, "beaker.water"), (1, 2, "beaker"),
        (3, 1, "pipe"), (3, 3, "pipe"), (2, 3, "metal")],
    structures: [(2, 1, "access_point")],
    pipes: [(3, 2, 31), (3, 3, 8)],
    cables: [(3, 2, 7)],
)]==], 0)
local actor, patient = t.join(), t.join()
t.run_ticks(3)

local function take(id)
    if t.hands(actor).held ~= nil then
        t.drop(actor)
        t.run_ticks(2)
    end
    t.click(actor, 2, 2, assert(t.target_at(2, 2, id)))
    t.run_ticks(2)
    assert(t.hands(actor).held == id, "picked up " .. id)
end

local function entity_action(entity, id)
    for _, view in ipairs(t.actions(actor)) do
        if view.target.Entity == entity then
            for _, action in ipairs(view.actions) do
                if action.id == id then return action end
            end
        end
    end
    return nil
end

local metal = assert(t.target_at(2, 3, "metal"))
local loose = assert(t.target_at(3, 1, "pipe"))
local covered = assert(t.target_at(3, 3, "pipe"))
take("wrench")
assert(entity_action(loose, "fasten_pipe"), "a wrench can fasten the exact exposed loose pipe")
assert(entity_action(covered, "fasten_pipe") == nil, "finished flooring hides fastening")
assert(entity_action(metal, "fasten_pipe") == nil, "a wrench is not compatible with arbitrary items")
local pipe_layers = {}
for _, view in ipairs(t.actions(actor)) do
    local subfloor = view.target.Subfloor
    if subfloor then
        assert(subfloor.pos.x ~= 3 or subfloor.pos.y ~= 3, "covered infrastructure has no action target")
        if subfloor.kind == "Pipe" and subfloor.pos.x == 3 and subfloor.pos.y == 2 then
            for _, action in ipairs(view.actions) do
                if action.id == "unfasten_pipe" then pipe_layers[subfloor.layer] = true end
            end
        end
    end
end
for _, layer in ipairs({ 1, 2, 4, 8, 16 }) do
    assert(pipe_layers[layer], "every visible pipe layer has its own wrench action: " .. layer)
end

take("wirecutters")
for _, kind in ipairs({ "Cable", "Pipe" }) do
    local offered = false
    for _, action in ipairs(t.action_hints(actor,
        { Subfloor = { pos = { x = 3, y = 2 }, kind = kind, layer = 2 } })) do
        if action.id == "cut_cable" then offered = true end
    end
    assert(offered == (kind == "Cable"), "cutters match cable and never pipe")
end

take("beaker.water")
assert(entity_action(assert(t.target_at(1, 2, "beaker")), "pour"), "a vessel can pour into a vessel")
assert(entity_action(metal, "pour") == nil, "a vessel does not pour into arbitrary items")
assert(entity_action(t.body_id(patient), "pour") == nil, "a body's bloodstream is not a pouring target")
local at_feet = t.action_hints(actor, { Turf = { x = 2, y = 2 } })
assert(#at_feet > 0 and at_feet[1].id == "drink", "the shared vessel's own-tile gesture is drinking")

take("toolbox")
local body = t.body_id(patient)
assert(entity_action(body, "strike"), "the toolbox advertises its scripted body strike")
assert(entity_action(metal, "strike") == nil, "the body strike is absent on a loose item")
local health = t.health(patient).brute
t.run_ticks(3)
assert(t.health(patient).brute == health, "projecting the strike never executes damage")
t.click(actor, 3, 2, body)
t.run_ticks(2)
assert(t.health(patient).brute > health, "the advertised strike executes through a player click")

take("laptop")
local network = assert(t.target_at(2, 1))
assert(entity_action(network, "connect") == nil, "a closed laptop does not offer typing")
t.use_self(actor)
t.run_ticks(2)
t.use_self(actor)
t.run_ticks(2)
t.use_self(actor)
t.run_ticks(2)
local desktop = assert(t.ui(actor), "the laptop screen opens")
local data = if desktop.script then desktop.script.data else desktop.data
assert(data.powered, "the laptop is powered before projecting its network action")
local network_action = entity_action(network, "connect")
t.sounds(actor)
t.click(actor, 2, 1, network)
t.run_ticks(2)
local typing = false
for _, sound in ipairs(t.sounds(actor)) do
    if string.sub(sound, 1, 16) == "keyboard_clicks_" then typing = true end
end
assert(network_action, "powering on offers typing on a networked target")
assert(typing, "the advertised network action types on the receiver")
assert(entity_action(metal, "connect") == nil, "typing is absent on a nonnetworked item")
t.drop(actor)
t.run_ticks(2)
local laptop = assert(t.target_at(2, 2, "laptop"))
assert(entity_action(laptop, "engine.action.take"), "empty hands get the ordinary pickup action")
take("floppy_disk")
local insertion = assert(entity_action(laptop, "insert_disk"), "the matching media selects the receiver action")
assert(insertion.label.key == "lunatic/tfs:ui.affordance.insert_disk", "the receiver supplies its catalog label")
assert(entity_action(laptop, "insert_id") == nil, "a cartridge is not an ID card")
t.click(actor, 2, 2, laptop)
t.run_ticks(2)
assert(t.hands(actor).held == nil, "the advertised receiver action inserts the cartridge")
