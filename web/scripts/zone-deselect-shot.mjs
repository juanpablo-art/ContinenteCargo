import { chromium } from 'playwright';
import path from 'path';
import fs from 'fs';

const outDir = process.argv[2];
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true,
});
const page = await browser.newPage({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  isMobile: true,
  hasTouch: true,
});
page.on('pageerror', (e) => console.log('PAGEERROR', e.message));

await page.goto('http://127.0.0.1:5174/register', { waitUntil: 'networkidle' });
await page.waitForSelector('#name');
await page.fill('#name', 'Demo Transportista');
await page.fill('#reg-email', 'demo.zone@example.com');
await page.fill('#phone', '8181234567');
await page.fill('#reg-password', 'secret12');
await page.fill('#company', 'Transportes Demo SA');
await page.fill('#contact', 'Juan Demo');
await page.getByRole('button', { name: 'Siguiente: Rutas y equipo' }).click();
await page.waitForSelector('text=Por Zona');

// Select Norte zone (adds all its states)
await page.getByRole('button', { name: /Norte/ }).first().click();
await page.waitForSelector('text=Estados seleccionados');

// Verify chips show N.L.
const before = await page.locator('button[aria-label^="Quitar"]').allTextContents();
console.log('states_before', before.map((t) => t.replace('×', '').trim()));

// Deselect N.L. and Tamaulipas
await page.getByRole('button', { name: 'Quitar N.L.' }).click();
await page.getByRole('button', { name: 'Quitar Tamaulipas' }).click();

const after = await page.locator('button[aria-label^="Quitar"]').allTextContents();
console.log('states_after', after.map((t) => t.replace('×', '').trim()));
console.log('has_nl', after.some((t) => t.includes('N.L.')));
console.log('has_tamaulipas', after.some((t) => t.includes('Tamaulipas')));
console.log('badge', await page.locator('text=/\\d+\\/\\d+/').first().innerText());

// Partial styling — Norte should show partial count like 4/6
await page.waitForTimeout(300);
const file = path.join(outDir, 'register-zone-deselect-state.png');
await page.screenshot({ path: file, fullPage: true });
console.log('wrote', file, fs.statSync(file).size);

await browser.close();
