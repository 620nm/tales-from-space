// Drives the built gallery bundle in headless Chromium and screenshots every scenario and tab.
// Usage: node audit_browser.mjs [--out-dir <dir>]   (default <pack>/target/art/elemental)
// Env: PLAYWRIGHT_MODULE (module path or name; default "playwright", resolved from this
// directory and NODE_PATH), CHROMIUM_PATH (browser binary; default Playwright's own).
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || "playwright");

const HERE = path.dirname(fileURLToPath(import.meta.url));
const outFlag = process.argv.indexOf("--out-dir");
const OUT_DIR = path.resolve(
  outFlag >= 0 ? process.argv[outFlag + 1] : path.join(HERE, "../../../../target/art/elemental")
);
const AUDIT_DIR = path.join(OUT_DIR, "audit");
const GALLERY_URL = pathToFileURL(path.join(OUT_DIR, "gallery", "index.html")).href;
fs.mkdirSync(AUDIT_DIR, { recursive: true });

const SCENARIOS = [
  "campfire",
  "grease_fire",
  "gas_oxidation",
  "plasma_firestorm",
  "spill_balance",
  "smoke_gradient",
  "zerog_cabin",
  "flour_mill",
  "tunnel_debris",
  "farm_plot",
];

async function clickTile(page, gx, gy) {
  const box = await page.locator("#sandbox-canvas").boundingBox();
  const px = ((gx + 0.5) * box.width) / 10;
  const py = ((gy + 0.5) * box.height) / 8;
  await page.click("#sandbox-canvas", { position: { x: px, y: py } });
}

async function scanAllGridSprites(page) {
  await page.selectOption("#tool-mode", "inspect");
  const counts = {};
  const tintsByCoord = {};
  for (let y = 0; y < 8; y++) {
    for (let x = 0; x < 10; x++) {
      await clickTile(page, x, y);
      const rows = await page.evaluate(() => {
        return Array.from(document.querySelectorAll("#insp-layers-table tbody tr")).map((tr) => ({
          layer: tr.children[0]?.textContent?.trim() || "",
          spriteRaw: tr.children[1]?.childNodes[0]?.textContent?.trim() || tr.children[1]?.textContent?.trim() || "",
          tint: tr.children[2]?.textContent?.trim() || "",
        }));
      });
      tintsByCoord[`${x},${y}`] = rows;
      for (const r of rows) {
        if (r.layer.startsWith("0:") || r.layer.startsWith("1:Fixture")) continue;
        const sid = r.spriteRaw.split(" ")[0];
        counts[sid] = (counts[sid] || 0) + 1;
      }
    }
  }
  return { counts, tintsByCoord };
}

async function main() {
  const consoleErrors = [];
  const consoleWarnings = [];
  const pageErrors = [];
  const findings = {};

  const browser = await chromium.launch({
    headless: true,
    ...(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {}),
  });
  const context = await browser.newContext({ viewport: { width: 1680, height: 1080 } });
  const page = await context.newPage();

  page.on("console", (msg) => {
    const type = msg.type();
    if (type === "error") {
      consoleErrors.push({ text: msg.text(), location: msg.location() });
    } else if (type === "warning") {
      consoleWarnings.push({ text: msg.text(), location: msg.location() });
    }
  });
  page.on("pageerror", (err) => {
    pageErrors.push({ message: err.message, stack: err.stack });
  });

  await page.goto(GALLERY_URL, { waitUntil: "load" });
  await page.waitForFunction(() => {
    const el = document.getElementById("header-summary");
    return el && el.textContent && !el.textContent.startsWith("Loading");
  }, { timeout: 10000 });

  findings.headerSummary = await page.locator("#header-summary").textContent();

  // Pause animation for deterministic screenshots
  const animBtnText = await page.locator("#btn-anim-toggle").textContent();
  if (animBtnText && animBtnText.includes("Playing")) {
    await page.click("#btn-anim-toggle");
  }
  await page.waitForTimeout(40);

  // [MAJOR-6] Layout fit check across 2x, 3x, 4x scales at 1680x1080 AND 1440x900
  findings.layoutChecks = {};
  for (const [vw, vh] of [[1680, 1080], [1440, 900]]) {
    await page.setViewportSize({ width: vw, height: vh });
    for (const scVal of ["2", "3", "4"]) {
      await page.selectOption("#env-scale", scVal);
      await page.waitForTimeout(30);
      const rectInfo = await page.evaluate(() => {
        const cv = document.getElementById("sandbox-canvas").getBoundingClientRect();
        const st = document.querySelector(".panel.canvas-stage").getBoundingClientRect();
        const insp = document.querySelectorAll(".workbench-grid > .panel")[2].getBoundingClientRect();
        return {
          canvasWidth: Math.round(cv.width * 10) / 10,
          stageWidth: Math.round(st.width * 10) / 10,
          canvasRight: Math.round(cv.right * 10) / 10,
          stageRight: Math.round(st.right * 10) / 10,
          inspLeft: Math.round(insp.left * 10) / 10,
          fitsStage: cv.width <= st.width && cv.right <= st.right + 0.5,
          noOverlapInspector: cv.right <= insp.left,
        };
      });
      findings.layoutChecks[`${vw}x${vh}_scale${scVal}x`] = rectInfo;
    }
  }
  await page.setViewportSize({ width: 1680, height: 1080 });
  await page.selectOption("#env-scale", "3");
  await page.waitForTimeout(30);

  // Step 1: Audit all 10 scenarios + capture UI and clean (grid-off) canvas screenshots
  findings.scenarios = {};
  for (const sc of SCENARIOS) {
    await page.click(`#scenario-buttons button[data-scenario="${sc}"]`);
    await page.waitForTimeout(50);

    if (!(await page.isChecked("#vis-grid"))) {
      await page.check("#vis-grid");
      await page.waitForTimeout(25);
    }
    await page.screenshot({ path: path.join(AUDIT_DIR, `scenario_${sc}_ui.png`) });

    await page.uncheck("#vis-grid");
    await page.waitForTimeout(30);
    await page.locator("#sandbox-canvas").screenshot({
      path: path.join(AUDIT_DIR, `scenario_${sc}_clean.png`),
    });

    const scInfo = await page.evaluate(() => {
      const logText = document.getElementById("physics-log")?.textContent || "";
      const inspCoords = document.getElementById("insp-coords")?.textContent || "";
      const inspJunction = document.getElementById("insp-junction-box")?.textContent || "";
      const layerRows = Array.from(document.querySelectorAll("#insp-layers-table tbody tr")).map(
        (tr) => Array.from(tr.querySelectorAll("td")).map((td) => td.textContent.trim())
      );
      return { logText, inspCoords, inspJunction, layerRows };
    });
    findings.scenarios[sc] = scInfo;
    await page.check("#vis-grid");
  }

  // [CRITICAL-1] & [MAJOR-4] & [MAJOR-5]: Full 10x8 sprite census on key scenarios
  findings.gridCensus = {};
  for (const sc of ["gas_oxidation", "plasma_firestorm", "smoke_gradient", "spill_balance", "grease_fire", "campfire", "flour_mill"]) {
    await page.click(`#scenario-buttons button[data-scenario="${sc}"]`);
    await page.waitForTimeout(30);
    const { counts } = await scanAllGridSprites(page);
    findings.gridCensus[sc] = counts;
  }

  // [CRITICAL-2]: Verify zerog_cabin preserves BOTH #4BA3E3 Coolant Water around (2,3)/(3,3) AND #A3121A Venous Blood around (7,5)
  await page.click(`#scenario-buttons button[data-scenario="zerog_cabin"]`);
  await page.waitForTimeout(30);
  const zerogScan = await scanAllGridSprites(page);
  const waterTiles = [];
  const bloodTiles = [];
  for (const [coord, rows] of Object.entries(zerogScan.tintsByCoord)) {
    for (const r of rows) {
      if (r.tint.includes("#4BA3E3")) waterTiles.push(coord);
      if (r.tint.includes("#A3121A")) bloodTiles.push(coord);
    }
  }
  findings.zerogMultiFluidCheck = {
    waterTileCount: waterTiles.length,
    bloodTileCount: bloodTiles.length,
    sampleWaterCoords: waterTiles.slice(0, 5),
    sampleBloodCoords: bloodTiles.slice(0, 5),
  };

  // Also test interactive multi-fluid pour & multi-gas release non-overwrite!
  await page.click("#btn-clear-grid");
  await page.selectOption("#env-gravity", "1g");
  await page.selectOption("#tool-mode", "pour_liquid");
  await page.fill("#active-tint-hex", "#4BA3E3");
  await page.dispatchEvent("#active-tint-hex", "change");
  await page.evaluate(() => {
    const el = document.getElementById("liq-volume");
    el.value = "5060";
    el.dispatchEvent(new Event("input", { bubbles: true }));
  });
  await clickTile(page, 2, 3);
  await page.fill("#active-tint-hex", "#48C840");
  await page.dispatchEvent("#active-tint-hex", "change");
  await clickTile(page, 7, 4);
  const interactiveLiqScan = await scanAllGridSprites(page);
  let blueCount = 0, greenCount = 0;
  for (const rows of Object.values(interactiveLiqScan.tintsByCoord)) {
    for (const r of rows) {
      if (r.tint.includes("#4BA3E3")) blueCount++;
      if (r.tint.includes("#48C840")) greenCount++;
    }
  }
  findings.interactiveMultiFluidPour = { blueCount, greenCount };

  // [MINOR-3]: Test single-tile solid options in #solid-kind dropdown
  await page.click("#btn-clear-grid");
  await page.selectOption("#tool-mode", "dump_solid");
  await page.evaluate(() => {
    const el = document.getElementById("solid-radius");
    el.value = "0";
    el.dispatchEvent(new Event("input", { bubbles: true }));
  });
  const singleSolidResults = {};
  const singleKinds = [
    ["flour_single", 2, 2],
    ["debris_single", 4, 2],
    ["soil_single", 6, 2],
  ];
  for (const [k, tx, ty] of singleKinds) {
    await page.selectOption("#solid-kind", k);
    await clickTile(page, tx, ty);
  }
  await page.selectOption("#tool-mode", "inspect");
  for (const [k, tx, ty] of singleKinds) {
    await clickTile(page, tx, ty);
    singleSolidResults[k] = await page.evaluate(() =>
      Array.from(document.querySelectorAll("#insp-layers-table tbody tr")).map((tr) =>
        tr.children[1]?.textContent?.trim()
      )
    );
  }
  findings.singleSolidDropdownCheck = singleSolidResults;

  // Flour mill ignition check
  await page.click(`#scenario-buttons button[data-scenario="flour_mill"]`);
  await page.click("#btn-ignite-all");
  await page.uncheck("#vis-grid");
  await page.waitForTimeout(30);
  await page.locator("#sandbox-canvas").screenshot({
    path: path.join(AUDIT_DIR, "scenario_flour_mill_ignited_clean.png"),
  });
  await page.check("#vis-grid");

  // Step 2: Slicer, Catalog, Substances screenshots
  await page.click(`#main-tabs button[data-tab="slicer"]`);
  await page.waitForTimeout(50);
  await page.selectOption("#slicer-asset-select", "gas_cloud_smooth_gentle");
  await page.click("#slicer-reset-tint");
  await page.waitForTimeout(40);
  await page.screenshot({ path: path.join(AUDIT_DIR, "tab_slicer_gas_cloud.png"), fullPage: true });

  await page.selectOption("#slicer-asset-select", "liquid_puddle_smooth_shimmer");
  await page.fill("#slicer-tint-picker", "#4ba3e3");
  await page.dispatchEvent("#slicer-tint-picker", "input");
  await page.waitForTimeout(40);
  await page.screenshot({ path: path.join(AUDIT_DIR, "tab_slicer_liquid_puddle.png"), fullPage: true });

  await page.click(`#main-tabs button[data-tab="catalog"]`);
  await page.waitForTimeout(50);
  for (const dom of ["gas", "liquid", "solid", "fire"]) {
    await page.selectOption("#cat-filter-domain", dom);
    await page.waitForTimeout(50);
    await page.screenshot({ path: path.join(AUDIT_DIR, `tab_catalog_${dom}.png`), fullPage: true });
  }
  await page.selectOption("#cat-filter-domain", "all");

  await page.click(`#main-tabs button[data-tab="substances"]`);
  await page.waitForTimeout(50);
  // Test clicking Ferric Oxide (Rust) -> solid_dusting_flour_single in Tab 4!
  const rustBtn = page.locator("#substances-table tbody tr", { hasText: "solid_dusting_flour_single" }).locator("button");
  if ((await rustBtn.count()) > 0) {
    await rustBtn.first().click();
    await page.waitForTimeout(40);
    findings.rustSubstanceMappedSolidKind = await page.locator("#solid-kind").inputValue();
  }

  findings.consoleErrors = consoleErrors;
  findings.consoleWarnings = consoleWarnings;
  findings.pageErrors = pageErrors;

  fs.writeFileSync(
    path.join(AUDIT_DIR, "browser_audit_report.json"),
    JSON.stringify(findings, null, 2)
  );

  await browser.close();
  console.log(JSON.stringify({
    ok: consoleErrors.length === 0 && pageErrors.length === 0,
    consoleErrorCount: consoleErrors.length,
    pageErrorCount: pageErrors.length,
    layoutChecks: findings.layoutChecks,
    gridCensus: findings.gridCensus,
    zerogMultiFluidCheck: findings.zerogMultiFluidCheck,
    interactiveMultiFluidPour: findings.interactiveMultiFluidPour,
    singleSolidDropdownCheck: findings.singleSolidDropdownCheck,
    rustSubstanceMappedSolidKind: findings.rustSubstanceMappedSolidKind,
  }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
