// The colour a voice wears over the station, ported from tgstation's
// `colorize_string` (code/__HELPERS/colors.dm:118-153) so a speaker
// keeps one pastel hue wherever they are heard. The band is tg's own
// (code/__DEFINES/colors.dm:536-539); only the hash differs, because a
// UI guest has neither md5 nor a round id to salt one with.

/** tg `CM_COLOR_SAT_MIN`/`MAX`, `CM_COLOR_LUM_MIN`/`MAX`. */
const SAT_MIN = 0.6;
const SAT_MAX = 0.7;
const LUM_MIN = 0.65;
const LUM_MAX = 0.75;

// tg reads three bytes out of `md5(name + round_id)` at a per-round
// offset. A 32-bit FNV-1a over the name stands in: same three bytes,
// same spread, stable for the life of the pack rather than the round.
function digest(name: string): [number, number, number] {
  let hash = 0x811c9dc5;
  for (let index = 0; index < name.length; index += 1) {
    const code = name.charCodeAt(index);
    hash = Math.imul(hash ^ (code & 0xff), 0x01000193) >>> 0;
    hash = Math.imul(hash ^ (code >>> 8), 0x01000193) >>> 0;
  }
  return [(hash >>> 24) & 0xff, (hash >>> 16) & 0xff, (hash >>> 8) & 0xff];
}

const hex = (value: number): string =>
  Math.max(0, Math.min(255, Math.round(value)))
    .toString(16)
    .padStart(2, "0");

/**
 * A six-digit lowercase hex the style grammar accepts, hashed from a
 * speaker's name. tg darkens the same colour by 0.85/0.85 for italics
 * only; nothing on this wire is italic, so only the plain one is ported.
 */
export function voiceColor(name: string): string {
  const [bh, bs, bl] = digest(name);
  const h = bh * (360 / 255);
  const s = (bs >> 2) * ((SAT_MAX - SAT_MIN) / 63) + SAT_MIN;
  const l = (bl >> 2) * ((LUM_MAX - LUM_MIN) / 63) + LUM_MIN;
  const c = (1 - Math.abs(2 * l - 1)) * s;
  // BYOND's `%` truncates both operands, so tg's `(h / 60) % 2` is 0 in
  // even sectors and 1 in odd ones: six flat pastels, not a wheel.
  const x = c * (1 - Math.abs((Math.trunc(h / 60) % 2) - 1));
  const m = l - c * 0.5;
  // tg's `round(h / 60)` floors, so its hue of exactly 360 falls off the
  // end of the switch and answers null. Folding that sixth sector back
  // onto the fifth is the one repair this port makes.
  const sector = Math.min(5, Math.floor(h / 60));
  const hi = (c + m) * 255;
  const mid = (x + m) * 255;
  const lo = m * 255;
  const wheel: [number, number, number][] = [
    [hi, mid, lo],
    [mid, hi, lo],
    [lo, hi, mid],
    [lo, mid, hi],
    [mid, lo, hi],
    [hi, lo, mid],
  ];
  // `sector` is clamped to 0..5 above, so the index cannot miss.
  const [r, g, b] = wheel[sector]!;
  return `#${hex(r)}${hex(g)}${hex(b)}`;
}
