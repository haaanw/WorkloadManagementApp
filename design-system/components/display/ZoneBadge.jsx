import React from 'react';
const zones={optimal:'var(--zone-optimal)',caution:'var(--zone-caution)',danger:'var(--zone-danger)',low:'var(--zone-low)'};
/* Text-first hairline capsule. Zone color = text + border only, never a fill. cjk widens padding, drops caps/tracking. */
export function ZoneBadge({zone='optimal',label,cjk}){
  const c=zones[zone]||zones.optimal;
  return <span style={{fontFamily:cjk?'var(--font-cjk)':'var(--font-sans)',fontSize:'var(--text-micro)',letterSpacing:cjk?0:'var(--tracking-caps)',textTransform:cjk?'none':'uppercase',color:c,border:'0.5px solid '+c,borderRadius:'var(--radius-pill)',padding:cjk?'4px 16px':'4px 10px',display:'inline-block'}}>{label}</span>;
}