-- Bringing back the body the map arrived holding, the surgical way.
--
-- tests/heart_life_test.luau proves the MODEL on a patient a session is
-- steering: dying stops the heart, healing the parts does not restart
-- it, a defibrillator does. This proves the other revival path, and
-- proves it on the thing a surgeon actually finds -- a cadaver out of
-- the chamber, minted by `sim/stock.rs::stand_up_stock_body`, hurt past
-- the plan's dead line by a number its own content file wrote.
--
-- The whole loop: pull the drawer, lay it out, strip it, treat the
-- wound that killed it, open the chest, take the stopped heart out, put
-- a living one in. It sits up in crit.
--
-- Order matters and is the surgeon's, not the spec's: `tend_wounds` is
-- `blocked` on cut or open skin (content/operations/tend_wounds.luau),
-- so the tending comes BEFORE the incision -- and it has to, because a
-- living heart under a body still past the `dead` line revives nothing.
-- Both lines have to be clear at once, which is the whole of "the
-- plan's other thresholds still apply".

local ARENA = [==[(
    name: "morgue theatre",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#######",
        "#.....#",
        "#.....#",
        "#Gao..#",
        "#######",
    ],
    spawns: [(1, 1)],
    items: [
        (4, 1, "scalpel"), (4, 1, "retractor"), (4, 1, "hemostat"),
        (4, 1, "circular_saw"), (4, 1, "cautery"), (4, 1, "organ_heart"),
    ],
    structures: [
        (3, 2, "optable"),
        (5, 2, "cadaver_chamber.cadaver", { "dir": "north" }),
    ],
    cables: [(1, 3, 2), (2, 3, 3), (3, 3, 1)],
)]==]

t.world(ARENA, 0)
local surgeon = t.join()
t.run_ticks(3)

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

-- The wearables panel is a row model of its own (docs/TGUI.md): one
-- `labels` row per declared equipment slot, named by the slot's LABEL.
local function slot_row(panel, label)
    for _, r in ipairs(panel.labels or {}) do
        if word(r.label) == label then return r end
    end
    return nil
end

for _ = 1, 3 do
    t.move(surgeon, "east")
    t.run_ticks(8)
end
assert(t.pos(surgeon) == 4, "beside the drawer: " .. t.pos(surgeon))

-- ---- what the chamber was holding -------------------------------------
t.click(surgeon, 5, 2, t.target_at(5, 2, "cadaver_chamber.cadaver"))
t.run_ticks(2)
local found = t.bodies_at(5, 1)
assert(#found == 1, "one body rolled out on the slab")
local cid = found[1].id

-- The mint itself latched it. 200 brute crosses the plan's `dead` line
-- inside `stand_up_stock_body`, the plan's hook stops the heart on that
-- crossing, and the corpse therefore arrives with a heart at its
-- maximum -- a stopped one -- and not merely with a lot of bruises.
assert(found[1].animate == false, "it arrived dead")
assert(found[1].label == "Dead", "in the pack's own word")
assert(found[1].parts.chest.organs.heart, "with its heart still in its chest")

-- ---- onto the table, and out of the jumpsuit --------------------------
local optable = t.target_at(3, 2, "optable")
-- Laying a body out TAKES TIME now (`lay_body_secs`,
-- content/tuning.luau), so this waits the do_after out.
t.drag(surgeon, 5, 1, cid, 3, 2, optable)
t.run_ticks(2 * 20 + 2)
local function corpse()
    return t.bodies_at(3, 2)[1]
end
assert(corpse() ~= nil and corpse().posture == "lying", "laid out on the table")

t.drag(surgeon, 3, 2, cid, 4, 1, t.body_id(surgeon))
t.run_ticks(2)
assert(slot_row(t.ui(surgeon), "Uniform") ~= nil, "the wardrobe opened")
t.ui_act(surgeon, "toggle", '{"field":"strip","option":"uniform"}')
t.run_ticks(90)
assert(corpse().worn.uniform == nil, "the jumpsuit is off")

local function hold(id)
    if t.hands(surgeon).held ~= nil then t.drop(surgeon); t.tick() end
    t.click(surgeon, 4, 1, t.target_at(4, 1, id))
    t.run_ticks(2)
    assert(t.hands(surgeon).held == id, "the surgeon holds the " .. id)
end
local function step(tool, ticks, done, why)
    hold(tool)
    t.click(surgeon, 3, 2, cid)
    t.run_ticks(ticks)
    assert(done(), why)
end
local function states()
    return corpse().parts.chest.states
end

assert(t.set_zone(surgeon, "chest"), "aiming at the chest")

-- ---- 1. treat the wound that killed it --------------------------------
-- One application of first aid is all it takes: the body is sitting
-- exactly ON the dead line (200 brute of a 200-brute chest), and
-- `tend_wounds` takes five off it. Under the old model that alone stood
-- the corpse up. Now it clears one line of two.
step("hemostat", 130, function() return corpse().parts.chest.brute < 200 end, "tended")
local past = {}
for _, id in ipairs(corpse().thresholds) do past[id] = true end
assert(not past.dead, "the dead line is clear")
assert(past.undone, "and the stopped heart is not")
assert(corpse().animate == false, "STILL DEAD, and that is the point of the whole model")

-- ---- 2. open the chest ------------------------------------------------
step("scalpel", 40, function() return states().skin_cut end, "incised")
step("retractor", 55, function() return states().skin_open end, "retracted")
step("hemostat", 55, function() return states().vessels_clamped end, "clamped")
step("circular_saw", 115, function() return states().bone_sawed end, "sawed")
step("scalpel", 55, function() return states().organs_cut end, "organs cut")

-- ---- 3. take the stopped heart out ------------------------------------
hold("hemostat")
t.click(surgeon, 3, 2, cid)
t.run_ticks(2)
local win = t.ui(surgeon)
assert(win ~= nil and win.presentation == "choices", "several organs to reach")
-- Matched on the OPERATION and not on the label, because a stopped
-- heart is a damaged organ and `repair_heart` is on this window too --
-- which is a third way back, and not the one this spec is about. The
-- option is `<operation>|<socket>`.
local pick
for _, toggle in ipairs(win.toggles) do
    if toggle.option:find("remove_organ", 1, true) == 1
        and word(toggle.label):find("heart", 1, true) then
        pick = toggle.option
    end
end
assert(pick, "the window offers to take the heart out: " .. tostring(pick))
t.ui_act(surgeon, "toggle", string.format('{"field":"operation","option":"%s"}', pick))
t.run_ticks(60)
assert(corpse().parts.chest.organs.heart == false, "the socket is empty")
assert(corpse().animate == false, "no heart at all is no more alive than a stopped one")

-- ---- 4. ...and put a living one in ------------------------------------
hold("organ_heart")
t.click(surgeon, 3, 2, cid)
t.run_ticks(60)
assert(corpse().parts.chest.organs.heart ~= false, "a heart is seated")
assert(corpse().animate == true,
    "AND THE CADAVER IS ALIVE: a living heart clears the viability line, " ..
    "and the dead line was cleared before the first cut")
assert(corpse().label == "Critical",
    "in crit, not on its feet -- it is still carrying the wound that killed it: " ..
    tostring(corpse().label))

-- ---- 5. close up ------------------------------------------------------
step("cautery", 55, function()
    return not states().skin_open and not states().skin_cut
end, "closed")
assert(corpse().animate == true, "and it is still alive at the end of it")

print("cadaver revival: tended, opened, and brought back with a new heart")
