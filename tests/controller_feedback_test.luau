-- A press that cannot act still tells the presser why, exactly once.
local UNANSWERED = "The button clicks, but nothing answers."
local UNPROGRAMMED = "The controller beeps: no program is loaded."
local HAND_FULL = "Your hand is full; press it with an empty hand."
local FAULT = "The controller has stopped the airlock cycle."
local NOT_READY = "Open the laptop and turn it on first."
local LOCKED = "The connection is refused: its lock is shut. Unlock it at its panel first."

local function count(lines, text)
    local n = 0
    for _, line in ipairs(lines) do
        if line:find(text, 1, true) then n += 1 end
    end
    return n
end
local function said(lines, text) return count(lines, text) > 0 end
local function once(lines, text) return count(lines, text) == 1 end
-- Ledgered script-var writes whose key contains `fragment`.
local function rows_like(fragment)
    local n = 0
    for _, row in ipairs(t.ledger_rows("var_set")) do
        if tostring(row.key):find(fragment, 1, true) then n += 1 end
    end
    return n
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
local numbered, queued = rows_like("button_sequence"), rows_like("device_outbox")
press(p, 2, 1)
t.run_ticks(10)
local lines = t.messages(p)
assert(once(lines, UNANSWERED), "an orphan button answers the presser once, got: " .. table.concat(lines, " | "))
assert(rows_like("lunatic/tfs:button_sequence") == numbered + 1, "a hostless press still takes a sequence number")
assert(rows_like("device_outbox") == queued, "a hostless press queues nothing")
assert(table.concat(t.sounds(p), ","):find("click", 1, true), "the press still clicks")

-- A held non-tool item is refused with the reason, and only that.
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "cola")))
t.run_ticks(2)
assert(t.hands(p).held == "cola", "the can is in hand")
local _ = t.messages(p)
press(p, 2, 1)
t.run_ticks(10)
lines = t.messages(p)
assert(once(lines, HAND_FULL) and not said(lines, UNANSWERED),
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
    items: [(3, 1, "laptop")],
)]==], 0)
p = t.join()
t.run_ticks(20)
local before = t.door_at(5, 1)
local outbox_before = rows_like("device_outbox")
for round = 1, 2 do
    local _ = t.messages(p)
    press(p, 2, 1)
    t.run_ticks(20)
    lines = t.messages(p)
    assert(once(lines, UNPROGRAMMED) and not said(lines, FAULT) and not said(lines, UNANSWERED),
        "press " .. round .. " hears the empty socket once, got: " .. table.concat(lines, " | "))
end
local after = t.door_at(5, 1)
assert(rows_like("device_outbox") > outbox_before, "a joined button does queue its press, so the outbox check has teeth")
assert(after.open == before.open and after.bolted == before.bolted, "the door is left alone")

-- A burst batched into one packet hears the empty socket once per packet, not per press.
local _ = t.messages(p)
press(p, 2, 1)
t.run_ticks(2) -- The first packet leaves; its sender sleeps out the pacing.
for _ = 1, 5 do press(p, 2, 1) end
t.run_ticks(30)
lines = t.messages(p)
assert(count(lines, UNPROGRAMMED) == 2, "six presses in two packets hear two lines, got: " .. table.concat(lines, " | "))

-- A shut laptop held against the host says what to do; opened and on, it connects.
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "laptop")))
t.run_ticks(2)
assert(t.hands(p).held == "laptop", "the closed laptop is in hand")
local function offers(id)
    for _, action in ipairs(t.action_hints(p, { Entity = t.target_at(p, 4, 1, "access_point") })) do
        if action.id == id then return true end
    end
    return false
end
assert(offers("connect_not_ready") and not offers("connect"), "the hint names the laptop as not ready")
local _ = t.messages(p)
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "access_point")))
t.run_ticks(2)
lines = t.messages(p)
assert(once(lines, NOT_READY), "a closed laptop names the missing step once, got: " .. table.concat(lines, " | "))
assert(t.ui(p, "programming") == nil, "nothing connects through a closed laptop")
assert(t.ui(p) and t.ui(p).name == "access point", "the box still shows its own panel beside the line")
t.ui_close(p)
t.run_ticks(2)
t.drop(p)
t.run_ticks(2)
local laptop = assert(t.target_at(p, 3, 1, "laptop"))
for _ = 1, 2 do t.use_item(p, laptop, "secondary"); t.run_ticks(2) end
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, laptop)))
t.run_ticks(2)
assert(t.hands(p).held == "laptop", "the running laptop is back in hand")
assert(offers("connect") and not offers("connect_not_ready"), "a running laptop offers the real connection")

-- The box ships locked: the running laptop is refused, and says why.
local _ = t.messages(p)
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "access_point")))
t.run_ticks(2)
lines = t.messages(p)
assert(once(lines, LOCKED), "a locked box names its lock once, got: " .. table.concat(lines, " | "))
assert(t.ui(p, "programming") == nil, "nothing connects through a shut lock")

-- Unlock it at its panel with an empty hand; the same contact then opens the workspace.
t.drop(p)
t.run_ticks(2)
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "access_point")))
t.run_ticks(2)
ui_controls.toggle(p, "link_lock")
t.run_ticks(2)
t.ui_close(p)
t.run_ticks(2)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, laptop)))
t.run_ticks(2)
local _ = t.messages(p)
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "access_point")))
t.run_ticks(2)
lines = t.messages(p)
assert(t.ui(p, "programming"), "the unlocked box opens the programming workspace")
assert(not said(lines, NOT_READY) and not said(lines, LOCKED), "a connected laptop is not refused: " .. table.concat(lines, " | "))
