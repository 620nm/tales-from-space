-- A tool locker as a player meets it: collision while shut, a seeded
-- tg loadout appearing on open, ordinary items accepted while open,
-- concealment restored on close, and both transactions on the record.
t.world([==[(
    name: "locker bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "####",
        "#..#",
        "####",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "headset")],
    structures: [(2, 1, "locker.tools")],
)]==], 7)

local function has(rows, wanted)
    for _, row in ipairs(rows) do
        if row == wanted then return true end
    end
    return false
end

local p = t.join()
t.tick()
local locker = t.target_at(2, 1, "locker.tools")
assert(locker ~= nil, "the variant is one targetable structure")
local shut = t.structure_at(2, 1)
assert(shut.state == "closed" and shut.sprite == "locker_tools",
    "it starts closed in its variant art")
assert(#t.items_at(2, 1) == 0, "the random interior is not streamed through a shut door")

-- Dense while closed: with the wall pinning this otherwise draggable
-- structure, walking east cannot put the player inside it.
t.move(p, "east")
t.run_ticks(3)
local x, y = t.pos(p)
assert(x == 1 and y == 1, "the shut locker blocks movement")

_ = t.sounds(p)
t.click(p, 2, 1, locker)
t.tick()
local open = t.structure_at(2, 1)
assert(open.state == "open" and open.sprite == "locker_tools_open",
    "opening selects the authored state and art")
assert(has(t.sounds(p), "locker_open"), "the pack's opening clip is heard")

local rolled = t.items_at(2, 1)
local allowed = {
    screwdriver = true, wrench = true, welder = true, crowbar = true,
    wirecutters = true, toolbelt = true, cable_coil = true, multitool = true,
}
assert(#rolled <= 10, "at most one item per roll appeared: " .. #rolled)
for _, item in ipairs(rolled) do
    assert(allowed[item], "the locker rolled only its declared loadout: " .. tostring(item))
end

-- Open means passable. Walk through, come back, then put one known item
-- onto its turf; the close transaction is what takes that item inside.
t.move(p, "east")
t.run_ticks(3)
x, y = t.pos(p)
assert(x == 2 and y == 1, "the open locker no longer blocks movement")
t.move(p, "west")
t.run_ticks(3)
t.click(p, 1, 1, t.target_at(1, 1, "headset"))
t.tick()
assert(t.hands(p).held == "headset", "the known item is in hand")
t.click(p, 2, 1, locker)
t.tick()
assert(t.hands(p).held == nil and has(t.items_at(2, 1), "headset"),
    "an open locker accepts the held item onto its turf")

_ = t.sounds(p)
t.click(p, 2, 1, locker)
t.tick()
assert(t.structure_at(2, 1).state == "closed", "it closes again")
assert(#t.items_at(2, 1) == 0, "everything that fit is concealed again")
assert(has(t.sounds(p), "locker_close"), "the pack's closing clip is heard")

t.click(p, 2, 1, locker)
t.tick()
local reopened = t.items_at(2, 1)
assert(#reopened == #rolled + 1 and has(reopened, "headset"),
    "reopening preserves the rolled interior and the item put in")
assert(#t.ledger_rows("container_opened") == 2, "both opens are attributed")
assert(#t.ledger_rows("container_closed") == 1, "the close is attributed")
