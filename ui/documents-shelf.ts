// The stocked board: pictured products under their own group heading,
// one server-authored act envelope each. Every word and every sprite is
// the machine prototype's; nothing here names a machine.
import type { UiNode } from "@lunatic/ui";
import { Section, Table } from "@lunatic/ui";
import type { DocumentIdentity, Product } from "./document-model";
import { documentAction } from "./document-action";
import { labelText } from "./labels";
import { icon, press, text } from "./view";
import * as S from "./strings";

const COLUMNS = [32, "1fr", "auto", "auto"] as const;

function productRow(
  id: string,
  doc: DocumentIdentity,
  product: Product,
  index: number,
  active: boolean,
): UiNode[] {
  const key = `${id}/product/${index}`;
  return [
    icon(`${key}/icon`, product.sprite) ?? text(`${key}/icon`, ""),
    text(`${key}/name`, labelText(product.label), ["pname"]),
    text(`${key}/stock`, String(product.stock ?? 0), ["stock"]),
    press(
      `${key}/vend`,
      S.VEND,
      documentAction(doc, product.act, product.payload),
      {
        variant: "primary",
        disabled: !active || (product.stock ?? 0) <= 0,
      },
    ),
  ];
}

/** One block per category, in the order the machine's file declared. */
export function shelfRows(
  id: string,
  doc: DocumentIdentity,
  products: Product[],
  active: boolean,
): UiNode[] {
  const groups: { name: string; rows: UiNode[][] }[] = [];
  for (const [index, product] of products.entries()) {
    const name = product.category ?? "";
    let group = groups[groups.length - 1];
    if (!group || group.name !== name) {
      group = { name, rows: [] };
      groups.push(group);
    }
    group.rows.push(productRow(id, doc, product, index, active));
  }
  return groups.map((group, place) => {
    const key = `${id}/shelf/${place}`;
    const table = Table(`${key}/table`, [...COLUMNS], group.rows);
    return group.name
      ? Section(key, group.name, [table])
      : Section(key, S.STOCK, [table]);
  });
}
