import React from 'react';
/* Butted equal-weight decision cells in ONE 12px container — the nocebo guard:
   'act' and 'keep plan' carry identical size/type/press; only the fill differs. */
export function KeyRow({keys}){
  return <div style={{display:'flex',minHeight:44,borderRadius:'var(--radius-card)',overflow:'hidden',border:'0.5px solid var(--divider-strong)'}}>
    {keys.map((k,i)=>[
      i>0 && <span key={'d'+i} style={{width:'0.5px',background:'var(--divider-strong)'}}/>,
      <button key={i} onClick={k.onClick} style={{flex:1,border:'none',cursor:'pointer',fontFamily:'var(--font-sans)',fontSize:'var(--text-key)',fontWeight:500,minHeight:44,background:k.role==='cta'?'var(--cta-fill)':'var(--surface-el)',color:k.role==='cta'?'var(--cta-ink)':'var(--text-1)'}}>{k.title}</button>
    ])}
  </div>;
}