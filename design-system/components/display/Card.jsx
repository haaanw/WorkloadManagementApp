import React from 'react';
/* The stone planes. plain = surface-el + divider; emphasis = surface-el-2 + strong hairline;
   raised = milled plate gradient + top highlight; debossed = well pocket. NO shadows. */
export function Card({variant='plain',children,style,padding='var(--space-md) var(--space-sm)'}){
  const v={
    plain:{background:'var(--surface-el)',border:'0.5px solid var(--divider)',borderRadius:'var(--radius-card)'},
    emphasis:{background:'var(--surface-el-2)',border:'0.5px solid var(--divider-strong)',borderRadius:'var(--radius-card)'},
    raised:{background:'linear-gradient(var(--surface-el-2),var(--surface-el))',border:'0.5px solid var(--divider-strong)',borderRadius:'var(--radius-card)',boxShadow:'inset 0 1px 0 var(--relief-highlight)'},
    debossed:{background:'linear-gradient(var(--well-top),var(--well-bottom))',border:'0.5px solid var(--divider-strong)',borderRadius:'var(--radius-control)',boxShadow:'inset 0 1.5px 0 var(--relief-shade), inset 0 -1px 0 var(--relief-highlight)'}
  }[variant];
  return <div style={{padding,boxSizing:'border-box',...v,...style}}>{children}</div>;
}