"""Pixel library: the 3/4-perspective hexagonal concrete & brass intake head.

Not a shipped source: `spec_intake_floor` and `spec_intake_ceiling` draw these pixels into
their `head` layers; the kit validates this spec but exports nothing for it.
32x32 RGBA (24x24 occupied at x=4..27, y=3..26), 1 static frame.
Layers, bottom to top: intake_chamber, copper_ring, trash_rack_grille, concrete_hexagon_cap.
"""

from __future__ import annotations

from typing import Any

EMPTY = "." * 32


def _r(span24: str) -> str:
    assert len(span24) == 24, f"Expected 24-char x=4..27 span, got {len(span24)}: {span24!r}"
    return f"....{span24}...."


SPEC: dict[str, Any] = {
    "name": "intake_head",
    "kind": "intake_head",
    "title": "Intake Head (3/4 Crown, pixel library)",
    "width": 32,
    "height": 32,
    "blurb": (
        "3/4-perspective hexagonal intake head (24×24 at x=4..27, y=3..26 on a 32×32 transparent canvas) "
        "in warm ceramic-concrete and brushed khaki-brass. Dry interior: zero internal water animation."
    ),
    "design_notes": (
        "Hexagonal concrete cap with four raised brass corner lifting lugs, 12 vertical brass bars per "
        "front-left/front-right grille face (1px gaps, 2px horizontal cross-tie), inner copper-orange ring header + "
        "vertical drop riser, and dark S1/M2 outer contour (0 shared boundary hexes against the open hatch at dy=0)."
    ),
    "frame_count": 1,
    "frame_durations_ms": [100],
    "tags": [{"name": "idle", "from": 1, "to": 1}],
    "layers": [
        {
            "name": "intake_chamber",
            "animated": False,
            "legend": {
                "K": "BLK",
                "m": "M1",
            },
            "rows": [
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                _r("..mm................mm.."),  # y=10
                _r("..mmK..............Kmm.."),  # y=11
                _r("..mKK..............KKm.."),  # y=12
                _r("..mKK..mKKKKKKKKm..KKm.."),  # y=13
                _r("..mKK..KKKKKKKKKK..KKm.."),  # y=14
                _r("..mKK..KKKKKKKKKK..KKm.."),  # y=15
                _r("..mKK..KKKKKKKKKK..KKm.."),  # y=16
                _r("..mKK..KKKKKKKKKK..KKm.."),  # y=17
                _r("..mKK..KKKKKKKKKK..KKm.."),  # y=18
                _r("..mKK..KKKKKKKKKK..KKm.."),  # y=19
                _r("...mK..KKKKKKKKKK..Km..."),  # y=20
                _r(".......mKKKKKKKKm......."),  # y=21
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
            ],
        },
        {
            "name": "copper_ring",
            "animated": False,
            "legend": {
                "G": "CU5",
                "C": "CU4",
                "U": "CU3",
                "u": "CU2",
            },
            "rows": [
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                _r(".........UCGGCU........."),  # y=14: 2px CU5 center glint at x=15..16
                _r(".......UCCuuuuCCU......."),  # y=15: CU4/CU3/CU2 manifold ring
                _r("...CU..uu......uu..UC..."),  # y=16: side window copper ring
                _r("..uu................uu.."),  # y=17: shaded lower copper rim
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
            ],
        },
        {
            "name": "trash_rack_grille",
            "animated": False,
            "legend": {
                "6": "S6",
                "5": "S5",
                "4": "S4",
                "3": "S3",
                "2": "S2",
            },
            "rows": [
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                _r("...3................3..."),  # y=10
                _r("...4................4..."),  # y=11
                _r("...5................5..."),  # y=12
                _r("...5....4.4..4.4....4..."),  # y=13
                _r("...5....6.6..6.6....5..."),  # y=14
                _r("...4....5.6..6.5....4..."),  # y=15
                _r("...4....5.5..5.5....4..."),  # y=16
                _r("...3....4.4..4.4....3..."),  # y=17
                _r("...3....4.4..4.4....3..."),  # y=18
                _r("...2....3.3..3.3....2..."),  # y=19
                _r("...2....3.3..3.3....2..."),  # y=20
                _r("........2.2..2.2........"),  # y=21
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
            ],
        },
        {
            "name": "concrete_hexagon_cap",
            "animated": False,
            "legend": {
                "T": "CE3",
                "6": "N6",
                "C": "CE2",
                "c": "CE1",
                "3": "N3",
                "2": "N2",
                "1": "N1",
                "K": "CK3",
                "B": "CK2",
                "b": "CK1",
                "e": "EY1",
            },
            "rows": [
                EMPTY,
                EMPTY,
                EMPTY,
                _r("......KBTTTTTTTTBK......"),  # y=3: NW/NE CK3/CK2 lugs + 1-2px sunlit CE3 top bevel
                _r("....22beTTTTTTTTeb22...."),  # y=4: 2px sunlit CE3 north bevel + lug bases
                _r("..22TTCCCCCCCCCCCCTT22.."),  # y=5: CE3 corner bevels + calm CE2 upper slab
                _r("KBCCCC66KKKKKKKK66CCCCBK"),  # y=6: W/E CK3/CK2 lugs + calm CE2 + N6 rim + CK3 boss top
                _r("beCCCC6KBBBBBBBBK6CCCCeb"),  # y=7: W/E lug bases + calm CE2 + N6 rim + CK2 boss
                _r("22CCCC6BbbbbbbbbB6CCCC22"),  # y=8: calm CE2 + N6 rim + CK1 boss
                _r("2c23cc6beeeeeeeeb6cc32c2"),  # y=9: calm CE1 lower slab + N6 rim + EY1 boss base
                _r("2c..2KBccccccccccBK2..c2"),  # y=10: SW/SE CK3/CK2 lugs + calm CE1 slab
                _r("2c...be6666666666eb...c2"),  # y=11: SW/SE lug bases + N6 front inner rim
                _r("2c...C322222111113C...c2"),  # y=12
                _r("2c...C3..........3C...c2"),  # y=13
                _r("2c...C3..........3C...c2"),  # y=14
                _r("2c...C3..........3c...c2"),  # y=15
                _r("2c...c3..........3c...32"),  # y=16
                _r("23...c3..........3c...32"),  # y=17
                _r("23...c3..........3c...22"),  # y=18
                _r("23...KB..........BK...22"),  # y=19: lower mullion CK3/CK2 brass bushings
                _r("23c..be..........eb..c32"),  # y=20
                _r("12cc322..........223cc21"),  # y=21
                _r(".123333CCCCCCcccc333321."),  # y=22
                _r("..12233333333333333221.."),  # y=23
                _r("...111222222222222111..."),  # y=24
                _r(".....1233cccccc3321....."),  # y=25
                _r(".....11133cccc33111....."),  # y=26
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
                EMPTY,
            ],
        },
    ],
}
