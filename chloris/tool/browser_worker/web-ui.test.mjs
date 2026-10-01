import {test} from 'node:test';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
import {mkdir,writeFile} from 'node:fs/promises';
const root=new URL('../../build/music-evidence/',import.meta.url);
test('Flutter Web imports a real WAV and exposes the global player',async()=>{
  await mkdir(root,{recursive:true});
  const samples=44100*8,bytes=Buffer.alloc(44+samples*2);
  bytes.write('RIFF',0);bytes.writeUInt32LE(bytes.length-8,4);bytes.write('WAVEfmt ',8);bytes.writeUInt32LE(16,16);bytes.writeUInt16LE(1,20);bytes.writeUInt16LE(1,22);bytes.writeUInt32LE(44100,24);bytes.writeUInt32LE(88200,28);bytes.writeUInt16LE(2,32);bytes.writeUInt16LE(16,34);bytes.write('data',36);bytes.writeUInt32LE(samples*2,40);
  for(let i=0;i<samples;i++)bytes.writeInt16LE(Math.round(Math.sin(i/44100*440*Math.PI*2)*1000),44+i*2);
  const file=new URL('Chloris-fixture.wav',root).pathname;await writeFile(file,bytes);
  const browser=await chromium.launch({headless:true});
  let page;
  try {
    const context=await browser.newContext({viewport:{width:1280,height:900}});page=await context.newPage();const errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    await page.goto('http://127.0.0.1:2328/#/music',{waitUntil:'domcontentloaded'});
    await page.waitForTimeout(8000);await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(1000);
    const initial=await page.locator('body').innerText();
    assert.match(initial,/导入本地音频/,'Music deep link should survive bootstrap');
    const chooser=page.waitForEvent('filechooser');
    await page.getByRole('button',{name:'导入本地音频'}).click();await (await chooser).setFiles(file);
    await page.getByRole('tab',{name:'曲库',exact:true}).click();
    await page.getByRole('button',{name:/Chloris-fixture/}).first().waitFor({timeout:20000});
    await page.getByRole('button',{name:/Chloris-fixture/}).first().click();await page.waitForTimeout(1000);
    await page.screenshot({path:new URL('music-import-player.png',root).pathname});
    await page.getByRole('button',{name:'Chloris-fixture 音乐',exact:true}).click();
    await page.getByText('Chloris-fixture',{exact:true}).first().waitFor();
    await page.getByRole('button',{name:'暂停',exact:true}).click({force:true});await page.waitForTimeout(700);
    await page.screenshot({path:new URL('music-full-player.png',root).pathname});
    await page.setViewportSize({width:390,height:844});await page.waitForTimeout(250);
    await page.screenshot({path:new URL('music-full-player-mobile.png',root).pathname});
    await page.setViewportSize({width:1280,height:900});
    await page.evaluate(async()=>{await navigator.serviceWorker.ready;});
    await context.setOffline(true);await page.reload({waitUntil:'domcontentloaded'});await page.waitForTimeout(6000);
    await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(500);
    const restored=await page.locator('body').innerText();assert.match(restored,/Chloris-fixture/,'Managed audio and queue should survive offline reload');
    await page.getByRole('button',{name:'播放',exact:true}).first().click({force:true});await page.waitForTimeout(600);
    await page.screenshot({path:new URL('music-offline-player.png',root).pathname});
    const report={initial,restored,text:await page.locator('body').innerText(),buttons:await page.getByRole('button').allInnerTexts(),errors};
    await writeFile(new URL('web-ui.json',root),JSON.stringify(report,null,2));
    assert.match(report.text,/Chloris-fixture/);assert.equal(errors.length,0);console.log(JSON.stringify(report));
  } catch(error) {
    if(page){await page.screenshot({path:new URL('ui-failure.png',root).pathname});await writeFile(new URL('ui-failure.txt',root),await page.locator('body').innerText());await writeFile(new URL('ui-failure-dom.json',root),JSON.stringify(await page.locator('[role],[aria-label]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.textContent}))),null,2));}
    throw error;
  } finally {await browser.close();}
});
