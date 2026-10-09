import { chromium } from 'playwright';
import path from 'path';
import fs from 'fs';

const outDir = process.argv[2];
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true,
});

async function shot(page, name) {
  const file = path.join(outDir, name);
  await page.screenshot({ path: file, fullPage: true });
  console.log('wrote', file, 'bytes', fs.statSync(file).size);
}

const mobile = await browser.newPage({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  isMobile: true,
  hasTouch: true,
});
mobile.on('pageerror', (e) => console.log('PAGEERROR', e.message));
mobile.on('console', (msg) => {
  if (msg.type() === 'error') console.log('CONSOLE', msg.text());
});

await mobile.goto('http://127.0.0.1:5174/login', { waitUntil: 'networkidle' });
await mobile.waitForSelector('h1', { timeout: 15000 });
await mobile.waitForTimeout(800);
console.log('title', await mobile.title());
console.log('h1', await mobile.locator('h1').innerText().catch(() => 'none'));
console.log('body', (await mobile.locator('body').innerText()).slice(0, 200));
await shot(mobile, 'login-mobile.png');

await mobile.goto('http://127.0.0.1:5174/register', { waitUntil: 'networkidle' });
await mobile.waitForSelector('text=Tipo de cuenta', { timeout: 10000 });
await shot(mobile, 'register-step1-mobile.png');

await mobile.fill('#name', 'Demo Transportista');
await mobile.fill('#reg-email', 'demo.web@example.com');
await mobile.fill('#phone', '8181234567');
await mobile.fill('#reg-password', 'secret12');
await mobile.fill('#company', 'Transportes Demo SA');
await mobile.fill('#contact', 'Juan Demo');
await mobile.getByRole('button', { name: 'Siguiente: Rutas y equipo' }).click();
await mobile.waitForSelector('text=Por Zona', { timeout: 10000 });
await shot(mobile, 'register-step2-mobile.png');

const desktop = await browser.newPage({
  viewport: { width: 1280, height: 800 },
  deviceScaleFactor: 1,
});
desktop.on('pageerror', (e) => console.log('DESKTOP PAGEERROR', e.message));
await desktop.goto('http://127.0.0.1:5174/login', { waitUntil: 'networkidle' });
await desktop.waitForSelector('h1', { timeout: 15000 });
await desktop.waitForTimeout(800);
await shot(desktop, 'login-desktop.png');

await browser.close();
