-- One-sheet fax endpoint. The network service directory is native; this
-- declaration supplies the endpoint socket and names the script bridge.
-- tg code/modules/paperwork/fax.dm:222-237, :294-351, :406-428.
local printing = require("@lib/printing")

local ui_label = require("@lib/ui_label")

return {
    id = "fax",
    entity_class = "installed",
    actions = printing.actions(),
    visual_layer = "fixture",
    energy_network = "power",
    name_label = "lunatic/tfs:entity.fax.name",
    name = "fax machine",
    sprite = "fax",
    dense = true,
    corded = true,
    drive = { accepts = { "paper" } },
    resources = {
        paper = { capacity = 30, initial = 30 },
        toner = { capacity = 30, initial = 30 },
    },
    parts = { slots = { "network" } },
    link = { role = "endpoint", class = "fax", socket = "network" },
    -- The pack provider owns the endpoint window; native link/actions
    -- modules remain available to the generic machine contract without
    -- stealing the click from the provider.
    ui = {
        modules = { "link", "actions" },
        opens_on_click = false,
        actions = {
            { key = "advertise", label = ui_label.pack("lunatic/tfs:action.fax.advertise") },
            { key = "name", label = ui_label.pack("lunatic/tfs:action.fax.name") },
            { key = "target", label = ui_label.pack("lunatic/tfs:action.fax.target") },
            { key = "page", label = ui_label.pack("lunatic/tfs:action.fax.page") },
            { key = "confirm", label = ui_label.pack("lunatic/tfs:action.fax.confirm") },
            { key = "cancel", label = ui_label.pack("lunatic/tfs:action.fax.cancel") },
            { key = "send", label = ui_label.pack("lunatic/tfs:action.fax.send") },
            { key = "eject", label = ui_label.pack("lunatic/tfs:action.fax.eject") },
        },
    },
    script = "fax",
}
