import React from 'react';
const zones={optimal:'var(--zone-optimal)',caution:'var(--zone-caution)',danger:'var(--zone-danger)',low:'var(--zone-low)',accent:'var(--accent)'};
/* Shared banner plane (PR / spike / fatigue / cycle): standard card + 2px zone rule clipped inside.
   Text label carries the state; the rule is supplementary. */
export function AttentionBanner({zone='caution',title,message,action,onAction,onDismiss}){
  const c=zones[zone]||zones.caution;
  return <div style={{position:'relative',overflow:'hidden',background:'var(--surface-el)',border:'0.5px solid var(--divider)',borderRadius:'var(--radius-card)',padding:'14px 16px 14px 18px',fontFamily:'var(--font-sans)'}}>
    <span style={{position:'absolute',left:0,top:0,bottom:0,width:2,background:c}}/>
    <div style={{display:'flex',alignItems:'flex-start',gap:12}}>
      <div style={{flex:1}}>
        <div style={{fontSize:'var(--text-label)',fontWeight:500,color:'var(--text-1)'}}>{title}</div>
        {message&&<div style={{fontSize:'var(--text-small)',color:'var(--text-2)',lineHeight:'var(--leading-body)',marginTop:2}}>{message}</div>}
        {action&&<button onClick={onAction} style={{marginTop:8,fontFamily:'var(--font-sans)',fontSize:'var(--text-key)',fontWeight:500,background:'none',border:'none',padding:0,color:'var(--text-1)',textDecoration:'underline',textUnderlineOffset:3,cursor:'pointer'}}>{action}</button>}
      </div>
      {onDismiss&&<button onClick={onDismiss} aria-label="Dismiss" style={{fontFamily:'var(--font-mono)',fontSize:13,color:'var(--text-3)',background:'none',border:'none',cursor:'pointer',padding:0}}>×</button>}
    </div>
  </div>;
}