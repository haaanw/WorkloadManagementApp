import React from 'react';
/* Butted segments, hairline separators, 2px ink top-rule on the active cell. */
export function SegmentedControl({options,value,onChange}){
  return <div style={{display:'flex',minHeight:44,background:'var(--surface)',borderRadius:'var(--radius-control)',overflow:'hidden',border:'0.5px solid var(--divider)'}}>
    {options.map((o,i)=>{const sel=o===value;return [
      i>0&&<span key={'d'+i} style={{width:'0.5px',background:'var(--divider)'}}/>,
      <button key={o} onClick={()=>onChange&&onChange(o)} style={{flex:1,position:'relative',border:'none',cursor:'pointer',fontFamily:'var(--font-sans)',fontSize:'var(--text-label)',fontWeight:sel?500:400,color:sel?'var(--text-1)':'var(--text-2)',background:sel?'var(--surface-el-2)':'transparent'}}>
        {sel&&<span style={{position:'absolute',top:0,left:0,right:0,height:2,background:'var(--divider-strong)'}}/>}{o}</button>
    ]})}
  </div>;
}