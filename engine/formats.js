// D-Engine formats: lee personajes, stages y semanas de V-Slice (json), Psych (json) y Codename (xml). Funciona en navegador y Node.
(function(G){
const DEF={};
// ---- mini XML ----
DEF.xml=s=>{s=s.replace(/^\uFEFF/,'').replace(/<!--[\s\S]*?-->/g,'').replace(/<\?[\s\S]*?\?>/g,'').replace(/<!DOCTYPE[^>]*>/gi,'');
 const root={tag:'#',attr:{},kids:[]},st=[root],re=/<(\/?)([\w:.-]+)((?:\s+[\w:.-]+\s*=\s*(?:"[^"]*"|'[^']*'))*)\s*(\/?)>/g;let m;
 while(m=re.exec(s)){if(m[1]){st.pop();continue}const a={},r=/([\w:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g;let x;while(x=r.exec(m[3]))a[x[1]]=x[2]!==undefined?x[2]:x[3];
  const n={tag:m[2],attr:a,kids:[]};st[st.length-1].kids.push(n);if(!m[4])st.push(n)}
 return root.kids[0]||root};
const num=(v,d)=>v==null||v===''||isNaN(+v)?d:+v,bool=(v,d)=>v==null?d:(v===true||v==='true');
// ---- Sparrow / TextureAtlas: {nombre:[{x,y,w,h,fx,fy,fw,fh}]} ordenado por frame ----
DEF.sparrow=t=>{const r=DEF.xml(t),o={};(function w(n){if(n.tag=='SubTexture'){const a=n.attr;(o[a.name.replace(/\d{1,4}$/,'')]=o[a.name.replace(/\d{1,4}$/,'')]||[]).push({n:a.name,x:+a.x,y:+a.y,w:+a.width,h:+a.height,fx:num(a.frameX,0),fy:num(a.frameY,0),fw:num(a.frameWidth,+a.width),fh:num(a.frameHeight,+a.height)})}n.kids.forEach(w)})(r);
 for(const k in o)o[k].sort((a,b)=>a.n<b.n?-1:1);return o};
// ---- Personajes -> {id,kind,image,scale,flipX,isPlayer,icon,color,pos:[x,y],singTime,danceEvery,anims:{name:{prefix,fps,loop,indices,off:[x,y]}}} ----
DEF.char=(path,text)=>{const id=path.split('/').pop().replace(/\.(json|xml)$/i,'');
 if(/\.xml$/i.test(path)||/^\s*(<\?xml|<!DOCTYPE|<character)/i.test(text)){const r=DEF.xml(text),a=r.attr,c={id,kind:'codename',image:a.sprite||id,scale:num(a.scale,1),flipX:bool(a.flipX,false),isPlayer:bool(a.isPlayer,false),icon:a.icon||id,color:a.color||'#a1a1a1',pos:[num(a.x,0),num(a.y,0)],singTime:num(a.holdTime,4),danceEvery:num(a.interval,1),anims:{}};
  r.kids.filter(k=>k.tag=='anim').forEach(k=>{const q=k.attr;c.anims[q.name]={prefix:q.anim,fps:num(q.fps,24),loop:bool(q.loop,false),indices:q.indices?q.indices.split(',').map(Number):[],off:[num(q.x,0),num(q.y,0)]}});return c}
 const j=JSON.parse(text);
 if(j.anims&&!Array.isArray(j.anims)){const c={id,kind:'dengine',image:(j.image||id).split('/').pop().replace(/\.png$/,''),scale:num(j.scale,1),flipX:!!j.flipX,isPlayer:false,icon:j.icon||id,color:j.healthColor||'#a1a1a1',pos:j.position||[0,0],singTime:num(j.singTime,4),danceEvery:num(j.danceEvery,2),anims:{}};for(const k in j.anims){const a=j.anims[k];c.anims[k]={prefix:a.prefix,fps:num(a.fps,24),loop:!!a.loop,indices:a.indices||[],off:a.offsets||[0,0]}}return c}
 if(j.animations&&j.animations[0]&&'anim' in j.animations[0]){const c={id,kind:'psych',image:(j.image||id).replace(/^characters\//,''),scale:num(j.scale,1),flipX:!!j.flip_x,isPlayer:false,icon:j.healthicon||id,color:'#'+(j.healthbar_colors||[161,161,161]).map(v=>('0'+v.toString(16)).slice(-2)).join(''),pos:j.position||[0,0],camPos:j.camera_position||[0,0],singTime:num(j.sing_duration,4),anims:{}};
  j.animations.forEach(a=>c.anims[a.anim]={prefix:a.name,fps:num(a.fps,24),loop:!!a.loop,indices:a.indices||[],off:a.offsets||[0,0]});return c}
 if(j.animations&&j.assetPath){const c={id,kind:'vslice',image:j.assetPath.replace(/^characters\//,''),scale:num(j.scale,1),flipX:!!j.flipX,isPlayer:false,icon:(j.healthIcon&&j.healthIcon.id)||id,color:'#a1a1a1',isPixel:!!j.isPixel,pos:[0,0],offsets:j.offsets||[0,0],singTime:num(j.singTime,8),danceEvery:num(j.danceEvery,1),renderType:j.renderType||'sparrow',anims:{}};
  j.animations.forEach(a=>c.anims[a.name]={prefix:a.prefix,fps:num(a.frameRate,24),loop:!!a.looped,indices:a.frameIndices||[],off:a.offsets||[0,0]});return c}
 return null};
// ---- Stages -> {id,kind,zoom,props:[{name,image,x,y,scale,scroll:[x,y],z,alpha,flipX,anims}],chars:{bf:[x,y],dad:[x,y],gf:[x,y]},dir,cam} ----
DEF.stage=(path,text)=>{const id=path.split('/').pop().replace(/\.(json|xml)$/i,'');
 if(/\.xml$/i.test(path)||/^\s*(<\?xml|<!DOCTYPE|<stage)/i.test(text)){const r=DEF.xml(text),a=r.attr,s={id,kind:'codename',zoom:num(a.zoom,.9),dir:a.folder||'',props:[],chars:{},cam:[num(a.startCamPosX,0),num(a.startCamPosY,0)]},sx={boyfriend:'bf',dad:'dad',girlfriend:'gf'};
  r.kids.forEach((k,i)=>{if(k.tag=='sprite'){const q=k.attr;s.props.push({name:q.name,image:q.sprite,x:num(q.x,0),y:num(q.y,0),scale:num(q.scale,1),scroll:[num(q.scroll,num(q.scrollx,1)),num(q.scroll,num(q.scrolly,1))],z:i,alpha:num(q.alpha,1),flipX:bool(q.flipX,false),anims:[]})}
   else if(sx[k.tag])s.chars[sx[k.tag]]=[num(k.attr.x,0),num(k.attr.y,0),i]});return s}
 const j=JSON.parse(text);
 if(j.props){const s={id,kind:'vslice',zoom:num(j.cameraZoom,1),dir:j.directory||'',props:[],chars:{},cam:[0,0]};
  (j.props||[]).forEach(p=>s.props.push({name:p.name,image:p.assetPath,x:(p.position||[0,0])[0],y:(p.position||[0,0])[1],scale:Array.isArray(p.scale)?p.scale[0]:num(p.scale,1),scroll:p.scroll||[1,1],z:num(p.zIndex,0),alpha:num(p.alpha,1),flipX:!!p.flipX,anims:p.animations||[]}));
  for(const k of ['bf','dad','gf'])if(j.characters&&j.characters[k])s.chars[k]=[...(j.characters[k].position||[0,0]),num(j.characters[k].zIndex,0)];return s}
 if(j.characters&&!j.boyfriend){const s={id,kind:'dengine',zoom:num(j.cameraZoom,.9),dir:'',props:[],chars:{},cam:[0,0]};if(j.background)s.props.push({name:'bg',image:j.background.split('/').pop().replace(/\.(png|jpg)$/,''),x:0,y:0,scale:1,scroll:[1,1],z:0,alpha:1,anims:[]});for(const k in j.characters)s.chars[k]=j.characters[k];return s}
 return{id,kind:'psych',zoom:num(j.defaultZoom,.9),dir:j.directory||'',props:[],chars:{bf:j.boyfriend||[770,100],dad:j.opponent||[100,100],gf:j.girlfriend||[400,130]},hideGF:!!j.hide_girlfriend,camOff:{bf:j.camera_boyfriend||[0,0],dad:j.camera_opponent||[0,0],gf:j.camera_girlfriend||[0,0]},camSpeed:num(j.camera_speed,1),cam:[0,0]}};
// ---- Semanas/Levels -> {id,kind,name,songs:[{name,icon,color}],chars:[dad,bf,gf],bg,diffs,hideStory,hideFree,props} ----
DEF.week=(path,text)=>{const id=path.split('/').pop().replace(/\.(json|xml)$/i,'');
 if(/\.xml$/i.test(path)||/^\s*(<\?xml|<!DOCTYPE|<week)/i.test(text)){const r=DEF.xml(text),a=r.attr;return{id,kind:'codename',name:a.name||id,chars:(a.chars||'').split(','),bg:a.sprite||id,diffs:a.difficulties?a.difficulties.split(','):['easy','normal','hard'],songs:r.kids.filter(k=>k.tag=='song').map(k=>({name:(k.kids[0]&&k.kids[0].text)||k.attr.name||''}))}}
 const j=JSON.parse(text);
 if(Array.isArray(j.songs)&&j.songs[0]&&Array.isArray(j.songs[0]))return{id,kind:'psych',name:j.storyName||j.weekName||id,label:j.weekName,chars:j.weekCharacters||[],bg:j.weekBackground,diffs:j.difficulties?String(j.difficulties).split(','):['easy','normal','hard'],before:j.weekBefore,hideStory:!!j.hideStoryMode,hideFree:!!j.hideFreeplay,songs:j.songs.map(s=>({name:s[0],icon:s[1],color:'rgb('+(s[2]||[146,113,253]).join(',')+')'}))};
 if(j.songs&&(j.titleAsset||j.props||j.background))return{id,kind:'vslice',name:j.name||id,chars:[],bg:j.background,title:j.titleAsset,props:j.props||[],diffs:['easy','normal','hard'],hideStory:j.visible===false,songs:j.songs.map(s=>({name:s}))};
 return null};
DEF.kind=(path,text)=>{const p=path.toLowerCase();try{
 if(/(^|\/)characters?\//.test(p)&&!/menu|dialogue|weeks\/characters/.test(p))return'char';
 if(/(^|\/)stages?\//.test(p))return'stage';
 if(/(^|\/)(weeks?|levels?|story\/levels)\//.test(p)&&!/characters/.test(p))return'week'}catch(e){}return null};
G.DEF=DEF;if(typeof module!='undefined')module.exports=DEF;
})(typeof window!='undefined'?window:globalThis);
