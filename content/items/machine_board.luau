-- One physical machine-board shell, programmed for the machine or
-- structure it will make a frame become. The variants are identities,
-- not procedures: the generic frame reads the installed board's target
-- and requirements, while each product keeps its own behavior in its
-- machine or structure file.
--
-- Stock-part sockets are derived from each product's `parts.slots`
-- (docs/CONTENT-SCHEMA.md §1.10b). A board lists only stack materials
-- which have no socket of their own.
return {
    id = "machine_board",
    name = "unprogrammed machine board",
    sprite = "board",
    inhand_sprite = { "held_board_l", "held_board_r" },
    category = "machine components",
    variants = {
        access_point = {
            name = "machine board (access point)",
            -- A STRUCTURE board, for the same reason the thermomachine's
            -- is one: what it builds has states, a transition table and
            -- -- here -- a wall to hang on, which is what a structure
            -- entry describes and a finished machine cannot.
            --
            -- tg has no board for its wall boxes at all: an APC's
            -- electronics are their own kind of item
            -- (`/obj/item/electronics/apc`, apc_tool_act.dm:19-21) and
            -- the access console has no circuit. One board grammar for
            -- every assembly in this pack is worth more than tg's second
            -- kind of insert, so the wall frame reads a board exactly as
            -- the machine frame does.
            --
            -- Its network socket is the product's and is derived; the
            -- one length of cable is the stack material no socket holds.
            board = {
                structure = "access_point",
                parts = { cable_coil = 1 },
            },
        },
        chem_dispenser = {
            name = "machine board (chem dispenser)",
            -- tg machine_circuitboards.dm:752-762. The two matter bins,
            -- capacitor and servo are product sockets; the pane remains.
            board = {
                machine = "chem_dispenser",
                parts = { glass = 1 },
            },
        },
        chem_heater = {
            name = "machine board (reaction chamber)",
            -- tg machine_circuitboards.dm:803-809. Its micro-laser is a
            -- product socket and the pane is the remaining stack part.
            board = {
                machine = "chem_heater",
                parts = { glass = 1 },
            },
        },
        evaporator = {
            name = "machine board (evaporator)",
            -- Baystation12, not tgstation, which has no such machine:
            -- code/game/objects/items/weapons/circuitboards/machinery/
            -- chemistry.dm:21-25 asks for a micro-laser, a capacitor and
            -- a matter bin. All three are product sockets on the
            -- structure itself, so only the stack materials are here.
            -- This target is a structure because it occupies a pipe run.
            board = {
                structure = "evaporator",
                parts = {
                    cable_coil = 1,
                    glass = 1,
                },
            },
        },
        chemdrobe = {
            name = "machine board (ChemDrobe)",
            board = { machine = "chemdrobe" },
        },
        games_vendor = {
            name = "machine board (Good Clean Fun)",
            board = { machine = "games_vendor" },
        },
        nanomed_plus = {
            name = "machine board (NanoMed Plus)",
            board = { machine = "nanomed_plus" },
        },
        network_router = {
            name = "machine board (network router)",
            -- tg's relay board asks for two servos, two lengths of cable
            -- and two subspace filters
            -- (machine_circuitboards.dm:160-168). The servos and the
            -- filters go: this pack models neither netspeed nor
            -- subspace, and a socket that scales nothing is a socket a
            -- player fills for no reason. The cable is tg's and stays,
            -- halved to the one unit every other board here asks for.
            board = {
                machine = "network_router",
                parts = { cable_coil = 1 },
            },
        },
        transceiver = {
            name = "machine board (transceiver)",
            -- tg's bus mainframe board asks for two servos, a length
            -- of cable and a subspace filter
            -- (machine_circuitboards.dm:106-114). The servos and the
            -- filter model nothing here, per the router row's argument
            -- above; the cable is tg's and stays. The network and
            -- encryption sockets are the product's own and are derived
            -- (machines/transceiver.luau).
            board = {
                machine = "transceiver",
                parts = { cable_coil = 1 },
            },
        },
        steam_generator = {
            name = "machine board (steam generator)",
            -- Baystation12's water-only board, which is the
            -- evaporator's with a different `build_path` and nothing
            -- else (code/game/objects/items/weapons/circuitboards/
            -- machinery/chemistry.dm:30-32).
            board = {
                structure = "steam_generator",
                parts = {
                    cable_coil = 1,
                    glass = 1,
                },
            },
        },
        thermomachine = {
            name = "machine board (temperature control unit)",
            -- tg machine_circuitboards.dm:406-415. The bins and lasers
            -- are sockets; cable and glass are stack materials. This
            -- target is a structure because it occupies a pipe run.
            board = {
                structure = "thermomachine",
                parts = {
                    cable_coil = 1,
                    glass = 1,
                },
            },
        },
        tool_vendor = {
            name = "machine board (YouTool)",
            board = { machine = "tool_vendor" },
        },
        tv = {
            name = "machine board (television)",
            board = { machine = "tv" },
        },
        vendor = {
            name = "machine board (vending)",
            board = { machine = "vendor" },
        },
    },
}
