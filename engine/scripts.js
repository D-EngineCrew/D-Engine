// D-Engine scripts: HScript / .hx / .hxc (se transpilan a JS) y Lua (Fengari). Hooks de Psych, Codename y V-Slice.
(function(G){
const S={};
const skipStr=(s,i)=>{const q=s[i];i++;while(i<s.length&&s[i]!=q){if(s[i]=='\\')i++;i++}return i};
// Haxe -> JS. Devuelve {js, classes:[nombres], fns:[nombres]}
const wrapBodies=s=>{let o='',i=0;const re=/\bfunction\s*\w*\s*\([^()]*\)\s*/g;let m,last=0;
 while(m=re.exec(s)){const e=m.index+m[0].length;if(/^[{]/.test(s.slice(e))||/^\s*$/.test(s.slice(e,e+1)))continue;
  let j=e,d=0,end=-1;while(j<s.length){const c=s[j];if(c=='"'||c=="'"||c=='`'){j=skipStr(s,j)+1;continue}
   if('([{'.includes(c))d++;else if(')]}'.includes(c)){if(d==0){end=j;break}d--}else if((c==';'||c==',')&&d==0){end=c==';'?j+1:j;break}j++}
  if(end<0)continue;o+=s.slice(last,e)+'{'+wrapBodies(s.slice(e,end))+'}';last=end;re.lastIndex=end}
 return o+s.slice(last)};
S.transpile=src=>{let s=src.replace(/^\uFEFF/,'').replace(/\r/g,'');
 s=s.replace(/^\s*(package|import|using)\s[^;]*;/gm,'').replace(/^\s*#(if|elseif|else|end)\b.*$/gm,'').replace(/@:?\w+(\([^)]*\))?\s*/g,'');
 // strings con interpolacion: '...$x ${y}...' -> `...${x} ${y}...`
 let o='',i=0;while(i<s.length){const c=s[i];
  if(c=='/'&&s[i+1]=='/'){const e=s.indexOf('\n',i);o+=e<0?'':'\n';i=e<0?s.length:e+1;continue}
  if(c=='/'&&s[i+1]=='*'){const e=s.indexOf('*/',i+2);i=e<0?s.length:e+2;continue}
  if(c=='"'){const e=skipStr(s,i);o+=s.slice(i,e+1);i=e+1;continue}
  if(c=="'"){const e=skipStr(s,i);let b=s.slice(i+1,e);if(/\$[\w{$]/.test(b)){b=b.replace(/`/g,'\\`').replace(/\$\$/g,'\u0001').replace(/\$(\w+)/g,'${$1}').replace(/\u0001/g,'$');o+='`'+b+'`'}else o+="'"+b+"'";i=e+1;continue}
  o+=c;i++}
 s=o;
 const T='[\\w.]+(?:<[\\w.,<>\\s?:\\->]*>)?\\??';
 s=s.replace(new RegExp('\\b(var|final)\\s+(\\w+)\\s*:\\s*'+T,'g'),'$1 $2');
 for(let k=0;k<4;k++)s=s.replace(new RegExp('(\\b(?:var|final)\\s+[^;=(){}]*?,\\s*\\w+)\\s*:\\s*'+T,'g'),'$1');
 s=s.replace(/\bfunction\s*(\w*)\s*(?:<[^>(]*>)?\s*\(([^)]*)\)\s*(?::\s*[\w.<>,\[\]?]+)?\s*(?=[^\s:])/g,(m,n,p)=>'function '+n+'('+p.split(',').map(x=>x.replace(/\s*:\s*[\w.<>,\[\]?\s\->]+?(?=\s*=|\s*$)/,'').replace(/^\s*\?/,'')).join(',')+') ');
 s=s.replace(/\(([^()]*)\)\s*->/g,(m,p)=>'('+p.split(',').map(x=>x.replace(/\s*:\s*[\w.<>\[\]?]+/,'')).join(',')+') =>');
 s=s.replace(/\bcatch\s*\(\s*(\w+)\s*(?::[^)]*)?\)/g,'catch($1)').replace(/->/g,'=>').replace(/\bnew\s+(\w+)\s*<[^>(]*>\s*\(/g,'new $1(').replace(/\bnew Array\(\)/g,'[]').replace(/\bnew Map\(/g,'new HMap(').replace(/\bcast\s*\(\s*([^,()]+(?:\([^)]*\))?)\s*,\s*[\w.<>]+\s*\)/g,'($1)');
 s=s.replace(/\bfor\s*\(\s*(\w+)\s+in\s+([^.\n)]+?)\s*\.\.\.\s*([^)\n]+?)\)/g,'for(var $1=$2;$1<$3;$1++)').replace(/\bfor\s*\(\s*(\w+)\s*=>\s*(\w+)\s+in\s+([^)]+)\)/g,'for(var [$1,$2] of HMap.pairs($3))').replace(/\bfor\s*\(\s*(\w+)\s+in\s+([^)]+)\)/g,'for(var $1 of $2)');
 s=s.replace(/\b(public|private|static|inline|override|dynamic|extern)\s+/g,'');
 // scanner: miembros de clase (function->metodo, var->campo) y break en switch
 const cls=[],fns=[];let out='',d=0,st=[],j=0;const kw=(w)=>s.startsWith(w,j)&&!/\w/.test(s[j-1]||' ')&&!/\w/.test(s[j+w.length]||' ');
 while(j<s.length){const c=s[j];
  if(c=='"'||c=="'"||c=='`'){const e=skipStr(s,j);out+=s.slice(j,e+1);j=e+1;continue}
  if(c=='{'){const t=st.length&&st[st.length-1].pend?st[st.length-1].pend:null;if(t){st[st.length-1].pend=null;st.push({k:t,d:++d,first:true})}else{d++;st.push({k:'b',d})}out+=c;j++;continue}
  if(c=='}'){const t=st.pop();if(t&&t.k=='switch'&&!t.first)out+='break;';d--;out+=c;j++;continue}
  if(kw('class')){const m=/^class\s+(\w+)/.exec(s.slice(j));if(m){cls.push(m[1]);if(!st.length)st.push({k:'top',d:0});st[st.length-1].pend='class'}}
  else if(kw('switch'))(st.length?st[st.length-1]:(st.push({k:'top',d:0}),st[0])).pend='switch';
  const top=st[st.length-1];
  if(top&&top.k=='switch'&&(kw('case')||kw('default'))&&d==top.d){if(!top.first)out+='break;';top.first=false;
   if(kw('case')){const e=s.indexOf(':',j);const lab=s.slice(j+4,e);if(lab.includes(',')&&!/[\[({]/.test(lab)){out+=lab.split(',').map(x=>'case '+x.trim()+':').join(' ');j=e+1;continue}}}
  if(top&&top.k=='class'&&d==top.d){if(kw('function')){const m=/^function\s+(\w+)/.exec(s.slice(j));if(m){out+=m[1]=='new'?'constructor':m[1];j+=m[0].length;continue}}else if(kw('var')||kw('final')){j+=kw('var')?3:5;continue}}
  out+=c;j++}
 s=wrapBodies(out);const re=/\bfunction\s+(\w+)\s*\(/g;let m;while(m=re.exec(s))fns.push(m[1]);
 return{js:s,classes:cls,fns:[...new Set(fns)]}};
// ---- Entorno compartido (Flixel minimo sobre la escena de D-Engine) ----
class HMap extends Map{exists(k){return this.has(k)}static pairs(m){return m instanceof Map?[...m.entries()]:Object.entries(m)}}
class HBase{constructor(...a){this.args=a}}
S.env=(g)=>{const sc=g.scene,Std={int:x=>Math.trunc(x),string:x=>String(x),parseInt:x=>parseInt(x),parseFloat:x=>parseFloat(x),random:n=>Math.floor(Math.random()*n)};
 const tw=(o,p,t,op={})=>g.tween(o,p,t,op);
 const FlxG={width:1280,height:720,random:{int:(a,b)=>Math.floor(a+Math.random()*(b-a+1)),float:(a=0,b=1)=>a+Math.random()*(b-a),bool:(c=50)=>Math.random()*100<c},sound:{play:()=>({}),music:null},camera:g.camGame,get elapsed(){return g.dt},save:{data:{}},keys:{pressed:{},justPressed:{}}};
 class FlxSprite{constructor(x=0,y=0){Object.assign(this,{x,y,alpha:1,angle:0,visible:true,scale:{x:1,y:1},scrollFactor:{x:1,y:1},color:null,img:null,w:0,h:0,antialiasing:true,z:0});sc.add(this)}
  loadGraphic(p){this.img=sc.image(String(p));return this}makeGraphic(w,h,c){this.w=w;this.h=h;this.color=typeof c=='number'?'#'+('00000000'+(c>>>0).toString(16)).slice(-8).slice(2):c;return this}
  screenCenter(){this.x=(1280-(this.w||this.img?.width||0)*this.scale.x)/2;this.y=(720-(this.h||this.img?.height||0)*this.scale.y)/2;return this}setGraphicSize(w){if(this.w)this.scale.x=w/this.w;return this}updateHitbox(){}destroy(){sc.remove(this)}kill(){this.visible=false}}
 class FlxText extends FlxSprite{constructor(x,y,w,t='',s=16){super(x,y);this.text=t;this.size=s}setFormat(){return this}}
 class FlxTimer{start(t=1,cb,l=1){let n=0;const f=()=>{n++;cb&&cb(this);if(l==0||n<l)g.later(t,f)};g.later(t,f);return this}}
 const FlxTween={tween:tw,num:(a,b,t,op,cb)=>tw({v:a},{v:b},t,{...op,onUpdate:o=>cb&&cb(o.v)})};
 const FlxMath={lerp:(a,b,r)=>a+(b-a)*r,bound:(v,a,b)=>Math.max(a,Math.min(b,v)),roundDecimal:(v,n)=>Math.round(v*10**n)/10**n};
 const FlxColor={WHITE:'#fff',BLACK:'#000',RED:'#f00',GREEN:'#0f0',BLUE:'#00f',fromRGB:(r,g2,b)=>`rgb(${r},${g2},${b})`};
 const PlayState={get instance(){return g.api},get boyfriend(){return sc.chars.bf},get dad(){return sc.chars.dad},get gf(){return sc.chars.gf}};
 const Paths={image:p=>p,sound:p=>p,music:p=>p};
 return{Std,Math,HMap,HBase,FlxG,FlxSprite,FlxText,FlxTimer,FlxTween,FlxMath,FlxColor,PlayState,Paths,game:g.api,
  trace:(...a)=>console.log('[script]',...a),add:s=>s,remove:s=>sc.remove(s),insert:(i,s)=>s,
  StringTools:{trim:x=>x.trim(),startsWith:(a,b)=>a.startsWith(b),endsWith:(a,b)=>a.endsWith(b),replace:(a,b,c)=>a.split(b).join(c),lpad:(s,c,l)=>String(s).padStart(l,c)},
  Reflect:{field:(o,k)=>o[k],setField:(o,k,v)=>o[k]=v,hasField:(o,k)=>k in o},Json:{parse:JSON.parse,stringify:JSON.stringify},FlxEase:new Proxy({},{get:(_,k)=>String(k)})}};
// ---- HScript/hx/hxc -> script con hooks ----
const HOOKS={create:['onCreate','create','postCreate','onCreatePost','onSongStart'],update:['onUpdate','update'],beat:['onBeatHit','beatHit'],step:['onStepHit','stepHit'],
 hit:['goodNoteHit','onNoteHit','onPlayerHit'],opp:['opponentNoteHit','onDadHit'],miss:['noteMiss','onNoteMiss','onPlayerMiss']};
S.loadHx=(path,code,g)=>{try{const t=S.transpile(code),env=S.env(g),ext=[...t.js.matchAll(/\bextends\s+(\w+)/g)].map(m=>m[1]).filter(n=>!t.classes.includes(n)&&!(n in env));
  const pre=ext.map(n=>`var ${n}=HBase;`).join(''),names=[...t.fns,...Object.values(HOOKS).flat()],
   body=`with(env){${pre}${t.js}\nreturn {${[...new Set(names)].map(n=>`${n}:typeof ${n}!=='undefined'?${n}:undefined`).join(',')}${t.classes.length?',__classes:['+t.classes.join(',')+']':''}}}`;
  const mod=new Function('env',body)(env),objs=(mod.__classes||[]).map(C=>{try{return new C()}catch(e){console.warn(path,e);return null}}).filter(Boolean);
  const call=(names,...a)=>{for(const n of names){if(typeof mod[n]=='function')try{mod[n](...a)}catch(e){console.warn(path,n,e)}for(const o of objs)if(typeof o[n]=='function')try{o[n](...a)}catch(e){console.warn(path,n,e)}}};
  return{path,call,mod}}catch(e){console.warn('Script',path,'no compila:',e.message);return null}};
S.HOOKS=HOOKS;
// ---- Lua (Psych) via Fengari ----
S.loadLua=(path,code,g)=>{const F=G.fengari;if(!F){console.warn('Fengari no cargado; omito',path);return null}
 const {lua,lauxlib,lualib,to_luastring:tl}=F,L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const get=i=>{switch(lua.lua_type(L,i)){case lua.LUA_TSTRING:return lua.lua_tojsstring(L,i);case lua.LUA_TNUMBER:return lua.lua_tonumber(L,i);case lua.LUA_TBOOLEAN:return lua.lua_toboolean(L,i);default:return undefined}};
 const push=v=>{if(typeof v=='number')lua.lua_pushnumber(L,v);else if(typeof v=='boolean')lua.lua_pushboolean(L,v);else if(typeof v=='string')lua.lua_pushstring(L,tl(v));else lua.lua_pushnil(L)};
 const api=g.luaApi;for(const n in api){lua.lua_pushcfunction(L,()=>{const k=lua.lua_gettop(L),a=[];for(let i=1;i<=k;i++)a.push(get(i));let r;try{r=api[n](...a)}catch(e){console.warn(path,n,e)}if(r===undefined)return 0;push(r);return 1});lua.lua_setglobal(L,tl(n))}
 for(const [k,v] of Object.entries(g.luaVars()))push(v)||lua.lua_setglobal(L,tl(k));
 if(lauxlib.luaL_loadstring(L,tl(code))||lua.lua_pcall(L,0,0,0)){console.warn('Lua',path,lua.lua_tojsstring(L,-1));return null}
 const callFn=(n,...a)=>{lua.lua_getglobal(L,tl(n));if(lua.lua_type(L,-1)!=lua.LUA_TFUNCTION){lua.lua_pop(L,1);return}a.forEach(push);if(lua.lua_pcall(L,a.length,0,0))console.warn('Lua',path,n,lua.lua_tojsstring(L,-1))};
 const sync=()=>{for(const [k,v] of Object.entries(g.luaVars())){push(v);lua.lua_setglobal(L,tl(k))}};
 return{path,call:(names,...a)=>{sync();for(const n of names)callFn(n,...a)}}};
S.load=(path,code,g)=>/\.lua$/i.test(path)?S.loadLua(path,code,g):/\.(hx|hxc|hscript)$/i.test(path)?S.loadHx(path,code,g):/\.js$/i.test(path)?S.loadJs(path,code,g):null;
S.loadJs=(path,code,g)=>{const h={};try{new Function('game',code)({...g.api,on:(n,f)=>(h[n]=h[n]||[]).push(f)})}catch(e){console.warn(path,e);return null}
 const map={onCreate:'create',onUpdate:'update',onBeat:'beat',onBeatHit:'beat',onNoteHit:'hit',onMiss:'miss',onStepHit:'step'};
 return{path,call:(names,...a)=>{for(const n of names)for(const f of h[n]||[])try{f(...a)}catch(e){console.warn(path,e)}}}};
G.DES=S;if(typeof module!='undefined')module.exports=S;
})(typeof window!='undefined'?window:globalThis);
