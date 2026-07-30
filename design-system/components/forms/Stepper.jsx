import React from 'react';
import {ReadoutWell} from './ReadoutWell.jsx';
/* Detent control: − / readout well / + . Value cell never resizes with digit count. */
export function Stepper({value,onChange,min=0,max=999,step=1,unit,wellWidth=88}){
  const clamp=v=>Math.min(max,Math.max(min,v));
  const b={width:44,height:44,border:'0.5px solid var(--divider-strong)',borderRadius:'var(--radius-control)',background:'linear-gradient(var(--surface-el-2),var(--surface-el))',boxShadow:'inset 0 1px 0 var(--relief-highlight)',fontFamily:'var(--font-mono)',fontSize:16,color:'var(--text-1)',cursor:'pointer'};
  return <div style={{display:'inline-flex',alignItems:'center',gap:'var(--space-xs)'}}>
    <button style={b} onClick={()=>onChange&&onChange(clamp(value-step))} aria-label="Decrease">−</button>
    <ReadoutWell value={value} unit={unit} width={wellWidth}/>
    <button style={b} onClick={()=>onChange&&onChange(clamp(value+step))} aria-label="Increase">＋</button>
  </div>;
}