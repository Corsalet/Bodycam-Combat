const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader', '--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.addInitScript(() => { try { localStorage.setItem('bc_build', '5'); } catch (e) { } });
  await page.goto('http://localhost:8188/', { waitUntil: 'commit', timeout: 30000 });
  await page.waitForFunction('window.BC && BC.GLB.ok === true', null, { timeout: 150000 });
  await page.evaluate("document.getElementById('bc-grain').style.display = 'none'");
  await page.evaluate('BC.debug.start("RU","sniper")');
  await page.waitForFunction('BC.G.state === "play"', null, { timeout: 40000 });
  await page.evaluate('BC.debug.clearBots(); BC.debug.teleport(-30, 25); BC.debug.setLook(2.6, -0.05)');
  await page.waitForTimeout(600);
  for (const [name, pitch] of [['A_plus', 0.22], ['B_minus', -0.22]]) {
    await page.evaluate(function (p) { BC.WPN['svd'].vmPitch = p; return p; }, pitch);
    await page.waitForTimeout(400);
    await page.screenshot({ path: '/home/z/my-project/scripts/shots/pitch_' + name + '.png' });
  }
  await browser.close();
  console.log('done');
})().catch(e => { console.error('FATAL', String(e && e.stack || e)); process.exit(1); });
