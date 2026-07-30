import React from 'react';
/* Signed delta glyph in mono: ▲/▼ significant, △/▽ mild, = flat. Color by direction (goodIsUp flips). */
export function DeltaIndicator({delta,goodIsUp=true,threshold=3}){
  const flat=delta===0;
  const up=delta>0;
  const big=Math.abs(delta)>=threshold;
  const glyph=flat?'=':up?(big?'▲':'△'):(big?'▼':'▽');
  const good=flat?null:(up===goodIsUp);
  const color=flat?'var(--text-3)':good?'var(--zone-optimal)':'var(--zone-caution)';
  return <span style={{fontFamily:'var(--font-mono)',fontSize:'var(--anno-sm)',color}}>{glyph}{!flat&&' '+(up?'+':'')+delta}</span>;
}