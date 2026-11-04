-- What a vendor board builds. The frame never knew this; the board
-- named it, and this file says what the name means.
--
-- `vends` is the whole of the shelf: the engine reads the shape of a
-- product list and builds a clean-room document from it, and knows the
-- name of nothing on it.
return {
    id = "vendor",
    visual_layer = "fixture",
    energy_network = "power",
    name_label = "lunatic/tfs:entity.vendor.name",
    name = "Robust Softdrinks vending machine",
    sprite = "vendor",
    ui = { modules = { "shelf" }, opens_on_click = false },
    sounds = { dispense = "vend" },
    dense = true,
    script = "vendor",
    actions = {
        {
            id = "browse",
            gesture = "primary",
            route = "receiver",
            label = "lunatic/tfs:ui.affordance.browse_shelf",
        },
        {
            id = "return_empty",
            gesture = "primary",
            route = "receiver",
            label = "lunatic/tfs:ui.affordance.return_empty",
            held = { fact = "held.proto", value = "bottle" },
            uses_held = true,
            suggest = true,
            suggest_implement = { item = "bottle" },
        },
    },
    corded = true,
    ad = "Robust! Refreshing! Occasionally fermented!",
    categories = { "Drinks" },
    vends = {
        { item = "cola", name = "Space Cola", category = "Drinks", amount = 99 },
    },
}
