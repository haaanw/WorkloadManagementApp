/* Tuwa homepage motion — ported from tuwa-website homeMotion.ts (rAF scenes + reveal/count observers). */
(function(){'use strict';
var RM=false;try{RM=window.matchMedia('(prefers-reduced-motion: reduce)').matches;}catch(e){}
if(!RM)document.documentElement.classList.add('motion');
/* hero line masks */
var hl=document.getElementById('heroLines');
if(hl){if(RM){hl.classList.add('played');}else{setTimeout(function(){hl.classList.add('played');},120);}}
/* count-ups — markup carries final values */
function runCount(el){var target=parseFloat(el.getAttribute('data-count'))||0;var comma=el.getAttribute('data-comma')==='1';
function fmt(v){return comma?v.toLocaleString('en-US'):String(v);}
if(RM){el.textContent=fmt(target);return;}
var start=null,dur=500;
function step(ts){if(start===null)start=ts;var t=Math.min((ts-start)/dur,1);var eased=1-Math.pow(1-t,3);el.textContent=fmt(Math.round(target*eased));if(t<1)requestAnimationFrame(step);}
requestAnimationFrame(step);}
/* hero readiness count on load */
var hs=document.getElementById('heroScore');
if(hs&&!RM){(function(){var start=null;function step(ts){if(start===null)start=ts;var t=Math.min((ts-start)/700,1);hs.textContent=String(Math.round(82*(1-Math.pow(1-t,3))));if(t<1)requestAnimationFrame(step);}requestAnimationFrame(step);})();}
/* reveal + counter observer */
var revealEls=Array.prototype.slice.call(document.querySelectorAll('[data-reveal]'));
var countEls=Array.prototype.slice.call(document.querySelectorAll('[data-count]'));
if(RM||typeof IntersectionObserver==='undefined'){
 revealEls.forEach(function(el){el.classList.add('in');});
 countEls.forEach(runCount);
}else{
 var counted=new WeakSet();
 var io=new IntersectionObserver(function(entries){entries.forEach(function(entry){
  if(!entry.isIntersecting)return;var el=entry.target;io.unobserve(el);
  if(el.hasAttribute('data-reveal')&&!el.classList.contains('in')){
   var sibs=revealEls.filter(function(s){return s.parentElement===el.parentElement&&!s.classList.contains('in');});
   el.style.transitionDelay=(Math.max(sibs.indexOf(el),0)*60)+'ms';el.classList.add('in');}
  if(el.hasAttribute('data-count')&&!counted.has(el)){counted.add(el);runCount(el);}
 });},{threshold:0.2,rootMargin:'0px 0px -5% 0px'});
 revealEls.forEach(function(el){io.observe(el);});
 countEls.forEach(function(el){io.observe(el);});
}
/* self-drawing chart — reduced motion handled by CSS (html:not(.motion) shows final state) */
var spark=document.getElementById('spark');
if(spark&&!RM&&typeof IntersectionObserver!=='undefined'){(function(){
 var line=spark.querySelector('path.line'),baseline=document.getElementById('baseline'),nowDot=document.getElementById('nowDot'),drawn=false;
 var cio=new IntersectionObserver(function(es){es.forEach(function(en){
  if(!en.isIntersecting||drawn)return;drawn=true;cio.disconnect();
  line.style.transition='stroke-dashoffset .9s cubic-bezier(.22,1,.36,1)';
  requestAnimationFrame(function(){line.style.strokeDashoffset='0';});
  setTimeout(function(){if(baseline){baseline.style.transition='opacity .4s';baseline.style.opacity='1';}},700);
  setTimeout(function(){if(nowDot){nowDot.style.transition='opacity .3s';nowDot.style.opacity='1';}},1000);
 });},{threshold:0.4});
 cio.observe(spark);})();}
if(RM)return;
/* ---------- rAF scenes: pinned showcase, zone scrub, fans, ghosts ---------- */
try{
 var vh=window.innerHeight||800;
 var clamp01=function(x){return x<0?0:x>1?1:x;};
 var scenes=[];
 function progressOf(el){var r=el.getBoundingClientRect();var span=r.height-vh;
  if(span<=0)return r.top<0?1:0;return clamp01(-r.top/span);}
 /* scene: sticky 3-step showcase */
 (function(){
  var wrap=document.getElementById('showWrap');if(!wrap)return;
  var railFill=document.getElementById('railFill');
  var plates=Array.prototype.slice.call(wrap.querySelectorAll('.shot'));
  var steps=Array.prototype.slice.call(wrap.querySelectorAll('.sstep'));
  var cur=-1;
  scenes.push({el:wrap,p:-1,fn:function(p){
   if(railFill)railFill.style.transform='scaleY('+p.toFixed(4)+')';
   var idx=Math.min(2,Math.floor(p*3));
   if(idx!==cur){cur=idx;
    plates.forEach(function(pl,i){pl.classList.toggle('active',i===idx);pl.classList.toggle('prev',i<idx);});
    steps.forEach(function(st,i){st.classList.toggle('active',i===idx);});}
  }});})();
 /* scene: pinned strike-zone scrub — ACWR 0.40→1.45, live zone label */
 (function(){
  var wrap=document.getElementById('zoneWrap'),bar=document.getElementById('zoneBar'),
   fill=document.getElementById('zoneFill'),needle=document.getElementById('zoneNeedle'),
   chip=document.getElementById('zoneChip'),label=document.getElementById('zoneLabel');
  if(!(wrap&&bar&&fill&&needle&&chip&&label))return;
  var barW=bar.getBoundingClientRect().width||1;
  window.addEventListener('resize',function(){barW=bar.getBoundingClientRect().width||1;});
  needle.style.left='0';fill.style.transformOrigin='left';
  var zones=[['Undertraining — room to build','var(--zone-low)'],['In the strike zone','var(--zone-optimal)'],['Trending hot — time to modify','var(--zone-caution)'],['Overreach risk — hold','var(--zone-danger)']];
  var curZ=-1;
  scenes.push({el:wrap,p:-1,fn:function(p){
   var ac=0.4+1.05*p;var pos=ac/2; /* bar axis runs 0.0–2.0 */
   fill.style.transform='scaleX('+pos.toFixed(4)+')';
   needle.style.transform='translateX('+(pos*barW).toFixed(1)+'px)';
   chip.textContent='NOW '+ac.toFixed(2);
   var z=ac<0.8?0:ac<=1.3?1:ac<=1.5?2:3;
   if(z!==curZ){curZ=z;label.textContent=zones[z][0];label.style.color=zones[z][1];}
  }});})();
 /* fans + ghost numerals, driven from the same loop */
 var spreads=Array.prototype.slice.call(document.querySelectorAll('[data-spread]'));
 var ghosts=Array.prototype.slice.call(document.querySelectorAll('[data-ghost]'));
 window.addEventListener('resize',function(){vh=window.innerHeight||800;});
 function frame(){
  var i,s,p,r,raw,eased,off;
  for(i=0;i<scenes.length;i++){s=scenes[i];p=progressOf(s.el);
   if(Math.abs(p-s.p)>0.0004){s.p=p;s.fn(p);}}
  for(i=0;i<spreads.length;i++){r=spreads[i].getBoundingClientRect();
   if(r.bottom<-80||r.top>vh+80)continue;
   raw=(vh*0.92-r.top)/(vh*0.55);eased=1-Math.pow(1-clamp01(raw),3);
   spreads[i].style.setProperty('--p',eased.toFixed(4));}
  for(i=0;i<ghosts.length;i++){r=ghosts[i].getBoundingClientRect();
   if(r.bottom<-200||r.top>vh+200)continue;
   off=(r.top+r.height/2-vh/2)*-0.08;
   ghosts[i].style.transform='translateY('+off.toFixed(1)+'px)';}
  requestAnimationFrame(frame);}
 requestAnimationFrame(frame);
}catch(e){}
})();
