// The HUD's own rules: the tray, the worn cluster, the action bar and the
// storage trays. `theme.ts` appends them last, so anything declared here
// wins over the base system for the classes those screens wear.
import type { UiStyleRule } from "@lunatic/ui";

export const hudRules: UiStyleRule[] = [];
