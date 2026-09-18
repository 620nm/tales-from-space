local ui_controls = require("@helpers/ui_controls")

-- The welder's self-use key and HUD are retained, while its secondary pointer
-- gesture makes the same stateful toggle available on a reachable item.
t.world(
    [==[(
    name: "welder gestures",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: ["########", "#......#", "#......#", "########"],
    structures: [(1, 1, "player_spawn")],
    items: [(2, 1, "welder"), (3, 1, "welder"), (5, 1, "welder")],
)]==],
    7
)

local p = t.join()
t.tick()

local function action(target, gesture: string): SpecActionDescriptor?
    for _, row in ipairs(t.action_hints(p, target)) do
        if row.gesture == gesture then
            return row
        end
    end
    return nil
end

local function inventory_action(hand: number, gesture: string): SpecActionDescriptor?
    local site: SpecItemSite = { Held = { hand = hand } }
    return action({ Inventory = site }, gesture)
end

local function assert_label(row: SpecActionDescriptor?, key: string, context: string)
    assert(row ~= nil, context .. ": gesture is advertised")
    assert(row.label.key == key, context .. ": state-aware label")
    return row
end

local ignite = "lunatic/tfs:ui.affordance.ignite"
local extinguish = "lunatic/tfs:ui.affordance.extinguish"
local function hud_action(): ui_controls.Record
    local view = ui_controls.state(p, "actions")
    local group = ui_controls.rows(ui_controls.record(view.data).groups)[1]
    return ui_controls.rows(group.actions)[1]
end

-- A reachable item on the deck advertises the label and dispatches the same
-- handler as self-use, with the label following the new state.
local ground = assert(t.target_at(p, 2, 1, "welder"))
local row = assert_label(action({ Entity = ground }, "secondary"), ignite, "ground welder")
assert(row.available, "ground welder is reachable")
t.use_item(p, ground, "secondary")
t.tick()
assert(assert(t.item_at(2, 1, "welder")).state == "lit", "ground secondary lights the welder")
assert_label(action({ Entity = ground }, "secondary"), extinguish, "lit ground welder")
t.use_item(p, ground, "secondary")
t.tick()
assert(assert(t.item_at(2, 1, "welder")).state == "unlit", "ground secondary extinguishes the welder")

-- The active held card still has self-use and the possession-scoped HUD.
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "welder")))
t.run_ticks(2)
local active_hand = t.hands(p).active - 1
assert_label(inventory_action(active_hand, "self"), ignite, "active welder self-use")
assert_label(inventory_action(active_hand, "secondary"), ignite, "active welder secondary")
assert(hud_action().id == "activate", "welder HUD keeps its action")

-- The pointer gesture reaches a held tool through the same validated site.
local held_site: SpecItemSite = { Held = { hand = active_hand } }
t.use_item_site(p, held_site, "secondary")
t.tick()
assert_label(inventory_action(active_hand, "self"), extinguish, "lit held welder self-use")
assert(hud_action().state == "on", "welder HUD reports the lit state")

-- An inactive hand omits its self-use keycap, but its declared secondary
-- pointer gesture remains a real, state-aware action on the held item.
t.swap_hands(p)
t.run_ticks(2)
t.move(p, "east")
t.run_ticks(5)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "welder")))
t.run_ticks(2)
local inactive_hand = 2 - t.hands(p).active
assert(inventory_action(inactive_hand, "self") == nil, "inactive welder suppresses its self-use hint")
assert_label(inventory_action(inactive_hand, "secondary"), extinguish, "inactive lit welder secondary")
local inactive_site: SpecItemSite = { Held = { hand = inactive_hand } }
t.use_item_site(p, inactive_site, "secondary")
t.tick()
assert_label(inventory_action(inactive_hand, "secondary"), ignite, "inactive welder updates after secondary use")

-- A visible item outside reach may show the disabled pointer hint, but the
-- validated claim cannot toggle it.
local far = assert(t.target_at(p, 5, 1, "welder"))
local far_row = assert_label(action({ Entity = far }, "secondary"), ignite, "out-of-reach welder")
assert(not far_row.available and far_row.group == "range", "out-of-reach welder cannot be used")
local far_before = assert(t.item_at(5, 1, "welder")).state
t.use_item(p, far, "secondary")
t.tick()
assert(assert(t.item_at(5, 1, "welder")).state == far_before, "out-of-reach secondary does not toggle")
