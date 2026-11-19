-- A powered paper copier. Resource quantities and the source sheet are
-- native machine state; the fixture only names the player-facing actions.
-- tg code/modules/paperwork/photocopier.dm:60-65, :140-152, :281-379.
local printing = require("@lib/printing")

local ui_label = require("@lib/ui_label")

return {
    id = "photocopier",
    entity_class = "installed",
    actions = printing.actions(),
    visual_layer = "fixture",
    energy_network = "power",
    name_label = "lunatic/tfs:entity.photocopier.name",
    name = "photocopier",
    sprite = "photocopier",
    dense = true,
    corded = true,
    drive = { accepts = { "paper" } },
    resources = {
        paper = { capacity = 30, initial = 30 },
        toner = { capacity = 30, initial = 30 },
    },
    ui = {
        modules = { "actions" },
        opens_on_click = false,
        actions = {
            { key = "copy", label = ui_label.pack("lunatic/tfs:action.photocopier.copy") },
            { key = "eject", label = ui_label.pack("lunatic/tfs:action.photocopier.eject") },
            { key = "set_count", label = ui_label.pack("lunatic/tfs:action.photocopier.set_count") },
            { key = "set_color", label = ui_label.pack("lunatic/tfs:action.photocopier.set_color") },
        },
    },
    script = "photocopier",
}
