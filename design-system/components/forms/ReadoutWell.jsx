import React from 'react';
/* Fixed-width debossed pocket holding a tabular value + mono unit. */
export function ReadoutWell({value,unit,width=96,color='var(--text-1)',size=22}){
  return <span style={{display:'inline-flex',alignItems:'baseline',justifyContent:'center',gap:6,width,boxSizing:'border-box',padding:'8px 10px',background:'linear-gradient(var(--well-top),var(--well-bottom))',border:'0.5px solid var(--divider-strong)',borderRadius:'var(--radius-control)',boxShadow:'inset 0 1.5px 0 var(--relief-shade), inset 0 -1px 0 var(--relief-highlight)'}}>
    <span style={{fontFamily:'var(--font-sans)',fontSize:size,lineHeight:1.1,color,fontVariantNumeric:'tabular-nums'}}>{value}</span>
    {unit&&<span style={{fontFamily:'var(--font-mono)',fontSize:10,color:'var(--text-3)',textTransform:'uppercase'}}>{unit}</span>}
  </span>;
}