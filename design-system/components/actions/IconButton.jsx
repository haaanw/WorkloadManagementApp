import React from 'react';
/* 44px square control. Glyph is a Unicode/annotation character (no icon font). */
export function IconButton({glyph,label,selected,onClick}){
  return <button aria-label={label} onClick={onClick} style={{width:44,height:44,display:'inline-flex',alignItems:'center',justifyContent:'center',fontFamily:'var(--font-mono)',fontSize:15,color:selected?'var(--text-1)':'var(--text-2)',background:selected?'var(--surface-el-2)':'var(--surface)',border:selected?'0.5px solid var(--divider-strong)':'0.5px solid var(--divider)',borderRadius:'var(--radius-control)',cursor:'pointer'}}>{glyph}</button>;
}