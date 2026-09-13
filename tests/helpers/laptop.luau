-- Hold a running laptop against a device: the way into an access point's
-- interface (docs/LAPTOP.md, contact programming).
local ui_controls = require("@helpers/ui_controls")
local laptop = {}

-- Take the laptop lying at (x, y) into the empty active hand, as it is.
function laptop.take(p: number, x: number, y: number): SpecObservedTarget
    local item = t.target_at(p, x, y, "laptop")
    assert(item ~= nil, "a laptop to hand")
    t.click(p, x, y, item)
    t.run_ticks(2)
    assert(t.hands(p).held == "laptop", "the laptop is in hand")
    return item
end

-- Open the lid and power the laptop lying at (x, y), then take it into the
-- empty active hand. Returns the laptop's handle.
function laptop.ready(p: number, x: number, y: number): SpecObservedTarget
    local item = t.target_at(p, x, y, "laptop")
    assert(item ~= nil, "a laptop to hand")
    for _ = 1, 2 do t.use_item(p, item, "secondary"); t.run_ticks(2) end
    return laptop.take(p, x, y)
end

-- Click the device at (x, y) with the held laptop; returns the contact
-- workspace document, or nil when none opened.
function laptop.connect(p: number, x: number, y: number, id: string | SpecObservedTarget): ui_controls.Record?
    local target = t.target_at(p, x, y, id)
    assert(target ~= nil, "the device is in view")
    t.click(p, x, y, target)
    t.run_ticks(2)
    local state = t.ui(p, "programming")
    return if state == nil then nil else ui_controls.record(state)
end

-- The open contact workspace, asserted.
function laptop.ui(p: number): ui_controls.Record
    local ui = t.ui(p, "programming")
    assert(ui ~= nil, "the contact workspace is open")
    return ui_controls.record(ui)
end

function laptop.toggle(p: number, field: string, option: ui_controls.Option?): ()
    ui_controls.toggle(p, field, option, "programming")
end

-- Unlock from the lock screen through its rendered Unlock press.
function laptop.unlock(p: number): ()
    ui_controls.press(p, "/toggle/link_lock/switch", nil, t.ui_document(p, "programming"))
end

function laptop.close(p: number): ()
    t.ui_close(p, "programming")
    t.run_ticks(2)
end

return laptop
