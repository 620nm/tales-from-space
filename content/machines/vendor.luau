-- What a vendor board builds. The frame never knew this; the board
-- named it, and this file says what the name means.
--
-- `vends` is the whole of the shelf: the engine reads the shape of a
-- product list and drives tg's Vending window off it, and knows the
-- name of nothing on it.
return {
    id = "vendor",
    name = "Robust Softdrinks vending machine",
    sprite = "vendor",
    dense = true,
    script = "vendor",
    corded = true,
    ad = "Robust! Refreshing! Occasionally fermented!",
    categories = { Drinks = "basket-shopping" },
    vends = {
        { item = "cola", name = "Space Cola", category = "Drinks", amount = 99 },
    },
}
