-- A press that cannot act still tells the presser why, and never twice.
local UNANSWERED = "The button clicks, but nothing answers."
local UNPROGRAMMED = "The access point beeps: no program is loaded."
local HAND_FULL = "Your hand is full; press it with an empty hand."
local FAULT = "The controller has stopped the airlock cycle."

local function said(lines, text)
    for _, line in ipairs(lines) do
        if line:find(text, 1, true) then return true end
    end
    return false
end
local function press(p, x, y)
    t.click(p, x, y, (assert(t.target_at(p, x, y, "airlock_button"), "the button is targetable")))
end

-- A button joined to nothing clicks and says nobody answered.
t.world([==[(
    name: "lone button",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: ["######", "#....#", "######"],
    spawns: [(3, 1)],
    structures: [(2, 1, "airlock_button")],
    mounts: [(2, 1, North)],
    items: [(4, 1, "cola"), (4, 1, "screwdriver")],
)]==], 0)
local p = t.join()
t.run_ticks(2)
local _ = t.messages(p)
press(p, 2, 1)
t.run_ticks(10)
local lines = t.messages(p)
assert(said(lines, UNANSWERED), "an orphan button answers the presser, got: " .. table.concat(lines, " | "))
assert(table.concat(t.sounds(p), ","):find("click", 1, true), "the press still clicks")

-- A held non-tool item is refused with the reason, and only that.
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "cola")))
t.run_ticks(2)
assert(t.hands(p).held == "cola", "the can is in hand")
local _ = t.messages(p)
press(p, 2, 1)
t.run_ticks(10)
lines = t.messages(p)
assert(said(lines, HAND_FULL) and not said(lines, UNANSWERED),
    "a full hand is told to empty it, got: " .. table.concat(lines, " | "))

-- The screwdriver still takes the button off the wall, without the refusal.
t.drop(p)
t.run_ticks(2)
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "screwdriver")))
t.run_ticks(2)
assert(t.hands(p).held == "screwdriver", "the screwdriver is in hand")
local _ = t.messages(p)
press(p, 2, 1)
t.run_ticks(45)
lines = t.messages(p)
assert(t.structure_at(2, 1) == nil and t.count_items("airlock_button_fitting") == 1,
    "the mounted button comes back as its fitting")
assert(not said(lines, HAND_FULL), "a resolved tool use is not refused: " .. table.concat(lines, " | "))

-- A powered, linked access point with no program says so instead of faulting.
t.world([==[(
    name: "unprogrammed host",
    legend: {
        '.': (turf: Plating), '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'A': (turf: Plating, fixture: Some(Apc)),
        'o': (turf: Plating, fixture: Some(Outlet)),
    },
    rows: ["#######", "#.....#", "#GA.o##", "#######"],
    spawns: [(3, 1)],
    structures: [
        (4, 1, "access_point", { "network_1": "network_card" }),
        (2, 1, "airlock_button"),
        (5, 1, "airlock"),
    ],
    mounts: [(4, 1, North), (2, 1, North)],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1), (4, 2, 1),
        (2, 1, 1), (3, 1, 1), (4, 1, 1), (5, 1, 1)],
    links: [(4, 1, 2, 1), (4, 1, 5, 1)],
)]==], 0)
p = t.join()
t.run_ticks(20)
local before = t.door_at(5, 1)
for round = 1, 2 do
    local _ = t.messages(p)
    press(p, 2, 1)
    t.run_ticks(20)
    lines = t.messages(p)
    assert(said(lines, UNPROGRAMMED) and not said(lines, FAULT) and not said(lines, UNANSWERED),
        "press " .. round .. " hears the empty socket once, got: " .. table.concat(lines, " | "))
end
local after = t.door_at(5, 1)
assert(after.open == before.open and after.bolted == before.bolted, "the door is left alone")
