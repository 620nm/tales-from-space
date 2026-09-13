import type { UiNode } from "@lunatic/ui";
import { Card, Stack } from "@lunatic/ui";
import { text } from "../../view";
import { initials, type StaffProfile } from "../model";
import * as S from "../strings";

export interface IdentityCardOptions {
  open?: UiNode | null;
  timeline?: UiNode | null;
  header?: UiNode | null;
  context?: string;
}

/** Shared account card: portrait left, two identity lines, timeline right. */
export function identityCard(id: string, profile: StaffProfile | null | undefined, options: IdentityCardOptions = {}): UiNode {
  if (!profile) return Card(id, [text(`${id}/empty`, S.NO_ACCOUNT, ["staff-muted"])], { cls: ["staff-profile", "staff-profile-empty"] });
  const avatar: UiNode = {
    id: `${id}/avatar`, type: "panel", class: ["staff-avatar-wrap"],
    style: { position: "relative", width: 34, height: 34, minWidth: 34 },
    children: [
      text(`${id}/avatar/fallback`, initials(profile.username), [], { position: "absolute", left: 0, right: 0, top: 0, bottom: 0, display: "flex", alignItems: "center", justifyContent: "center" }),
      { id: `${id}/avatar/image`, type: "image", asset: `profile-avatar:${profile.avatar}`, text: profile.username, class: ["staff-avatar", "staff-avatar-portrait"], style: { position: "absolute", left: 0, top: 0 } },
    ],
  };
  const identity = Stack(`${id}/identity`, [
    avatar,
    { id: `${id}/copy`, type: "column", class: ["staff-profile-copy"], children: [
      text(`${id}/username`, profile.username, ["staff-username"]),
      text(`${id}/role`, S.serverRole(profile.role), ["staff-role"]),
    ] },
  ], { cls: ["staff-profile-row"], gap: 6, align: "center" });
  const open = options.open && {
    ...options.open,
    class: [...(options.open.class ?? []), "staff-profile-hit"],
    style: { ...options.open.style, position: "absolute", left: 0, right: 0, top: 0, bottom: 0 },
    text: "",
    label: S.OPEN_PROFILE,
  };
  const openLabel = options.open ? text(`${id}/open-label`, S.OPEN_PROFILE, ["staff-card-action-label"]) : null;
  const body = Stack(`${id}/body`, [identity, options.timeline, openLabel, open].filter((child): child is UiNode => !!child), { cls: ["staff-profile-body"], gap: 8, align: "center", style: { position: "relative" } });
  const children = [options.header, body, options.context ? text(`${id}/context`, options.context, ["staff-profile-context"]) : null]
    .filter((child): child is UiNode => !!child);
  return Card(id, children, { cls: ["staff-profile"] });
}

/** Header variant keeps the same two-line identity contract. */
export const staffIdentityHeader = identityCard;
