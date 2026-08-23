-- A power socket on the wall: the branch circuit's public face, and
-- what a corded appliance plugs into.
--
-- ELECTRICAL, not atmospheric. It has nothing to do with air -- the fan
-- that blows a room full of it is `vent.luau`, an ordinary machine in
-- the plumbing.
return {
    id = "outlet",
    name = "power outlet",
    sprite = "outlet",
    fixture = "Outlet",
    category = "power",
    examine = {
        flavor = "A socket at knee height. Whatever is plugged in draws "
            .. "from this room's own circuit.",
    },
}
