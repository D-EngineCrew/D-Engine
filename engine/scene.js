// D-Engine scene: dibuja stage + personajes (Sparrow XML + PNG) y sprites/tweens de scripts. Las imagenes salen de los mods (IndexedDB).
(function(G){
class Scene{
 constructor(mod){this.mod=mod||{assets:{},atlases:{}};this.sprites=[];this.chars={};this.tweens=[];this.timers=[];this.cache={};this.zoom=1;this.camX=640;this.camY=360;this.stage=null}
 add(s){if(!this.sprites.includes(s))this.sprites.push(s);return s}remove(s){this.sprites=this.sprites.filter(x=>x!==s)}
 find(name,hint){const n=String(name).toLowerCase().replace(/\.png$/,''),a=this.mod.assets,keys=Object.keys(a);
  const h=keys.filter(k=>k.endsWith('/'+n+'.png')||k==n+'.png'||k.endsWith('/'+n+'.jpg'));return h.find(k=>hint&&k.includes(hint))||h.find(k=>k.includes('/images/'))||h[0]}
 image(name,hint){const k=this.find(name,hint);if(!k)return null;if(this.cache[k])return this.cache[k];const im=new Image();this.cache[k]=im;
  DE.idb.get(this.mod.assets[k]).then(b=>{if(b)im.src=URL.createObjectURL(b)});return im}
 atlas(name,hint){const k=this.find(name,hint);if(!k)return null;const x=this.mod.atlases[k.replace(/\.(png|jpg)$/,'.xml')];return x?(this.cache['a'+k]=this.cache['a'+k]||DEF.sparrow(x)):null}
 // personaje animado
 addChar(slot,def,x,y,flip){if(!def)return null;const c={slot,def,x:x+(def.pos?def.pos[0]:0),y:y+(def.pos?def.pos[1]:0),img:this.image(def.image,'characters'),atlas:this.atlas(def.image,'characters'),anim:'idle',t:0,flip:def.flipX!=!!flip,hold:0};
  c.play=(n)=>{if(def.anims[n]){c.anim=n;c.t=0}};this.chars[slot]=c;return c}
 tween(o,p,t,op={}){const from={};for(const k in p)from[k]=o[k];this.tweens.push({o,p,from,t:0,d:Math.max(.0001,t),op})}
 later(t,f){this.timers.push({t,f})}
 update(dt){this.timers=this.timers.filter(x=>{x.t-=dt;if(x.t<=0){x.f();return false}return true});
  this.tweens=this.tweens.filter(w=>{w.t+=dt;const r=Math.min(1,w.t/w.d);for(const k in w.p)w.o[k]=w.from[k]+(w.p[k]-w.from[k])*r;w.op.onUpdate&&w.op.onUpdate(w.o);if(r>=1){w.op.onComplete&&w.op.onComplete(w.o);return false}return true});
  for(const k in this.chars){const c=this.chars[k],a=c.def.anims[c.anim];if(!a)continue;c.t+=dt;if(c.hold>0){c.hold-=dt;if(c.hold<=0)c.play('idle')}}}
 frame(c){const a=c.def.anims[c.anim];if(!a||!c.atlas)return null;const fr=c.atlas[a.prefix]||Object.entries(c.atlas).find(([k])=>k.startsWith(a.prefix))?.[1];if(!fr)return null;
  let list=a.indices&&a.indices.length?a.indices.map(i=>fr[i]).filter(Boolean):fr;if(!list.length)list=fr;let i=Math.floor(c.t*a.fps);i=a.loop?i%list.length:Math.min(i,list.length-1);return list[i]}
 draw(g,W,H){g.save();const z=this.zoom,s=Math.min(W/1280,H/720);g.translate(W/2,H/2);g.scale(s*z,s*z);g.translate(-this.camX,-this.camY);
  for(const sp of this.sprites.filter(p=>p.visible!==false&&!p.hud).sort((a,b)=>(a.z||0)-(b.z||0)))this.drawSprite(g,sp);
  for(const k of ['gf','dad','bf'])this.drawChar(g,this.chars[k]);g.restore();
  g.save();g.scale(s,s);g.translate((W/s-1280)/2,(H/s-720)/2);for(const sp of this.sprites.filter(p=>p.hud&&p.visible!==false))this.drawSprite(g,sp);g.restore()}
 drawSprite(g,sp){g.save();g.globalAlpha=sp.alpha==null?1:sp.alpha;g.translate(sp.x,sp.y);g.rotate((sp.angle||0)*Math.PI/180);
  const sx=(sp.scale&&sp.scale.x!=null?sp.scale.x:sp.scale)||1,sy=(sp.scale&&sp.scale.y!=null?sp.scale.y:sp.scale)||1;g.scale(sx,sy);
  if(sp.text!=null){g.fillStyle=sp.color||'#fff';g.font='bold '+(sp.size||16)+'px sans-serif';g.fillText(sp.text,0,sp.size||16)}
  else if(sp.img&&sp.img.complete&&sp.img.naturalWidth)g.drawImage(sp.img,0,0);else if(sp.color&&sp.w){g.fillStyle=sp.color;g.fillRect(0,0,sp.w,sp.h)}g.restore()}
 drawChar(g,c){if(!c||!c.img||!c.img.complete||!c.img.naturalWidth)return;const f=this.frame(c);if(!f)return;const a=c.def.anims[c.anim],o=a.off||[0,0],sc=c.def.scale||1;
  g.save();g.translate(c.x-(c.flip?-o[0]:o[0])*sc*0+(-o[0])*sc,c.y-o[1]*sc);g.scale(c.flip?-sc:sc,sc);g.drawImage(c.img,f.x,f.y,f.w,f.h,-f.fx-(c.flip?f.w:0),-f.fy,f.w,f.h);g.restore()}
 // construye el stage desde un def normalizado (V-Slice/Psych/Codename)
 loadStage(st,chars){this.stage=st;this.zoom=st.zoom||1;if(!st)return;
  for(const p of st.props||[]){const sp=this.add({x:p.x,y:p.y,scale:{x:p.scale||1,y:p.scale||1},alpha:p.alpha,z:p.z,img:this.image(p.image,st.dir)});sp.scroll=p.scroll}
  const pos=st.chars||{};for(const k of ['gf','dad','bf'])if(chars[k]&&!(k=='gf'&&st.hideGF))this.addChar(k,chars[k],(pos[k]||[0,0])[0],(pos[k]||[0,0])[1],k=='bf')}
 beat(b){for(const k in this.chars){const c=this.chars[k];if(c.hold<=0&&b%(c.def.danceEvery||2)==0)c.play('idle')}}
 sing(slot,lane,miss){const c=this.chars[slot];if(!c)return;const n='sing'+['LEFT','DOWN','UP','RIGHT'][lane]+(miss?'miss':'');c.play(c.def.anims[n]?n:(c.def.anims['sing'+['LEFT','DOWN','UP','RIGHT'][lane]]?'sing'+['LEFT','DOWN','UP','RIGHT'][lane]:c.anim));c.hold=(c.def.singTime||4)*.12}
}
G.DScene=Scene;
})(window);
