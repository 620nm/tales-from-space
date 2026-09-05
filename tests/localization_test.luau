-- EVERY WORD A PLAYER READS COMES OUT OF THE CATALOG, and this is the
-- three ways it gets there.
--
--   1. A pack line: content emits a KEY and arguments, and the socket
--      resolves it for the one recipient reading it. The Luau file
--      spells no sentence at all (docs/LOCALIZATION.md 3).
--   2. A panel row: the server names the FIELD as a label id and the
--      pack owns the word, so a document carries `{id}` and never
--      prose (docs/tgui/labels.md).
--   3. An engine line the pack would rather word itself: the engine
--      renders the mechanism plainly, `locale/en.json` overrides it,
--      and the override is what a crewman hears.
--
-- The three together are the claim the whole effort makes: nothing on
-- screen is a string the engine or the pack wrote in code.
--
-- SEED-PINNED so the die's face is a fact rather than a range; the
-- assertion below matches whichever line that face earns, because a
-- bad roll is its own sentence and not a clause glued onto this one.
t.world([==[(
    name: "phrasebook",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'E': (turf: Floor, fixture: Some(Door)),
    },
    blends: {
        "canister_air": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15, amount: per_tile),
    },
    structures: [
        (2, 2, "canister", { "blend": "canister_air", "open": true }),
    ],
    rows: [
        "######",
        "#....#",
        "#...E#",
        "#....#",
        "######",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "d6")],
)]==], 2)

local p = t.join()
t.tick()

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

local function readout(ui, label)
    for _, r in ipairs(ui.readouts or {}) do
        if word(r.label) == label then
            return r
        end
    end
    return nil
end

local function heard(who, needle)
    for _, line in ipairs(t.messages(who)) do
        if line:find(needle, 1, true) then
            return line
        end
    end
    return nil
end

-- ---------------------------------------------------------------
-- 1. A PACK LINE. The die's file names `items.d6.roll` and passes the
--    face; the sentence it comes out as is `locale/en.json`'s, and it
--    is English because this session asked for no other language.
-- ---------------------------------------------------------------
t.click(p, 1, 1, t.target_at(1, 1, "d6"))
t.tick()
assert(t.hands(p).held == "d6", "the die is in hand")
local _ = t.messages(p)
t.use_self(p)
t.run_ticks(2)
local rolled = heard(p, "You roll the d6. It lands on ")
assert(rolled ~= nil,
    "the roller is told what it landed on: " .. table.concat(t.messages(p), " | "))
-- The face is an ARGUMENT, so the number is in the sentence rather than
-- the sentence being built around it.
local face = rolled:match("It lands on (%d+)%.")
assert(face ~= nil and tonumber(face) >= 1 and tonumber(face) <= 6,
    "with the face substituted into it: " .. rolled)
t.drop(p)
t.run_ticks(2)

-- ---------------------------------------------------------------
-- 2. A PANEL ROW. Not one word of this document is prose: the engine
--    names the field, the value and the heading, and every one of them
--    is an id out of `sim/ui/ids.rs` that this pack renders.
-- ---------------------------------------------------------------
t.click(p, 2, 2, t.target_at(2, 2))
t.tick()
local ui = t.ui(p)
assert(ui ~= nil and ui.document == "modules", "the canister opens its window")

local port = readout(ui, "canister.port")
assert(port ~= nil, "the panel says whether it is plumbed in")
assert(port.label.id == "canister.port",
    "and it says so as an id, not as a word: " .. tostring(word(port.label)))
assert(port.value.id == "canister.port.loose",
    "a bottle standing on the deck is loose: " .. tostring(word(port.value)))

local valve = ui.toggles and ui.toggles[1]
assert(valve ~= nil and valve.label.id == "canister.valve",
    "the release valve is a switch, named by id")
assert(valve.on_text.id == "canister.valve.open" and valve.off_text.id == "canister.valve.shut",
    "with both of its positions named the same way")

local dial = ui.setpoints and ui.setpoints[1]
assert(dial ~= nil and dial.label.id == "canister.release",
    "the regulator's dial carries an id and a number, never a caption")

local block = ui.matter and ui.matter[1]
assert(block ~= nil and block.section.id == "holder.contents",
    "and the contents block's heading is one too: " .. tostring(block and word(block.section)))
-- What a substance is CALLED is the pack's own word and travels as
-- itself: content wrote it, so nothing looks it up.
local named = false
for _, state in ipairs(block.states or {}) do
    for _, row in ipairs(state.rows or {}) do
        named = named or row.name == "oxygen"
    end
end
assert(named, "a substance keeps the name its own file gave it")
t.ui_close(p)
t.tick()

-- ---------------------------------------------------------------
-- 3. AN ENGINE LINE, IN THIS STATION'S WORDS. The engine renders
--    `engine.door.unpowered` as what stopped -- "It has no power to
--    move." -- and `locale/en.json` overrides it with the fiction. A
--    crewman hears the override and never the mechanism.
-- ---------------------------------------------------------------
local _ = t.messages(p)
for _ = 1, 4 do
    t.move(p, "east")
    t.run_ticks(5)
end
t.move(p, "south")
t.run_ticks(5)
t.move(p, "east")
t.run_ticks(5)
assert(not t.door_at(4, 2).open, "an airlock with no mains behind it stays shut")
assert(heard(p, "The airlock's motors are dead.") ~= nil,
    "and it is refused in the pack's words: " .. table.concat(t.messages(p), " | "))
assert(heard(p, "It has no power to move.") == nil,
    "never in the engine's, which the override replaced")

print("localization: a keyed line, a document of ids, and the engine's own key said in the pack's words")
