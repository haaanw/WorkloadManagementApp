import React from 'react';
/* Focus thickens the INK hairline to 1px (accent never marks focus). Error uses zone-danger. */
export function TextField({label,value,onChange,placeholder,error,type='text'}){
  const [f,setF]=React.useState(false);
  const bc=error?'var(--zone-danger)':f?'var(--text-1)':'var(--divider)';
  return <div style={{display:'flex',flexDirection:'column',gap:'var(--space-pair)',fontFamily:'var(--font-sans)'}}>
    {label&&<span style={{fontSize:'var(--text-small)',color:'var(--text-2)'}}>{label}</span>}
    <input type={type} value={value} placeholder={placeholder} onChange={e=>onChange&&onChange(e.target.value)}
      onFocus={()=>setF(true)} onBlur={()=>setF(false)}
      style={{fontFamily:'var(--font-sans)',fontSize:'var(--text-body)',color:'var(--text-1)',minHeight:44,padding:'0 var(--space-sm)',background:f?'linear-gradient(var(--well-top),var(--well-bottom))':'var(--surface)',border:(f||error)?'1px solid '+bc:'0.5px solid '+bc,borderRadius:'var(--radius-control)',outline:'none',boxSizing:'border-box',transition:'border-color var(--dur-state) var(--ease)'}}/>
    {error&&<span style={{fontSize:'var(--text-small)',color:'var(--zone-danger)'}}>{error}</span>}
  </div>;
}