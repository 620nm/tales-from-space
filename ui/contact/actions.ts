import type { Json, UiNode } from "@lunatic/ui";
import { Card, Field, Stack } from "@lunatic/ui";
import type { GameplayView } from "../model";
import { bind, entry, press, row, screen, text, type Command } from "../view";
import * as S from "./strings";
import {
  bodyLimit, contactAction, readContact, resetContactRequests, selectedConversation,
  type ContactAction, type ContactConversation, type ContactLocalState, type ContactMessage,
  type StaffContactState,
} from "./model";
import { refKey } from "../refs";

export interface ContactViewState {
  state: StaffContactState;
  local: ContactLocalState;
}

export function contactLocal(round: number | string = ""): ContactLocalState {
  const currentRound = String(round);
  if (local.round !== currentRound) {
    resetContactRequests();
    local = { open: false, selected: null, drafts: {}, round: currentRound, cache: new Map() };
  }
  return local;
}

let local: ContactLocalState = {
  open: false, selected: null, drafts: {}, round: "", cache: new Map(),
};

export function resetContactLocal(): void {
  resetContactRequests();
  local = { open: false, selected: null, drafts: {}, round: "", cache: new Map() };
}

function request(action: ContactAction): Command {
  return contactAction(action) as Command;
}

export function readContactState(view: GameplayView): ContactViewState | null {
  const state = readContact(view);
  if (!state) return null;
  const localState = contactLocal((view.state.round?.round ?? "") as number | string);
  const conversations = state.available
    ? state.conversations.map((conversation) => mergeConversation(localState, conversation))
    : [];
  if (state.available) {
    const currentKeys = new Set(conversations.map((conversation) => refKey(conversation.ref)));
    for (const cached of localState.cache.values()) {
      if (!currentKeys.has(refKey(cached.ref))) conversations.push(cached);
    }
  }
  const merged: StaffContactState = {
    ...state,
    conversations,
    // A page response can be older than the page already displayed. Keep the
    // unread count for the exact messages now present in the bounded cache.
    unread: conversations.reduce((count, item) => count + item.unread, 0),
  };
  return { state: merged, local: localState };
}

const MAX_CACHED_CONVERSATIONS = 32;
const MAX_CACHED_MESSAGES = 256;
const MAX_DISPLAYED_MESSAGES = 100;

function decimalId(value: string): string | null {
  if (!/^\d+$/.test(value)) return null;
  return value.replace(/^0+(?=\d)/, "");
}

function messageOrder(left: ContactMessage, right: ContactMessage): number {
  const leftId = decimalId(left.ref.id);
  const rightId = decimalId(right.ref.id);
  if (leftId !== null && rightId !== null) {
    if (leftId.length !== rightId.length) return leftId.length - rightId.length;
    if (leftId !== rightId) return leftId < rightId ? -1 : 1;
  }
  if (left.second !== undefined && right.second !== undefined && left.second !== right.second)
    return left.second < right.second ? -1 : 1;
  return 0;
}

function mergeMessages(oldMessages: ContactMessage[], newMessages: ContactMessage[]): ContactMessage[] {
  const merged = new Map(oldMessages.map((message) => [refKey(message.ref), message]));
  for (const message of newMessages) {
    const key = refKey(message.ref);
    const old = merged.get(key);
    merged.set(key, old
      ? {
          ...old,
          ...message,
          delivered: old.delivered || message.delivered,
          unread: old.unread && message.unread,
        }
      : message);
  }
  const rows = [...merged.values()];
  rows.sort(messageOrder);
  return rows.slice(-MAX_CACHED_MESSAGES);
}

function mergeConversation(localState: ContactLocalState, incoming: ContactConversation): ContactConversation {
  const key = refKey(incoming.ref);
  const cached = localState.cache.get(key);
  const conversation: ContactConversation = {
    ...(cached ?? incoming),
    ...incoming,
    label: incoming.label || cached?.label || "",
    staffName: incoming.staffName || cached?.staffName || "",
    messages: mergeMessages(cached?.messages ?? [], incoming.messages),
  };
  conversation.unread = conversation.messages.filter((message) => message.from === "staff" && message.unread).length;
  localState.cache.set(key, conversation);
  while (localState.cache.size > MAX_CACHED_CONVERSATIONS) {
    const oldest = localState.cache.keys().next().value;
    if (oldest === undefined) break;
    localState.cache.delete(oldest);
  }
  return conversation;
}

/** Only rows in the bounded history subtree count as displayed. */
function displayedMessages(conversation: ContactConversation): ContactMessage[] {
  return conversation.messages.slice(-MAX_DISPLAYED_MESSAGES);
}

/** Ack one displayed incoming message; the next is emitted after its read response. */
export function contactOnView(view: GameplayView): Command | undefined {
  const parsed = readContactState(view);
  if (!parsed || !parsed.local.open || !parsed.state.available) return undefined;
  const conversation = selectedConversation(parsed.state, parsed.local);
  if (!conversation) return undefined;
  const displayed = displayedMessages(conversation);
  const pending = parsed.local.delivered;
  const pendingMessage = pending && displayed.find((message) => refKey(message.ref) === pending.message);
  if (pendingMessage && !pendingMessage.unread) parsed.local.delivered = undefined;
  const unread = displayed.filter((message) => message.from === "staff" && message.unread);
  if (!unread.length) {
    parsed.local.delivered = undefined;
    return undefined;
  }
  const message = pendingMessage?.unread ? pendingMessage : unread[0];
  const conversationKey = refKey(conversation.ref);
  const messageKey = refKey(message.ref);
  if (
    parsed.local.delivered?.conversation === conversationKey &&
    parsed.local.delivered.message === messageKey
  ) {
    // Exact receipts survive coalesced views; wait for the server's receipt.
    return undefined;
  }
  parsed.local.delivered = { conversation: conversationKey, message: messageKey };
  return request({ Delivered: { conversation: conversation.ref, message: message.ref } });
}

function sender(id: string, name: unknown, staff: boolean): UiNode {
  return Card(id, [
    text(`${id}/name`, name || (staff ? S.STAFF_MEMBER : S.YOU), [staff ? "contact-staff-name" : "contact-own-name"]),
    text(`${id}/kind`, staff ? S.STAFF_MEMBER : S.YOUR_MESSAGE, ["contact-sender-kind"]),
  ], { cls: ["contact-sender"] });
}

function messageRow(id: string, message: ContactMessage, staffName: unknown): UiNode {
  const staff = message.from === "staff";
  const stamp = typeof message.second === "number" ? S.STAMP(message.second) : null;
  return Card(id, [
    Stack(`${id}/head`, [
      text(`${id}/sender`, staff ? message.sender || staffName || S.STAFF_MEMBER : S.YOU, ["contact-message-sender"]),
      stamp ? text(`${id}/time`, stamp, ["contact-message-time"]) : null,
    ].filter(Boolean) as UiNode[], { cls: ["contact-message-head"], gap: 5, align: "center" }),
    text(`${id}/text`, message.body, [staff ? "contact-message-staff" : "contact-message-own"]),
  ].filter(Boolean) as UiNode[], { cls: ["contact-message", staff ? "contact-message-incoming" : "contact-message-outgoing"] });
}

function conversationList(state: StaffContactState, localState: ContactLocalState): UiNode {
  const rows = state.conversations.map((conversation, index) => {
    const key = refKey(conversation.ref);
    return press(
      `contact/list/${index}`,
      conversation.unread ? S.CONVERSATION_UNREAD(conversation.label || S.TITLE, conversation.unread) : conversation.label || S.TITLE,
      () => {
        localState.selected = key;
        if (localState.delivered?.conversation !== key) localState.delivered = undefined;
        return undefined;
      },
      { variant: localState.selected === key ? "selected" : "default", cls: ["contact-conversation"] },
    );
  });
  const cursor = state.cursor;
  return Stack("contact/list", [
    text("contact/list/title", S.CONVERSATIONS, ["contact-section-title"]),
    ...(rows.length ? rows : [text("contact/list/empty", S.EMPTY, ["contact-muted"])]),
    cursor ? press("contact/list/load", S.LOAD_MORE, () => request({ Inbox: { after: cursor } }), { variant: "ghost", cls: ["contact-load"] }) : null,
  ].filter(Boolean) as UiNode[], { dir: "column", cls: ["contact-list"] });
}

function history(conversation: ContactConversation | null): UiNode {
  if (!conversation) return Stack("contact/history", [text("contact/history/empty", S.SELECT_PROMPT, ["contact-muted"])], { dir: "column", cls: ["contact-history"] });
  const rows = displayedMessages(conversation).map((message, index) => messageRow(`contact/history/${index}`, message, conversation.staffName || S.STAFF_MEMBER));
  return Stack("contact/history", [
    Stack("contact/history/title", [
      text("contact/history/heading", conversation.label || S.TITLE, ["contact-section-title"]),
      text("contact/history/staff", conversation.staffName || S.STAFF_MEMBER, ["contact-muted"]),
    ], { dir: "column", cls: ["contact-history-heading"], gap: 2, align: "start" }),
    sender("contact/history/sender", conversation.staffName || S.STAFF_MEMBER, true),
    ...(rows.length ? rows : [text("contact/history/empty", S.EMPTY, ["contact-muted"])]),
    conversation.cursor ? press("contact/history/load", S.LOAD_OLDER, () => request({ Inbox: { after: conversation.cursor } }), { variant: "ghost", cls: ["contact-load"] }) : null,
  ].filter(Boolean) as UiNode[], { dir: "column", cls: ["contact-history"] });
}

function composer(state: StaffContactState, localState: ContactLocalState, conversation: ContactConversation | null): UiNode[] {
  if (!conversation) return [text("contact/composer/disabled", S.SELECT_PROMPT, ["contact-muted"] )];
  const key = refKey(conversation.ref);
  const reply = (value: string): Command | undefined => {
    localState.drafts[key] = bodyLimit(value);
    if (!value.trim()) return undefined;
    return request({ Reply: { conversation: conversation.ref, body: bodyLimit(value) } });
  };
  return [
    Field("contact/composer/field", S.REPLY, entry("contact/composer", localState.drafts[key] ?? "", reply, {
      label: S.REPLY, submitOnly: true, clearOnSubmit: true, blurOnSubmit: true, cls: ["contact-entry"],
    })),
    press("contact/composer/send", S.SEND, (event) => reply(event.value ?? localState.drafts[key] ?? ""), {
      variant: "primary", submit: "contact/composer", disabled: state.available === false,
    }),
  ];
}

export function contactWindow(state: StaffContactState, localState: ContactLocalState): UiNode {
  const conversation = selectedConversation(state, localState);
  return screen("contact/window", {
    toolbar: [
      text("contact/window/title", S.TITLE, ["contact-title"]),
      state.unread ? text("contact/window/unread", S.UNREAD(state.unread), ["contact-unread"]) : null,
      press("contact/window/close", S.CLOSE, () => { localState.open = false; localState.delivered = undefined; return undefined; }, { variant: "ghost", cls: ["at-end"] }),
    ].filter(Boolean) as UiNode[],
    body: [
      state.available
        ? Stack("contact/window/content", [conversationList(state, localState), history(conversation)], { dir: "column", cls: ["contact-window-body"] })
        : text("contact/window/unavailable", S.denial(state.denial ?? "contact.unavailable"), ["contact-denial"]),
    ].filter(Boolean) as UiNode[],
    footer: composer(state, localState, conversation),
  }, { cls: ["contact-window"] });
}

export function contactPanel(view: GameplayView): UiNode | null {
  const parsed = readContactState(view);
  if (!parsed) return null;
  const { state, local: localState } = parsed;
  const button = press("contact/entry", state.unread ? S.UNREAD(state.unread) : S.ENTRY, () => {
    localState.open = true;
    localState.delivered = undefined;
    return request({ Inbox: { after: null } });
  }, { variant: state.unread ? "primary" : "ghost", cls: ["contact-entry-button"] });
  if (!localState.open) return Card("contact/entry-card", [
    Stack("contact/entry-head", [text("contact/entry/title", S.ENTRY, ["contact-title"]), button], { cls: ["contact-entry-head"], gap: 6, align: "center" }),
    state.unread ? text("contact/entry/notice", S.NEW_NOTICE(state.unread), ["contact-notice"]) : text("contact/entry/hint", S.HINT, ["contact-muted"]),
    state.denial ? text("contact/entry/denial", S.denial(state.denial), ["contact-denial"]) : null,
  ].filter(Boolean) as UiNode[], { cls: ["contact-entry-card"] });
  return contactWindow(state, localState);
}
