import React from 'react';
/* Data-sufficiency dial: hairline ring, accent arc (live state), tabular % in the middle. */
export function SufficiencyRing({pct=0,size=64,label}){
  const r=(size/2)-3, c=2*Math.PI*r;
  return <div style={{display:'inline-flex',flexDirection:'column',alignItems:'center',gap:4}}>
    <svg width={size} height={size} viewBox={'0 0 '+size+' '+size}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="var(--divider)" strokeWidth="1"/>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="var(--accent)" strokeWidth="2.5" strokeDasharray={c*pct/100+' '+c} strokeLinecap="butt" transform={'rotate(-90 '+size/2+' '+size/2+')'} style={{transition:'stroke-dasharray var(--dur-countup) var(--ease)'}}/>
      <text x="50%" y="50%" dy="0.36em" textAnchor="middle" fontFamily="var(--font-sans)" fontSize={size/4.2} fill="var(--text-1)" style={{fontVariantNumeric:'tabular-nums'}}>{Math.round(pct)}%</text>
    </svg>
    {label&&<span style={{fontFamily:'var(--font-mono)',fontSize:'var(--anno-sm)',textTransform:'uppercase',color:'var(--text-3)'}}>{label}</span>}
  </div>;
}