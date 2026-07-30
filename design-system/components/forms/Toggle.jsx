import React from 'react';
/* Neutral toggle — no Apple green. On-track = ink; knob rides a debossed track. */
export function Toggle({checked,onChange,label}){
  return <label style={{display:'flex',alignItems:'center',gap:'var(--space-sm)',minHeight:44,cursor:'pointer',fontFamily:'var(--font-sans)',fontSize:'var(--text-body)',color:'var(--text-1)'}}>
    {label && <span style={{flex:1}}>{label}</span>}
    <span onClick={()=>onChange&&onChange(!checked)} role="switch" aria-checked={!!checked} style={{position:'relative',width:48,height:32,borderRadius:'var(--radius-control)',background:checked?'var(--text-1)':'linear-gradient(var(--well-top),var(--well-bottom))',border:'0.5px solid var(--divider-strong)',transition:'background var(--dur-state) var(--ease)',boxSizing:'border-box',flex:'none'}}>
      <span style={{position:'absolute',top:3,left:checked?19:3,width:24,height:24,borderRadius:6,background:checked?'var(--bg)':'linear-gradient(var(--surface-el-2),var(--surface-el))',border:'0.5px solid var(--divider-strong)',boxShadow:'inset 0 1px 0 var(--relief-highlight)',transition:'left var(--dur-state) var(--ease)',boxSizing:'border-box'}}/>
    </span>
  </label>;
}