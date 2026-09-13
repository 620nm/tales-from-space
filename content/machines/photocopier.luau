-- A powered paper copier. Resource quantities and the source sheet are
-- native machine state; the fixture only names the player-facing actions.
-- tg code/modules/paperwork/photocopier.dm:60-65, :140-152, :281-379.
return {
    id = "photocopier",
    name_label = "lunatic/tfs:entity.photocopier.name",
    name = "photocopier",
    sprite = "photocopier",
    states = { "closed", "open", "printing" },
    state = "closed",
    dense = true,
    corded = true,
    drive = { accepts = { "paper" } },
    resources = {
        paper = { capacity = 30, initial = 30 },
        toner = { capacity = 30, initial = 30 },
    },
    ui = {
        modules = { "actions" }, opens_on_click = false,
        actions = {
            { key = "copy", label = "lunatic/tfs:action.photocopier.copy" },
            { key = "eject", label = "lunatic/tfs:action.photocopier.eject" },
            { key = "set_count", label = "lunatic/tfs:action.photocopier.set_count" },
            { key = "set_color", label = "lunatic/tfs:action.photocopier.set_color" },
        },
    },
    script = "photocopier",
}
