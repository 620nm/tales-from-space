-- Diagonal wall mounts remain ordinary structures on their room tile. The
-- wallward direction changes their support and overhang; visibility and reach
-- are checked against the room tile.

local function sequence_rows()
    local count = 0
    for _, row in ipairs(t.ledger_rows("var_set")) do
        if tostring(row.key):find("button_sequence", 1, true) then count += 1 end
    end
    return count
end

-- In a one-tile room the button overhangs the south-east
-- corner, but the player and the authoritative structure still share one floor
-- tile.
t.world([==[(
    name: "south-east button room",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#####",
        "##.##",
        "#####",
        "#####",
    ],
    spawns: [(2, 2)],
    structures: [(2, 2, "airlock_button")],
    mounts: [(2, 2, SouthEast)],
)]==], 0)

local p = t.join()
t.run_ticks(4)
local se = t.structure_at(2, 2)
assert(se and se.id == "airlock_button", "the south-east button is on the room tile")
assert(se.sprite == "airlock_button_s", "south-east uses the south cardinal face")
assert(t.turf(2, 2) == "floor", "the mounted button does not replace the floor")

local target = assert(t.target_at(p, 2, 2, "airlock_button"),
    "the south-east overhang is visible from its one-tile room")
local look = assert(t.examine(p, 2, 2, target),
    "the south-east overhang is examinable")
assert(look.sprite == "airlock_button_s", "examine resolves the mounted face")
local before = sequence_rows()
t.click(p, 2, 2, target) -- target_at and click use the actual opaque sprite pixel.
t.run_ticks(4)
assert(sequence_rows() == before + 1, "pressing the diagonal button reaches its content handler")
local heard = false
for _, message in ipairs(t.messages(p)) do
    if message == "The button clicks, but nothing answers." then heard = true end
end
assert(heard, "the diagonal button's content handler answers the player")

-- A map-authored ring covers every MountDir spelling. The diagonal faces keep
-- using the existing north/south art while their overhang moves on both axes.
t.world_file("diagonal_wall_mount.ron", 0)
p = t.join()
t.run_ticks(4)

local mounts = {
    { x = 1, y = 1, sprite = "airlock_button_n" },
    { x = 2, y = 1, sprite = "airlock_button_n" },
    { x = 3, y = 1, sprite = "airlock_button_n" },
    { x = 1, y = 2, sprite = "airlock_button_w" },
    { x = 3, y = 2, sprite = "airlock_button_e" },
    { x = 1, y = 3, sprite = "airlock_button_s" },
    { x = 2, y = 3, sprite = "airlock_button_s" },
    { x = 3, y = 3, sprite = "airlock_button_s" },
}
for _, row in ipairs(mounts) do
    local structure = t.structure_at(row.x, row.y)
    assert(structure and structure.id == "airlock_button",
        "the map keeps the button on its floor tile")
    assert(structure.sprite == row.sprite,
        "the map uses the cardinal art for " .. row.x .. "," .. row.y)
    local observed = assert(t.target_at(p, row.x, row.y, "airlock_button"),
        "every mounted button has an opaque visible pixel")
    local examined = assert(t.examine(p, row.x, row.y, observed),
        "every mounted button is examinable")
    assert(examined.sprite == row.sprite, "examine sees the mounted art")
end

-- Clicking all eight is also the reach check: each observed target must make it
-- through the same player command seam, including the four diagonal corners.
before = sequence_rows()
for _, row in ipairs(mounts) do
    local observed = assert(t.target_at(p, row.x, row.y, "airlock_button"))
    t.click(p, row.x, row.y, observed)
    t.run_ticks(2)
end
assert(sequence_rows() == before + #mounts, "all eight mounted buttons are reachable")

-- Construct each diagonal on an actual 1x1 room. A frame is removed between
-- attempts so the one-bracket-per-tile rule remains part of the fixture.
t.world([==[(
    name: "diagonal construction room",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#####",
        "##.##",
        "#####",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "metal"), (2, 2, "welder")],
)]==], 0)
p = t.join()
t.run_ticks(4)

local corners = {
    { x = 1, y = 1, sprite = "wall_frame_n" },
    { x = 3, y = 1, sprite = "wall_frame_n" },
    { x = 1, y = 3, sprite = "wall_frame_s" },
    { x = 3, y = 3, sprite = "wall_frame_s" },
}
local function take(id)
    t.click(p, 2, 2, assert(t.target_at(p, 2, 2, id)))
    t.run_ticks(2)
end
local function put_down()
    t.drop(p)
    t.run_ticks(2)
end

for _, corner in ipairs(corners) do
    take("metal")
    ui_controls.build(p, "metal", "wall_frame", corner.x, corner.y)
    t.run_seconds(4.5)
    local frame = t.structure_at(2, 2)
    assert(frame and frame.id == "wall_frame" and frame.sprite == corner.sprite,
        "construction reaches the " .. corner.x .. "," .. corner.y .. " corner")

    put_down()
    take("welder")
    t.click(p, 2, 2, assert(t.target_at(p, 2, 2, "wall_frame")))
    t.run_seconds(4.5)
    assert(t.structure_at(2, 2) == nil, "the diagonal frame can be removed")
    put_down()
end
