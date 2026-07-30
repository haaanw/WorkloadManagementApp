import React from 'react';
/* v1 editorial header: mono context line (annotation register) above a 28px sentence-case title. */
export function ScreenHeader({title,context,meta,trailing}){
  return <div style={{fontFamily:'var(--font-sans)',padding:'var(--space-xs) 0 var(--space-md)'}}>
    {(context||meta)&&<div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline'}}>
      <span style={{fontFamily:'var(--font-mono)',fontSize:'var(--anno-sm)',letterSpacing:'.06em',textTransform:'uppercase',color:'var(--text-3)'}}>{context}</span>
      {meta&&<span style={{fontFamily:'var(--font-mono)',fontSize:'var(--anno-sm)',color:'var(--text-3)'}}>{meta}</span>}</div>}
    <div style={{display:'flex',alignItems:'baseline',gap:'var(--space-sm)',marginTop:2}}>
      <span style={{fontSize:'var(--text-page-title)',color:'var(--text-1)',flex:1}}>{title}</span>
      {trailing&&<span style={{fontSize:10,fontWeight:500,letterSpacing:'.06em',textTransform:'uppercase',color:'var(--text-2)'}}>{trailing}</span>}
    </div>
  </div>;
}