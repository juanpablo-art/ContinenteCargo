import { chromium } from 'playwright';
import path from 'path';
import fs from 'fs';

const outDir = process.argv[2];
const only = process.argv[3];
if (!outDir) {
  console.error('Usage: node scripts/design-tour.mjs <outDir> [nameFilter]');
  process.exit(1);
}
fs.mkdirSync(outDir, { recursive: true });

const BASE = 'http://127.0.0.1:5174';
const pages = {
  admin: [
    ['dashboard', '/admin/dashboard'],
    ['loads', '/admin/loads'],
    ['load-detail', '/admin/loads/l3'],
    ['publish', '/admin/loads/new'],
    ['carriers', '/admin/carriers'],
    ['carrier-detail', '/admin/carriers/c11'],
    ['invitations', '/admin/invitations'],
    ['units', '/admin/units'],
    ['notifications', '/notifications'],
    ['profile', '/profile'],
  ],
  carrier: [
    ['home', '/carrier/home'],
    ['load-detail', '/carrier/loads/l1'],
    ['bid-detail', '/carrier/loads/l2'],
    ['offers', '/carrier/offers'],
    ['trips', '/carrier/trips'],
    ['trip-detail', '/carrier/trips/l5'],
    ['units', '/carrier/units'],
    ['availability', '/carrier/availability'],
    ['notifications', '/notifications'],
    ['profile', '/profile'],
  ],
};

const viewports = {
  mobile: { width: 390, height: 844 },
  desktop: { width: 1366, height: 860 },
};

const browser = await chromium.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true,
});

for (const [role, list] of Object.entries(pages)) {
  for (const [vpName, viewport] of Object.entries(viewports)) {
    const isMobile = vpName === 'mobile';
    const context = await browser.newContext({
      viewport,
      deviceScaleFactor: isMobile ? 2 : 1,
      isMobile,
      hasTouch: isMobile,
    });
    await context.addInitScript((r) => sessionStorage.setItem('ccDemoRole', r), role);
    const page = await context.newPage();
    page.on('pageerror', (e) => console.log('PAGEERROR', role, e.message));
    page.on('console', (m) => {
      if (m.type() === 'error') console.log('CONSOLE', role, m.text());
    });
    for (const [name, url] of list) {
      const file = `${role}-${name}-${vpName}.png`;
      if (only && !file.includes(only)) continue;
      await page.goto(BASE + url, { waitUntil: 'load' });
      await page.waitForTimeout(1200);
      await page.screenshot({ path: path.join(outDir, file), fullPage: !isMobile });
      console.log('wrote', file);
    }
    await context.close();
  }
}

await browser.close();
