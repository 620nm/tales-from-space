-- The station's own idea of which gases belong together, read off a
-- panel a player has open.
--
-- A scrubber offers a button per gas. Unordered that is a wall of words
-- a technician has to read end to end; grouped it is a control panel.
-- WHICH groups, and which gas is in each, is this pack's decision
-- (content/substance_groups.luau) and every word of it lives there --
-- the engine contributes the ordering and nothing else, so the only
-- place these headings can be checked is here.
--
-- The gas filter carries the same roster for the same reason and is
-- asserted alongside, because two machines listing the same gases in
-- two different orders is exactly the bug the shared ordering exists to
-- make unspeakable.

local SCRUB_MAP = [==[(
    name: "grouped panel",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#....ag#",
        "########",
    ],
    spawns: [(5, 2)],
    pipes: [(0, 1, 2), (1, 1, 2)],
    structures: [(2, 1, "air_scrubber")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==]

t.world(SCRUB_MAP, 7)

local p = t.join()
t.tick()

local function walk(dir)
    t.move(p, dir)
    t.run_ticks(5)
end

for _ = 1, 3 do
    walk("west")
end
t.click(p, 2, 1, t.target_at(2, 1, "air_scrubber"))
t.tick()

local panel = t.ui(p)
assert(panel, "a scrubber wears a panel of its own")

-- Only the roster's buttons: the power, direction and roster switches
-- are three controls of their own and carry no heading.
local function gas_rows(window)
    local rows = {}
    for _, sw in ipairs(window.toggles) do
        if sw.field == "filter" then
            rows[#rows + 1] = { id = sw.option, section = sw.section }
        end
    end
    return rows
end

local rows = gas_rows(panel)
assert(#rows > 6, "a station with one gas would not need grouping: " .. #rows)

-- The three gases a room is supposed to hold, first and in that order:
-- this pack ranks them 100/90/80 and the panel reads the rank
-- (each substance file's own `relevance`).
local AIR = { "o2", "n2", "co2" }
for index, id in ipairs(AIR) do
    assert(
        rows[index].id == id,
        "the air a station runs on leads the list, in rank order: wanted "
            .. id
            .. " at "
            .. index
            .. ", got "
            .. tostring(rows[index].id)
    )
    assert(
        rows[index].section == "Atmospheric gases",
        id .. " belongs under the air heading, not " .. tostring(rows[index].section)
    )
end

-- And chlorine, which is the most dangerous thing on this shelf, under
-- the heading that says so rather than filed with the air.
local chlorine = nil
for _, row in ipairs(rows) do
    if row.id == "chlorine" then
        chlorine = row
    end
end
assert(chlorine ~= nil, "the scrubber offers every gas this pack models")
assert(
    chlorine.section == "Atmospheric poisons",
    "chlorine is a poison, not air: " .. tostring(chlorine.section)
)

-- Each heading appears in ONE unbroken run, in the order the pack
-- declared them. The client draws a heading where its first row appears
-- (docs/TGUI.md), so a block that came out in two pieces would be drawn
-- as two headings with the same words.
local DECLARED = { "Atmospheric gases", "Atmospheric poisons", "Gases at room temperature" }
local function block_order(list)
    local seen = {}
    local order = {}
    for _, row in ipairs(list) do
        local heading = row.section
        assert(heading ~= nil, tostring(row.id) .. " is under no heading at all")
        if order[#order] ~= heading then
            assert(not seen[heading], "the " .. heading .. " block is broken in two")
            seen[heading] = true
            order[#order + 1] = heading
        end
    end
    return order
end

local order = block_order(rows)
assert(#order == #DECLARED, "one block per declared group: " .. #order)
for index, heading in ipairs(DECLARED) do
    assert(
        order[index] == heading,
        "declaration order is display order: wanted " .. heading .. ", got " .. tostring(order[index])
    )
end

-- The gas filter is the same list, said again. It is a different
-- machine with a different field and a different pair of words on each
-- button, and its gases must still come out in exactly this sequence.
local FILTER_MAP = [==[(
    name: "grouped filter",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#..a..g#",
        "########",
    ],
    spawns: [(5, 2)],
    pipes: [(1, 1, 1), (5, 1, 1), (3, 2, 1)],
    structures: [(3, 1, "gas_filter")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==]

t.world(FILTER_MAP, 7)
local q = t.join()
t.tick()
for _ = 1, 2 do
    t.move(q, "west")
    t.run_ticks(5)
end
t.click(q, 3, 1, t.target_at(3, 1, "gas_filter"))
t.tick()

local filter_panel = t.ui(q)
assert(filter_panel, "a gas filter wears a panel of its own")
local filter_rows = gas_rows(filter_panel)
assert(#filter_rows == #rows, "the two machines offer the same roster")
for index, row in ipairs(filter_rows) do
    assert(
        row.id == rows[index].id and row.section == rows[index].section,
        "the filter and the scrubber disagree at " .. index .. ": " .. tostring(row.id)
    )
end
