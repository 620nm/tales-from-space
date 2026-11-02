"""The sump pump: a bilge manifold body between two tarnished-brass grates, on both pipe axes.

32x32 RGBA, 12 frames: E-W manifold on frames 1..6, N-S manifold on 7..12, each off (1),
pumping (4), fault (1). Tags `<state>-<dir>`: e and w share the E-W frames, n and s the
N-S frames, so a facing always meets the solid spine. Layers, bottom to top:
pump_housing_and_sump (static per axis), impeller_and_water (animated), top_grille_and_hub
(static per axis). The rules are docs/art-reference/drainage-asset-guide.md.
"""

from __future__ import annotations

import math
from typing import Any

Grid = list[list[str]]


def blank_grid(fill: str = ".") -> Grid:
    return [[fill for _ in range(32)] for _ in range(32)]


def to_rows(g: Grid) -> list[str]:
    return ["".join(r) for r in g]


def paste_ascii(g: Grid, x0: int, y0: int, lines: list[str]) -> None:
    for dy, line in enumerate(lines):
        for dx, ch in enumerate(line):
            if ch != " ":
                g[y0 + dy][x0 + dx] = ch


def build_east_west() -> dict[str, Any]:
    # 19x19 rounded-square/octagonal body at x=6..24, y=6..24 (by=6 clears the y=5 north pipe mouth):
    #   - Flat S2/S3/S4/S5 outer housing split horizontally by an E-W steel pump manifold bridge (y=14..16)
    #   - Symmetrical 2x1 status LEDs at x=9..10 and x=20..21 (y=15) + central EY1-bezeled 3x2 CK2 brass cap
    #   - Upper (y=9..13) and lower (y=17..21) recessed tarnished-brass waffle/cross-grate intake bays over M1/BLK sump.
    housing = blank_grid()
    housing_art = [
        "...2222222222222...",  # y=6  (13) vent_off-style wider flat N rim at y=6
        ".33555566666555533.",  # y=7  (17) soft S3 chamfer + flat S5/sparse N5 collar
        ".35544444444444553.",  # y=8  (17) inner bezel step
        "2541100000000011452",  # y=9  (19) upper wet sump bay opens (M1/BLK)
        "2540000000000000452",  # y=10 (19)
        "2540000000000000452",  # y=11 (19)
        "2540000000000000452",  # y=12 (19)
        "2541100000000011452",  # y=13 (19)
        "2554444444444444552",  # y=14 (19) E-W manifold bridge seat
        "2443333333333333442",  # y=15 (19) manifold mid
        "2443333333333333442",  # y=16 (19) manifold lower
        "2441100000000011442",  # y=17 (19) lower wet sump bay opens
        "2440000000000000442",  # y=18 (19) S4 inner wall contrasts cleanly with EY1 lower brass ends
        "2440000000000000442",  # y=19 (19)
        "2440000000000000442",  # y=20 (19)
        "2441100000000011442",  # y=21 (19)
        ".34444444444444443.",  # y=22 (17) flat S4 south collar
        ".33444444444444433.",  # y=23 (17) soft S3 south chamfer
        "...2222222222222...",  # y=24 (13) flat S2 south edge
    ]
    paste_ascii(housing, 6, 6, housing_art)

    # Layer 3: top_grille_and_hub
    # Upper (y=9..13) & lower (y=17..21) recessed tarnished-brass cross-grates (K=CK2, k=CK1, e=EY1)
    # + E-W steel pump manifold bridge (y=14..16 in S5/S4) with EY1-bezeled 3x2 CK2 central brass cap
    # and symmetrical 2x1 LED windows left '.' at cols 3..4 (x=9..10) and cols 14..15 (x=20..21) on y=15!
    grille = blank_grid()
    grille_art = [
        "...................",  # y=6
        "...................",  # y=7
        "...................",  # y=8
        ".....K...K...K.....",  # y=9   upper brass cross-grate vertical bars (CK2 vs S4: |dY|=42.2!)
        ".....K...K...K.....",  # y=10
        "...KKKKKKKKKKKKK...",  # y=11  upper brass cross-grate horizontal bar (CK2)
        ".....k...k...k.....",  # y=12  CK1 lower half of upper grate (meets S5 manifold: |dY|=31.3!)
        ".....k...k...k.....",  # y=13
        "..55555eKKKe55555..",  # y=14  E-W steel manifold top + EY1 bezel + 3x2 CK2 central brass cap
        "..4..45eKKKe54..4..",  # y=15  2x1 LEDs at x=9..10 & x=20..21 + central brass cap!
        "..44444eeeee44444..",  # y=16  E-W steel manifold bottom + EY1 brass cap undercut (|dY|=37.3!)
        ".....e...e...e.....",  # y=17  lower brass cross-grate vertical bars (EY1 vs S4: |dY|=37.3!)
        ".....e...e...e.....",  # y=18
        "...eekkkkkkkkkee...",  # y=19  lower tarnished-brass bar (CK1 center, EY1 ends vs S4: |dY|=37.3!)
        ".....e...e...e.....",  # y=20
        ".....e...e...e.....",  # y=21  meets S4 south collar with |dY|=37.3!
        "...................",  # y=22
        "...................",  # y=23
        "...................",  # y=24
    ]
    paste_ascii(grille, 6, 6, grille_art)

    led_pts = [(9, 15), (10, 15), (20, 15), (21, 15)]
    bay_pts: list[tuple[int, int]] = []
    for y in list(range(9, 14)) + list(range(17, 22)):
        for x in range(8, 23):
            if housing[y][x] in ("0", "1") and grille[y][x] == ".":
                bay_pts.append((x, y))

    imp_frames: list[list[str]] = []

    # Frame 1: off (calm symmetric dark MB1 bilge shadow adjacent to central manifold + M5 unlit 2x1 LEDs)
    f_off = blank_grid()
    for x, y in bay_pts:
        if y in (13, 17) and 12 <= x <= 18:
            f_off[y][x] = "b"
    for lx, ly in led_pts:
        f_off[ly][lx] = "u"
    imp_frames.append(to_rows(f_off))

    # Frames 2..5: pumping (4-phase inward suction along the 8 inner manifold waffle cells + steady outer shadow + AT2/AT3 LEDs)
    for phase in range(4):
        fg = blank_grid()
        for x, y in bay_pts:
            if y in (12, 13, 17, 18):
                # 4 vertical columns of waffle cells: col_idx 0 (x=9..10), 1 (x=12..14), 2 (x=16..18), 3 (x=20..21)
                col_idx = 0 if x < 11 else (1 if x < 15 else (2 if x < 19 else 3))
                st = (col_idx + (phase if y < 15 else -phase)) % 4
                if st == 0:
                    fg[y][x] = "g"
                elif st == 1:
                    fg[y][x] = "a"
                elif st == 2:
                    fg[y][x] = "b"
            elif y in (10, 20) and 12 <= x <= 18:
                fg[y][x] = "b"
        # Outer pixel AT2, inner pixel AT3 on each 2x1 lens
        fg[15][9], fg[15][10] = "t", "T"
        fg[15][20], fg[15][21] = "T", "t"
        imp_frames.append(to_rows(fg))

    # Frame 6: fault (stagnant backed-up murky bilge RB2/MB1/AT1 filling waffle cells + FR2/FR3 crimson fault LEDs)
    f_fault = blank_grid()
    for x, y in bay_pts:
        if y in (9, 12, 17, 20):
            f_fault[y][x] = "r"  # RB2 dark meniscus under each horizontal rim/bar
        else:
            f_fault[y][x] = "a" if 12 <= x <= 18 and y <= 14 else "b"
    f_fault[15][9], f_fault[15][10] = "f", "R"
    f_fault[15][20], f_fault[15][21] = "R", "f"
    imp_frames.append(to_rows(f_fault))

    return {
        "frame_durations_ms": [100, 200, 200, 200, 200, 100],
        "layers": [
            {
                "name": "pump_housing_and_sump",
                "animated": False,
                "legend": {
                    "0": "BLK", "1": "M1",
                    "2": "S2", "3": "S3", "4": "S4", "5": "S5", "6": "N5",
                },
                "rows": to_rows(housing),
            },
            {
                "name": "impeller_and_water",
                "animated": True,
                "legend": {
                    "u": "M5",
                    "b": "MB1", "a": "AT1", "g": "G1", "r": "RB2",
                    "t": "AT2", "T": "AT3",
                    "f": "FR2", "R": "FR3",
                },
                "frames": imp_frames,
            },
            {
                "name": "top_grille_and_hub",
                "animated": False,
                "legend": {
                    "4": "S4", "5": "S5",
                    "e": "EY1", "k": "CK1", "K": "CK2",
                },
                "rows": to_rows(grille),
            },
        ],
    }


def build_north_south() -> dict[str, Any]:
    # North-lit 90-degree counterpart of the E-W axis, for north and south pipes:
    #   - Exact 19x19 rounded-chamfer outer frame preserving North-top lighting (S5/N5 top collar -> S4/S3/S2 south)
    #   - Solid N-S central steel manifold bridge (x=13..17 housing backing, x=14..16 S5/N4 spine, twin 1x2 LEDs at
    #     (15,9..10) & (15,20..21), and EY1-bezeled 3x2 CK2 central brass impeller cap at x=14..16, y=14..15)
    #   - Left (x=9..12) & Right (x=18..21) recessed tarnished-brass waffle grates graded top-to-bottom (CK2 -> CK1 -> EY1).
    housing = blank_grid()
    housing_art = [
        "...2222222222222...",  # y=6  (13) flat N rim in S2
        ".33555566666555533.",  # y=7  (17) soft S3 chamfer + S5/N5 sunlit top collar
        ".35544444444444553.",  # y=8  (17) inner bezel + N manifold seat
        "2541100433340011452",  # y=9  (19) L & R wet sump bays (x=9..12, 18..21) + N-S manifold backing (x=13..17)
        "2540000433340000452",  # y=10 (19)
        "2540000433340000452",  # y=11 (19)
        "2540000433340000452",  # y=12 (19)
        "2540000433340000452",  # y=13 (19)
        "2520000433340000252",  # y=14 (19) S2 outer sump shadow groove (contrasts CK1 mid crossbar |dY|=36.2!)
        "2420000433340000242",  # y=15 (19)
        "2420000433340000242",  # y=16 (19)
        "2440000433340000442",  # y=17 (19) S4 walls contrast EY1 lower brass crossbars (|dY|=37.3!)
        "2440000433340000442",  # y=18 (19)
        "2440000433340000442",  # y=19 (19)
        "2440000433340000442",  # y=20 (19)
        "2441100433340011442",  # y=21 (19) M1 sump corners
        ".34444444444444443.",  # y=22 (17) flat S4 south collar
        ".33444444444444433.",  # y=23 (17) soft S3 south chamfer
        "...2222222222222...",  # y=24 (13) flat S2 south edge
    ]
    paste_ascii(housing, 6, 6, housing_art)

    # Layer 3: top_grille_and_hub
    # Vertical N-S steel manifold spine (x=14..16: S5 upper y=8..12, EY1-bezeled 3x2 CK2 central brass cap y=13..16,
    # N4/S4 lower spine y=17..22) with twin 1x2 LEDs at (15,9..10) & (15,20..21), flanked by Left & Right brass grates.
    grille = blank_grid()
    grille_art = [
        "...................",  # y=6
        "...................",  # y=7
        "........555........",  # y=8   N manifold spine top (x=14..16)
        ".....K..5.5..K.....",  # y=9   upper 1x2 LED at (15,9..10) + L/R CK2 vertical bars
        ".....K..5.5..K.....",  # y=10
        "...KKKK.555.KKKK...",  # y=11  upper CK2 horizontal crossbars (|dY|=42.2 vs S4!)
        ".....K..555..K.....",  # y=12  CK2 upper-mid vertical bar
        ".....k.eeeee.k.....",  # y=13  CK1 mid vertical bar + EY1 top bezel on central boss
        ".....k.eKKKe.k.....",  # y=14  3x2 CK2 central brass impeller cap (row 1)
        "...kkkkeKKKekkkk...",  # y=15  middle CK1 crossbars + 3x2 CK2 central brass impeller cap (row 2)
        ".....k.eeeee.k.....",  # y=16  CK1 mid vertical bar + EY1 undercut on central boss
        ".....e..444..e.....",  # y=17  EY1 lower vertical bar + S4 lower spine
        ".....e..444..e.....",  # y=18
        "...eeee.444.eeee...",  # y=19  lower EY1 crossbars (|dY|=37.3 vs S4!)
        ".....e..4.4..e.....",  # y=20  lower 1x2 LED at (15,20..21)
        ".....e..4.4..e.....",  # y=21
        "........444........",  # y=22  S manifold spine foot (x=14..16)
        "...................",  # y=23
        "...................",  # y=24
    ]
    paste_ascii(grille, 6, 6, grille_art)

    led_pts = [(15, 9), (15, 10), (15, 20), (15, 21)]
    bay_pts: list[tuple[int, int]] = []
    for y in range(9, 22):
        for x in list(range(9, 13)) + list(range(18, 22)):
            if housing[y][x] in ("0", "1") and grille[y][x] == ".":
                bay_pts.append((x, y))

    imp_frames: list[list[str]] = []

    # Frame 1: off (calm symmetric dark MB1 bilge shadow adjacent to N-S manifold + M5 unlit 1x2 LEDs)
    f_off = blank_grid()
    for x, y in bay_pts:
        if x in (12, 18) and 12 <= y <= 18:
            f_off[y][x] = "b"
    for lx, ly in led_pts:
        f_off[ly][lx] = "u"
    imp_frames.append(to_rows(f_off))

    # Frames 2..5: pumping (4-phase inward suction across Left & Right waffle bays into N-S manifold + AT2/AT3 LEDs)
    for phase in range(4):
        fg = blank_grid()
        for x, y in bay_pts:
            if y in (12, 13, 14, 16, 17, 18):
                inward_col = 1 if x in (12, 18) else 0
                cell_q = (0 if y < 15 else 2) + (0 if x < 15 else 1)
                st = (cell_q + inward_col - phase) % 4
                if st == 0:
                    fg[y][x] = "g"
                elif st == 1:
                    fg[y][x] = "a"
                elif st == 2:
                    fg[y][x] = "b"
            elif y in (10, 20) and x in (9, 10, 20, 21):
                fg[y][x] = "b"
        # Outer pixel AT2, inner pixel AT3 on each vertical 1x2 lens
        fg[9][15], fg[10][15] = "t", "T"
        fg[20][15], fg[21][15] = "T", "t"
        imp_frames.append(to_rows(fg))

    # Frame 6: fault (stagnant backed-up murky bilge RB2/MB1/AT1 filling waffle cells + FR2/FR3 crimson fault LEDs)
    f_fault = blank_grid()
    for x, y in bay_pts:
        if y in (9, 12, 16, 20):
            f_fault[y][x] = "r"  # RB2 dark meniscus under each horizontal rim/crossbar
        else:
            f_fault[y][x] = "a" if x in (12, 18) and y <= 14 else "b"
    f_fault[9][15], f_fault[10][15] = "f", "R"
    f_fault[20][15], f_fault[21][15] = "R", "f"
    imp_frames.append(to_rows(f_fault))

    return {
        "frame_durations_ms": [100, 200, 200, 200, 200, 100],
        "layers": [
            {
                "name": "pump_housing_and_sump",
                "animated": False,
                "legend": {
                    "0": "BLK", "1": "M1",
                    "2": "S2", "3": "S3", "4": "S4", "5": "S5", "6": "N5",
                },
                "rows": to_rows(housing),
            },
            {
                "name": "impeller_and_water",
                "animated": True,
                "legend": {
                    "u": "M5",
                    "b": "MB1", "a": "AT1", "g": "G1", "r": "RB2",
                    "t": "AT2", "T": "AT3",
                    "f": "FR2", "R": "FR3",
                },
                "frames": imp_frames,
            },
            {
                "name": "top_grille_and_hub",
                "animated": False,
                "legend": {
                    "4": "S4", "5": "S5",
                    "e": "EY1", "k": "CK1", "K": "CK2",
                },
                "rows": to_rows(grille),
            },
        ],
    }


def join_axes(ew: dict[str, Any], ns: dict[str, Any]) -> dict[str, Any]:
    """One spec of twelve frames: the E-W axis, then the N-S axis, with one legend per layer."""
    joined = []
    for lyr_ew, lyr_ns in zip(ew["layers"], ns["layers"], strict=True):
        assert lyr_ew["name"] == lyr_ns["name"], lyr_ew["name"]
        assert lyr_ew["legend"] == lyr_ns["legend"], lyr_ew["name"]
        frames_ew = lyr_ew["frames"] if "frames" in lyr_ew else [lyr_ew["rows"]] * 6
        frames_ns = lyr_ns["frames"] if "frames" in lyr_ns else [lyr_ns["rows"]] * 6
        joined.append({
            "name": lyr_ew["name"],
            "animated": lyr_ew["animated"],
            "legend": lyr_ew["legend"],
            "frames": frames_ew + frames_ns,
        })
    tags = []
    for state, first, last in (("off", 1, 1), ("pumping", 2, 5), ("fault", 6, 6)):
        for suffix, base in (("e", 0), ("w", 0), ("n", 6), ("s", 6)):
            tags.append({"name": f"{state}-{suffix}", "from": first + base, "to": last + base})
    return {
        "name": "sump_pump",
        "title": "Sump Pump",
        "kind": "sump_pump",
        "width": 32,
        "height": 32,
        "blurb": "19x19 bilge manifold pump: chamfered-square flat steel frame split by a solid manifold spine (twin LEDs + brass cap) between two tarnished-brass waffle grates.",
        "design_notes": "The spine lies across the frame on E-W frames and down it on N-S frames, so a pipe mouth meets solid steel on every facing; both axes keep the north-top lighting.",
        "frame_count": 12,
        "frame_durations_ms": ew["frame_durations_ms"] + ns["frame_durations_ms"],
        "tags": tags,
        "layers": joined,
    }


SPEC: dict[str, Any] = join_axes(build_east_west(), build_north_south())
