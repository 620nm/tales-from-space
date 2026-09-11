-- A press that cannot act still tells the presser why, exactly once.
local UNANSWERED = "The button clicks, but nothing answers."
local UNPROGRAMMED = "The controller beeps: no program is loaded."
local HAND_FULL = "Your hand is full; press it with an empty hand."
local FAULT = "The controller has stopped the airlock cycle."
local LID = "The laptop's lid is closed. Open it first."
local OFF = "The laptop is off. Turn it on first."

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

-- A laptop held against the host names the one step it is missing:
-- the lid while shut, the power while dark. Running, it connects.
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "laptop")))
t.run_ticks(2)
assert(t.hands(p).held == "laptop", "the closed laptop is in hand")
local function offers(id)
    for _, action in ipairs(t.action_hints(p, { Entity = t.target_at(p, 4, 1, "access_point") })) do
        if action.id == id then return action end
    end
    return nil
end
assert(offers("connect_not_ready") and not offers("connect"), "the hint names the laptop as not ready")
assert(offers("connect_not_ready").implement.sprite == "laptop_on",
    "and pictures the laptop as it must be: open and powered")
assert(not offers("needs_laptop"), "a held laptop is not told to fetch one")
local function refused_with(line, why)
    local _ = t.messages(p)
    t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "access_point")))
    t.run_ticks(2)
    local heard = t.messages(p)
    assert(once(heard, line), why .. ", got: " .. table.concat(heard, " | "))
    assert(t.ui(p, "programming") == nil and t.ui(p) == nil, "and nothing opens: " .. why)
    return heard
end
-- One step of the lid-power ladder, taken on the floor and picked back up.
local function step()
    t.drop(p)
    t.run_ticks(2)
    local lap = assert(t.target_at(p, 3, 1, "laptop"))
    t.use_item(p, lap, "secondary")
    t.run_ticks(2)
    t.click(p, 3, 1, assert(t.target_at(p, 3, 1, lap)))
    t.run_ticks(2)
    assert(t.hands(p).held == "laptop", "the laptop is back in hand")
end
lines = refused_with(LID, "a closed laptop names its lid once")
assert(not said(lines, OFF), "and not its power")
step()
lines = refused_with(OFF, "an open, dark laptop names its power once")
assert(not said(lines, LID), "and not its lid")
step()
assert(offers("connect") and not offers("connect_not_ready"), "a running laptop offers the real connection")
assert(offers("connect").implement.sprite == "laptop_on", "pictured as the running laptop in hand")

-- The box ships locked: the running laptop opens on its lock screen, and
-- the lock row's own press lets it straight into the workspace.
local _ = t.messages(p)
local ui = laptop.connect(p, 4, 1, "access_point")
lines = t.messages(p)
assert(ui and ui.contact_locked, "a locked box shows the laptop its lock screen")
assert(not said(lines, LID) and not said(lines, OFF), "a running laptop is not refused: " .. table.concat(lines, " | "))
laptop.unlock(p)
t.run_ticks(2)
ui = laptop.ui(p)
assert(not ui.contact_locked and ui.stores, "the unlocked box opens the programming workspace")
