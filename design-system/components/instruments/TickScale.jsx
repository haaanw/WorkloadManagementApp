import React from 'react';
/* The measured-value grammar: two-weight ticks, optional zone band, 1.5px accent needle.
   Needles travel current→new directly, never back through zero. */
export function TickScale({value=0,min=0,max=100,zone,ghost,width='100%',hue='var(--accent)'}){
  const pct=v=>((v-min)/(max-min))*100;
  const ticks=[];
  for(let i=0;i<=16;i++)ticks.push(i);
  return <div style={{position:'relative',width,height:26,boxSizing:'border-box'}}>
    {zone&&<div style={{position:'absolute',left:pct(zone[0])+'%',width:(pct(zone[1])-pct(zone[0]))+'%',top:2,height:14,background:'var(--zone-optimal)',opacity:.12}}/>}
    <div style={{position:'absolute',inset:'2px 0 auto 0',display:'flex',justifyContent:'space-between',alignItems:'flex-start',height:14}}>
      {ticks.map(i=><span key={i} style={{width:1,height:i%4===0?12:6,background:i%4===0?'var(--text-2)':'var(--text-3)',opacity:i%4===0?1:.7}}/>)}
    </div>
    {ghost!==undefined&&<span style={{position:'absolute',left:'calc('+pct(ghost)+'% - 0.75px)',top:0,width:1.5,height:18,background:'var(--text-3)',opacity:.5}}/>}
    <span style={{position:'absolute',left:'calc('+pct(value)+'% - 0.75px)',top:0,width:1.5,height:18,background:hue,transition:'left var(--dur-countup) var(--ease)'}}/>
    <div style={{position:'absolute',bottom:0,left:0,right:0,display:'flex',justifyContent:'space-between',fontFamily:'var(--font-mono)',fontSize:8,color:'var(--text-3)'}}><span>{min}</span><span>{max}</span></div>
  </div>;
}