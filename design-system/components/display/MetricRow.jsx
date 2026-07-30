import React from 'react';
import {DeltaIndicator} from './DeltaIndicator.jsx';
/* A metric list row: hue identity dot · sans label · mono value + delta. Rows butt with 0.5px separators. */
export function MetricRow({label,value,unit,delta,hue,onClick,last}){
  return <div onClick={onClick} style={{display:'flex',justifyContent:'space-between',alignItems:'baseline',padding:'12px 0',borderBottom:last?'none':'0.5px solid var(--divider)',cursor:onClick?'pointer':'default',fontFamily:'var(--font-sans)'}}>
    <span style={{fontSize:'var(--text-label)',color:'var(--text-1)',display:'inline-flex',alignItems:'center',gap:8}}>
      {hue&&<span style={{width:8,height:8,borderRadius:'50%',background:hue,flex:'none'}}/>}{label}</span>
    <span style={{fontFamily:'var(--font-mono)',fontSize:'var(--anno)',color:'var(--text-1)',display:'inline-flex',gap:6,alignItems:'baseline'}}>
      {value}{unit&&<span style={{color:'var(--text-3)',fontSize:'var(--anno-sm)',textTransform:'uppercase'}}>{unit}</span>}
      {delta!==undefined&&<DeltaIndicator delta={delta}/>}
    </span>
  </div>;
}