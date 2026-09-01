-- A network interface card: the stock part that gives a device its
-- ADDRESS.
--
-- It is two declarations at once, and both of them matter. The
-- `component` half makes it a thing that fits a socket, exactly as a
-- micro-laser or a matter bin does (docs/CONTENT-SCHEMA.md §1.10b). The
-- `link` half makes it an INTERFACE: it is minted one address when it
-- is spawned, keeps it for the whole shift, and lends it to whatever it
-- is fitted into (docs/DEVICES.md §5a).
--
-- WHY THE ADDRESS IS THE CARD'S AND NOT THE BOX'S. Pull the card and
-- the box goes quiet without forgetting anything -- the joins are on
-- the address, and the address is in your hand. Fit it into another
-- socketed thing and that thing inherits the whole branch, still
-- joined. Nothing implements that; it falls out of naming the card.
-- Which is also why a stolen card is worth stealing.
--
-- There is ONE rung of this ladder and there is not meant to be a
-- second. Every other stock part in the pack orders four tiers because
-- a better one makes a machine work harder (lib/stock_parts.luau);
-- nothing about carrying an address is done better by a nicer card, so
-- a tier two would be a rung with nothing on it.
return {
    id = "network_card",
    name = "network card",
    sprite = "network_card",
    examine = {
        flavor = "A short green card with a wire socket at one end. Every "
            .. "one is stamped with an address, and no two are stamped alike.",
    },
    component = { kind = "network", tier = 1, efficiency = stock_parts.efficiency[1] },
    link = { interface = true },
}
