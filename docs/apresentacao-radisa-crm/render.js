// Renders the deck HTML to an A4 PDF plus one PNG preview per page, and reports
// pages whose content runs past the safe area (above the footer band).
// usage: node render.js <deck.html> <out.pdf> <previewDir>
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

(async () => {
  const [html, pdf, previews] = process.argv.slice(2);
  fs.mkdirSync(previews, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 794, height: 1123 }, deviceScaleFactor: 1.5 });
  await page.goto('file://' + path.resolve(html), { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForFunction(() => [...document.images].every(i => i.complete));

  const report = await page.evaluate(() => {
    const out = [];
    document.querySelectorAll('.page').forEach((p, i) => {
      const top = p.getBoundingClientRect().top;
      const limit = p.classList.contains('dark') ? 1123 - 40 : 1123 - 64;
      let maxBottom = 0; let worst = '';
      p.querySelectorAll('*').forEach(el => {
        if (el.closest('.chrome') || el.closest('.no-measure')) return;
        const r = el.getBoundingClientRect();
        if (r.width === 0 || r.height === 0) return;
        const b = r.bottom - top;
        if (b > maxBottom) { maxBottom = b; worst = el.className || el.tagName; }
      });
      const fonts = [...document.fonts].filter(f => f.status !== 'loaded').map(f => f.family + f.weight);
      out.push({ page: i + 1, maxBottom: Math.round(maxBottom), limit, overflow: maxBottom > limit, worst: String(worst).slice(0, 60), unloadedFonts: fonts.length });
    });
    return out;
  });
  console.table(report);

  const pages = await page.$$('.page');
  for (let i = 0; i < pages.length; i++) {
    await pages[i].screenshot({ path: path.join(previews, `p${String(i + 1).padStart(2, '0')}.png`) });
  }
  await page.emulateMedia({ media: 'print' });
  await page.pdf({ path: pdf, preferCSSPageSize: true, printBackground: true });
  await browser.close();
  console.log('pdf', pdf, fs.statSync(pdf).size, 'bytes');
})();
