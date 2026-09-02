-- Building an access point, and then working its lock.
--
-- The ladder is `machine_frame`'s ladder said against a wall: two
-- sheets, five lengths of cable, a board, the parts the board's product
-- asks for, and a screwdriver -- with the frame refusing the last step
-- by NAME while anything is missing. What is new is the part it asks
-- for: a network card, which is where the finished box's ADDRESS comes
-- from (docs/DEVICES.md §5a). A socket with no card in it is a box on
-- no network at all, and the assembly will not close over an empty one.
--
-- Then the lock, which is two different facts depending on where the
-- box came from. What opens THIS one is never written in the file: it
-- is the placement's own `access` word (docs/DEVICES.md §8). So a box a
-- player screwed together has no key -- still a lock, still worked only
-- by somebody standing at it -- while one the station was built with
-- wants the claim its placement names. Both halves are below, in that
-- order, because the first is what an engineer meets first.
--
-- THE BENCH IS WIRED, and has to be: an access point is a corded
-- appliance, and no panel on a dead cord takes a press. So there is a
-- plant, a controller and a socket along the back wall of every world
-- in this file, two tiles from where the box hangs.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

-- `t.messages` DRAINS, so a block asking two questions of one moment
-- captures the traffic once and asks both of the list.
local function among(lines, needle)
    for _, m in ipairs(lines) do
        if m:find(needle, 1, true) then
            return true
        end
    end
    return false
end

local function readout(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r.value
        end
    end
    return nil
end

-- Every toggle row on one field, in the order the panel drew them.
local function rows(ui, field)
    local out = {}
    for _, row in ipairs(ui.toggles or {}) do
        if row.field == field then
            out[#out + 1] = row
        end
    end
    return out
end

-- ---------------------------------------------------------------
-- 1. THE LADDER, on a wall, with everything it needs at the
--    builder's feet.
-- ---------------------------------------------------------------
t.world([==[(
    name: "mount bench",
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
        "#Gao..#",
        "#######",
    ],
    spawns: [(4, 1)],
    items: [
        (4, 1, "metal"),
        (4, 1, "cable_coil"),
        (4, 1, "machine_board.access_point"),
        (4, 1, "network_card"),
        (4, 1, "screwdriver"),
        (4, 1, "crowbar"),
    ],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==], 7)

local p = t.join()
t.run_ticks(10)

local function take(id)
    t.click(p, 4, 1, t.target_at(4, 1, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function put_down()
    t.drop(p)
    t.run_ticks(2)
end

local function work(id, seconds)
    t.click(p, 4, 1, t.target_at(4, 1, id))
    t.run_seconds(seconds)
end

take("metal")
t.build(p, "metal", "wall_frame", 4, 0)
t.run_seconds(4.5)
assert(t.structure_at(4, 1).id == "wall_frame", "two sheets make the box")

put_down()
take("cable_coil")
work("wall_frame", 2.5)
assert(t.structure_at(4, 1).state == "wired", "and five lengths of cable wire it")

put_down()
take("machine_board.access_point")
work("wall_frame", 0.5)
assert(t.structure_at(4, 1).state == "boarded", "the board says what it is becoming")

-- THE REFUSAL NAMES THE CARD. The board spells no component of its own
-- (docs/CONTENT-SCHEMA.md §1.10b) -- what the assembly is short of is
-- read off the SOCKETS of the thing the board builds, and the socket an
-- access point has is the one its address comes out of.
put_down()
take("screwdriver")
local _ = t.messages(p)
work("wall_frame", 4.5)
local heard = table.concat(t.messages(p), " | ")
assert(
    heard:find("It still needs 1 x network card.", 1, true),
    "the screwdriver says the box has no address yet, got: " .. heard
)
assert(t.structure_at(4, 1).id == "wall_frame", "and nothing was assembled")

put_down()
take("network_card")
work("wall_frame", 0.5)
assert(t.hands(p).held == nil, "the card goes into the socket whole")

-- ...and then the one length of cable the board itself asks for, which
-- is the stack material no socket holds.
take("cable_coil")
work("wall_frame", 0.5)
assert(t.hands(p).held == "cable_coil", "a stack gives up a unit and stays in the hand")

put_down()
take("screwdriver")
work("wall_frame", 4.5)
local box = t.structure_at(4, 1)
assert(box ~= nil and box.id == "access_point", "the assembly becomes what its board named")
-- The DARK north face: still bolted to the wall it was framed against,
-- and drawn off because a box built on a bench with no grid under it
-- has a dead cord (`appearance.device`,
-- docs/content-schema/appearance.md). The wall is in the suffix, the
-- power is in the stem, and both are being asserted here.
assert(box.sprite == "access_point_off_n", "bolted to its wall and drawn dead")
assert(t.structure_at(4, 0) == nil, "and still nothing standing on the wall")
assert(
    t.ledger_has("StructureStep", "wall_frame", "finished"),
    "and the assembly is on the record"
)

-- ---------------------------------------------------------------
-- 2. THE PANEL, AND A LOCK WITH NO KEY.
--
-- A fresh boot finds every lock shut, and this one was never placed by
-- a map, so nothing names a claim for it. It still has to be WORKED by
-- somebody standing at it, which is the whole of what a lock on a panel
-- is -- and while it is shut the panel says what this box is and not
-- one word about the network behind it.
-- ---------------------------------------------------------------
put_down()
-- Long enough for the box to find the socket behind it and start
-- drawing: no panel on a dead cord takes a press.
t.run_ticks(40)
t.click(p, 4, 1, t.target_at(4, 1, "access_point"))
t.tick()
local panel = t.ui(p)
assert(panel ~= nil, "an access point wears a panel")
assert(#readout(panel, "address") == 17, "with the address a shift log will name")
local lock = rows(panel, "link_lock")
assert(#lock == 1 and not lock[1].on, "a lock row, shut, because a fresh boot finds them all shut")
assert(#rows(panel, "link_join") == 0, "and a shut panel offers nothing to join")

t.ui_act(p, "toggle", '{"field":"link_lock"}')
t.tick()
panel = t.ui(p)
assert(panel ~= nil, "the panel stays open under a press")
assert(rows(panel, "link_lock")[1].on, "a lock with no key opens for whoever is standing at it")
assert(#t.ledger_rows("link_locked") == 1, "and the lock is on the record either way")

-- An unlocked panel is an operable panel: the roster and the
-- candidates are drawn now, and there is nothing on either yet because
-- this box is alone in the room.
assert(#rows(panel, "link_drop") == 0, "nothing has joined it")
assert(#rows(panel, "link_join") == 0, "and there is nothing in range to join")

-- The pack's own sentence about the box, which is the one thing about
-- an access point that is not native panel work
-- (content/fixtures/access_point.luau, content/lib/network.luau). The
-- window opens AND the line is heard: the hook rides the completion, so
-- it adds a sentence rather than eating the panel.
t.ui_close(p)
t.tick()
local _ = t.messages(p)
t.click(p, 4, 1, t.target_at(4, 1, "access_point"))
t.tick()
assert(t.ui(p) ~= nil, "the window still opens under the hook")
assert(
    said(p, "The access point is on the air with nothing joined to it."),
    "and it says so in words somebody could repeat, got: " .. table.concat(t.messages(p), " | ")
)

-- ---------------------------------------------------------------
-- 3. AND BACK APART. The crowbar takes the whole assembly off,
--    leaving the frame on its wall -- and the card comes back because
--    the SOCKET says what comes out, not the `yields` list.
-- ---------------------------------------------------------------
t.ui_close(p)
t.tick()
take("crowbar")
local coil_before = t.count_items("cable_coil")

-- A TOOL CLICK IS NOT A QUESTION. The crowbar's own step completes the
-- box's `interaction.use` on its way past, so the hook runs for this
-- click too -- and declines, because `implement` names what the hand
-- was holding. An engineer taking a fixture off the wall is not asking
-- it how it is (content/fixtures/access_point.luau).
local _ = t.messages(p)
work("access_point", 4.5)
local during = t.messages(p)
local said_during = table.concat(during, " | ")
assert(among(during, "You start prying the access point apart."),
    "the crowbar step ran: " .. said_during)
assert(not among(during, "is on the air"),
    "and the box said nothing about itself: " .. said_during)
assert(not among(during, "is locked"),
    "in either direction: " .. said_during)
local left = t.structure_at(4, 1)
assert(left ~= nil and left.id == "wall_frame", "a frame is what is left on the wall")
assert(left.state == "empty", "standing in its first state, as anything a step leaves does")
assert(left.sprite == "wall_frame_n", "and still facing the wall it was bolted to")
assert(t.count_items("machine_board.access_point") == 1, "the board comes back")
assert(t.count_items("network_card") == 1, "and so does the card, address and all")
assert(t.count_items("cable_coil") == coil_before + 1, "with the wiring as its own pile")

-- ---------------------------------------------------------------
-- 4. A LOCK WITH A KEY. The same entry, placed by a map that names a
--    claim for it -- which is where a lock's key comes from and the
--    only place it can (docs/DEVICES.md §8).
-- ---------------------------------------------------------------
t.world([==[(
    name: "keyed bench",
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
        "#Gao..#",
        "#######",
    ],
    spawns: [(5, 1)],
    items: [(5, 1, "id_engineering")],
    structures: [(4, 1, "access_point", { "access": "engineering" })],
    mounts: [(4, 1, North)],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==], 7)

local eng = t.join()
t.run_ticks(10)

t.click(eng, 4, 1, t.target_at(4, 1, "access_point"))
t.tick()
panel = t.ui(eng)
assert(panel ~= nil, "the mapped box wears the same panel")
assert(not rows(panel, "link_lock")[1].on, "shut, as every lock is at boot")

-- Empty-handed, and it stays shut. Opening it is checked against
-- whoever is standing there, on the tick the lock moves.
t.ui_act(eng, "toggle", '{"field":"link_lock"}')
t.tick()
assert(not rows(t.ui(eng), "link_lock")[1].on, "and it does not open for an empty hand")
local denials = t.ledger_rows("link_denied")
assert(#denials == 1 and denials[1].why == "access", "the refusal names the rule it broke")

-- The claim itself, in a hand -- worn or held, the check is the same
-- one an airlock makes.
t.click(eng, 5, 1, t.target_at(5, 1, "id_engineering"))
t.run_ticks(2)
assert(t.hands(eng).held == "id_engineering", "with the card in hand")
t.ui_act(eng, "toggle", '{"field":"link_lock"}')
t.tick()
assert(rows(t.ui(eng), "link_lock")[1].on, "the claim opens it")

-- Shutting one is not checked at all: it takes nothing away that a
-- card cannot put back.
t.drop(eng)
t.run_ticks(2)
t.ui_act(eng, "toggle", '{"field":"link_lock"}')
t.tick()
assert(not rows(t.ui(eng), "link_lock")[1].on, "and anybody may shut it again")
