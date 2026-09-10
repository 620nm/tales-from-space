// The overlay package's sheet. A theme is adopted per package, so this
// one carries the chrome it shares with the HUD rather than inheriting
// it: the same `theme/kit.ts` both are built out of, then the rules
// only the hover card draws with.
import type { UiStyleRule } from "@lunatic/ui";
import { defineStyles } from "@lunatic/ui";
import { kitRules } from "../theme/kit";
import { overlayRules } from "../theme/overlay";

export default defineStyles([...kitRules, ...overlayRules] as UiStyleRule[]);
