import React from 'react';
/* Console tab bar: text-only title-case labels on a flat opaque bar; selection = ink step +
   sliding well + the 1.5px accent tick — the app's ONE sanctioned overshoot. No icons. */
export function TabBar({items,active,onSelect}){
  return <div style={{display:'flex',background:'#ECEBE7',borderTop:'0.5px solid var(--divider-strong)',fontFamily:'var(--font-sans)'}}>
    {items.map(t=>{const sel=t===active;return <button key={t} onClick={()=>onSelect&&onSelect(t)} style={{flex:1,position:'relative',border:'none',cursor:'pointer',background:sel?'rgba(27,26,23,.05)':'transparent',color:sel?'var(--text-1)':'var(--text-3)',fontFamily:'inherit',fontSize:'var(--text-tab)',fontWeight:500,padding:'14px 0 18px',transition:'color var(--dur-state) var(--ease)'}}>
      {sel&&<span style={{position:'absolute',top:-1,left:'25%',right:'25%',height:1.5,background:'var(--accent)'}}/>}{t}</button>;})}
  </div>;
}