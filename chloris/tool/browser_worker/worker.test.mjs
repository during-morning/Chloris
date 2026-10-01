import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';
import {fileURLToPath} from 'node:url';
const worker=spawn(process.execPath,[fileURLToPath(new URL('./worker.mjs',import.meta.url))],{stdio:['pipe','pipe','pipe']});
const pending=new Map();let seq=0;
createInterface({input:worker.stdout}).on('line',line=>{const m=JSON.parse(line);pending.get(m.id)?.(m);pending.delete(m.id);});
worker.stderr.on('data',chunk=>process.stderr.write(chunk));
function run(input){const id='test-'+seq++;const future=new Promise(resolve=>pending.set(id,resolve));worker.stdin.write(JSON.stringify({v:1,id,url:'https://example.com/',html:'<html><body></body></html>',capture:'',script:'null',timeoutMs:2000,...input})+'\n');return {id,future};}
const script="(() => { const n=document.querySelector('audio'); return n?JSON.stringify({body:n.src,url:location.href}):null; })()";
test('delayed DOM media is captured in a real Chromium context',async()=>{const {future}=run({html:"<html><script>setTimeout(()=>{const a=document.createElement('audio');a.src='https://cdn.chloris.example/music.mp3';document.body.append(a)},200)</script><body></body></html>",script});const result=await future;assert.equal(result.result.body,'https://cdn.chloris.example/music.mp3');});
test('inline HTML executes scripts without requiring a page origin',async()=>{const result=await run({url:'about:blank',html:"<script>setTimeout(()=>{const a=document.createElement('audio');a.src='https://cdn.chloris.example/inline.mp3';document.body.append(a)},150)</script><body></body>",script}).future;assert.equal(result.result.body,'https://cdn.chloris.example/inline.mp3');});
test('thirty successive parsing contexts release their session slots',async()=>{for(let i=0;i<30;i++){const result=await run({url:'about:blank',script:"JSON.stringify({body:'ready',url:location.href})"}).future;assert.equal(result.result.body,'ready');}});
test('fetch requests expose method and body',async()=>{const {future}=run({html:"<script>fetch('https://cdn.chloris.example/song',{method:'POST',body:'token=fixture'}).catch(()=>{})</script>",script:"(() => {const r=window.__chlorisResources?.find(r=>r.url.includes('/song'));return r?JSON.stringify({body:JSON.stringify(r),url:location.href}):null;})()"});const result=await future;const resource=JSON.parse(result.result.body);assert.equal(resource.options.method,'POST');assert.equal(resource.options.body,'token=fixture');});
test('cancellation closes a context and releases its slot',async()=>{const {id,future}=run({script:'null',timeoutMs:10000});setTimeout(()=>worker.stdin.write(JSON.stringify({v:1,type:'cancel',id})+'\n'),500);assert.match((await future).error,/取消|closed|超时/);const result=await run({script:"JSON.stringify({body:'ready',url:location.href})"}).future;assert.equal(result.result.body,'ready');});
test('deadline and private network guard return explicit failures',async()=>{const timed=await run({timeoutMs:100,script:'null'}).future;assert.ok(timed.error);const blocked=await run({url:'http://127.0.0.1/'}).future;assert.match(blocked.error,/拒绝/);});
after(async()=>{worker.stdin.end();await new Promise(resolve=>worker.on('exit',resolve));});
