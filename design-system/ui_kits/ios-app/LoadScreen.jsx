/* Load & progress — recreation of 02_Workload in Field Notes dress. */
function LoadScreen(){
  const {Card,MetricTile,ScreenHeader,SectionHeader,TickScale,SegmentedControl}=window.DesignSystem_cf6e68;
  const [range,setRange]=React.useState('4W');
  const load=[22,26,24,25,23,28,26,30,27,32,29,34,31,36,32,38,34,40,36,42,38,44,40,46];
  const tsb=[-1,-2,-1,-3,-2,-4,-3,-5,-4,-6,-5,-7,-6,-8,-7,-9,-8,-9,-9,-10,-9,-11,-10,-9];
  const W=326,H=120;
  const x=i=>i/(load.length-1)*W;
  const yl=v=>10+(1-(v/50))*80;
  const yt=v=>100+(-v/12)*16;
  return <div style={{padding:'0 16px'}}>
    <ScreenHeader context="TUE 07.21 · WK 30" meta="D-021" title="Load & progress" trailing="Share"/>
    <Card variant="raised" padding="20px 16px 18px">
      <div style={{fontFamily:'var(--font-mono)',fontSize:10,letterSpacing:'.06em',color:'var(--metric-load)'}}>ACWR ●</div>
      <div style={{display:'flex',alignItems:'baseline',gap:12}}>
        <span style={{fontSize:'var(--text-hero)',lineHeight:1.05,letterSpacing:'-0.02em',color:'var(--metric-load)',fontVariantNumeric:'tabular-nums'}}>1.23</span>
        <span style={{fontFamily:'var(--font-mono)',fontSize:11,color:'var(--zone-optimal)'}}>LOAD STEADY</span>
      </div>
      <div style={{marginTop:12}}><TickScale value={1.23} min={0} max={2} zone={[0.8,1.3]} hue="var(--metric-load)"/></div>
    </Card>
    <div style={{height:12}}/>
    <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10}}>
      <MetricTile title="ATL" value="47" subtitle="ACUTE · 7D" color="var(--metric-strain)"/>
      <MetricTile title="CTL" value="38" subtitle="CHRONIC · 28D" color="var(--metric-load)"/>
      <MetricTile title="TSB" value="−9" subtitle="FATIGUED" color="var(--metric-sleep)"/>
    </div>
    <SectionHeader title="Load trend" anno={range}/>
    <SegmentedControl options={['4W','12W','6M']} value={range} onChange={setRange}/>
    <div style={{height:12}}/>
    <Card padding="14px 12px">
      <svg width="100%" height={H} viewBox={'0 0 '+W+' '+H}>
        <g stroke="var(--chart-grid)"><line x1="0" y1="30" x2={W} y2="30"/><line x1="0" y1="60" x2={W} y2="60"/><line x1="0" y1="90" x2={W} y2="90"/></g>
        <path d={tsb.map((v,i)=>(i?'L':'M')+x(i).toFixed(1)+' '+yt(v).toFixed(1)).join(' ')+' L'+W+' 100 L0 100 Z'} fill="var(--metric-sleep)" opacity=".14"/>
        <path d={load.map((v,i)=>(i?'L':'M')+x(i).toFixed(1)+' '+yl(v).toFixed(1)).join(' ')} fill="none" stroke="var(--metric-load)" strokeWidth="1.5"/>
        <path d="M0 46 L326 34" stroke="var(--text-3)" strokeWidth="1" strokeDasharray="1 3"/>
        <circle cx={x(load.length-1)} cy={yl(load[load.length-1])} r="2.5" fill="var(--surface-el)" stroke="var(--metric-load)"/>
        <g fontFamily="Fragment Mono" fontSize="8" fill="var(--text-3)"><text x="2" y="10">LOAD/AU</text><text x="2" y="98">TSB</text><text x={W-30} y={H-4}>JUL 19</text><text x="2" y={H-4}>JUN 28</text></g>
      </svg>
    </Card>
    <div style={{height:24}}/>
  </div>;
}
window.TuwaLoadScreen=LoadScreen;