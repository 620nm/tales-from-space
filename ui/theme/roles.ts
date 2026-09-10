// The kit's roles, retuned to the station: what every kit class draws
// with (docs/pack-ui/components.md, "Extending the theme"). `screenRoles`
// is the same set seen through a computer's glass: phosphor ink, a mono
// body face, square corners, the ground docs/LAPTOP.md names.
import type { RolePatch } from "@lunatic/ui";
import {
  alpha, amber, black, dim, face, faceLine, line, phosphor, raised, red,
  screen, surface, teal, ink, bright,
} from "./tokens";

export const roles: RolePatch = {
  surface: alpha(surface, 0.95),
  raised,
  sunken: alpha(black, 0.6),
  field: face,
  ink,
  muted: dim,
  line: faceLine,
  lineStrong: line,
  accent: amber,
  accentInk: surface,
  good: teal,
  warn: amber,
  bad: red,
  focus: amber,
  on: { face: alpha(teal, 0.25), line: teal, ink: bright },
  radius: { sm: 2, md: 2, lg: 3 },
  font: { body: "sans" },
  size: { xs: 8, sm: 11, md: 12, lg: 14 },
  space: { xs: 2, sm: 4, md: 6, lg: 8, xl: 8 },
};

export const screenRoles: RolePatch = {
  ...roles,
  surface: screen,
  ink: phosphor,
  radius: { sm: 0, md: 0, lg: 0 },
  font: { body: "mono" },
};
