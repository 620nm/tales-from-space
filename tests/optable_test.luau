-- The operating table, and the drag that puts somebody on it.
--
-- tg's optable is `can_buckle` with `buckle_lying = 90`
-- (code/game/objects/structures/tables_racks.dm:898-908): drag a mob
-- onto it and the mob ends up horizontal on its tile. Here that is the
-- engine's drag seam plus one declared bit (`body_surface`), and the
-- whole point of it is the sentence at the end of this file -- a
-- surgeon who lays a patient out on the table can then operate on
-- them, because the not_lying refusal (tests/surgery_refusal_test.luau)
-- has nothing left to refuse.
--
-- Laying somebody out TAKES TIME (the engine's `lay_body_secs`, two
-- seconds by default, tg's own number for putting a mob somewhere in
-- `code/modules/recycling/disposal/bin.dm:225`), so every drag below is
-- stepped through its whole delay -- and the one in the middle is
-- walked out of, which is what the delay is for.
--
-- The table is AIMED, which is the other half: tg's buckle takes the
-- mob's dir from the thing it is seated on (`M.setDir(dir)`,
-- code/game/objects/buckling.dm:119-121), so a rank of tables shows
-- its patients the same way up whichever way the surgeon walked in.

local ARENA = [==[(
    name: "theatre",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "######", "#....#", "#....#", "######" ],
    spawns: [(1, 1), (2, 1)],
    structures: [(2, 2, "optable", { "dir": "east" })],
    items: [ (1, 1, "scalpel") ],
)]==]

t.world(ARENA, 0)
local surgeon = t.join()
local patient = t.join()
t.run_ticks(3)

-- The whole lay delay and a tick over, in ticks (20 Hz).
local LAY_TICKS = 2 * 20 + 2

local pid = t.body_id(patient)
local table_id = t.target_at(2, 2, "optable")
assert(table_id ~= nil, "the map stood one there")
assert(t.structure_at(2, 2).id == "optable", "and it is the operating table")

local function said(who, needle)
    return (" " .. table.concat(t.messages(who), " || ") .. " "):find(needle, 1, true) ~= nil
end

-- ---- out of reach: the far corner is visible and untouchable --------
-- tg checks `IsReachableBy` on BOTH ends of a drag (drag_drop.dm:41),
-- so a surgeon standing away from the patient cannot lay them out from
-- across the room even though they can see both.
t.move(surgeon, "east")
t.run_ticks(8)
t.move(surgeon, "east")
t.run_ticks(8)
t.move(surgeon, "east")
t.run_ticks(8)
local sx = t.pos(surgeon)
assert(sx >= 3, "the surgeon walked away from the patient: " .. sx)
t.drag(surgeon, 2, 1, pid, 2, 2, table_id)
t.run_ticks(LAY_TICKS)
local px, py = t.pos(patient)
assert(px == 2 and py == 1, "out of reach: nobody was moved")
assert(t.body(patient).posture == "standing", "and nobody was laid out")

-- ---- in reach: the drag lands ---------------------------------------
t.move(surgeon, "west")
t.run_ticks(8)
t.move(surgeon, "west")
t.run_ticks(8)
t.move(surgeon, "west")
t.run_ticks(8)
assert(t.pos(surgeon) == 1, "back beside the patient")

-- ---- the wait, and walking out of it --------------------------------
-- A patient who does not want to be on the table simply leaves, and the
-- engine's per-tick guard ends the attempt where they left rather than
-- at its wake tick.
t.drag(surgeon, 2, 1, pid, 2, 2, table_id)
t.run_ticks(2)
px, py = t.pos(patient)
assert(px == 2 and py == 1, "two ticks in, nothing has happened yet")
assert(t.body(patient).posture == "standing", "nobody is lying down yet")
assert(said(surgeon, "start laying"), "but the surgeon was told it started")
t.move(patient, "east")
t.run_ticks(8)
t.move(patient, "east")
t.run_ticks(8)
assert(t.pos(patient) >= 4, "the patient walked out of arm's reach")
t.run_ticks(LAY_TICKS)
assert(t.body(patient).posture == "standing", "and was never laid out")
assert(#t.ledger_rows("DoAfterInterrupted") > 0, "the record says it was interrupted")

-- ---- in reach, and waited out: the drag lands -----------------------
t.move(patient, "west")
t.run_ticks(8)
t.move(patient, "west")
t.run_ticks(8)
assert(t.pos(patient) == 2, "back beside the surgeon")
_ = t.messages(surgeon)
t.drag(surgeon, 2, 1, pid, 2, 2, table_id)
t.run_ticks(LAY_TICKS)
px, py = t.pos(patient)
assert(px == 2 and py == 2, "the patient is on the table: " .. px .. "," .. py)
assert(t.body(patient).posture == "lying", "lying on it")
assert(said(surgeon, "operating table"), "and the surgeon is told so")

-- ...facing the way the table does, not the way they walked in. The
-- assertion is on what the WIRE carried, which is what a viewer draws.
assert(t.seen(surgeon, patient).facing == "east",
    "the patient takes the table's own facing: "
        .. t.seen(surgeon, patient).facing)

-- ---- and that is what surgery wanted --------------------------------
-- The standing patient was refused with not_lying; laid out here, the
-- same swing parks an incision instead. The jumpsuit is off first
-- because a covered chest is the OTHER refusal.
t.unequip(patient, "uniform")
t.run_ticks(2)
t.click(surgeon, 1, 1, t.target_at(1, 1, "scalpel"))
t.run_ticks(2)
t.click(surgeon, 2, 2, pid)
t.run_ticks(4)
assert(#t.ledger_rows("DoAfterStarted") > 0, "the incision parked: the patient is lying down")
assert(not said(surgeon, "lying down"), "and nothing refused it for posture")

print("optable: drag refused out of reach, lands in reach, and surgery follows")
