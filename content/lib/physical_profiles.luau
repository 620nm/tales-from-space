-- Pack-owned physical defaults for loose entities. The engine does not infer
-- an item's mass; every throwable item opts into one of these profiles.
-- Ordinary carried objects use one kilogram, while unusually large objects
-- declare a more suitable value beside their prototype.
return {
    loose_item1kg = {
        mass = 1.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.25,
        public_contacts = true,
    },
}
