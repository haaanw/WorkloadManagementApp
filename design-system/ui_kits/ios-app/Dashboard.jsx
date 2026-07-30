/* Home / Dashboard — recreation of 01_Dashboard in Field Notes dress. */
function Dashboard({onStart}){
  const {Card,Button,MetricRow,ScreenHeader,SectionHeader,TickScale,SufficiencyRing,SparkBar,AttentionBanner,ZoneBadge}=window.DesignSystem_cf6e68;
  return <div style={{padding:'0 16px'}}>
    <ScreenHeader context="TUE 07.21 · WK 30" meta="D-021" title="Dashboard" trailing="Log workout"/>
    <Card variant="raised" padding="20px 16px 18px">
      <div style={{fontFamily:'var(--font-mono)',fontSize:10,letterSpacing:'.06em',color:'var(--metric-readiness)'}}>READINESS ●</div>
      <div style={{display:'flex',alignItems:'baseline',gap:12}}>
        <span style={{fontSize:'var(--text-hero)',lineHeight:1.05,letterSpacing:'-0.02em',color:'var(--metric-readiness)',fontVariantNumeric:'tabular-nums'}}>71</span>
        <span style={{fontFamily:'var(--font-mono)',fontSize:11,color:'var(--text-2)'}}>GO +3/7D</span>
      </div>
      <div style={{marginTop:12}}><TickScale value={71} zone={[66,100]} ghost={68} hue="var(--metric-readiness)"/></div>
      <div style={{fontFamily:'var(--font-mono)',fontSize:10,color:'var(--text-2)',marginTop:10}}>GO ZONE — RECOVERY IS HIGH</div>
    </Card>
    <div style={{height:16}}/>
    <Card padding="4px 16px">
      <MetricRow label="Resting heart rate" value="−3%" unit="vs base" hue="var(--metric-strain)"/>
      <MetricRow label="Heart rate variability" value="+0%" unit="vs base" hue="var(--metric-recovery)"/>
      <MetricRow label="Sleep" value="7.6" unit="h" delta={0} hue="var(--metric-sleep)" last/>
    </Card>
    <div style={{height:16}}/>
    <Card padding="14px 16px">
      <div style={{display:'flex',gap:14,alignItems:'center'}}>
        <SufficiencyRing pct={37} size={52}/>
        <div>
          <div style={{fontSize:15,fontWeight:500,color:'var(--text-1)'}}>3 of 8 weeks</div>
          <div style={{fontSize:13,color:'var(--text-2)',lineHeight:1.5}}>Keep logging — periodization insights unlock after 8 weeks.</div>
        </div>
      </div>
    </Card>
    <div style={{height:16}}/>
    <AttentionBanner zone="accent" title="Guidance method updated" message="Readiness now blends HRV and strain history." onDismiss={()=>{}}/>
    <div style={{height:20}}/>
    <Button fullWidth onClick={onStart}>Start session</Button>
    <SectionHeader title="Training load" anno="LOAD STEADY"/>
    <Card padding="14px 16px">
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline'}}>
        <SparkBar data={[3,4,4,5,4,6,5,6,7,6,7,8]} hue="var(--metric-load)" trailing={2}/>
        <ZoneBadge zone="optimal" label="Load steady"/>
      </div>
      <div style={{fontFamily:'var(--font-mono)',fontSize:9,color:'var(--text-3)',marginTop:8,textTransform:'uppercase'}}>ACWR 1.23 · ATL 47 · CTL 38 · TSB −9</div>
    </Card>
    <div style={{height:24}}/>
  </div>;
}
window.TuwaDashboard=Dashboard;