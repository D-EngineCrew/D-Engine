// D-Engine core: cookies, chart converters (Psych/V-Slice/Codename), mod loader
const DE={
 cfg:{scale:.8,hitbox:false,hideEnemy:false,noMissTap:true,pos:'bottom',fs:false},
 load(){try{const m=document.cookie.match(/de_cfg=([^;]+)/);if(m)Object.assign(this.cfg,JSON.parse(decodeURIComponent(m[1])))}catch(e){}return this.cfg},
 save(){document.cookie='de_cfg='+encodeURIComponent(JSON.stringify(this.cfg))+';max-age=31536000;path=/'},
 mods(){try{return JSON.parse(localStorage.de_mods||'[]')}catch(e){return[]}},
 saveMods(m){try{localStorage.de_mods=JSON.stringify(m);document.cookie='de_modnames='+encodeURIComponent(m.map(x=>x.name).join('|'))+';max-age=31536000;path=/'}catch(e){alert('Mod muy grande para guardar')}},
 // Normaliza a {bpm,notes:[{t(ms),lane 0-3,sus(ms),pl:bool}]}
 psych(j){const s=j.song||j;let bpm=s.bpm,t=0,out=[];(s.notes||[]).forEach(sec=>{if(sec.changeBPM)bpm=sec.bpm;(sec.sectionNotes||[]).forEach(n=>{const l=n[1]%8,pl=sec.mustHitSection?l<4:l>=4;out.push({t:n[0],lane:l%4,sus:n[2]||0,pl})})});return{bpm:s.bpm,notes:out}},
 vslice(chart,meta,diff='normal'){const n=(chart.notes[diff]||Object.values(chart.notes)[0]||[]).map(x=>({t:x.t,lane:x.d%4,sus:x.l||0,pl:x.d<4}));const bpm=meta?.timeChanges?.[0]?.bpm||100;return{bpm,notes:n}},
 codename(chart,meta){const out=[];(chart.strumLines||[]).forEach(sl=>sl.notes.forEach(n=>out.push({t:n.time,lane:n.id%4,sus:n.sLen||0,pl:sl.type==1})));return{bpm:meta?.bpm||chart.meta?.bpm||100,notes:out}},
 detect(files){ // files: {path:text}
  const k=Object.keys(files);
  if(k.some(f=>/_polymod_meta\.json$/.test(f)))return'vslice';
  if(k.some(f=>/pack\.json$/.test(f)))return k.some(f=>/songs\/.+\/charts\/|\.hx$/.test(f))?'codename':'psych';
  return k.some(f=>/\.lua$/.test(f))?'psych':'unknown'},
 demo(){const n=[];for(let i=0;i<64;i++){n.push({t:2000+i*500,lane:(i*3+(i>>2))%4,sus:0,pl:true});n.push({t:2250+i*500,lane:(i*5)%4,sus:0,pl:false})}return{bpm:120,notes:n}}
};

// ---- Constantes reales de V-Slice 0.8.7 (Scoring.hx / Constants.hx / Strumline.hx) ----
DE.K={PPMS:.45,STRUM:104,SPACE:112,HMAX:2,HSTART:1,SICK:45,GOOD:90,BAD:135,SHIT:160,
 H:{sick:.03,good:.015,bad:0,shit:-.02},HMISS:-.08,HHOLD:.12,PMAX:500,PMIN:9,SLOPE:.08,OFF:54.99,PERFECT:5,MISS:-100};
DE.judge=ms=>{const a=Math.abs(ms);return a<=DE.K.SICK?'sick':a<=DE.K.GOOD?'good':a<=DE.K.BAD?'bad':'shit'};
DE.score=ms=>{const a=Math.abs(ms),k=DE.K;if(a>k.SHIT)return k.MISS;if(a<k.PERFECT)return k.PMAX;return Math.floor(k.PMAX*(1-1/(1+Math.exp(-k.SLOPE*(a-k.OFF))))+k.PMIN)};
// ---- Formato nativo D-Engine: {bpm,speed,notes:[{t,d,l}],events:[]} d 0-3 jugador, 4-7 rival ----
DE.native=j=>({bpm:j.bpm||100,speed:j.speed||1.5,events:j.events||[],notes:(j.notes||[]).map(n=>({t:n.t,lane:n.d%4,sus:n.l||0,pl:n.d<4}))});
// ---- IndexedDB para audio de mods ----
DE.idb={db:null,open(){return this.db||(this.db=new Promise((r,j)=>{const q=indexedDB.open('dengine',1);q.onupgradeneeded=()=>q.result.createObjectStore('f');q.onsuccess=()=>r(q.result);q.onerror=j}))},
 async put(k,v){const d=await this.open();return new Promise(r=>{const t=d.transaction('f','readwrite');t.objectStore('f').put(v,k);t.oncomplete=r})},
 async get(k){const d=await this.open();return new Promise(r=>{const q=d.transaction('f').objectStore('f').get(k);q.onsuccess=()=>r(q.result)})}};
// ---- Import universal: IGNORA versiones; detecta por estructura. Guarda el mod completo en IndexedDB ----
DE.getMod=id=>DE.idb.get('mod:'+id);
DE.importZip=async(file,JSZ)=>{let intro='';const z=await JSZ.loadAsync(file),files={},audio=[],assets={},atlases={},scripts=[];
 for(const p in z.files){const e=z.files[p];if(e.dir)continue;const lp=p.toLowerCase();
  if(/\.(json|xml)$/i.test(p))files[p]=await e.async('string');
  if(/\.(xml)$/i.test(p))atlases[lp]=files[p];
  if(/(^|\/)introtext\.txt$/i.test(p))intro=await e.async('string');
  if(/\.(lua|hx|hxc|hscript|js)$/i.test(p)&&!/node_modules/.test(p)){const code=await e.async('string');scripts.push({path:p,code});}
  else if(/\.(ogg|mp3|wav)$/i.test(p))audio.push(p);
  else if(/\.(png|jpg|jpeg)$/i.test(p)){const k=file.name+'/'+p;await DE.idb.put(k,await e.async('blob'));assets[lp]=k}}
 const eng=Object.keys(files).some(p=>/(^|\/)dmod\.json$/.test(p))?'D-Engine':DE.detect(files);
 const mp=Object.keys(files).find(p=>/(^|\/)(dmod|pack|_polymod_meta|meta)\.json$/.test(p));let info={};try{info=JSON.parse(files[mp])}catch(e){}
 const modId=(info.id||info.name||file.name.replace(/\.zip$/i,'')).toString().replace(/\W+/g,'_'),songs=[],chars={},stages={},weeks=[];
 for(const p in assets)assets[p]=assets[p]; // claves ya guardadas
 for(const p in files){if(!/\.(json|xml)$/i.test(p))continue;const kd=DEF.kind(p,'');
  try{if(kd=='char'){const c=DEF.char(p,files[p]);if(c)chars[c.id]=c}else if(kd=='stage'){const s=DEF.stage(p,files[p]);if(s)stages[s.id]=s}else if(kd=='week'){const w=DEF.week(p,files[p]);if(w)weeks.push(w)}}catch(e){}
  if(!/\.json$/.test(p)||/(dmod|pack|meta|manifest|stage|character|week|level)[^/]*\.json$/i.test(p)&&!/chart/i.test(p)||kd)continue;
  try{const j=JSON.parse(files[p]);let c=null;
   if(j.song&&j.song.notes)c=DE.psych(j);else if(j.strumLines)c=DE.codename(j,null);
   else if(j.notes&&!Array.isArray(j.notes)){const mpth=Object.keys(files).find(f=>/metadata/.test(f)&&f.split('/').slice(0,-1).join('/')==p.split('/').slice(0,-1).join('/'));c=DE.vslice(j,mpth&&JSON.parse(files[mpth]))}
   else if(Array.isArray(j.notes)&&j.notes.length&&'d' in j.notes[0])c=DE.native(j);
   if(!c||!c.notes.length)continue;
   const seg=p.split('/'),i=seg.findIndex(x=>x.toLowerCase()=='songs'),name=(i>=0&&seg[i+1]&&!/\.json$/.test(seg[i+1])?seg[i+1]:seg[seg.length-2])||'song';
   if(songs.some(s=>s.name==name&&s.chart.notes.length>=c.notes.length))continue;
   const mine=audio.filter(a=>a.toLowerCase().includes('/'+name.toLowerCase()+'/')||a.toLowerCase().startsWith(name.toLowerCase()+'/'));
   const keys={inst:null,voices:[]};
   for(const a of mine){const f=a.split('/').pop().toLowerCase(),k=modId+'/'+a;
    if(/inst/.test(f)){keys.inst=k;await DE.idb.put(k,await z.files[a].async('blob'))}else if(/voices/.test(f)){keys.voices.push(k);await DE.idb.put(k,await z.files[a].async('blob'))}}
   songs.push({name,chart:c,audio:keys,speed:c.speed||(j.song&&j.song.speed)||1.5,stage:j.song&&j.song.stage,player:j.song&&j.song.player1,opponent:j.song&&j.song.player2,gf:j.song&&j.song.gfVersion})}catch(e){}}
 const full={id:modId,name:info.name||modId,engine:eng,songs,chars,stages,weeks,assets,atlases,scripts,intro};
 await DE.idb.put('mod:'+modId,full);
 return{id:modId,name:full.name,engine:eng,intro:intro.slice(0,4000),songs:songs.map(s=>({name:s.name})),weeks:weeks.map(w=>({id:w.id,name:w.name,songs:w.songs,chars:w.chars,diffs:w.diffs,bg:w.bg,hideStory:w.hideStory,hideFree:w.hideFree})),counts:{chars:Object.keys(chars).length,stages:Object.keys(stages).length,weeks:weeks.length,scripts:scripts.length,lua:scripts.filter(x=>/\.lua$/i.test(x.path)).length,hx:scripts.filter(x=>/\.(hx|hxc|hscript)$/i.test(x.path)).length}}};
DE.load();
// ---- helpers de menus ----
DE.base=()=>DE._b||(DE._b=fetch('base/base.json').then(r=>r.json()).then(j=>j&&j.weeks?j:{weeks:[],chars:{},stages:{}}).catch(()=>({weeks:[],chars:{},stages:{}})));
DE.allWeeks=async()=>{const b=await DE.base(),seen=new Set(),w=b.weeks.filter(x=>{let k=String((x.songs[0]||{}).name||x.id).toLowerCase().replace(/\W/g,'').toLowerCase().replace(/\W/g,'');if(seen.has(k))return false;seen.add(k);return true}).map(x=>({...x,from:'D-Engine base ('+x.src+')'}));DE.mods().forEach(m=>(m.weeks||[]).forEach(x=>w.push({...x,from:m.name,mod:m.id})));return w};
DE.findSong=name=>{const n=String(name).toLowerCase().replace(/[\s_-]/g,'');for(const m of DE.mods()){const i=m.songs.findIndex(s=>s.name.toLowerCase().replace(/[\s_-]/g,'')==n);if(i>=0)return'mod='+encodeURIComponent(m.id)+'&i='+i}return'demo=1&name='+encodeURIComponent(name)};
DE.hiscore=(k,v)=>{try{const d=JSON.parse(localStorage.de_scores||'{}');if(v!=null){d[k]=Math.max(d[k]||0,v);localStorage.de_scores=JSON.stringify(d)}return d[k]||0}catch(e){return 0}};
