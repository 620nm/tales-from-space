import type { StaffSession } from "./model";
import * as S from "./strings";

/** Applied effects stay applied even when revival cannot complete. */
export function staffNotice(session: Pick<StaffSession, "records" | "error">): { message: string; tone: string } | null {
  const response = session.records?.response;
  const error = response?.error ?? session.error;
  if (error === "staff.history_not_recorded") return { message: S.HISTORY_NOT_RECORDED, tone: "staff-warning" };
  if (error === "staff.storage_failed") return { message: S.STORAGE_FAILED, tone: "staff-warning" };
  if (error) return { message: S.REQUEST_FAILED(error), tone: "staff-warning" };
  const result = response?.result;
  if (result?.action !== "restore" || result.applied !== true) return null;
  return result.revived === true
    ? { message: S.RESTORE_APPLIED, tone: "staff-good" }
    : { message: S.RESTORE_PARTIAL(typeof result.reason === "string" ? result.reason : S.NO_CONTROLS), tone: "staff-warning" };
}
