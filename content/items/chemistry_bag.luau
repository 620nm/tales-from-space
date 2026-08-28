-- tg's chemistry bag is a belt container for pills, patches and vessels
-- (code/game/objects/items/storage/bags.dm:429-436; its accepted roster
-- is code/datums/storage/subtypes/bags.dm:142-158). TfS containers do
-- not yet filter insertions, but the belt slot and seven usable pockets
-- preserve the implemented parts of that contract.
return {
    id = "chemistry_bag",
    name = "chemistry bag",
    sprite = "chemistry_bag",
    slot = "belt",
    storage = 7,
}
