import { chromium } from 'playwright';
import { createInterface } from 'node:readline';
import { lookup } from 'node:dns/promises';
import net from 'node:net';
// stdout is reserved for the versioned NDJSON protocol.
let browserPromise;
const sessions = new Map();
const reply = (id, data) => process.stdout.write(JSON.stringify({v:1,id,...data})+'\n');
function privateIP(ip) {
  if (ip.includes(':')) return ip==='::' || ip==='::1' || /^(fc|fd|fe[89ab])/i.test(ip) || ip.toLowerCase().startsWith('::ffff:') && privateIP(ip.slice(7));
  const a=ip.split('.').map(Number);
  return a[0]===0 || a[0]===10 || a[0]===127 || a[0]===169 && a[1]===254 || a[0]===172 && a[1]>=16 && a[1]<=31 || a[0]===192 && a[1]===168 || a[0]===100 && a[1]>=64 && a[1]<=127 || a[0]>=224;
}
async function allowed(url, privateAllowed) {
  const u=new URL(url);if(!['http:','https:'].includes(u.protocol) || u.username || u.password)return false;
  if(privateAllowed)return true;
  const host=u.hostname.replace(/^\[|\]$/g,'');
  const addresses=net.isIP(host)?[{address:host}]:await lookup(host,{all:true});
  return addresses.length>0 && addresses.every(a=>!privateIP(a.address));
}
async function run(m) {
  if(m.v!==1 || typeof m.id!=='string')throw Error('Unsupported browser protocol');
  if(sessions.has(m.id))throw Error('Duplicate browser operation');
  if(sessions.size>=2)throw Error('Browser worker busy');
  const session={cancelled:false,context:null};sessions.set(m.id,session);
  let timer;
  try {
    const inline=m.url==='about:blank' && typeof m.html==='string' && m.html.length>0;
    if(!inline && !await allowed(m.url,m.allowPrivate===true))throw Error('网页解析目标地址被拒绝');
    const browser=await (browserPromise ??= chromium.launch({headless:true}).then(browser=>{browser.on('disconnected',()=>{browserPromise=null;});return browser;}).catch(e=>{browserPromise=null;throw e;}));
    if(session.cancelled)throw Error('解析已取消');
    const headers={...m.headers};const cookie=headers.Cookie||headers.cookie;delete headers.Cookie;delete headers.cookie;
    const userAgent=headers['User-Agent']||headers['user-agent'];delete headers['User-Agent'];delete headers['user-agent'];
    const ctx=session.context=await browser.newContext({serviceWorkers:'block',extraHTTPHeaders:headers,...(userAgent?{userAgent}:{})});
    timer=setTimeout(()=>{session.cancelled=true;ctx.close().catch(()=>{});},Math.min(20000,Math.max(1,m.timeoutMs||20000)));
    if(session.cancelled)throw Error('解析已取消');
    if(cookie && !inline)await ctx.addCookies(cookie.split(';').map(s=>{const i=s.indexOf('=');return i>0?{name:s.slice(0,i).trim(),value:s.slice(i+1).trim(),url:new URL(m.url).origin}:null;}).filter(Boolean));
    await ctx.addInitScript(m.capture||'');
    const resources=[];
    await ctx.route('**/*',async route=>{
      try {
        if(session.cancelled || !await allowed(route.request().url(),m.allowPrivate===true))return await route.abort('blockedbyclient');
        await route.continue();
      } catch {await route.abort('blockedbyclient').catch(()=>{});}
    });
    const page=await ctx.newPage();
    page.on('request',r=>{if(resources.length<4096)resources.push({url:r.url(),options:{method:r.method(),headers:r.headers(),body:r.postData()}});});
    if(m.html && !inline) {
      // Fulfill the initial document at its real URL so relative URLs and cookies retain their origin.
      await page.route(m.url,route=>route.request().isNavigationRequest()?route.fulfill({status:200,contentType:'text/html',body:m.html}):route.fallback());
    }
    await page.goto(m.url,{waitUntil:'domcontentloaded',timeout:20000});
    if(inline)await page.setContent(m.html,{waitUntil:'domcontentloaded',timeout:20000});
    while(!session.cancelled) {
      await page.evaluate(items=>{window.__chlorisResources=(window.__chlorisResources||[]).concat(items).slice(-4096);},resources.splice(0));
      const result=await page.evaluate(m.script);
      if(result) {
        const data=JSON.parse(result);
        if(new TextEncoder().encode(data.body||'').length>2*1024*1024)throw Error('网页解析结果超过 2 MiB');
        const cookies=inline?[]:await ctx.cookies(data.url||m.url);data.cookie=cookies.map(c=>`${c.name}=${c.value}`).join('; ');
        return data;
      }
      await new Promise(resolve=>setTimeout(resolve,100));
    }
    throw Error('网页解析超时或已取消');
  } finally {
    clearTimeout(timer);session.cancelled=true;await session.context?.close().catch(()=>{});sessions.delete(m.id);
  }
}
createInterface({input:process.stdin}).on('line',line=>{
  let m;try{m=JSON.parse(line);}catch{return;}
  if(m.type==='cancel'){const s=sessions.get(m.id);if(s){s.cancelled=true;s.context?.close().catch(()=>{});}return;}
  run(m).then(data=>reply(m.id,{result:data}),e=>reply(m.id,{error:String(e.message||e)}));
});
process.stdin.on('end',async()=>{for(const s of sessions.values()){s.cancelled=true;await s.context?.close().catch(()=>{});}await (await browserPromise)?.close();process.exit(0);});
