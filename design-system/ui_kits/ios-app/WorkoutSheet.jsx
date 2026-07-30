/* Log workout sheet — recreation of the ActiveWorkout entry sheet in Field Notes dress. */
function WorkoutSheet({onClose}){
  const {Card,Button,TextField,TagChip,KeyRow}=window.DesignSystem_cf6e68;
  const [name,setName]=React.useState('');
  const [sport,setSport]=React.useState('Strength');
  const sports=[['Strength','▮▮'],['Basketball','●'],['Aerobic / class','≋'],['Other sport','+']];
  return <div style={{position:'absolute',inset:0,background:'rgba(27,26,23,.12)',display:'flex',alignItems:'flex-end',zIndex:5}} onClick={onClose}>
    <div onClick={e=>e.stopPropagation()} style={{background:'var(--bg)',borderRadius:'12px 12px 0 0',borderTop:'0.5px solid var(--divider-strong)',width:'100%',padding:'14px 16px 24px',boxSizing:'border-box',maxHeight:'88%',overflowY:'auto'}}>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:16}}>
        <button onClick={onClose} style={{background:'none',border:'none',fontFamily:'var(--font-sans)',fontSize:11,fontWeight:500,letterSpacing:'.06em',textTransform:'uppercase',color:'var(--text-2)',cursor:'pointer',padding:0}}>Cancel</button>
        <span style={{fontSize:20}}>Workout</span>
        <button onClick={onClose} style={{background:'none',border:'none',fontFamily:'var(--font-sans)',fontSize:11,fontWeight:500,letterSpacing:'.06em',textTransform:'uppercase',color:'var(--text-1)',cursor:'pointer',padding:0}}>Finish</button>
      </div>
      <TextField value={name} onChange={setName} placeholder="Session name (optional)"/>
      <div style={{fontSize:17,fontWeight:500,margin:'20px 0 10px'}}>What are you training?</div>
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
        {sports.map(([s,g])=>{const sel=s===sport;return <button key={s} onClick={()=>setSport(s)} style={{fontFamily:'var(--font-sans)',fontSize:15,color:'var(--text-1)',padding:'22px 0',cursor:'pointer',borderRadius:'var(--radius-control)',border:sel?'1px solid var(--text-1)':'0.5px solid var(--divider-strong)',background:sel?'linear-gradient(var(--surface-el-2),var(--surface-el))':'var(--surface)',display:'flex',flexDirection:'column',alignItems:'center',gap:6}}>
          <span style={{fontFamily:'var(--font-mono)',fontSize:14,color:sel?'var(--text-1)':'var(--text-3)'}}>{g}</span>{s}</button>;})}
      </div>
      <div style={{height:16}}/>
      <Card variant="debossed" padding="12px 16px">
        <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline'}}>
          <span style={{fontFamily:'var(--font-mono)',fontSize:10,textTransform:'uppercase',color:'var(--text-3)'}}>DURATION</span>
          <span style={{fontSize:26,fontVariantNumeric:'tabular-nums'}}>0<span style={{fontFamily:'var(--font-mono)',fontSize:10,color:'var(--text-3)'}}> MIN</span></span>
        </div>
      </Card>
      <div style={{height:12}}/>
      <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
        <TagChip label="Import plan"/><TagChip label="From template"/><TagChip label="Repeat last"/>
      </div>
      <div style={{height:16}}/>
      <KeyRow keys={[{title:'Adjust for readiness'},{title:'+ Add exercise',role:'cta'}]}/>
    </div>
  </div>;
}
window.TuwaWorkoutSheet=WorkoutSheet;