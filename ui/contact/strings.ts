import { tfs } from "../strings";

export const TITLE = tfs("ui.contact.title");
export const ENTRY = tfs("ui.contact.entry");
export const HINT = tfs("ui.contact.hint");
export const NEW_NOTICE = (count: number) => tfs("ui.contact.new_notice", { count });
export const UNREAD = (count: number) => tfs("ui.contact.unread", { count });
export const CONVERSATIONS = tfs("ui.contact.conversations");
export const CONVERSATION_UNREAD = (label: string, count: number) => tfs("ui.contact.conversation_unread", { label, count });
export const EMPTY = tfs("ui.contact.empty");
export const SELECT_PROMPT = tfs("ui.contact.select_prompt");
export const LOAD_MORE = tfs("ui.contact.load_more");
export const LOAD_OLDER = tfs("ui.contact.load_older");
export const REPLY = tfs("ui.contact.reply");
export const SEND = tfs("ui.contact.send");
export const CLOSE = tfs("ui.contact.close");
export const YOU = tfs("ui.contact.you");
export const STAFF_MEMBER = tfs("ui.contact.staff_member");
export const YOUR_MESSAGE = tfs("ui.contact.your_message");
export const UNAVAILABLE = tfs("ui.contact.unavailable");
export const STAMP = (second: number) => tfs("ui.contact.stamp", { second });

export function denial(reason: string): unknown {
  if (reason === "contact.unavailable") return UNAVAILABLE;
  if (reason === "contact.unauthorized") return tfs("ui.contact.denied");
  if (reason === "contact.invalid_request") return tfs("ui.contact.invalid");
  if (reason === "contact.not_found") return tfs("ui.contact.not_found");
  return reason;
}
