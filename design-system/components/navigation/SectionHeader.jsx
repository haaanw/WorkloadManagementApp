import React from 'react';
/* 17px/500 section head; optional mono annotation on the right. Sections break with 32px gaps. */
export function SectionHeader({title,anno}){
  return <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline',fontFamily:'var(--font-sans)',marginTop:'var(--space-lg)',marginBottom:'var(--space-xs)'}}>
    <span style={{fontSize:'var(--text-section-head)',fontWeight:500,color:'var(--text-1)'}}>{title}</span>
    {anno&&<span style={{fontFamily:'var(--font-mono)',fontSize:'var(--anno-sm)',textTransform:'uppercase',color:'var(--text-3)'}}>{anno}</span>}
  </div>;
}