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
    items: [
        (1, 2, "welder"), (2, 1, "welder"), (3, 1, "welder"), (5, 1, "welder"),
        (2, 2, "syringe"), (1, 2, "lab_flask"),
    ],
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

local function heard(asset: string): boolean
    for _, sound in ipairs(t.sounds(p)) do
        if sound == asset then
            return true
        end
    end
    return false
end

local function has_layer(sprite: string): boolean
    for _, layer in ipairs(t.layers(p)) do
        if layer == sprite then
            return true
        end
    end
    return false
end

local function held_sprite(hand: number, lit: boolean): string
    local side = if hand == 0 then "l" else "r"
    return if lit then "held_welder_lit_" .. side else "held_welder_" .. side
end

local function inventory_sprite(lit: boolean): string
    return if lit then "welder_lit" else "welder"
end

local ignite = "lunatic/tfs:ui.affordance.ignite"
local extinguish = "lunatic/tfs:ui.affordance.extinguish"
local function hud_action(): ui_controls.Record
    local view = ui_controls.state(p, "actions")
    local group = ui_controls.rows(ui_controls.record(view.data).groups)[1]
    return ui_controls.rows(group.actions)[1]
end

local function hud_activate(): ()
    local scope = assert(t.ui_document(p, "actions"))
    local view = ui_controls.state(p, "actions")
    local group = ui_controls.rows(ui_controls.record(view.data).groups)[1]
    local action = ui_controls.rows(group.actions)[1]
    local base = "actions/" .. ui_controls.text(group.id) .. "/buttons"
    if not ui_controls.find(p, base .. "/search") then
        ui_controls.press(p, base .. "/more")
    end
    scope = assert(t.ui_document(p, "actions"))
    ui_controls.press(
        p,
        "action/"
            .. scope.document
            .. "/"
            .. scope.generation
            .. "/"
            .. ui_controls.text(action.id),
        nil,
        scope
    )
    t.tick()
end

-- A reachable item on the deck advertises the label and dispatches the same
-- handler as self-use, with the label following the new state.
local ground = assert(t.target_at(p, 2, 1, "welder"))
local row = assert_label(action({ Entity = ground }, "secondary"), ignite, "ground welder")
assert(row.available, "ground welder is reachable")
t.use_item(p, ground, "secondary")
t.tick()
local ground_lit = assert(t.item_at(2, 1, "welder"))
assert(ground_lit.state == "lit", "ground secondary lights the welder")
assert(ground_lit.sprite == "welder_lit", "lit ground welder uses the lit world sprite")
assert(heard("welder_activate"), "lighting a ground welder is audible")
assert_label(action({ Entity = ground }, "secondary"), extinguish, "lit ground welder")
t.use_item(p, ground, "secondary")
t.tick()
local ground_unlit = assert(t.item_at(2, 1, "welder"))
assert(ground_unlit.state == "unlit", "ground secondary extinguishes the welder")
assert(ground_unlit.sprite == "welder", "unlit ground welder uses the base world sprite")
assert(heard("welder_deactivate"), "extinguishing a ground welder is audible")

-- Empty the reservoir through the player-facing syringe gestures. The map
-- fixture starts with the welder prototype's ordinary fuel, so this also
-- proves the empty state is real rather than a blend override.
local empty = assert(t.target_at(p, 1, 2, "welder"))
assert_label(action({ Entity = empty }, "secondary"), ignite, "empty welder")
local syringe = assert(t.target_at(p, 2, 2, "syringe"))
local bucket = assert(t.target_at(p, 1, 2, "lab_flask"))
assert((assert(t.contents(empty)).naphtha or 0) > 2.9, "the fixture starts fueled")
t.click(p, 1, 2, bucket)
t.tick()
assert(t.hands(p).held == "lab_flask", "the receiving flask is in hand")
t.use_self(p)
t.tick()
t.drop(p)
t.tick()
assert(t.hands(p).held == nil, "the receiving flask is put down open")
t.click(p, 2, 2, syringe)
t.tick()
assert(t.hands(p).held == "syringe", "the syringe is in hand")
bucket = assert(t.target_at(p, 1, 1, "lab_flask"))
local strokes = 0
for _ = 1, 30 do
    t.click(p, 1, 2, empty)
    t.tick()
    t.use_self(p)
    t.tick()
    t.click(p, 1, 1, bucket)
    t.tick()
    strokes += 1
    if (assert(t.contents(empty)).naphtha or 0) <= 1e-9 then
        break
    end
    t.use_self(p)
    t.tick()
end
assert(strokes > 0, "the syringe drew fuel")
assert((assert(t.contents(empty)).naphtha or 0) <= 1e-9, "the syringe emptied the welder")
assert((assert(t.contents(bucket)).naphtha or 0) > 2.9, "the syringe injected fuel into the flask")
t.drop(p)
t.tick()
assert(t.hands(p).held == nil, "the syringe is put down before the welder test")
local _ = t.messages(p)
local _sounds = t.sounds(p)
t.use_item(p, empty, "secondary")
t.tick()
local empty_state = assert(t.item_at(1, 2, "welder"))
assert(empty_state.state == "unlit", "an empty welder stays unlit")
assert(empty_state.sprite == "welder", "an empty welder keeps the unlit world sprite")
local empty_messages = table.concat(t.messages(p), " | ")
assert(empty_messages:find("The welder has no fuel.", 1, true), "an empty welder reports no fuel")
for _, sound in ipairs(t.sounds(p)) do
    assert(sound ~= "welder_activate", "an empty welder makes no activation sound")
end

-- The active held card still has self-use and the possession-scoped HUD.
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "welder")))
t.run_ticks(2)
local active_hand = t.hands(p).active - 1
assert(t.hud(p)[active_hand + 1] == inventory_sprite(false), "unlit welder uses the base inventory sprite")
assert(has_layer(held_sprite(active_hand, false)), "the world view shows the unlit in-hand sprite")
assert_label(inventory_action(active_hand, "self"), ignite, "active welder self-use")
assert_label(inventory_action(active_hand, "secondary"), ignite, "active welder secondary")
assert(hud_action().id == "activate", "welder HUD keeps its action")
local action_scope = assert(t.ui_document(p, "actions"))
assert(
    ui_controls.node(p, "actions/equipment/title", action_scope).text == "Equipment",
    "the rendered action group is captioned Equipment"
)
assert(
    ui_controls.node(p, "/activate", action_scope).label == "Welding tool",
    "the rendered action is captioned Welding tool"
)

-- The pointer gesture reaches a held tool through the same validated site.
local held_site: SpecItemSite = { Held = { hand = active_hand } }
t.use_item_site(p, held_site, "secondary")
t.tick()
assert(t.hud(p)[active_hand + 1] == inventory_sprite(true), "lit welder uses the lit inventory sprite")
assert(has_layer(held_sprite(active_hand, true)), "the world view shows the lit in-hand sprite")
assert_label(inventory_action(active_hand, "self"), extinguish, "lit held welder self-use")
assert(hud_action().state == "on", "welder HUD reports the lit state")
assert(heard("welder_activate"), "lighting a held welder is audible")

-- Self-use and the rendered HUD action share the same state and feedback.
t.use_self(p)
t.tick()
assert(t.hud(p)[active_hand + 1] == inventory_sprite(false), "self-use restores the unlit inventory sprite")
assert(has_layer(held_sprite(active_hand, false)), "self-use repaints the world in-hand sprite")
assert(hud_action().state == "off", "self-use updates the welder HUD state")
assert(heard("welder_deactivate"), "self-use deactivation is audible")
hud_activate()
assert(t.hud(p)[active_hand + 1] == inventory_sprite(true), "HUD activation uses the lit inventory sprite")
assert(has_layer(held_sprite(active_hand, true)), "HUD activation repaints the world in-hand sprite")
assert(heard("welder_activate"), "HUD activation is audible")

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
assert(heard("welder_deactivate"), "extinguishing an inactive welder is audible")

-- A visible item outside reach may show the disabled pointer hint, but the
-- validated claim cannot toggle it.
local far = assert(t.target_at(p, 5, 1, "welder"))
local far_row = assert_label(action({ Entity = far }, "secondary"), ignite, "out-of-reach welder")
assert(not far_row.available and far_row.group == "range", "out-of-reach welder cannot be used")
local far_before = assert(t.item_at(5, 1, "welder")).state
t.use_item(p, far, "secondary")
t.tick()
assert(assert(t.item_at(5, 1, "welder")).state == far_before, "out-of-reach secondary does not toggle")
assert(#t.sounds(p) == 0, "out-of-reach secondary is silent")
