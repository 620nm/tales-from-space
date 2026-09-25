-- The medical HUD: what a crewman wearing health scanner glasses sees
-- hanging over somebody else, and what everyone else never sees.
--
-- The display is `content/part_tree.luau`'s `medhud`, tg's HEALTH_HUD
-- and STATUS_HUD pair; the glasses are `content/items/gear/health_hud.luau`.
-- Levels are 0-based step indices into RoundHealth's bands
-- (tgstation code/game/data_huds.dm:107-153): 0 is `health100`, 1 is
-- `health93.75`, and 19 is the `else` row, `health-100`.

local WARD = [==[(
    name: "ward",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#######",
        "#.....#",
        "#######",
    ],
    structures: [(1, 1, "player_spawn"), (3, 1, "player_spawn"), (5, 1, "player_spawn")],
    items: [(2, 1, "health_hud")],
)]==]

t.world(WARD, 0)
local medic = t.join()
local patient = t.join()
local bystander = t.join()
t.run_ticks(3)

local mx, my = t.pos(medic)
assert(math.abs(mx - 2) <= 1 and my == 1, ("the medic stands beside the glasses, got (%d, %d)"):format(mx, my))

-- The one medhud row a viewer was sent for the patient, or nil.
local function medhud(viewer: number)
    local rows = t.seen(viewer, patient).status
    assert(#rows <= 1, "one display on a human")
    local row = rows[1]
    if row then
        assert(row.display == "medhud", "the only display is the medical HUD: " .. row.display)
    end
    return row
end

local function icons(row): string
    return table.concat(row.icons, ",")
end

-- ---- nobody sees it bare-eyed ------------------------------------------
assert(t.seen(medic, patient).kind == "player", "the medic can see the patient")
assert(medhud(medic) == nil, "without the glasses the medic is sent nothing")
assert(medhud(bystander) == nil, "and neither is anyone else")

-- ---- on go the glasses -------------------------------------------------
t.click(medic, 2, 1, t.target_at(medic, 2, 1, "health_hud"))
t.run_ticks(2)
assert(t.hands(medic).held == "health_hud", "picked up")
t.equip(medic)
t.run_ticks(2)
assert(t.worn(medic).eyes == "health_hud", "the glasses go over the eyes")

local row = assert(medhud(medic), "wearing them, the medic reads the patient")
assert(row.level == 0, "full health is health100: " .. row.level)
assert(icons(row) == "healthy", "and hudhealthy: " .. icons(row))
assert(medhud(bystander) == nil, "the bystander still sees nothing")
assert(#t.seen(patient, patient).status == 0, "nor does the patient, of themselves")

-- ---- RoundHealth's edges -----------------------------------------------
-- Each band's lower edge belongs to it: DM's switch takes the first
-- matching range, so `1 to 9.375` claims 1 before `-50 to 1` can. Health
-- is kept to DAMAGE_PRECISION, 0.1 (carbon.dm:429, combat.dm:307), so
-- 90.625 itself is never read: 90.7 is over that edge and 90.6 under it.
local function at(brute: number, level: number, why: string)
    t.set_health(patient, { brute = brute })
    t.run_ticks(1)
    local r = assert(medhud(medic), why .. ": still sent")
    assert(r.level == level, ("%s: brute %g reads level %d, want %d"):format(why, brute, r.level, level))
    return r
end

at(9.3, 1, "90.7 is health93.75")
at(9.4, 2, "90.6 is health87.5")
at(50, 8, "half is health50")
at(99, 15, "one point left is health6.25")
at(99.1, 16, "under one point is health0")
at(150, 16, "-50 is still health0")
at(150.1, 17, "under -50 is health-50")
at(199, 18, "-99 is health-85")
row = at(199.1, 19, "under -99 is health-100 before the `dead` line")
assert(icons(row) == "healthy", "alive past crit is still hudhealthy: " .. icons(row))
assert(medhud(bystander) == nil, "however hurt, the bystander is sent nothing")

-- ---- dead reads health-100 whatever health says ------------------------
-- IS_DEAD_OR_FAKING short-circuits RoundHealth (data_huds.dm:108-109),
-- and med_hud_set_status lights huddead (:181-183).
t.set_health(patient, { brute = 400 })
t.run_ticks(1)
assert(not assert(t.body(patient)).animate, "four hundred brute is past `dead`")
row = assert(medhud(medic), "the dead are read too")
assert(row.level == 19, "dead is health-100: " .. row.level)
-- Crossing `dead` stops the heart (content/bodies/human.luau), so
-- `undone` latches beside it: both light the huddead picture.
assert(icons(row) == "dead,undone", "and huddead: " .. icons(row))

-- Healed to full, `dead` clears but the stopped heart keeps `undone`:
-- the body is as dead as it was, and the HUD still says so.
t.set_health(patient, { brute = 0, burn = 0, oxy = 0, tox = 0 })
t.run_ticks(1)
local tended = assert(t.body(patient))
assert(tended.health == tended.max_health, "every point of damage is healed: " .. tended.health)
assert(not tended.animate, "and a tended corpse stays a corpse")
row = assert(medhud(medic), "a tended corpse is still read")
assert(row.level == 19, "health-100 whatever a full bar would read: " .. row.level)
assert(icons(row) == "undone", "and huddead for the stopped heart: " .. icons(row))

-- ---- off come the glasses ----------------------------------------------
t.unequip(medic, "eyes")
t.run_ticks(2)
assert(t.worn(medic).eyes == nil, "the glasses come off")
assert(medhud(medic) == nil, "and the reading is taken away with them")

print("medhud: the glasses reveal RoundHealth's bands, dead forces health-100")
