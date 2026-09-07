// The overlay package's sheet. A theme is adopted per package, so this
// one restates the chrome it shares with the HUD rather than inheriting
// it: the same `theme-base.ts` both are built out of, then the rules
// only these two surfaces use.
import type { UiStyleRule } from "@lunatic/ui";
import { defineStyles } from "@lunatic/ui";
import { baseRules } from "../theme-base";
import { overlayRules } from "../theme-overlay";

export default defineStyles([...baseRules, ...overlayRules] as UiStyleRule[]);
