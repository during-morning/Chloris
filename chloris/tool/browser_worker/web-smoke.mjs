import {chromium} from 'playwright';
import {mkdir,writeFile} from 'node:fs/promises';
const dir=new URL('../../build/music-evidence/',import.meta.url);
await mkdir(dir,{recursive:true});
const browser=await chromium.launch({headless:true});
try {
  const context=await browser.newContext({viewport:{width:1280,height:900}});
  const page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:2328/#/music',{waitUntil:'domcontentloaded',timeout:60000});
  await page.waitForTimeout(8000);
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1000);
  if(!(await page.locator('body').innerText()).includes('发现')) {
    await page.mouse.click(95,238);await page.waitForTimeout(1500);
  }
  await page.screenshot({path:new URL('music-desktop.png',dir).pathname});
  const report={title:await page.title(),url:page.url(),text:await page.locator('body').innerText(),labels:await page.locator('[aria-label]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label')}))),errors};
  await writeFile(new URL('initial-web.json',dir),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
}finally {await browser.close();}
