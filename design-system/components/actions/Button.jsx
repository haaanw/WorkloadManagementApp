import React from 'react';
/* Primary = the ONE ink-filled pill per screen. Secondary = hairline rect (8px). Quiet = text. Never accent-filled. */
export function Button({variant='primary',children,disabled,onClick,fullWidth,style}){
  const [p,setP]=React.useState(false);
  const base={fontFamily:'var(--font-sans)',fontSize:'var(--text-key)',fontWeight:500,minHeight:44,padding:'0 var(--space-md)',cursor:disabled?'default':'pointer',border:'none',display:'inline-flex',alignItems:'center',justifyContent:'center',opacity:disabled?0.5:1,transition:'transform 100ms var(--ease), background 100ms var(--ease)',width:fullWidth?'100%':undefined,boxSizing:'border-box',...style};
  const v={
    primary:{background:'var(--cta-fill)',color:'var(--cta-ink)',borderRadius:'var(--radius-pill)',boxShadow:p?'inset 0 1.5px 0 var(--relief-shade)':'inset 0 1px 0 rgba(255,255,254,.25)'},
    secondary:{background:p?'linear-gradient(var(--well-top),var(--well-bottom))':'var(--surface-el)',color:'var(--text-1)',borderRadius:'var(--radius-control)',border:'0.5px solid var(--divider-strong)'},
    quiet:{background:'transparent',color:'var(--text-2)',borderRadius:'var(--radius-control)'}
  }[variant];
  return <button style={{...base,...v}} disabled={disabled} onClick={onClick}
    onPointerDown={()=>setP(true)} onPointerUp={()=>setP(false)} onPointerLeave={()=>setP(false)}>{children}</button>;
}