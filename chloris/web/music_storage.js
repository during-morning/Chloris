/* Durable audio storage: OPFS first, IndexedDB Blob fallback. */
(() => {
  const handles = new Map();
  const valid = key => { if (!/^[a-zA-Z0-9_.-]+$/.test(key)) throw Error('Invalid audio key'); return key; };
  let db;
  async function database() {
    if (db) return db;
    db = await new Promise((resolve, reject) => {
      const req = indexedDB.open('chloris_music', 1);
      req.onupgradeneeded = () => req.result.createObjectStore('files');
      req.onsuccess = () => resolve(req.result); req.onerror = () => reject(req.error);
    }); return db;
  }
  async function idb(mode, callback) {
    const d = await database();
    return new Promise((resolve, reject) => {
      const tx = d.transaction('files', mode); let value;
      const req = callback(tx.objectStore('files'));
      if (req) req.onsuccess = () => { value = req.result; };
      tx.oncomplete = () => resolve(value); tx.onerror = () => reject(tx.error); tx.onabort = () => reject(tx.error);
    });
  }
  async function directory() {
    if (!navigator.storage?.getDirectory) return null;
    const root = await navigator.storage.getDirectory();
    return root.getDirectoryHandle('chloris_music', { create: true });
  }
  async function read(key) {
    valid(key); const root = await directory();
    if (root) { try { return await (await root.getFileHandle(key)).getFile(); } catch (e) { if (e.name !== 'NotFoundError') throw e; } }
    return await idb('readonly', s => s.get(key));
  }
  globalThis.chlorisMusicStorage = {
    file: read,
    async begin(key, append) {
      valid(key);
      const estimate = await navigator.storage?.estimate?.();
      if (estimate && estimate.quota - estimate.usage < 1024 * 1024) throw Error('浏览器存储空间不足');
      await navigator.storage?.persist?.();
      const root = await directory();
      if (root) {
        const f = await root.getFileHandle(key, { create: true });
        const writer = await f.createWritable({ keepExistingData: append });
        if (append) await writer.seek((await f.getFile()).size);
        handles.set(key, { writer });
      } else {
        const old = append ? await read(key) : null;
        handles.set(key, { parts: old ? [old] : [] });
      }
    },
    async append(key, bytes) { const h = handles.get(key); if (!h) throw Error('音频写入任务不存在'); if (h.writer) await h.writer.write(bytes); else h.parts.push(new Blob([bytes])); },
    async end(key) { const h = handles.get(key); if (!h) return; try { if (h.writer) await h.writer.close(); else await idb('readwrite', s => s.put(new Blob(h.parts), key)); } finally { handles.delete(key); } },
    async abort(key) { const h=handles.get(key); handles.delete(key); if(h?.writer) await h.writer.abort(); },
    async size(key) { return (await read(key))?.size || 0; },
    async tail(key,limit){const blob=await read(key);return new Uint8Array(await blob.slice(Math.max(0,blob.size-limit)).arrayBuffer());},
    async bytes(key, limit) { const f = await read(key); if (!f) throw Error('音频文件不存在'); return new Uint8Array(await (limit > 0 ? f.slice(0, limit) : f).arrayBuffer()); },
    async open(key) { const f = await read(key); if (!f) throw Error('音频文件不存在'); if (typeof document !== 'undefined' && navigator.serviceWorker?.controller) return {url: new URL('music-offline/'+key,document.baseURI).href,size:f.size};
      if(key.endsWith('.m3u8')) throw Error('离线 HLS 需要启用 Service Worker，请刷新页面后播放');
      return { url: URL.createObjectURL(f), size: f.size }; },
    async commit(key) {
      const partial = `${valid(key)}.part`; const f=await read(partial); if(!f) throw Error('音频下载未完成');
      const root=await directory();
      if(root) { const dest=await root.getFileHandle(key,{create:true}); const w=await dest.createWritable(); await f.stream().pipeTo(w); await root.removeEntry(partial); }
      else { await idb('readwrite', s=>s.put(f,key)); await idb('readwrite',s=>s.delete(partial)); }
    },
    async remove(key) { valid(key); const root=await directory(); if(root) { try { await root.removeEntry(key); } catch(e) { if(e.name!=='NotFoundError') throw e; } } await idb('readwrite',s=>s.delete(key)); },
    async export(key, name) { const f=await read(key); if(!f) throw Error('音频文件不存在'); const url=URL.createObjectURL(f); const a=document.createElement('a'); a.href=url; a.download=name || key; a.click(); setTimeout(()=>URL.revokeObjectURL(url),30000); }
  };
})();
