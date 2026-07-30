import React from 'react';
const LEVELS='▁▂▃▄▅▆▇█';
/* ASCII spark bars — inline 8-level history in pure text. The last glyph takes the hue. */
export function SparkBar({data=[],hue='var(--accent)',trailing=0}){
  const min=Math.min(...data),max=Math.max(...data),span=(max-min)||1;
  const g=v=>LEVELS[Math.round(((v-min)/span)*7)];
  return <span style={{fontFamily:'var(--font-mono)',fontSize:'var(--anno)',letterSpacing:1,color:'var(--text-1)'}}>
    {data.slice(0,-1).map(g).join('')}<span style={{color:hue}}>{g(data[data.length-1])}</span>
    {trailing>0&&<span style={{color:'var(--divider)'}}>{'▁'.repeat(trailing)}</span>}
  </span>;
}