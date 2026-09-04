-- The operating computer (docs/SURGERY.md, docs/TGUI.md): a console that
-- reads the bodies on the four tiles it faces, says what each open part
-- is holding and what that admits next, and lets the surgeon standing at
-- it change what their next cut aims for.
--
-- tg's console watches one operating table and one patient
-- (code/game/machinery/computer/operating_computer.dm:96-101, :162-247).
-- This one has no table to watch, so what it draws is the neighbourhood:
-- two patients laid orthogonally beside it are on the panel, one laid on
-- a corner is not.

local ARENA = [==[(
    name: "theatre",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
    },
    rows: [
        "#######",
        "#o...a#",
        "#.....#",
        "#.....#",
        "#.....#",
        "#######",
    ],
    spawns: [(2, 2), (3, 2), (2, 3), (4, 2)],
    items: [(2, 2, "scalpel")],
    machines: [(3, 3, "operating_computer")],
    cables: [
        (1, 1, 1), (2, 1, 1), (3, 1, 1), (4, 1, 1), (5, 1, 1),
    ],
)]==]

local CX, CY = 3, 3

local function row(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r
        end
    end
    return nil
end

local function rows_named(ui, label)
    local n = 0
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            n = n + 1
        end
    end
    return n
end

-- Every heading the document draws, once each, minus the surgeon's own
-- aim block. One per body the panel is willing to talk about.
local function body_sections(ui)
    local seen, order = {}, {}
    local function note(r)
        if r.section and r.section ~= "target" and not seen[r.section] then
            seen[r.section] = true
            order[#order + 1] = r.section
        end
    end
    for _, r in ipairs(ui.readouts) do note(r) end
    for _, r in ipairs(ui.toggles) do note(r) end
    return order
end

local function has(haystack, needle)
    return (haystack or ""):find(needle, 1, true) ~= nil
end

t.world(ARENA, 0)
local surgeon = t.join()
local near = t.join()   -- (3, 2): the tile north of the console
local other = t.join()  -- (2, 3): the tile west of it
local corner = t.join() -- (4, 2): a corner, and therefore nobody
t.run_ticks(3)

-- ---- three patients on the deck ---------------------------------------
for _, who in ipairs({ near, other, corner }) do
    t.rest(who, true)
end
t.run_ticks(2)
assert(t.body(near).posture == "lying", "the patients are down")

-- ---- one of them gets opened up ---------------------------------------
-- Bare the chest first: a jumpsuit is what "obstructed" means
-- (content/items/uniform_*.luau `covers`).
t.unequip(near, "uniform")
t.run_ticks(2)
t.click(surgeon, 2, 2, t.target_at(2, 2, "scalpel"))
t.run_ticks(2)
assert(t.hands(surgeon).held ~= nil, "the scalpel is in hand")
t.click(surgeon, 3, 2, t.body_id(near))
t.run_ticks(100)
assert(t.parts(near).chest.states.skin_cut == true, "the chest is open")

-- ---- the console, read by a surgeon standing beside it ----------------
t.drop(surgeon) -- an empty hand is what opens a machine's window
t.run_ticks(2)
t.click(surgeon, CX, CY, t.target_at(CX, CY))
t.run_ticks(2)

local ui = t.ui(surgeon)
assert(ui, "the console opened a window")
assert(ui.document == "modules", "a clean-room module document")

-- TWO bodies, not three and not four: the two on orthogonal tiles. The
-- one on the corner is as absent as somebody in the next room, and the
-- surgeon -- standing on a corner themselves -- is not a patient either.
local blocks = body_sections(ui)
assert(#blocks == 2, "two patients, one block each: got " .. #blocks)

-- ---- what the open part is holding ------------------------------------
-- TWO `chest` rows, one per patient, and for two different reasons: one
-- chest is open, and the other is what the surgeon is AIMED at, which
-- the panel draws whether or not anything is holding it (the plan's
-- `default_zone` is the chest and nobody has pressed a target key).
-- Without that second rule the console has nothing to say about a body
-- nobody has cut yet, which is no use to a surgeon deciding where to
-- start (tests/surgery_cadaver_test.luau).
assert(rows_named(ui, "chest") == 2, "the open chest and the aimed one")
local opened, untouched = nil, nil
for _, r in ipairs(ui.readouts) do
    if r.label == "chest" then
        if has(r.value, "skin_cut") then opened = r else untouched = r end
    end
end
assert(opened ~= nil, "one chest names the states it is holding")
assert(has(opened.value, "vessels_unclamped"), "both of them: " .. opened.value)
assert(has(opened.value, "/s"), "with what it is bleeding: " .. opened.value)
assert(untouched ~= nil and untouched.value == "\u{2014}",
    "and the other is holding nothing: " .. tostring(untouched and untouched.value))
local blood = row(ui, "blood")
assert(blood ~= nil, "and how much blood is left to lose")
-- IN LITRES, and bleeding in millilitres a second. tg counts blood in
-- bare units -- a number with no unit on it, which is only a scale if
-- you already know it -- and a surgeon deciding whether to clamp is
-- deciding about a volume.
assert(blood.value:match("^%d+%.%d%d L") ~= nil,
    "the blood row is in litres: " .. blood.value)
-- Nothing is wrong with the head and nobody is aiming at it, so the head
-- is not on the panel.
assert(row(ui, "head") == nil, "a part with nothing wrong with it is not a row")

-- ---- and what it admits next ------------------------------------------
-- tg's `show_as_next_step` beside `get_recommended_tool`
-- (_operation.dm:596-607, :818-820): the operation's own name, and the
-- word for the first implement its file declares.
local retract = row(ui, "retract the skin")
assert(retract ~= nil, "an incision may be held open")
assert(retract.value == "retractor", "with a retractor: " .. tostring(retract.value))
local mend = row(ui, "mend the incision")
assert(mend ~= nil, "...or closed again")
assert(mend.value == "cautery", "with a cautery: " .. tostring(mend.value))
-- Not this one: clamping wants the skin RETRACTED, and it is only cut.
assert(row(ui, "clamp the bleeders") == nil, "the state does not admit it yet")
-- And not this one either, for a different reason: cauterising your own
-- wound is `self_only`, and this chest belongs to somebody else. A
-- catalog that offered it would be offering a click the click chain then
-- refuses (content/operations/close_incision_self.luau).
assert(row(ui, "cauterise your own wound") == nil, "a self-only step is nobody else's")

-- ---- the aim ----------------------------------------------------------
-- One button per part slot of the SURGEON's own plan, and pressing one
-- is what their next click means.
local aimed = nil
for _, toggle in ipairs(ui.toggles) do
    if toggle.field == "zone" and toggle.option == "head" then
        aimed = toggle
    end
end
assert(aimed ~= nil, "the panel offers the head as a target")
assert(aimed.label == "head", "labelled out of the plan: " .. tostring(aimed.label))

t.ui_act(surgeon, "toggle", '{"field":"zone","option":"head"}')
t.run_ticks(2)

-- The same scalpel, the same patient, a different part.
t.click(surgeon, 2, 2, t.target_at(2, 2, "scalpel"))
t.run_ticks(2)
t.click(surgeon, 3, 2, t.body_id(near))
t.run_ticks(100)
assert(t.parts(near).head.states.skin_cut == true, "the head is where the cut landed")

print("operating computer: four tiles, the state that is there, the next step, and the aim")
