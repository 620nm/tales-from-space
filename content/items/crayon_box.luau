-- The box is native storage stocked with one thirty-use stick of each
-- colour. The sticks are ordinary items, so taking and returning them uses
-- the same capacity and custody rules as every other container.
-- tg crayons.dm:24-74, :628-634, :726-752.
local content = {
    id = "crayon_box",
    name_label = "lunatic/tfs:entity.crayon_box.name",
    name = "box of crayons",
    sprite = "crayon_box",
    storage = 7,
    show_contents = true,
    holds = {
        "crayon_red", "crayon_orange", "crayon_yellow", "crayon_green",
        "crayon_blue", "crayon_purple", "crayon_black",
    },
}

return content
