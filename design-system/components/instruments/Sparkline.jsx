import React from 'react';
/* Plotter sparkline: 1.5px hue line, dashed baseline, mono end annotations, open-circle 'now' marker. */
export function Sparkline({data=[],hue='var(--metric-readiness)',baseline,width=340,height=40,startLabel,endLabel}){
  const min=Math.min(...data),max=Math.max(...data),span=(max-min)||1;
  const x=i=>(i/(data.length-1))*width;
  const y=v=>4+(1-(v-min)/span)*(height-12);
  const d=data.map((v,i)=>(i?'L':'M')+x(i).toFixed(1)+' '+y(v).toFixed(1)).join(' ');
  return <svg width="100%" height={height} viewBox={'0 0 '+width+' '+height} style={{display:'block'}}>
    {baseline!==undefined&&<line x1="0" y1={y(baseline)} x2={width} y2={y(baseline)} stroke="var(--text-3)" strokeWidth="1" strokeDasharray="1 3"/>}
    <path d={d} fill="none" stroke={hue} strokeWidth="1.5"/>
    <circle cx={x(data.length-1)} cy={y(data[data.length-1])} r="2.5" fill="var(--surface-el)" stroke={hue}/>
    {startLabel&&<text x="0" y={height-1} fontFamily="Fragment Mono" fontSize="7" fill="var(--text-3)">{startLabel}</text>}
    {endLabel&&<text x={width} y={height-1} textAnchor="end" fontFamily="Fragment Mono" fontSize="7" fill="var(--text-3)">{endLabel}</text>}
  </svg>;
}