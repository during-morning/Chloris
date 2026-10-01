(() => {
  let audio,hls,urls=[],segment=0,durations=[],callback,generation=0,cancelSource;
  const emit=(type,value)=>callback?.(type,JSON.stringify(value));
  const offset=()=>durations.slice(0,segment).reduce((a,b)=>a+(b||0),0);
  const total=()=>durations.length && durations.every(Number.isFinite)?durations.reduce((a,b)=>a+b,0):null;
  function ensure(){
    if(audio)return;audio=new Audio();audio.preload='metadata';
    audio.addEventListener('playing',()=>emit('state',{phase:'ready',playing:true}));
    audio.addEventListener('pause',()=>emit('state',{phase:'ready',playing:false}));
    audio.addEventListener('waiting',()=>emit('state',{phase:'buffering',playing:!audio.paused}));
    audio.addEventListener('timeupdate',()=>emit('position',Math.round((offset()+audio.currentTime)*1000)));
    audio.addEventListener('loadedmetadata',()=>{durations[segment]=Number.isFinite(audio.duration)?audio.duration:null;emit('duration',total()===null?null:Math.round(total()*1000));});
    audio.addEventListener('error',()=>{if(audio.getAttribute('src'))emit('error',audio.error?.message||'浏览器无法解码此音频');});
    audio.addEventListener('ended',async()=>{const g=generation;if(segment+1<urls.length){segment++;try{await source(g);if(g===generation)await audio.play();}catch(e){if(g===generation)emit('error',String(e));}}else emit('state',{phase:'completed',playing:false});});
  }
  function reset(){cancelSource?.();cancelSource=null;hls?.destroy();hls=null;audio?.pause();audio?.removeAttribute('src');audio?.load();}
  async function source(g){
    reset();if(g!==generation)throw Error('旧加载已取消');
    const url=urls[segment],a=audio;
    await new Promise((resolve,reject)=>{
      let done=false;const finish=e=>{if(done)return;done=true;clearTimeout(timer);a.removeEventListener('loadedmetadata',ready);a.removeEventListener('error',error);cancelSource=null;e?reject(e):resolve();};
      const ready=()=>finish(g!==generation?Error('旧加载已取消'):null),error=()=>finish(Error(a.error?.message||'音频加载失败'));
      const timer=setTimeout(()=>finish(Error('音频加载超时')),15000);
      cancelSource=()=>finish(Error('旧加载已取消'));a.addEventListener('loadedmetadata',ready);a.addEventListener('error',error);
      if((/\.m3u8(?:$|[?#])/.test(url)||urls.hls) && !a.canPlayType('application/vnd.apple.mpegurl')){
        if(!window.Hls?.isSupported()){finish(Error('此浏览器不支持 HLS 音频'));return;}
        hls=new Hls({enableWorker:true});const active=hls;
        hls.on(Hls.Events.MEDIA_ATTACHED,()=>{if(g===generation)active.loadSource(url);});
        hls.on(Hls.Events.ERROR,(_,data)=>{if(data.fatal)finish(Error(data.details));});hls.attachMedia(a);
      }else{a.src=url;a.load();}
    });
  }
  window.chlorisMusicAudio={
    attach(fn){callback=fn;ensure();},
    async load(json){ensure();const g=++generation,data=JSON.parse(json);urls=data.urls;urls.hls=data.hls;segment=0;durations=data.durations;emit('state',{phase:'loading',playing:false});await source(g);if(g===generation)emit('state',{phase:'ready',playing:false});},
    play(){return audio.play();},pause(){audio?.pause();},stop(){generation++;reset();},
    async seek(ms){const g=generation;let target=ms/1000,i=0;while(i+1<durations.length && durations[i]!=null && target>=durations[i])target-=durations[i++];const wasPlaying=!audio.paused;if(i!==segment){segment=i;await source(g);}if(g!==generation)return;audio.currentTime=Math.max(0,target);if(wasPlaying)await audio.play();},
    speed(v){ensure();audio.playbackRate=v;},volume(v){ensure();audio.volume=v;},
    dispose(){this.stop();callback=null;audio=null;urls=[];durations=[];}
  };
})();
