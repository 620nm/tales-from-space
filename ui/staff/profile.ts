import type { Json, UiNode } from "@lunatic/ui";
import { Card, LabeledList, Section, Stack } from "@lunatic/ui";
import { nativePress as staffPress } from "./shared/actions";
import { capability, createCasePress, inspectPress, openCasePress, profileCard, staffLocal } from "./actions";
import { isProfileId, type StaffEntity, type StaffRef, type StaffSession } from "./model";
import { caseRef, conversationQuery, objectValue, profileQuery, readRef, recordResponse, stringValue } from "./cases/records";
import { recordsRequest } from "./shared/actions";
import { bodyIdentity, caseIdentity, conversationFor, messageCount, messageResponse, profileRef, profileView, warningCount, type ProfileView, type ProfileWarning } from "./profile/data";
import { conversationRequest, messageRequest, observeDisplayedConversation, observeDisplayedProfile, profileNoteRequest, warningRequest } from "./profile/flows";
import { profileFor } from "./model";
import { entry, press, text } from "../view";
import * as S from "./strings";

/** Account drill-in shared by event cards and associated records. */
export function profileDrill(session: StaffSession, accountId: string): UiNode {
  const view = profileView(session, accountId);
  const account = view?.account ?? (isProfileId(accountId) ? profileRef(session, accountId) : null);
  if (account) observeDisplayedProfile(session, account);
  if (!view) return Card("staff/profile", [textNode("staff/profile/unavailable", S.NO_ACCOUNT, "staff-muted")], { cls: ["staff-evidence-inspector"] });
  return Card("staff/profile", [
    textNode("staff/profile/kicker", S.ACCOUNT_PROFILE, "staff-eyebrow"),
    profileCard("staff/profile/identity", view.profile, S.RECORD_ONLY),
    Stack("staff/profile/actions", [
      press("staff/profile/message", S.START_CONVERSATION, () => conversationRequest(session, view.account), { variant: "primary" }),
      createCasePress("staff/profile/create-case", S.CREATE_CASE, session, { ...view.account, label: view.profile.username }, { variant: "ghost" }),
    ], { cls: ["staff-action-row"], gap: 5 }),
    ownerActions(session, view),
    profileFacts(view),
    bodyHistory(session, view.bodies),
    warnings(session, view),
    linkedCases(session, view.cases),
    profileRecords(session, view),
    conversationPanel(session, view),
  ].filter(Boolean) as UiNode[], { cls: ["staff-evidence-inspector"] });
}

function profileFacts(view: ProfileView): UiNode {
  const role = S.serverRole(view.profile.role);
  return Section("staff/profile/facts", S.ACCOUNT_PROFILE, [LabeledList("staff/profile/facts/list", [
    { label: S.STATUS, value: role },
    { label: S.WARNINGS, value: String(warningCount(view)) },
    { label: S.MESSAGES, value: String(messageCount(view)) },
  ])]);
}

/** Permission changes are offered only from the server-disclosed owner view. */
function ownerActions(session: StaffSession, view: ProfileView): UiNode | null {
  const operator = session.operator;
  if (!operator || operator.role !== "owner") return null;
  // The configured owner is a protected target; the server remains the final
  // authority for every request and may reject any stale projection.
  if (view.profile.role === "owner" || view.profile.id === operator.id) return null;
  return Section("staff/profile/permissions", S.STATUS, [
    textNode("staff/profile/permissions/hint", view.profile.role, "staff-muted"),
    Stack("staff/profile/permissions/actions", [
      staffPress("staff/profile/permissions/grant", S.GRANT_STAFF, session, recordsRequest("grant", { profile: view.profile.id, grant: "staff" }), { variant: "primary" }),
      staffPress("staff/profile/permissions/revoke", S.REVOKE_STAFF, session, recordsRequest("revoke", { profile: view.profile.id, grant: "staff" }), { variant: "ghost" }),
    ], { cls: ["staff-action-row"], gap: 5 }),
  ]);
}

function bodyHistory(session: StaffSession, bodies: StaffEntity[]): UiNode {
  if (!bodies.length) return Section("staff/profile/bodies", S.BODY, [textNode("staff/profile/bodies/empty", S.NO_HISTORY, "staff-muted")]);
  return Section("staff/profile/bodies", S.BODY, bodies.map((body, index) => bodyRow(session, body, index)));
}

function bodyRow(session: StaffSession, body: StaffEntity, index: number): UiNode {
  const target = body.ref ?? { round: session.roundId, kind: body.kind || "entity", id: String(body.id) } satisfies StaffRef;
  const actions: UiNode[] = [
    inspectPress(`staff/profile/body/${index}/inspect`, bodyIdentity(body), session, target, { variant: "ghost", cls: ["staff-related-ref"] }),
    createCasePress(`staff/profile/body/${index}/create-case`, S.CREATE_CASE, session, { ...target, label: body.name }, { variant: "ghost" }),
  ];
  if (capability(body, "freeze")) actions.push(staffPress(`staff/profile/body/${index}/freeze`, body.frozen ? S.UNFREEZE : S.FREEZE, session, { kind: "freeze", target: body.id, on: !body.frozen }, { variant: body.frozen ? "selected" : "default" }));
  if (capability(body, "drive")) actions.push(staffPress(`staff/profile/body/${index}/drive`, S.DRIVE, session, { kind: "drive", target: body.id }, { variant: "ghost" }));
  return Stack(`staff/profile/body/${index}`, [
    textNode(`staff/profile/body/${index}/context`, body.state ?? body.role ?? S.BODY, "staff-muted"),
    textNode(`staff/profile/body/${index}/location`, body.location ?? formatPosition(body.pos), "staff-mono"),
    Stack(`staff/profile/body/${index}/actions`, actions, { cls: ["staff-action-row"], gap: 4, wrap: true }),
  ], { cls: ["staff-profile-body"], gap: 3 });
}

function formatPosition(pos: StaffEntity["pos"]): string {
  if (!pos) return S.NO_HISTORY;
  return `(${pos.x}, ${pos.y}${pos.z === undefined ? "" : `, ${pos.z}`})`;
}

function warnings(session: StaffSession, view: ProfileView): UiNode {
  const state = staffLocal(session);
  const warningKey = `profile:${view.profile.id}:warning`;
  const noteKey = `profile:${view.profile.id}:note`;
  const list = view.warnings;
  const rows = list.map((warning, index) => Stack(`staff/profile/warning/${index}`, [
    textNode(`staff/profile/warning/${index}/text`, warning.text, "staff-warning"),
    textNode(`staff/profile/warning/${index}/meta`, [warning.severity, warning.time].filter(Boolean).join(" · ") || S.RECORD_ONLY, "staff-mono"),
    warning.author ? inspectPress(`staff/profile/warning/${index}/author`, refCaption(session, warning.author), session, warning.author, { variant: "ghost", cls: ["staff-related-ref"] }) : null,
  ].filter(Boolean) as UiNode[], { cls: ["staff-profile-warning"], gap: 3 }));
  rows.push(entry(`staff/profile/warning/new`, state.drafts[warningKey] ?? "", (value) => { state.drafts[warningKey] = value; return undefined; }, { label: S.OPERATOR_REASON, debounceMs: 120 }));
  rows.push(profileWritePress("staff/profile/warning/save", S.ADD_WARNING, session, view.account, "warning", warningKey, (value) => ({ target: view.account, text: value }), "staff/profile/warning/new", { variant: "ghost" }));
  rows.push(entry(`staff/profile/note/new`, state.drafts[noteKey] ?? "", (value) => { state.drafts[noteKey] = value; return undefined; }, { label: S.CONTACT_NOTE, debounceMs: 120 }));
  rows.push(profileWritePress("staff/profile/note/save", S.SAVE_NOTE, session, view.account, "profile_note", noteKey, (value) => ({ target: view.account, text: value }), "staff/profile/note/new", { variant: "ghost" }));
  if (!list.length && rows.length === 4) rows.unshift(textNode("staff/profile/warnings/empty", S.NO_HISTORY, "staff-muted"));
  return Section("staff/profile/warnings", S.WARNINGS, rows);
}

function linkedCases(session: StaffSession, cases: ProfileView["cases"]): UiNode {
  const values = cases;
  if (!values.length) return Section("staff/profile/cases", S.CASES, [textNode("staff/profile/cases/empty", S.NO_CASE, "staff-muted")]);
  return Section("staff/profile/cases", S.CASES, values.map((item, index) => {
    const target = caseRef(session, item);
    return target
      ? openCasePress(`staff/profile/case/${index}`, caseIdentity(item), session, item, { variant: "ghost", cls: ["staff-related-ref"] })
      : textNode(`staff/profile/case/${index}`, caseIdentity(item), "staff-muted");
  }));
}

function profileRecords(session: StaffSession, view: NonNullable<ReturnType<typeof profileView>>): UiNode {
  const page = view.records;
  const response = recordResponse(session);
  const children: UiNode[] = [];
  if (page.notes.length) children.push(textNode("staff/profile/records/notes", page.notes.map((note) => objectValue(note)?.text).filter((value): value is string => typeof value === "string").join(" · "), "staff-muted"));
  if (page.conversations.length) children.push(textNode("staff/profile/records/conversations", page.conversations.map((conversation) => objectValue(conversation)?.reference).filter(Boolean).map((reference) => {
    const ref = readRef(reference, session.roundId);
    return ref ? `${ref.kind} · ${ref.id}` : "";
  }).filter(Boolean).join(" · "), "staff-mono"));
  if (page.error) children.push(textNode("staff/profile/records/error", page.error, "staff-warning"));
  const responseError = stringValue(response?.error, "");
  if (responseError && responseError !== page.error) children.push(textNode("staff/profile/records/server-error", responseError, "staff-warning"));
  if (page.next) children.push(staffPress("staff/profile/records/load-more", S.ALL_RECORDS, session, profileQuery(profileRef(session, view.profile.id), page.next), { variant: "ghost" }));
  if (!children.length && !page.warnings.length && !page.notes.length && !page.conversations.length) return textNode("staff/profile/records/empty", S.NO_HISTORY, "staff-muted");
  if (!children.length) children.push(textNode("staff/profile/records/loaded", S.RECORD_ONLY, "staff-muted"));
  return Section("staff/profile/records", S.RECORDS, children);
}

function conversationPanel(session: StaffSession, view: ProfileView): UiNode | null {
  const state = staffLocal(session);
  const key = `profile:${view.profile.id}:conversation`;
  let conversation = conversationFor(session, view);
  if (conversation) state.drafts[key] = JSON.stringify(conversation.reference);
  else {
    try {
      const reference = readRef(JSON.parse(state.drafts[key] ?? ""), session.roundId);
      if (reference?.kind === "conversation") conversation = { reference, account: view.account, record: {} };
    } catch {
      // A draft is only a remembered server reference; malformed local state is ignored.
    }
  }
  if (!conversation) {
    observeDisplayedConversation(session, view.account, null);
    return null;
  }
  observeDisplayedConversation(session, view.account, conversation.reference);
  const record = objectValue(conversation.record);
  const messages = Array.isArray(record?.messages)
    ? record.messages.map(objectValue).filter((message): message is Record<string, unknown> => !!message && typeof message.body === "string")
    : [];
  const loaded = Array.isArray(record?.messages);
  const messageKey = `profile:${view.profile.id}:message`;
  const body = state.drafts[messageKey] ?? "";
  const response = messageResponse(session);
  const children: UiNode[] = [
    textNode("staff/profile/conversation/ref", `${conversation.reference.kind} · ${conversation.reference.id}`, "staff-mono"),
    messages.length ? Stack("staff/profile/conversation/messages", messages.map((message, index) => textNode(`staff/profile/conversation/message/${index}`, message.body, "staff-muted")), { dir: "column", gap: 3 }) : null,
    staffPress("staff/profile/conversation/load", loaded ? S.REFRESH_MESSAGES : S.MESSAGES, session, conversationQuery(conversation.reference), { variant: "ghost" }),
    loaded && typeof record?.next === "string" ? staffPress("staff/profile/conversation/load-more", S.ALL_RECORDS, session, conversationQuery(conversation.reference, record.next), { variant: "ghost" }) : null,
    response ? textNode("staff/profile/conversation/response", `${S.RECORD_ONLY} · ${response.kind} · ${response.id}`, "staff-good") : null,
    entry("staff/profile/conversation/body", body, (value) => { state.drafts[messageKey] = value; return undefined; }, { label: S.CONTACT_NOTE, multiline: true, debounceMs: 120 }),
    profileWritePress("staff/profile/conversation/send", S.SEND_MESSAGE, session, view.account, "message", messageKey, (value) => ({ conversation: conversation.reference, body: value }), "staff/profile/conversation/body", { variant: "primary" }),
  ].filter(Boolean) as UiNode[];
  return Section("staff/profile/conversation", S.MESSAGES, children);
}

function profileWritePress(
  id: string,
  caption: unknown,
  session: StaffSession,
  account: StaffRef,
  op: "warning" | "profile_note" | "message",
  draftKey: string,
  fields: (value: string) => Record<string, Json>,
  submit: string,
  opts: Parameters<typeof press>[3] = {},
): UiNode {
  return press(id, caption, (event) => {
    const state = staffLocal(session);
    const value = event.value ?? state.drafts[draftKey] ?? "";
    state.drafts[draftKey] = value;
    if (!value.trim()) return undefined;
    if (op === "warning") return warningRequest(session, account, value, draftKey);
    if (op === "profile_note") return profileNoteRequest(session, account, value, draftKey);
    const conversation = fields(value).conversation;
    return messageRequest(session, account, conversation as StaffRef, value, draftKey);
  }, { ...opts, submit });
}

function textNode(id: string, value: unknown, cls?: string): UiNode {
  return text(id, value, cls ? [cls] : undefined);
}

function refCaption(session: StaffSession, ref: StaffRef): string {
  const profile = ref.kind === "account" ? profileFor(session, ref.id) : null;
  return ref.kind === "account"
    ? `${profile?.username ?? S.NO_ACCOUNT} · ${shortId(ref.id)}`
    : `${ref.label ?? ref.kind} · ${ref.id}`;
}

function shortId(id: string): string {
  return id.length > 14 ? `${id.slice(0, 6)}…${id.slice(-4)}` : id;
}
