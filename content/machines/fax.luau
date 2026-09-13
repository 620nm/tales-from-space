-- One-sheet fax endpoint. The network service directory is native; this
-- declaration supplies the endpoint socket and names the script bridge.
-- tg code/modules/paperwork/fax.dm:222-237, :294-351, :406-428.
return {
    id = "fax",
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
        modules = { "link", "actions" }, opens_on_click = false,
        actions = {
            { key = "advertise", label = "lunatic/tfs:action.fax.advertise" },
            { key = "name", label = "lunatic/tfs:action.fax.name" },
            { key = "target", label = "lunatic/tfs:action.fax.target" },
            { key = "page", label = "lunatic/tfs:action.fax.page" },
            { key = "confirm", label = "lunatic/tfs:action.fax.confirm" },
            { key = "cancel", label = "lunatic/tfs:action.fax.cancel" },
            { key = "send", label = "lunatic/tfs:action.fax.send" },
            { key = "eject", label = "lunatic/tfs:action.fax.eject" },
        },
    },
    script = "fax",
}
