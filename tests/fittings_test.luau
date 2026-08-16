-- How every atmospherics device in the game is placed and taken away.
--
-- tg has ONE pattern for this and no exceptions: you never put a machine
-- down. You put a FITTING down and wrench it, and
-- `/obj/item/pipe/wrench_act` (code/game/machinery/pipe/construction.dm
-- :268-312) refuses unless the fitting is lying on a turf, spawns the
-- machine in its place, and deletes the item. Unwrenching runs the same
-- trade backwards -- `on_deconstruction` mints the machine's
-- `construction_type` back onto the tile
-- (code/modules/atmospherics/machinery/atmosmachinery.dm:511-520).
--
-- So there is no such thing as a connector port lying on the floor. What
-- lies on the floor is a connector port FITTING, and the difference is
-- the whole feature: a fitting is an ITEM. You can pick it up, carry it
-- across the station, and bolt it down somewhere better. Before this,
-- unwrenching a port left a thing on its tile that could not be picked
-- up, could not be shoved, and could not be got rid of -- station litter
-- with a sprite.
--
-- The port is the only device modelled so far, but nothing below is
-- about ports: `build = { from_item = ..., tool = ... }` and a
-- transition's `yields` are the two halves of the generic round trip,
-- and the next twenty devices are twenty content files.

-- Moles in a volume at a pressure, at room temperature -- the ideal gas
-- law, so the spec can audit the books rather than trust a direction.
local function moles(kpa, volume_m3)
    return kpa * 1000.0 * volume_m3 / (8.314 * 293.15)
end

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function standing_on(p, x, y)
    local px, py = t.pos(p)
    return px == x and py == y
end

-- One step, plus the move cooldown (lunatic_core::MOVE_COOLDOWN_TICKS
-- is 4), so two calls in a row are two steps rather than one step and a
-- swallowed keypress.
local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- How many times the ledger has recorded a structure of this id being
-- raised. COUNTED rather than asked as a yes/no, because this spec
-- bolts a port down twice and the second time has to be tellable from
-- the first.
local function built(id)
    local n = 0
    for _, row in ipairs(t.ledger_rows("StructureStep")) do
        if row.structure == id and row.to == "built" then
            n = n + 1
        end
    end
    return n
end

local function lying_at(x, y, id)
    for _, item in ipairs(t.items_at(x, y)) do
        if item == id then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------
-- One sealed room, a distribution run under its top row, and a
-- connector port with a canister bolted onto it. The run reaches out
-- through the east wall to a vent standing on a scrap of deck in open
-- space, so anything that gets into the line goes straight out of the
-- station -- which is what makes the gauge a proof rather than a
-- decoration.
--
-- Take the whole thing apart, carry the port across the room, put it
-- back together somewhere else, and plug the bottle back in.
-- ---------------------------------------------------------------
t.world([==[(
    name: "fittings",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        '_': (turf: Plating),
        'c': (turf: Floor, fixture: Some(Canister)),
    },
    rows: [
        "##########  ",
        "#.c......#_ ",
        "#........#  ",
        "#........#  ",
        "##########  ",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "wrench")],
    pipes: [
        (2, 2, 4), (3, 2, 4), (4, 2, 4), (5, 2, 4),
        (5, 1, 4), (6, 1, 4), (7, 1, 4), (8, 1, 4), (9, 1, 4),
    ],
    structures: [(2, 1, "connector_port"), (10, 1, "vent")],
)]==], 7)

local p = t.join()
t.tick()

-- The wrench, which is the whole toolkit for this job.
t.click(p, 1, 1, t.target_at(1, 1, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")

-- The map drew the bottle on the socket, so the shift opens plumbed in
-- -- and, with a vent blowing into vacuum at the far end, visibly so.
local seated = t.structure_at(2, 1)
assert(seated ~= nil and seated.id == "canister", "the canister is on its tile")
assert(seated.state == "anchored", "and it opened the shift fastened down")

local mapped_full = t.canister_pressure(2, 1)
t.run_seconds(10)
assert(
    t.canister_pressure(2, 1) < mapped_full - 100.0,
    "a fastened canister feeds the run: " .. mapped_full .. " -> " .. t.canister_pressure(2, 1)
)

-- ---- you do not pull the socket out from under the bottle ----
--
-- tg's `can_unwrench`: "You cannot unwrench [src], detach
-- [connected_device] first!"
-- (components/unary_devices/portables_connector.dm:54-58). The port is
-- drawn on its own underfloor layer, so a click CAN name it past the
-- canister standing on it -- and when it does it earns a reason, not a
-- dropped click.
local _ = t.messages(p)
t.click(p, 2, 1, t.target_at(2, 1, "connector_port"))
t.run_ticks(2)
assert(
    said(p, "Detach the gas canister from the connector port first."),
    "the refusal named the device in the way"
)
assert(
    not t.ledger_has("StructureStep", "connector_port", "gone"),
    "and the port is still bolted down"
)
assert(t.target_at(2, 1, "connector_port") ~= nil, "still there, in fact")

-- ---- take it apart ----
--
-- The bottle comes off instantly (tg's `wrench_act` on a portable atmos
-- device has no do_after in it anywhere); the plumbing does not.
t.click(p, 2, 1, t.target_at(2, 1, "canister"))
t.run_ticks(1)
assert(
    t.ledger_has("StructureStep", "canister", "displaced"),
    "the canister comes off the port instantly"
)

t.click(p, 2, 1, t.target_at(2, 1, "connector_port"))
t.run_ticks(1)
assert(
    not t.ledger_has("StructureStep", "connector_port", "gone"),
    "one tick in, the port is still bolted down"
)
t.run_seconds(2.5)
assert(
    t.ledger_has("StructureStep", "connector_port", "gone"),
    "and two seconds in, it is up"
)
assert(t.target_at(2, 1, "connector_port") == nil, "there is no port here now")

-- THE POINT. What came up is an ITEM, named the way tg names it
-- (`name = "[initial(fakeA.name)] fitting"`, construction.dm:212).
assert(
    lying_at(2, 1, "connector_port_fitting"),
    "what came up is a fitting lying on the deck"
)

-- The line is off the bottle and the vent has emptied it. From here to
-- the far end of the round trip nothing is feeding anything, which is
-- what makes the books below worth taking.
t.run_seconds(15)
assert(t.pipe_pressure(5, 1) < 5.0, "the run the port left is spent")

-- The books, taken with everything static. The room is 8x3 tiles of
-- 1 m³, the run is nine lengths of 70 L plus the vent's 200 L mouth,
-- and the bottle is tg's 2000 L. The connector itself is zero-volume.
local ROOM_M3 = 24.0
local RUN_M3 = 9 * 0.070 + 0.200
local CAN_M3 = 2.0

local function books(can_x, can_y)
    return moles(t.canister_pressure(can_x, can_y), CAN_M3)
        + moles(t.pipe_pressure(5, 1), RUN_M3)
        + moles(t.room_pressure(4, 2), ROOM_M3)
end

local opening = books(2, 1)
assert(opening > 3000.0, "there is real air in the room and the bottle: " .. opening)

-- ---- carry it ----
--
-- With a wrench in the working hand a click on the fitting bolts it
-- back down, which is exactly tg's dispatch. Swap to the free hand and
-- it is an ordinary thing to pick up.
t.swap_hands(p)
t.click(p, 2, 1, t.target_at(2, 1, "connector_port_fitting"))
t.run_ticks(2)
assert(t.hands(p).held == "connector_port_fitting", "and it goes in your hand")
assert(not lying_at(2, 1, "connector_port_fitting"), "off the deck")

-- Two tiles east. The loose canister is in the way and gives way (see
-- movement.rs::shove -- tg would have you PULL it), which is how it
-- ends up at (4, 1) for later.
walk(p, "east")
walk(p, "east")
assert(standing_on(p, 3, 1), "two tiles east")
assert(t.canister_pressure(4, 1) ~= nil, "the bottle was shoved along ahead")

-- ---- a socket needs NO plumbing under it ----
--
-- Josh's ruling (2026-08-16). The first cut refused this: a port aimed
-- at bare deck is a socket wired to nothing, so the wrench said no.
-- That got the ORDER wrong. A station is built socket-first -- you put
-- the connector where the bottle has to stand and run pipe out to it
-- afterwards -- and refusing that bought nothing, because nothing is
-- cached: an unplumbed port simply feeds nothing until a run reaches
-- its stub, and the moment one does the gas loop notices by looking.
--
-- So: down two rows, where no run reaches, and it goes down fine.
walk(p, "west")
walk(p, "west")
walk(p, "south")
walk(p, "south")
t.drop(p)
t.run_ticks(2)
assert(lying_at(1, 3, "connector_port_fitting"), "dropped on bare deck")

t.swap_hands(p)
local _ = t.messages(p)
t.click(p, 1, 3, t.target_at(1, 3, "connector_port_fitting"))
t.run_seconds(2.5)
assert(
    not said(p, "There is no pipe under the floor here."),
    "the old refusal is gone from the wrench path"
)
local dry = t.structure_at(1, 3)
assert(dry ~= nil and dry.id == "connector_port", "a port stands on bare plating")
assert(dry.state == "anchored", "in the only state a port has")
-- The fitting remembers which way it pointed when it came up
-- (rotation_test.luau owns that rule), and nothing here re-aims it:
-- with no run in reach there is nothing to aim AT, and the port keeps
-- the facing it was carrying.
assert(
    dry.sprite == "connector_port_s",
    "aimed the way it was when it came up: " .. tostring(dry.sprite)
)
assert(built("connector_port") == 1, "and the raise is on the record")
assert(not lying_at(1, 3, "connector_port_fitting"), "the fitting was spent into it")

-- Take it straight back up: what the rest of this spec is about is
-- carrying the socket to the run, and one bolted down here would be a
-- second port nobody asked for.
t.click(p, 1, 3, t.target_at(1, 3, "connector_port"))
t.run_seconds(2.5)
assert(t.structure_at(1, 3) == nil, "up again")
assert(lying_at(1, 3, "connector_port_fitting"), "and back to being a fitting")

-- ---- put it back together somewhere better ----
t.swap_hands(p)
t.click(p, 1, 3, t.target_at(1, 3, "connector_port_fitting"))
t.run_ticks(2)
assert(t.hands(p).held == "connector_port_fitting", "picked back up")
walk(p, "north")
walk(p, "north")
walk(p, "east")
walk(p, "east")
t.drop(p)
t.run_ticks(2)
assert(lying_at(3, 1, "connector_port_fitting"), "dropped over the run")

t.swap_hands(p)
t.click(p, 3, 1, t.target_at(3, 1, "connector_port_fitting"))
t.run_ticks(1)
assert(built("connector_port") == 1, "one tick in, it is still a fitting")
t.run_seconds(2.5)
assert(built("connector_port") == 2, "and two seconds in, it is a port again")
local rebuilt = t.structure_at(3, 1)
assert(rebuilt ~= nil and rebuilt.id == "connector_port", "a port stands here")
assert(rebuilt.state == "anchored", "bolted down, the only state a port has")
assert(not lying_at(3, 1, "connector_port_fitting"), "the fitting was spent into it")
-- Under the deck, so it does not mind being stood on: the player is
-- standing on the very tile they bolted it to.
assert(standing_on(p, 3, 1), "standing right on it")

-- ---- the books ----
--
-- Taking the plumbing apart and putting it back somewhere else is a
-- carpentry job, not a chemistry one. Nothing above vented, nothing
-- was welded, the room is still sealed and the line is still off the
-- bottle -- so the same air is in the same three places it was.
-- (The tolerance is temperature: the conversion above pins 293.15 K,
-- and gas that moved between two of the three did not.)
local closing = books(4, 1)
assert(
    math.abs(closing - opening) < opening * 0.02,
    "the round trip created and destroyed nothing: "
        .. opening
        .. " mol -> "
        .. closing
        .. " mol"
)

-- ---- and it is real plumbing ----
--
-- Get behind the bottle -- you cannot pull it, so you walk around it --
-- and shove it west onto the socket you carried here.
walk(p, "south")
walk(p, "east")
walk(p, "east")
walk(p, "north")
walk(p, "west")
assert(t.canister_pressure(3, 1) ~= nil, "shoved onto the rebuilt port")

t.click(p, 3, 1, t.target_at(3, 1, "canister"))
t.run_ticks(1)
assert(
    t.ledger_has("StructureStep", "canister", "anchored"),
    "and fastened to it instantly, as tg fastens a portable"
)
local docked = t.structure_at(3, 1)
assert(docked ~= nil and docked.state == "anchored", "the bottle reads as connected")

-- The proof. The vent at the far end has been blowing the line into
-- vacuum this whole time; the moment the bottle is on the socket it is
-- what pays for that, exactly as it did from the tile it started on.
local before = t.canister_pressure(3, 1)
t.run_seconds(10)
local after = t.canister_pressure(3, 1)
assert(
    after < before - 100.0,
    "the canister feeds the run through the port it was carried to: "
        .. before
        .. " -> "
        .. after
)
-- The line itself stays near empty: a vent blowing into vacuum takes
-- whatever arrives, so what the gauge loses is a standoff between the
-- release valve and the hole, not a reservoir filling up. That is what
-- makes a breach expensive.
assert(t.pipe_pressure(5, 1) < 30.0, "the run is a standoff, not a reservoir")
assert(t.room_pressure(4, 2) > 90.0, "and the sealed room never noticed any of it")
