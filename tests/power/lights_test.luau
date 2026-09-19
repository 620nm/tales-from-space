-- Lights break, and somebody has to go and fix them.
--
-- The fixture owns every one of these answers (tfs/content/fixtures/
-- light.luau): a swing shatters the tube, a replacer fits a new one
-- until its charges run out, a loose tube out of the box does the same
-- job by hand. What the engine owns is the consequence — a dead socket
-- emits nothing, and a viewer is never even TOLD about a source that
-- stopped burning.
-- The corridor's own fitting is a warm tungsten bulb somebody left in
-- it (tg LIGHT_COLOR_TUNGSTEN, code/__DEFINES/colors.dm:312) — so what
-- the janitor's tube does to the colour of the room is visible here.
local TUNGSTEN = "#FFD6AA"
local TUBE = "#F3FFFA"

t.world(
    [==[(
    name: "corridor",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'l': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Light), light: Some("#FFD6AA")),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Apc)),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#alo#",
        "#..g#",
        "#####",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "toolbox"), (1, 2, "light_replacer"), (2, 2, "box_lights")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    7
)

local p = t.join()
t.tick()

-- The lamp overhead burns, and the client has been told so.
local light = t.light_at(2, 1)
assert(light ~= nil and light.status == "ok" and light.emits, "a fresh fitting burns")
local light_target = t.target_at(p, 2, 1)
assert(light_target ~= nil, "the fixture exposes the id a sprite click names")
assert(light.color == TUNGSTEN, "in the colour the map put in it, got " .. light.color)
local function lamp_colour_on_the_wire(): string?
    for _, src in ipairs(t.light_sources(p)) do
        if src[1] == 2 and src[2] == 1 then
            local color = src[4]
            assert(type(color) == "string", "the source color is a string")
            return color
        end
    end
    return nil
end
local function told_about_the_lamp()
    return lamp_colour_on_the_wire() ~= nil
end
assert(told_about_the_lamp(), "the burning lamp is disclosed to the viewer")
assert(
    lamp_colour_on_the_wire() == TUNGSTEN,
    "and disclosed in its own colour, so the client lights the corridor warm"
)
-- The tube drawn on the wall: the fitting's glow layer and the colour
-- the viewer is told to paint it, or nil while it wears none.
local function tube_colour_on_the_wall(): string?
    for _, layer in ipairs(t.seen(p, assert(light_target)).layers) do
        if string.find(layer.sprite, "light_glow", 1, true) == 1 then
            return layer.color or "untinted"
        end
    end
    return nil
end
assert(
    tube_colour_on_the_wall() == TUNGSTEN,
    "the tube on the wall burns the colour of its pool, got " .. tostring(tube_colour_on_the_wall())
)
-- Under it the fitting still wears its whole lit picture, so whatever
-- reads that alone (an examine icon, a replay) shows it lit.
local function fitting_picture(): string
    return t.seen(p, assert(light_target)).layers[1].sprite
end
assert(string.find(fitting_picture(), "light_on", 1, true) == 1, "lit, got " .. fitting_picture())

-- One swing with something heavy.
t.click(p, 1, 1, t.target_at(p, 1, 1, "toolbox"))
t.tick()
assert(t.hands(p).held == "toolbox", "picked the toolbox up")
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, light_target)))
t.tick()
assert(assert(t.light_at(2, 1)).status == "broken", "the tube shattered")
assert(not assert(t.light_at(2, 1)).emits, "and throws no light")
assert(assert(t.light_at(2, 1)).lit, "though the branch still feeds the fitting")
assert(not told_about_the_lamp(), "a dead fixture is a source the viewer is no longer told about")
assert(tube_colour_on_the_wall() == nil, "and shattered glass does not glow")
assert(table.concat(t.sounds(p), "\n"):find("glass_break", 1, true), "glass")

-- Vandalism is on the record, both ends of it, attributed to the file
-- that decided it and the player who swung.
local changed = t.ledger_rows("LightChanged")
assert(#changed == 1, "one socket change so far, got " .. #changed)
assert(changed[1].from == "ok" and changed[1].to == "broken", "from ok to broken")
local actor = changed[1].actor
assert(
    actor.kind == "script" and actor.file == "fixtures/light.luau",
    "the fixture's own file decided it"
)

-- The janitor's device, one click.
t.swap_hands(p)
t.click(p, 1, 2, t.target_at(p, 1, 2, "light_replacer"))
t.tick()
assert(t.hands(p).held == "light_replacer", "picked the replacer up")
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, light_target)))
t.tick()
assert(assert(t.light_at(2, 1)).status == "ok", "the replacer fitted a new tube")
assert(assert(t.light_at(2, 1)).emits, "and the corridor is lit again")
assert(told_about_the_lamp(), "the viewer is told about the source again")
assert(#t.ledger_rows("ItemConsumed") == 1, "one charge spent, on the record")
-- A tube is a tube: the warm fitting comes back fluorescent, and the
-- viewer is told the corridor changed colour.
assert(
    assert(t.light_at(2, 1)).color == TUBE,
    "a fitted tube burns what a tube burns, got " .. assert(t.light_at(2, 1)).color
)
assert(lamp_colour_on_the_wire() == TUBE, "and the wire carries the new colour")
assert(tube_colour_on_the_wall() == TUBE, "and the tube on the wall is the new glass")
local repaint = t.ledger_rows("LightChanged")
assert(
    repaint[#repaint].color == TUBE,
    "the record says what went into the socket, not just that something did"
)

-- tg's replacer holds ten. Break and fix until it is dry.
for _ = 1, 9 do
    t.swap_hands(p) -- toolbox
    t.click(p, 2, 1, assert(t.target_at(p, 2, 1, light_target)))
    t.tick()
    assert(assert(t.light_at(2, 1)).status == "broken", "smashed again")
    t.swap_hands(p) -- replacer
    t.click(p, 2, 1, assert(t.target_at(p, 2, 1, light_target)))
    t.tick()
    assert(assert(t.light_at(2, 1)).status == "ok", "and fixed again")
end
assert(#t.ledger_rows("ItemConsumed") == 10, "ten charges is the whole device")

t.swap_hands(p)
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, light_target)))
t.tick()
assert(assert(t.light_at(2, 1)).status == "broken", "one last smash")
t.swap_hands(p)
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, light_target)))
t.tick()
assert(assert(t.light_at(2, 1)).status == "broken", "an empty replacer fixes nothing")
assert(#t.ledger_rows("ItemConsumed") == 10, "and spends nothing")
local msgs = table.concat(t.messages(p), "\n")
assert(msgs:find("replacer is empty", 1, true), "and says so: " .. msgs)
assert(t.hands(p).held == "light_replacer", "an empty device is still a device")

-- The box: twenty-one fittings' worth, and a tube does the job by hand.
t.drop(p)
t.swap_hands(p)
t.drop(p)
t.tick()
t.click(p, 2, 2, t.target_at(p, 2, 2, "box_lights"))
t.tick()
assert(t.hands(p).held == "box_lights", "picked the box up")
t.take_held(p, 0)
t.tick()
local hands = t.hands(p)
assert(hands[1] == "light_tube" or hands[2] == "light_tube", "the box dispenses a tube")
t.swap_hands(p)
assert(t.hands(p).held == "light_tube", "a tube in the working hand")

t.click(p, 2, 1, assert(t.target_at(p, 2, 1, light_target)))
t.tick()
assert(assert(t.light_at(2, 1)).status == "ok", "the tube goes in by hand")
assert(assert(t.light_at(2, 1)).emits, "and the corridor is lit")
assert(t.hands(p).held == nil, "the tube was used up putting it in")
assert(#t.ledger_rows("ItemConsumed") == 11, "the tube is on the record too")
