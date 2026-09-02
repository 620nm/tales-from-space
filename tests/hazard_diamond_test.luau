-- The hazard diamond: a placard that says what went into the chamber.
--
-- The other half of hazard_placard_test.luau. That one asks what a
-- composition RATES; this one asks what a sign bolted beside it
-- actually draws, which is the whole of what a player ever sees of the
-- rating (docs/construction/signs.md).
--
-- Two placards on two walls of one room: one naming a plasma store and
-- one naming nothing at all. The difference between them is the ruling
-- -- an unfilled sign shows the placard only, because three zeroes
-- would be a claim that the chamber is safe.

local function worn(x, y, what)
    local structure = t.structure_at(x, y)
    assert(structure ~= nil, what .. ": the map hung one here")
    assert(structure.id == "hazard_diamond", what .. ": and it is a placard")
    return structure.overlays
end

local function drew(overlays, sprite, what)
    for _, name in ipairs(overlays) do
        if name == sprite then
            return true
        end
    end
    error(what .. ": expected " .. sprite .. " in the stack")
end

local function drew_nothing_like(overlays, prefix, what)
    for _, name in ipairs(overlays) do
        assert(
            string.sub(name, 1, #prefix) ~= prefix,
            what .. ": drew " .. name .. ", and should have drawn nothing"
        )
    end
end

t.world([==[(
    name: "diamonds",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    blends: {
        // A store of plasma with a little nitrogen over it: the one
        // substance this station is built to keep away from itself.
        "store": (rows: [("plasma", 90.0), ("n2", 10.0)], temperature_k: 293.15, amount: total),
    },
    mounts: [(1, 1, West), (3, 1, East)],
    structures: [
        (1, 1, "hazard_diamond", { "blend": "store" }),
        (3, 1, "hazard_diamond"),
    ],
)]==], 0)

-- The filled one. Plasma rates 4 on fire and carries `skull`
-- (content/substances/plasma.luau), and it is nine tenths of the
-- chamber, so nothing dilutes it below any threshold.
local filled = worn(1, 1, "the filled placard")
drew(filled, "nfpa_704_fire_4", "the filled placard")
drew(filled, "nfpa_704_health_4", "the filled placard")
drew(filled, "nfpa_704_special_skull", "the filled placard")

-- ...and ONE symbol, never two. Nitrogen is an asphyxiant past 85% and
-- is a tenth of this chamber, so it would not draw even if the sign
-- drew every symbol it had -- but the rule is the sign's, not the
-- threshold's: the first row of the priority list that matches wins and
-- the rest of the list never draws.
local prefix = "nfpa_704_special_"
local symbols = 0
for _, name in ipairs(filled) do
    if string.sub(name, 1, #prefix) == prefix then
        symbols = symbols + 1
    end
end
assert(symbols == 1, "a diamond wears exactly one symbol, got " .. symbols)

-- The blank one. No blend named, so no digits and no symbol: the
-- placard's own picture is the whole of it.
local blank = worn(3, 1, "the blank placard")
assert(#blank == 0, "an unfilled placard wears nothing, got " .. #blank)
drew_nothing_like(blank, "nfpa_704_health", "the blank placard")
drew_nothing_like(blank, "nfpa_704_special", "the blank placard")

print(
    "hazard diamond: filled wears "
        .. #filled
        .. " layers including fire 4 and the skull; blank wears none"
)
