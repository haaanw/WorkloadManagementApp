import React from 'react';
/* Transient confirmation: ink plate, inverse text, mono tick. Bottom-center, rises 6px on entrance. */
export function Toast({message,glyph='✓',visible=true}){
  return <div style={{display:'inline-flex',alignItems:'center',gap:10,background:'var(--text-1)',color:'var(--ink-inverse)',borderRadius:'var(--radius-pill)',padding:'10px 20px',fontFamily:'var(--font-sans)',fontSize:'var(--text-small)',opacity:visible?1:0,transform:visible?'none':'translateY(var(--rise))',transition:'opacity var(--dur-state) var(--ease), transform var(--dur-state) var(--ease)'}}>
    <span style={{fontFamily:'var(--font-mono)',fontSize:12}}>{glyph}</span>{message}
  </div>;
}