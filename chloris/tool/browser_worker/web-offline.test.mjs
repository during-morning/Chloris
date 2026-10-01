import {test} from 'node:test';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
const origin=process.env.CHLORIS_WEB_TEST_ORIGIN||'http://127.0.0.1:2328';
test('OPFS + Service Worker supports offline Range, HEAD, HLS paths and real audio',async()=>{
  const browser=await chromium.launch({headless:true});
  try {
    const context=await browser.newContext();const page=await context.newPage();
    await page.goto(origin,{waitUntil:'domcontentloaded'});
    await page.evaluate(async()=>{await navigator.serviceWorker.ready;if(!navigator.serviceWorker.controller)await new Promise(resolve=>navigator.serviceWorker.addEventListener('controllerchange',resolve,{once:true}));});
    const stored=await page.evaluate(async()=>{
      const samples=44100*4,bytes=new Uint8Array(44+samples*2),view=new DataView(bytes.buffer);
      const text=(offset,str)=>Array.from(str).forEach((c,i)=>bytes[offset+i]=c.charCodeAt(0));
      text(0,'RIFF');view.setUint32(4,bytes.length-8,true);text(8,'WAVE');text(12,'fmt ');view.setUint32(16,16,true);view.setUint16(20,1,true);view.setUint16(22,1,true);view.setUint32(24,44100,true);view.setUint32(28,88200,true);view.setUint16(32,2,true);view.setUint16(34,16,true);text(36,'data');view.setUint32(40,samples*2,true);
      for(let i=0;i<samples;i++)view.setInt16(44+i*2,Math.sin(i/44100*440*2*Math.PI)*1000,true);
      const storage=chlorisMusicStorage;await storage.begin('fixture.wav.part',false);await storage.append('fixture.wav.part',bytes);await storage.end('fixture.wav.part');await storage.commit('fixture.wav');
      await storage.begin('fixture.m3u8',false);await storage.append('fixture.m3u8',new TextEncoder().encode('#EXTM3U\n#EXTINF:4,\nfixture.wav\n#EXT-X-ENDLIST'));await storage.end('fixture.m3u8');
      return storage.open('fixture.wav');
    });
    await context.setOffline(true);
    const result=await page.evaluate(async url=>{
      const response=await fetch(url,{headers:{Range:'bytes=0-43'}}),head=await fetch(url,{method:'HEAD'}),playlist=await fetch(url.replace('fixture.wav','fixture.m3u8'));
      const audio=new Audio(url);await new Promise((resolve,reject)=>{audio.onloadedmetadata=resolve;audio.onerror=reject;});await audio.play();await new Promise(resolve=>setTimeout(resolve,150));audio.pause();audio.currentTime=2;
      const result={code:response.status,range:response.headers.get('content-range'),length:(await response.arrayBuffer()).byteLength,head:head.status,headBytes:(await head.arrayBuffer()).byteLength,hls:await playlist.text(),duration:audio.duration,position:audio.currentTime};audio.removeAttribute('src');audio.load();return result;
    },stored.url);
    assert.equal(result.code,206);assert.equal(result.length,44);assert.equal(result.head,200);assert.equal(result.headBytes,0);assert.match(result.hls,/fixture.wav/);assert.equal(result.duration,4);assert.equal(result.position,2);
    const cycles=await page.evaluate(async url=>{
      let durations=0,positions=0;
      for(let i=0;i<30;i++){
        chlorisMusicAudio.attach((type)=>{if(type==='duration')durations++;if(type==='position')positions++;});
        await chlorisMusicAudio.load(JSON.stringify({urls:[url],durations:[null],hls:false}));
        await chlorisMusicAudio.play();chlorisMusicAudio.pause();await chlorisMusicAudio.seek(2000);chlorisMusicAudio.dispose();
      }
      return {cycles:30,durations,positions};
    },stored.url);
    assert.equal(cycles.durations,30);console.log(JSON.stringify(cycles));
    console.log(JSON.stringify(result));
  }finally{await browser.close();}
});
