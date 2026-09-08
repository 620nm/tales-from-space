-- Inventory interactions use the same player commands as the slot UI.
local ARENA = [==[(
    name: "inventory laptop",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#####", "#...#", "#...#", "#...#", "#####"],
    spawns: [(2, 2)],
    items: [(2, 2, "laptop"), (2, 2, "floppy_disk"),
        (2, 2, "floppy_disk"), (2, 2, "id_assistant"),
        (2, 2, "id_captain"), (2, 2, "backpack"), (3, 2, "backpack")],
)]==]

t.world(ARENA, 0)
local p = t.join()
t.run_ticks(3)
local function step() t.run_ticks(2) end
local function take(id, x)
    x = x or 2
    t.click(p, x, 2, assert(t.target_at(x, 2, id)))
    step()
    assert(t.hands(p).held == id, "picked up " .. id)
end
local function gesture(site, name)
    t.use_item_site(p, site, name)
    step()
end
local function apply(site)
    t.interact_item(p, site)
    step()
end
local function desktop()
    local ui = assert(t.ui(p), "desktop is open")
    return if ui.script then ui.script.data else ui.data
end

take("laptop")
local laptop_hand = t.hands(p).active - 1
local held_laptop = { Held = { hand = laptop_hand } }
t.swap_hands(p)
step()
take("floppy_disk")
apply(held_laptop)
assert(t.hands(p).held == nil, "cartridge enters the laptop in the other hand")
assert(t.hands(p)[laptop_hand + 1] == "laptop", "insertion preserves the target hand")
gesture(held_laptop, "secondary")
assert(t.ui(p) == nil, "right-click only raises the held laptop lid")
gesture(held_laptop, "secondary")
gesture(held_laptop, "secondary")
assert(desktop().powered and desktop().cartridge, "held laptop powers and opens with its cartridge")
take("floppy_disk")
apply(held_laptop)
assert(t.hands(p).held == "floppy_disk", "occupied cartridge slot swaps into the inserting hand")
assert(#t.ledger_rows("media_inserted") == 2 and #t.ledger_rows("media_ejected") == 1,
    "cartridge replacement records both the old cartridge leaving and the new one entering")
t.drop(p)
step()
gesture(held_laptop, "shift_ctrl_primary")
assert(t.hands(p).held == "floppy_disk" and not desktop().cartridge,
    "declared modified click ejects from the other hand")
t.drop(p)
step()
take("id_assistant")
apply(held_laptop)
assert(t.hands(p).held == nil and desktop().card, "ID inserts into the held laptop")
take("id_captain")
apply(held_laptop)
assert(t.hands(p).held == "id_assistant", "ID replacement returns the original card")
t.drop(p)
step()
gesture(held_laptop, "shift_ctrl_secondary")
assert(t.hands(p).held == "id_captain" and not desktop().card, "modified right-click ejects the replacement ID")
t.drop(p)
step()

-- Empty-hand navigation remains separate from item-pair commands.
t.ui_close(p)
step()
apply(held_laptop)
assert(t.hands(p).held == nil and t.ui(p) == nil, "empty-hand pair command does nothing")
t.swap_hands(p)
step()
assert(t.hands(p).held == "laptop" and t.ui(p) == nil, "hand selection does not use the laptop")
apply(held_laptop)
assert(t.hands(p).held == "laptop" and t.ui(p) == nil, "active square does not self-use")
t.swap_hands(p)
step()
take("backpack")
t.equip(p)
step()
assert(t.worn(p).back == "backpack", "outer bag is worn")
if t.hands(p).held ~= nil then
    t.drop(p)
    step()
end
t.swap_hands(p)
step()
apply({ Equipment = { slot = "back" } })
assert(t.hands(p).held == nil and t.stored(p, "back")[1] == "laptop",
    "a worn container stows the held laptop after handlers decline")

local stored_laptop = { NestedEquipment = { slot = "back", path = { 0 } } }
take("floppy_disk")
apply(stored_laptop)
assert(t.hands(p).held == nil, "cartridge inserts into a laptop in a worn bag")
gesture(stored_laptop, "secondary")
assert(desktop().cartridge, "stored laptop exposes its inserted cartridge")
gesture(stored_laptop, "shift_ctrl_primary")
assert(t.hands(p).held == "floppy_disk", "stored laptop ejects to the active hand")
t.drop(p)
step()
t.ui_close(p)
step()
apply(stored_laptop)
assert(t.hands(p).held == nil, "empty-hand pair command does not take a stored laptop")
t.take_from(p, "back", 1)
step()
assert(t.hands(p).held == "laptop", "empty-hand navigation takes the stored laptop")
t.swap_hands(p)
step()
take("backpack", 3)
local inner_hand = t.hands(p).active - 1
t.swap_hands(p)
step()
apply({ Held = { hand = inner_hand } })
assert(t.hands(p).held == nil, "other held bag collects the laptop")
local held_stored_laptop = { NestedHeld = { hand = inner_hand, path = { 0 } } }
take("floppy_disk")
apply(held_stored_laptop)
assert(t.hands(p).held == nil, "cartridge inserts into a laptop inside the other held bag")
gesture(held_stored_laptop, "secondary")
assert(desktop().cartridge, "held bag laptop opens its desktop")
gesture(held_stored_laptop, "shift_ctrl_primary")
assert(t.hands(p).held == "floppy_disk", "held bag laptop ejects its cartridge")
t.drop(p)
step()
t.swap_hands(p)
step()
apply({ Equipment = { slot = "back" } })
assert(t.hands(p).held == nil and t.stored(p, "back")[1] == "backpack", "inner bag nests in worn bag")
local nested_laptop = { NestedEquipment = { slot = "back", path = { 0, 0 } } }
take("floppy_disk")
apply(nested_laptop)
assert(t.hands(p).held == nil, "cartridge inserts through the nested bag path")
gesture(nested_laptop, "secondary")
assert(desktop().cartridge, "nested laptop remains the same powered computer")
gesture(nested_laptop, "shift_ctrl_primary")
assert(t.hands(p).held == "floppy_disk" and not desktop().cartridge,
    "nested cartridge ejection preserves the target and updates its desktop")
gesture(nested_laptop, "alt_primary")
assert(t.ui(p) == nil, "Alt-click closes the nested laptop and dismisses its desktop")
gesture(nested_laptop, "secondary")
assert(t.ui(p) == nil, "normal use raises the nested lid without opening a desktop")
gesture(nested_laptop, "secondary")
assert(desktop().powered, "nested laptop keeps power when its lid closes")
