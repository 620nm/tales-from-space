-- A map boots with the station's dead in its shut chambers, as tg's
-- `dead_body_placer` stocks the morgue (content/lib/cadaver_stock.luau): three
-- bodies, one to a chamber when there are three, each dead, settled, named
-- and in a crew job's kit. Opening a chamber slides its body onto the tray's
-- tile (tests/bodies/cadaver_chamber_test.luau), where any crewman sees it.
t.set_breathing(false)
t.bootstrap_world({ host_map = "morgue.ron", mode = "free_build", seed = 7 })
assert(#t.ledger_rows("lunatic/tfs:map_boot_failed") == 0, "no boot refusal is ledgered")

local attendant = t.join()
t.run_ticks(4)

local function assert_at(x: number, y: number, why: string)
    local px, py = t.pos(attendant)
    assert(px == x and py == y, ("%s: expected (%d, %d), got (%d, %d)"):format(why, x, y, px, py))
end

local function walk(directions: { "north" | "south" | "east" | "west" })
    for _, direction in ipairs(directions) do
        t.move(attendant, direction)
        t.run_seconds(1)
    end
end

-- The chamber at `x` on the north wall holds its stock out of sight until
-- it opens; then exactly one of the dead lies on its tray's tile.
local function open_and_read(x: number)
    assert(#t.bodies_at(x, 2) == 0, ("chamber %d's stock is concealed while shut"):format(x))
    local chamber = assert(t.target_at(attendant, x, 1, "cadaver_chamber"), "a chamber to open")
    assert(assert(t.structure_at(x, 1)).state ~= "open", ("chamber %d boots shut"):format(x))
    t.click(attendant, x, 1, chamber)
    t.run_ticks(2)
    assert(assert(t.structure_at(x, 1)).state == "open", ("chamber %d opens"):format(x))
    local bodies = t.bodies_at(x, 2)
    assert(#bodies == 1, ("chamber %d held one body, got %d"):format(x, #bodies))
    local body = bodies[1]
    assert(body.plan == "human", "the dead are human, got " .. body.plan)
    assert(not body.player, "nobody plays the dead")
    assert(not body.animate and not body.controllable, "the body is dead and steers nothing")
    assert(body.health < body.max_health, "it died of something")
    local full = string.find(body.name, " ", 1, true) ~= nil
    assert(full, "it has a given and a family name: " .. body.name)
    assert(body.worn.uniform ~= nil, "it wears a crew uniform")
    assert(body.worn.id ~= nil, "and the job's card")
end

assert_at(2, 2, "the attendant stands between the first two chambers")
open_and_read(1)
open_and_read(3)
walk({ "south", "east", "east", "north" })
assert_at(4, 2, "beside the third chamber")
open_and_read(5)

local seated = 0
for _, row in ipairs(t.ledger_rows("body_spawned")) do
    if row.into ~= nil then
        seated += 1
    end
end
assert(seated == 3, "three bodies are seated into chambers, no more, got " .. seated)
assert(#t.script_errors() == 0, "the stock's handlers run cleanly")
