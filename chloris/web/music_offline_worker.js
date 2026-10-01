importScripts('music_storage.js');
const CACHE='chloris-music-shell-v2';
self.addEventListener('install',event=>event.waitUntil((async()=>{
  const cache=await caches.open(CACHE);
  const files=[
    'index.html','flutter_bootstrap.js','flutter.js','main.dart.js',
    'sqlite3.wasm','drift_worker.js','music_storage.js','music_audio.js',
    'vendor/hls-1.7.3.min.js','canvaskit/canvaskit.js','canvaskit/canvaskit.wasm',
    'assets/AssetManifest.bin','assets/AssetManifest.bin.json','assets/FontManifest.json',
    'assets/assets/sources/default_book_sources.json',
    'assets/assets/sources/default_txt_toc_rules.json',
    'assets/assets/sources/default_replace_rules.json',
    'assets/assets/sources/default_dict_rules.json',
    'assets/assets/sources/default_rss_sources.json',
    'assets/assets/brand/icon.png','manifest.json','favicon.png'
  ];
  const fonts=await fetch('assets/FontManifest.json',{cache:'reload'});
  if(!fonts.ok)throw Error('Offline font manifest unavailable');
  for(const family of await fonts.json()) {
    for(const font of family.fonts||[])files.push('assets/'+font.asset);
  }
  // A worker only becomes ready after every startup dependency is saved.
  // Bounded parallel fetches avoid serially loading the larger CJK fonts.
  let cursor=0;
  await Promise.all(Array.from({length:4},async()=>{
    while(cursor<files.length){
      const file=files[cursor++],response=await fetch(file,{cache:'reload'});
      if(!response.ok)throw Error('Offline startup asset unavailable: '+file);
      await cache.put(file,response);
    }
  }));
  await self.skipWaiting();
})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  for(const name of await caches.keys()) {
    if(name.startsWith('chloris-music-shell-') && name!==CACHE)await caches.delete(name);
  }
  await self.clients.claim();
})()));
self.addEventListener('fetch',event=>{
  const url=new URL(event.request.url);if(url.origin!==location.origin)return;
  if(url.pathname.includes('/music-offline/')) {
    event.respondWith((async()=>{
      try {
        const key=decodeURIComponent(url.pathname.split('/music-offline/')[1]);
        const file=await chlorisMusicStorage.file(key);if(!file)return new Response('音频文件不存在',{status:404});
        const mime=key.endsWith('.m3u8')?'application/vnd.apple.mpegurl':key.endsWith('.mp3')?'audio/mpeg':key.endsWith('.m4a')?'audio/mp4':'application/octet-stream';
        const range=event.request.headers.get('range');let start=0,end=file.size-1;
        if(range){const m=/^bytes=(\d*)-(\d*)$/.exec(range);if(!m)return new Response(null,{status:416});if(m[1]){start=Number(m[1]);if(m[2])end=Math.min(Number(m[2]),end);}else if(m[2]){start=Math.max(0,file.size-Number(m[2]));}}
        if(start>end || start>=file.size)return new Response(null,{status:416,headers:{'content-range':`bytes */${file.size}`}});
        const headers={'content-type':mime,'accept-ranges':'bytes','content-length':String(end-start+1)};
        if(range)headers['content-range']=`bytes ${start}-${end}/${file.size}`;
        return new Response(event.request.method==='HEAD'?null:file.slice(start,end+1),{status:range?206:200,headers});
      }catch(_){return new Response('离线音频不可用',{status:500});}
    })());return;
  }
  if(event.request.method!=='GET' || url.search || /\/(proxy|api)\//.test(url.pathname))return;
  event.respondWith((async()=>{
    const cache=await caches.open(CACHE);
    try{const response=await fetch(event.request);if(response.ok && (url.pathname.includes('/assets/') || !response.headers.get('content-type')?.includes('application/json')))await cache.put(event.request,response.clone());return response;}
    catch(e){const cached=await cache.match(event.request);if(cached)return cached;if(event.request.mode==='navigate'){const shell=await cache.match('index.html');if(shell)return shell;}throw e;}
  })());
});
