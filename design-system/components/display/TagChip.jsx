import React from 'react';
/* Behavior tag chip (check-ins): neutral capsule; selected = ink fill. */
export function TagChip({label,selected,onClick}){
  return <button onClick={onClick} style={{fontFamily:'var(--font-sans)',fontSize:'var(--text-small)',padding:'6px 14px',borderRadius:'var(--radius-pill)',cursor:'pointer',background:selected?'var(--text-1)':'var(--surface-el)',color:selected?'var(--ink-inverse)':'var(--text-2)',border:selected?'0.5px solid var(--text-1)':'0.5px solid var(--divider-strong)'}}>{label}</button>;
}