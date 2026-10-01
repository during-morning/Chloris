import 'dart:convert';
import 'package:chloris_engine/chloris_engine.dart';

String browserCaptureScript() => r'''(() => {
  if(window.__chlorisCapture)return;window.__chlorisCapture=true;window.__chlorisResources=[];
  const add=(url,options={})=>{try{const u=new URL(url,location.href).href;if(window.__chlorisResources.length<4096 && !window.__chlorisResources.some(r=>r.url===u))window.__chlorisResources.push({url:u,options});}catch(_){}};
  const originalFetch=window.fetch;
  window.fetch=function(input,init={}){const url=typeof input==='string'?input:input?.url;add(url,{method:init.method||input?.method||'GET',headers:Object.fromEntries(new Headers(init.headers||input?.headers||{}).entries()),body:typeof init.body==='string'?init.body:null});return originalFetch.apply(this,arguments).then(r=>{add(r.url);return r;});};
  const open=XMLHttpRequest.prototype.open,send=XMLHttpRequest.prototype.send,set=XMLHttpRequest.prototype.setRequestHeader;
  XMLHttpRequest.prototype.open=function(method,url){this.__chloris={method,url,headers:{}};return open.apply(this,arguments);};
  XMLHttpRequest.prototype.setRequestHeader=function(k,v){if(this.__chloris)this.__chloris.headers[k]=v;return set.apply(this,arguments);};
  XMLHttpRequest.prototype.send=function(body){if(this.__chloris){this.__chloris.body=typeof body==='string'?body:null;add(this.__chloris.url,this.__chloris);}return send.apply(this,arguments);};
  try{new PerformanceObserver(list=>{for(const e of list.getEntries())add(e.name);}).observe({type:'resource',buffered:true});}catch(_){}
})();''';
String browserResultScript(WebViewRequest request) {
  final regex = jsonEncode(request.sourceRegex ?? '');
  final js = jsonEncode(request.javaScript ?? '');
  return '''(() => {
    const regex=$regex,js=$js;let result=null;
    if(js && !window.__chlorisJsStarted){window.__chlorisJsStarted=true;try {let value;try{value=(0,eval)(js);}catch(_){value=(new Function(js))();}Promise.resolve(value).then(v=>window.__chlorisJsResult=v).catch(()=>{});}catch(_) {}}

    if(regex){const re=new RegExp(regex);const items=(window.__chlorisResources||[]).concat(Array.from(document.querySelectorAll('audio,video,source,[src]')).map(n=>({url:n.currentSrc||n.src||n.getAttribute('src'),options:{}})));
      const found=items.find(r=>r.url && re.test(r.url));if(found)result=found.url+(Object.keys(found.options||{}).length?', '+JSON.stringify(found.options):'');}
    if(!result && js)result=window.__chlorisJsResult;
    if(regex && !result)return null;
    if(!result && !js && document.readyState==='complete')result=document.documentElement.outerHTML;
    if(result===null || result===undefined || result==='')return null;
    return JSON.stringify({body:typeof result==='object'?JSON.stringify(result):String(result),url:location.href,cookie:document.cookie||''});
  })();''';
}
