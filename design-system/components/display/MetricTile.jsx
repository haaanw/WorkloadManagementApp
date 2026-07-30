import React from 'react';
/* Compact stat tile: micro-caps title / tabular value / mono subtitle. */
export function MetricTile({title,value,subtitle,color='var(--text-1)'}){
  return <div style={{background:'var(--surface-el)',border:'0.5px solid var(--divider)',borderRadius:'var(--radius-card)',padding:'12px 16px',fontFamily:'var(--font-sans)',display:'flex',flexDirection:'column',gap:'var(--space-pair)'}}>
    <span style={{fontFamily:'var(--font-mono)',fontSize:'var(--anno-sm)',letterSpacing:'.06em',textTransform:'uppercase',color:'var(--text-3)'}}>{title}</span>
    <span style={{fontSize:20,fontWeight:500,color,fontVariantNumeric:'tabular-nums'}}>{value}</span>
    {subtitle&&<span style={{fontFamily:'var(--font-mono)',fontSize:'var(--anno-sm)',color:'var(--text-2)',textTransform:'uppercase'}}>{subtitle}</span>}
  </div>;
}