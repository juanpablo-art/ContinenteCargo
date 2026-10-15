import { chromium } from 'playwright';
import path from 'path';
import fs from 'fs';

const outDir = process.argv[2];
if (!outDir) {
  console.error('Usage: node scripts/applayout-shots.mjs <outDir>');
  process.exit(1);
}
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true,
});

async function shot(page, name) {
  const file = path.join(outDir, name);
  await page.screenshot({ path: file, fullPage: false });
  console.log('wrote', file, 'bytes', fs.statSync(file).size);
}

async function openAs(role, viewport) {
  const context = await browser.newContext({
    viewport,
    deviceScaleFactor: viewport.width < 768 ? 2 : 1,
    isMobile: viewport.width < 768,
    hasTouch: viewport.width < 768,
  });
  await context.addInitScript((demoRole) => {
    sessionStorage.setItem('ccDemoRole', demoRole);
  }, role);
  const page = await context.newPage();
  page.on('pageerror', (e) => console.log('PAGEERROR', e.message));
  return { context, page };
}

const adminMobile = await openAs('admin', { width: 390, height: 844 });
await adminMobile.page.goto('http://127.0.0.1:5174/admin/dashboard', {
  waitUntil: 'networkidle',
});
await adminMobile.page.getByRole('heading', { name: 'Inicio' }).waitFor({
  timeout: 15000,
});
await adminMobile.page.waitForTimeout(500);
await shot(adminMobile.page, 'admin-mobile.png');
await adminMobile.context.close();

const adminDesktop = await openAs('admin', { width: 1280, height: 800 });
await adminDesktop.page.goto('http://127.0.0.1:5174/admin/dashboard', {
  waitUntil: 'networkidle',
});
await adminDesktop.page.getByRole('heading', { name: 'Inicio' }).waitFor({
  timeout: 15000,
});
await adminDesktop.page.waitForTimeout(500);
await shot(adminDesktop.page, 'admin-desktop.png');
await adminDesktop.context.close();

const carrierMobile = await openAs('carrier', { width: 390, height: 844 });
await carrierMobile.page.goto('http://127.0.0.1:5174/carrier/home', {
  waitUntil: 'networkidle',
});
await carrierMobile.page
  .getByRole('heading', { name: 'Cargas disponibles' })
  .waitFor({ timeout: 15000 });
await carrierMobile.page.waitForTimeout(500);
await shot(carrierMobile.page, 'carrier-mobile.png');
await carrierMobile.context.close();

const carrierDesktop = await openAs('carrier', { width: 1280, height: 800 });
await carrierDesktop.page.goto('http://127.0.0.1:5174/carrier/home', {
  waitUntil: 'networkidle',
});
await carrierDesktop.page
  .getByRole('heading', { name: 'Cargas disponibles' })
  .waitFor({ timeout: 15000 });
await carrierDesktop.page.waitForTimeout(500);
await shot(carrierDesktop.page, 'carrier-desktop.png');
await carrierDesktop.context.close();

await browser.close();
console.log('done');
