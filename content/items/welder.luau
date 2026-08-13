-- The engineer's answer to a hull breach. The "weld" tool tag is what
-- the Interact path checks; at M4-completion this becomes an on_interact
-- hook instead of a native tag.
return {
    id = "welder",
    name = "welding tool",
    sprite = "welder",
    tool = "weld",
}
