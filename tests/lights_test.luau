-- Lights break, and somebody has to go and fix them.
--
-- The fixture owns every one of these answers (tfs/content/fixtures/
-- light.luau): a swing shatters the tube, a replacer fits a new one
-- until its charges run out, a loose tube out of the box does the same
-- job by hand. What the engine owns is the consequence — a dead socket
-- emits nothing, and a viewer is never even TOLD about a source that
-- stopped burning.
t.world([==[(
    name: "corridor",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'l': (turf: Floor, fixture: Some(Light)),
    },
    rows: [
        "#####",
        "#.l.#",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "toolbox"), (1, 2, "light_replacer"), (2, 2, "box_lights")],
)]==], 7)

local p = t.join()
t.tick()

-- The lamp overhead burns, and the client has been told so.
local light = t.light_at(2, 1)
assert(light ~= nil and light.status == "ok" and light.emits, "a fresh fitting burns")
local light_target = light.target
assert(light_target ~= nil, "the fixture exposes the id a sprite click names")
local function told_about_the_lamp()
    for _, src in ipairs(t.light_sources(p)) do
        if src[1] == 2 and src[2] == 1 then
            return true
        end
    end
    return false
end
assert(told_about_the_lamp(), "the burning lamp is disclosed to the viewer")

-- One swing with something heavy.
t.click(p, 1, 1, t.target_at(1, 1, "toolbox"))
t.tick()
assert(t.hands(p).held == "toolbox", "picked the toolbox up")
t.click(p, 2, 1, light_target)
t.tick()
assert(t.light_at(2, 1).status == "broken", "the tube shattered")
assert(not t.light_at(2, 1).emits, "and throws no light")
assert(t.light_at(2, 1).lit, "though the branch still feeds the fitting")
assert(not told_about_the_lamp(),
    "a dead fixture is a source the viewer is no longer told about")
assert(table.concat(t.sounds(p), "\n"):find("glass_break", 1, true), "glass")

-- Vandalism is on the record, both ends of it, attributed to the file
-- that decided it and the player who swung.
local changed = t.ledger_rows("LightChanged")
assert(#changed == 1, "one socket change so far, got " .. #changed)
assert(changed[1].from == "ok" and changed[1].to == "broken", "from ok to broken")
assert(changed[1].actor.kind == "script"
    and changed[1].actor.file == "fixtures/light.luau",
    "the fixture's own file decided it")

-- The janitor's device, one click.
t.swap_hands(p)
t.click(p, 1, 2, t.target_at(1, 2, "light_replacer"))
t.tick()
assert(t.hands(p).held == "light_replacer", "picked the replacer up")
t.click(p, 2, 1, light_target)
t.tick()
assert(t.light_at(2, 1).status == "ok", "the replacer fitted a new tube")
assert(t.light_at(2, 1).emits, "and the corridor is lit again")
assert(told_about_the_lamp(), "the viewer is told about the source again")
assert(#t.ledger_rows("ItemConsumed") == 1, "one charge spent, on the record")

-- tg's replacer holds ten. Break and fix until it is dry.
for _ = 1, 9 do
    t.swap_hands(p) -- toolbox
    t.click(p, 2, 1, light_target)
    t.tick()
    assert(t.light_at(2, 1).status == "broken", "smashed again")
    t.swap_hands(p) -- replacer
    t.click(p, 2, 1, light_target)
    t.tick()
    assert(t.light_at(2, 1).status == "ok", "and fixed again")
end
assert(#t.ledger_rows("ItemConsumed") == 10, "ten charges is the whole device")

t.swap_hands(p)
t.click(p, 2, 1, light_target)
t.tick()
assert(t.light_at(2, 1).status == "broken", "one last smash")
t.swap_hands(p)
t.click(p, 2, 1, light_target)
t.tick()
assert(t.light_at(2, 1).status == "broken", "an empty replacer fixes nothing")
assert(#t.ledger_rows("ItemConsumed") == 10, "and spends nothing")
local msgs = table.concat(t.messages(p), "\n")
assert(msgs:find("replacer is empty", 1, true), "and says so: " .. msgs)
assert(t.hands(p).held == "light_replacer", "an empty device is still a device")

-- The box: twenty-one fittings' worth, and a tube does the job by hand.
t.drop(p)
t.swap_hands(p)
t.drop(p)
t.tick()
t.click(p, 2, 2, t.target_at(2, 2, "box_lights"))
t.tick()
assert(t.hands(p).held == "box_lights", "picked the box up")
t.take_held(p, 0)
t.tick()
local hands = t.hands(p)
assert(hands[1] == "light_tube" or hands[2] == "light_tube",
    "the box dispenses a tube")
t.swap_hands(p)
assert(t.hands(p).held == "light_tube", "a tube in the working hand")

t.click(p, 2, 1, light_target)
t.tick()
assert(t.light_at(2, 1).status == "ok", "the tube goes in by hand")
assert(t.light_at(2, 1).emits, "and the corridor is lit")
assert(t.hands(p).held == nil, "the tube was used up putting it in")
assert(#t.ledger_rows("ItemConsumed") == 11, "the tube is on the record too")
