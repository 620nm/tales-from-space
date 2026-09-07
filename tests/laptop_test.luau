-- Player-visible lid, power, shared desktop and removable-slot contracts.
-- docs/LAPTOP.md owns the gestures; no test mutates entity components.
local ARENA = [==[(
    name: "laptop desk",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#######", "#.....#", "#.....#", "#.....#", "#######"],
    spawns: [(2, 2), (3, 2)],
    items: [
        (2, 2, "laptop"), (2, 2, "floppy_disk"),
        (2, 2, "id_assistant"), (2, 2, "id_captain"),
        (2, 2, "screwdriver"),
    ],
)]==]

local function desktop(player)
    local state = t.ui(player)
    assert(state, "a desktop is open")
    local data = if state.script then state.script.data else state.data
    assert(data.kind == "desktop", "the document is the laptop desktop")
    if data.powered then
        assert(state.script and state.stores, "powered desktop composes native files")
        assert(state.stores[1].capacity == 65536 and state.stores[1].count_cap == 16,
            "the laptop carries the terminal's local-store capacity")
    else
        assert(state.document == "script" and state.stores == nil,
            "power off revokes native storage disclosure")
    end
    return data
end

local function sound_count(player, needle)
    local count = 0
    for _, sound in ipairs(t.sounds(player)) do
        if sound == needle then count += 1 end
    end
    return count
end

t.world(ARENA, 0)
local p, q = t.join(), t.join()
t.run_ticks(3)
local laptop = t.target_at(2, 2, "laptop")
assert(laptop ~= nil, "the laptop exists on the floor")

t.use_item(p, laptop, "alt")
t.run_ticks(2)
assert(t.ui(p) == nil, "Alt-click on a closed lid does not open it")
assert(sound_count(p, "computer_start") == 0, "a closed Alt-click does not boot")

t.use_item(p, laptop, "secondary")
t.run_ticks(2)
local wallpaper = desktop(p).wallpaper
assert(wallpaper == "wallpaper_bliss" or wallpaper == "wallpaper_moonlake",
    "creation selects a declared wallpaper")
assert(desktop(p).powered, "opening the lid boots in the same gesture")
assert(sound_count(p, "computer_start") == 1, "the first open boots exactly once")
assert(t.hands(p).held == nil, "right-click leaves the laptop on the desk")

t.use_item(q, laptop, "secondary")
t.run_ticks(2)
assert(desktop(q).wallpaper == wallpaper, "both readers see the item's wallpaper")
assert(sound_count(p, "computer_start") == 0, "a second reader does not reboot")

t.ui_close(p)
t.run_ticks(2)
assert(t.ui(p) == nil and desktop(q).powered, "title-bar close dismisses only its reader")
t.use_item(p, laptop, "secondary")
t.run_ticks(2)
assert(desktop(p).wallpaper == wallpaper, "reader dismissal preserves the wallpaper and open lid")

local host_binding = t.ui(p).stores[1].binding
t.ui_act(p, "text", '{"field":"file_create","option":"host:md:' .. host_binding
    .. '","text":"shift_note"}')
t.run_ticks(2)
local saved_file = t.ui(p).open
assert(saved_file and saved_file.name == "shift_note", "laptop creates a named local file atomically")
local saved_address = "host:" .. tostring(saved_file.uid) .. ":" .. saved_file.binding

t.ui_act(p, "power")
t.run_ticks(2)
assert(not desktop(p).powered and not desktop(q).powered,
    "power off refreshes every current reader")
assert(sound_count(p, "computer_end") == 1, "shutdown sounds once")
assert(desktop(p).wallpaper == wallpaper, "shutdown retains wallpaper")
t.ui_act(p, "text", '{"field":"file_save","option":"' .. saved_address
    .. '","text":"refused while off","revision":0}')
t.run_ticks(2)
assert(#t.ledger_rows("file_saved") == 0, "power off refuses stale native file actions")

t.ui_act(q, "power")
t.run_ticks(2)
assert(desktop(p).powered and desktop(q).powered, "another reader can switch it on")
assert(#t.ui(p).files == 1 and t.ui(p).files[1].name == "shift_note",
    "saved local files survive a power cycle")
assert(t.ui(p).stores[1].binding ~= host_binding, "power cycling invalidates old store bindings")
t.sounds(p)
t.ui_act(p, "close")
t.ui_act(q, "power")
t.run_ticks(2)
assert(t.ui(p) == nil and t.ui(q) == nil, "lid close dismisses every desktop")
assert(sound_count(p, "computer_end") == 0, "the dismissed reader cannot switch off a closed laptop")

t.use_item(p, laptop, "secondary")
t.run_ticks(2)
assert(desktop(p).powered and desktop(p).wallpaper == wallpaper,
    "reopening keeps power and the assigned wallpaper")
assert(sound_count(p, "computer_start") == 0, "closing the lid preserved power")

local function take(id)
    t.click(p, 2, 2, t.target_at(2, 2, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "picked up " .. id .. "; hands=" .. tostring(t.hands(p).held))
end

local function insert(id)
    take(id)
    t.click(p, 2, 2, laptop)
    t.run_ticks(2)
end

t.use_item(q, laptop, "secondary")
t.run_ticks(2)
insert("id_assistant")
assert(t.hands(p).held == nil, "the blank assistant ID fits the card slot")
assert(desktop(p).card and desktop(q).card, "card insertion refreshes both readers")
insert("id_captain")
assert(t.hands(p).held == "id_assistant", "insertion swaps the previous identity into hand")
t.drop(p)
t.run_ticks(2)
t.ui_act(p, "eject_id")
t.run_ticks(2)
assert(t.hands(p).held == "id_captain", "ejection returns the inserted card")
assert(not desktop(p).card and not desktop(q).card, "both readers see the empty card slot")
t.drop(p)
t.run_ticks(2)

insert("floppy_disk")
assert(t.hands(p).held == nil, "the disk enters the media slot")
assert(desktop(p).cartridge and desktop(q).cartridge, "both readers see the inserted disk")
t.use_item(p, laptop, "ctrl_shift")
t.run_ticks(2)
assert(t.hands(p).held == "floppy_disk", "Ctrl+Shift ejects the disk")
assert(not desktop(p).cartridge and not desktop(q).cartridge, "disk removal refreshes both readers")
t.drop(p)
t.run_ticks(2)

insert("screwdriver")
assert(t.hands(p).held == "screwdriver", "a tool cannot occupy either slot")
assert(not desktop(p).card and not desktop(p).cartridge, "invalid insertion changes no slot")
t.drop(p)
t.run_ticks(2)

insert("floppy_disk")
t.use_item(p, laptop, "alt")
t.run_ticks(2)
take("laptop")
t.swap_hands(p)
t.run_ticks(2)
take("screwdriver")
t.use_item(p, laptop, "secondary")
t.run_ticks(2)
assert(desktop(p).powered and desktop(p).wallpaper == wallpaper,
    "right-click opens the offhand laptop while the active hand holds a tool")
assert(t.hands(p).held == "screwdriver", "opening the offhand laptop preserves the active tool")
t.use_item(p, laptop, "ctrl_shift")
t.run_ticks(2)
assert(not desktop(p).cartridge, "full hands do not prevent disk ejection")
assert(t.target_at(2, 2, "floppy_disk") ~= nil, "ejection places the disk on the floor when both hands are full")
assert(t.hands(p).held == "screwdriver", "full-hands ejection preserves the active tool")
t.drop(p)
t.swap_hands(p)
t.run_ticks(2)
assert(t.hands(p).held == "laptop", "the laptop remained in the other hand")
t.use_self(p)
t.run_ticks(2)
assert(desktop(p).wallpaper == wallpaper, "self-use in hand opens the same persistent desktop")
t.drop(p)
t.run_ticks(2)
t.click(q, 2, 2, laptop)
t.run_ticks(2)
assert(t.hands(q).held == "laptop", "another player can take the laptop")
t.use_self(q)
t.run_ticks(2)
assert(desktop(q).wallpaper == wallpaper, "handoff preserves the creation choice")
