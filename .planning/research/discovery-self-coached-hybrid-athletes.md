---
title: Customer Discovery - Real Online Self-Coached Hybrid Athletes
date: 2026-06-13
method: 7-angle web mining of Reddit/forums/wearable communities; 51 unique verified voices with source URLs + verbatim quotes
context: Online proxy for customer-discovery interviews (founder lacks real-world access to this profile). Pairs with plan-aware-thesis-pressure-test.md
---

# Discovery: Real Self-Coached Hybrid Athletes (online)

**51 unique real voices** mined across 7 angles, distilled to 5 profiles. Every voice has a real source URL + verbatim quote. Real public posters, not invented personas - but mined posts, not interviews.

## The 5 profiles

### 1. The Build-It-Myself Today-Adjuster (powerbuilding + combat/running)
*Fit: strong*

> Stacks heavy squats/deadlifts with running and a combat sport, got so frustrated guessing how much to strip off the bar after yesterday's run that he coded his own CNS-vs-peripheral fatigue calculator that spits out a push/deload/swap verdict before he leaves for the gym.

- **Who:** Amateur serious hybrid lifter, a few years in, technically literate, no coach. Runs a percentage/RPE strength block alongside kickboxing/running/HIIT (Inevitable_Brick_221) or a U/L/P/P split alongside running (GreenInvestigator817). Treats his own body as the experiment and reaches for code, not a coach.
- **Plan source:** Self-written percentage-/RPE-based strength program run from a spreadsheet, with conditioning bolted on by hand.
- **Current modulation (today):** Used to go in too heavy and feel like garbage, or randomly knock weight off and hope. Now runs an explicit hand-built rule set (readiness 10-15% below 28-day norm -> cap RPE 8, cancel maximal testing; red -> swap barbell squat for machine, cap RPE 7; stable + good sleep -> auto-progress +2.5kg) and a private web utility / LLM prompt that outputs the verdict before the session.
  - pain: Percentage programs ignore cross-modal fatigue: 'Squat 80% today' without caring he ran 10km yesterday and rolled for an hour
  - pain: Device score says 'Recovered' while CNS and legs are fried 48h post-deadlift
  - pain: Linear penalty stacking (-10% run, -15% combat) is physiologically wrong; a hard run wrecks the squat but barely touches bench
  - pain: No off-the-shelf tool connects readiness to his authored plan per-lift, so he built one himself
- **Tools today:** self-built web calculator (HybridLoad / hybridload.com), private Garmin->push/deload/swap web utility, spreadsheet program, Garmin readiness/sleep metrics, ChatGPT for daily session tweaks
- **Willingness:** Highest BEHAVIORAL signal in the corpus: wants it so badly he built it. Inevitable_Brick_221 is monetizing a Pro tier (training history + RPE + volume optimization), implying he believes hybrid athletes will pay for the adjusted-number + tracking bundle. CAVEAT: this is the strongest 'build-not-buy' disconfirm too. He is effectively a competitor; he'd benchmark Tuwa against his own hand-tuned model and may never become a buyer.
  - src: https://reddit.com/r/HybridAthlete/comments/1roi0kr/i_got_tired_of_guessing_how_much_to_take_off_the/
  - src: https://www.reddit.com/r/Garmin/comments/1tfuujo/prepping_for_a_heavy_squat_block_this_is_how_my/
  - src: https://www.reddit.com/r/Garmin/comments/1s1az3l/how_im_using_garmin_recovery_metrics_to_decide_my/

### 2. The 5-Apps-and-a-Spreadsheet Hyrox Self-Programmer
*Fit: strong*

> Trains run/lift/row/ski/sled all at once, stitches Strava + Strong + MyFitnessPal + Whoop and a half-finished Google Sheet every week, and still can't answer 'is my running volume too high given how much I'm lifting?' — the recovery score has no idea he has a long run tomorrow.

- **Who:** First- or second-time Hyrox amateur, self-coached, time-crunched, data-curious. Trains the full hybrid modality set and reconciles everything manually. Spectrum spans the resigned multi-app stitcher (pulse_and_plates, mylesbr) to the systematic hand-builder (Armentero, who feeds metrics into ChatGPT every Sunday so next week auto-adjusts).
- **Plan source:** Self-written — a reusable 12-week Google Sheet, or a ChatGPT-assisted evidence-based weekly plan; explicitly 'a structured self-coaching system, not trying to replace coaching.'
- **Current modulation (today):** Manually stitches disconnected apps plus 'listen to my body' and ad hoc shuffling of sessions; when the fatigue signal is ambiguous (overreach vs underfuel vs life stress) the default is to grind through it (Venus_DST04). Scheduled deloads are the only systematic lever, and they still feel wrecked.
  - pain: Data fragmentation across 4-5 apps that don't talk; the spreadsheet is 'the tell' that the apps failed
  - pain: Recovery score is plan-blind: 'Whoop tells me I'm recovered but recovered for what? It has no clue I have a long run tomorrow'
  - pain: Can't tell if running volume is too high relative to lifting load (one fatigue budget)
  - pain: Can't decode the fatigue signal — accumulated overreach vs underfueling vs external stress
- **Tools today:** Strava, Strong, MyFitnessPal, Whoop / Garmin, Google Sheets, ChatGPT
- **Willingness:** Strong LATENT demand, stated almost verbatim ('until something better exists'; wants the apps to 'talk to each other and tell me whether I'm on track given my plan'). Armentero is hand-building Tuwa's exact pitch. BUT no price stated, framing is self-doubting ('maybe I'm overcomplicating this'), and a loud counter-chorus (No_Buyer_9020: 'you are overcomplicating this... I just listen to my body') tells first-timers exactly that. The willing slice is the multi-year/injury/time-constrained data-nerd, not the median.
  - src: https://reddit.com/r/hyrox/comments/1rlumrt/anyone_else_using_like_5_apps_just_to_understand/
  - src: https://reddit.com/r/hyrox/comments/1rg7bax/trying_to_create_an_adaptive_hyrox_training_plan/
  - src: https://reddit.com/r/hyrox/comments/1sqpo6l/midcycle_training_blues_during_hyrox_prep_fatigue/

### 3. The Tactical-Barbell Loyalist Who Needs the Plan to Bend
*Fit: strong*

> Runs a fixed strength+conditioning template by the book, hits every prescribed session, and the hardest skill he openly admits he lacks is knowing when to back off the prescribed weights for daily recovery — to the point he'll abandon a 2-year program just to buy that flexibility.

- **Who:** Serious self-coached strength+conditioning athlete on a published system (Tactical Barbell, Wendler 5/3/1, Boostcamp). Often 35-45, full-time job + young kids, recovery wrecked by work and life. Training for military selection or general capacity. This is the closest demographic to the founder's reference user.
- **Plan source:** Template app/book self-administered (Tactical Barbell Green/Operator, 5/3/1, Boostcamp programs).
- **Current modulation (today):** Mostly NO principled modulation today: hits every prescribed session and only discovers the fatigue hole at end-of-block testing (AM-Thoughts — strength, bodyweight reps AND run times all regressed at once); or contemplates switching whole programs (TB -> 5/3/1) purely for 'flexibility of adjusting the workload to daily recovery' (decydiddly); or backs off prescribed weights by feel and finally takes deloads instead of skipping them (Wtf_Sai).
  - pain: Prescribed/fixed program won't flex to day-to-day recovery; forced to trade structure for flexibility, can't have both
  - pain: 'Knowing when to back off the prescribed weights' is the unmet central skill the program app doesn't provide
  - pain: No mid-block signal he was digging a fatigue hole — only found out at the test, then crowdsourced the diagnosis from Reddit
  - pain: Sometimes the limiter is mental/life stress, not physical fatigue (toddler, 6-7h sleep), and he has no read on which
- **Tools today:** Tactical Barbell / 5/3/1 / Boostcamp, end-of-block physical tests, no HRV/readiness tool, home gym
- **Willingness:** Strong latent demand for exactly the TODAY wedge — decydiddly will switch entire programs to get daily-recovery flexibility, proving people change PRODUCTS for this even with no app on offer. MID-horizon need (overreach forecast) is real but discovered too late to be felt as a wanted feature. No explicit pay signal; many are template-loyal and reach for a subreddit, not an app, and value simplicity (an app must lower friction, not add overhead).
  - src: https://reddit.com/r/tacticalbarbell/comments/1sex5i9/over_18_months_of_tactical_barbell_observations/
  - src: https://reddit.com/r/tacticalbarbell/comments/1sjbyj2/performance_seems_to_be_getting_worse/
  - src: https://www.reddit.com/r/tacticalbarbell/comments/1pyyibq/long_term_tb_enthusiast_coming_to_a_stall_with/
  - src: https://www.reddit.com/r/fitness40plus/comments/1qvjo6r/recovery_at_40_is_a_whole_different_sport/

### 4. The Wearable Owner Whose Score Ignores His Lifting and His Plan
*Fit: partial*

> Already pays for Whoop/Bevel/Garmin, trains strength + endurance, and is actively frustrated that the recovery score misreads CNS/lifting fatigue as overtraining and that the AI coach keeps trying to sell him a new plan instead of reading the one he already runs.

- **Who:** Tech-forward hybrid (strength + swim/run/bike/ski). Often an ex-coached athlete now self-coaching via tools (Tari1337), or a paying Bevel user technically literate enough to write a feature request (Unleashed94), or a hybrid woman piping Garmin into Gemini daily (Derelicte_by_Mugatu). Wants decisions ON his data, explicitly not a competing program.
- **Plan source:** Self-written / self-structured hybrid routine; some bring a dietitian's plan or an old coach's periodization as a reference baseline.
- **Current modulation (today):** Uses the readiness score as input but overrides/distrusts it: manually integrates RPE because the algorithm is cardio-biased (Unleashed94); pipes Garmin metrics into Gemini/ChatGPT every morning to adjust (Derelicte); or has abandoned HRV entirely because 'HRV will be normal and I'll feel ready for death' (treadmill-trash).
  - pain: Recovery algorithm is cardio-biased ('Lower RHR + Higher HRV = Better' is inverted for strength) and misreads muscle repair/CNS fatigue as overtraining — 'No App is really useful for hybrid athletes'
  - pain: AI coach has a 'sales guy' attitude — ends every interaction proposing a new plan vs respecting his own routine
  - pain: Hybrid load isn't unified — the watch treats a swim and a squat as different stress though the body accumulates both
  - pain: Daily friction of manually prompting stats/screenshots into an LLM; nothing streamlines it
- **Tools today:** Whoop + Whoop AI Coach, Bevel + manual RPE, Garmin Training Readiness (HRV/body battery/sleep), Gemini / ChatGPT copilot, intervals.icu
- **Willingness:** High and explicit in places — Unleashed94 is a PAYING user who wrote a detailed volume×RPE strain-model feature request; Derelicte literally says 'We should start a startup! we know what to integrate.' Cleanest anti-positioning validation (itarrow rejects the plan-proposing AI coach almost verbatim, echoed by aurisdad/PortlandTakedown). BUT trust is burned: several override or churn the score, treadmill-trash dropped HRV outright, and the wrist genuinely misses strength fatigue — Tuwa must capture that to earn this user. Partial profile (some are endurance-skewed, not tri-modal).
  - src: https://reddit.com/r/bevelhealth/comments/1rdb3dw/feature_request_for_hybrid_athlete_optimization/
  - src: https://reddit.com/r/whoop/comments/1tukbhr/whoop_ai_coach_cant_stop_proposing_plans/
  - src: https://www.reddit.com/r/Garmin/comments/1s1az3l/how_im_using_garmin_recovery_metrics_to_decide_my/
  - src: https://www.reddit.com/r/HybridAthlete/comments/1oe3njx/hybrid_athletes_whats_the_hardest_part_of/
  - src: https://reddit.com/r/Velo/comments/1hry8gw/adaptive_training_tools/

### 5. The By-Feel Purist Who Treats Programming as Identity (disconfirming)
*Fit: weak*

> Decade-plus self-coached hybrid who already autoregulates by accumulated feel, uses zero metrics, ran one of his best sessions on a red-readiness morning, and regards an app touching his plan as either redundant or an autonomy intrusion — 'It's an aid, not an actual coach.'

- **Who:** The most serious, most experienced self-coached athletes in the sample, and demographically dead-center on the target: MythicalStrength (25yr strongman + martial arts + conditioning + running), Your_Good_Buddy (13yr, explicitly 'not a program at all'), Andejusjust (self-made Sheiko + own running plan), LordPeachez (gym + field sports + running). Founder's actual peer group — and the hardest to convert.
- **Plan source:** Self-written / self-authored, often deliberately unstructured — no percentages, no RPE, no spreadsheet; or a static progressive-overload block modulated entirely by feel.
- **Current modulation (today):** Pure by-feel + outcome-based: takes deload/bridge weeks when he feels he needs one, swaps lifts to spare a body part, judges load by 'owning' a max across a cycle; trains AGAINST the device verdict ('Garmin told me not to train, I did one of my best long runs'); makes the go/modify call in-session via the warm-up ramp; crosstrains instead of running purely on lower-leg feel.
  - pain: Genuinely believes readiness-vs-train is 'a judgment call you can't make with an app'
  - pain: Device verdict routinely contradicts felt state and performance — trust in algorithmic readiness already burned
  - pain: Already broke himself self-programming freely — wants FEWER decisions / a fixed prescriptive system, not a modulation layer
  - pain: App-fatigue + data-privacy objection: 'not sure we need another app hoovering up more of our data'; subscription resentment
- **Tools today:** nothing — bodily feel + RPE + in-session warm-up ramp, Tactical Barbell / Sheiko or no program at all, Garmin demoted to 'tidbits', intervals.icu for cycling only, no readiness app
- **Willingness:** DISCONFIRMING. Explicit refusal of the today-verdict (RoosterHuge4549: 'It's an aid, not an actual coach'; No_Safety_6803: 'letting your recovery control you' named as the failure mode), of structured numeric plans (Your_Good_Buddy 'stares blankly' at spreadsheets), and of the premise itself (picky_dude: 'those metrics are mostly for beginners'). LordPeachez researched unified-load tools — Tuwa's exact pitch — judged 'nothing worked great,' and resolved to self-reliance. The harder-core the athlete, the higher this wall. These are non-buyers/resenters, and they are exactly the segment the founder most resembles.
  - src: https://www.reddit.com/r/tacticalbarbell/comments/1sex5i9/over_18_months_of_tactical_barbell_observations/
  - src: https://www.reddit.com/r/weightroom/comments/srskk9/the_method_of_madness_one_meatheads_approach_to/
  - src: https://www.reddit.com/r/HybridAthlete/comments/1oe3njx/hybrid_athletes_whats_the_hardest_part_of/
  - src: https://www.reddit.com/r/Garmin/comments/1ph59uy/its_just_a_watch_not_your_life_coach/
  - src: https://www.reddit.com/r/HybridAthlete/comments/1tftmif/comment/ombz428/
  - src: https://www.reddit.com/r/Garmin/comments/1qnoc7x/comment/o1vejgs/


---

## All verified voices

### Inevitable_Brick_221 - Reddit — r/HybridAthlete  (strong fit)
https://reddit.com/r/HybridAthlete/comments/1roi0kr/i_got_tired_of_guessing_how_much_to_take_off_the/

> every percentage-based program treats you like you exist in a vacuum. It says "Squat 80% of your max today" without caring that you ran 10km yesterday morning and rolled for an hour the night before. So I'd either go in too heavy and feel like garbage, or I'd randomly knock off weight and hope for the best. Neither felt smart.

- **Plan source:** self-written (self-run percentage-based strength program — heavy squats/deadlifts + kickboxing + running + HIIT, training hybrid 'a few years')
- **Modulation today:** Adjusts the bar load ad hoc based on the prior day's fatigue source, but admits the method is a coin-flip: either he goes too heavy and feels like garbage, or randomly strips weight and hopes. Got frustrated enough that he built his own web calculator (HybridLoad) that varies the fatigue penalty per lift using a CNS-vs-local-fatigue 'anchor + modifier' model instead of linear penalties.
- **Pains:** Percentage programs ignore accumulated fatigue from yesterday's run/sparring; Guessing how much weight to take off the bar — no principled method; Going in too heavy and feeling like garbage, or arbitrarily deloading; Linear penalty stacking (run -10%, combat -15%) is too aggressive and ignores that a run hits squat hard but barely touches bench; No existing tool acts on fatigue per-lift before the session
- **Tools:** self-run percentage program, self-built web calculator (HybridLoad / hybridload.com), self-study of CNS vs peripheral fatigue research
- **Willingness:** Very high — built and is monetizing the exact product (free core calculator now; planned Pro tier with plate visualizer, training history, RPE integration, volume optimization). Actively soliciting validation of his fatigue percentages from people who 'actually train this way.' Proof of both demand and an emerging competitor.

### decydiddly - Reddit — r/tacticalbarbell (comment on 'Over 18 Months of Tactical Barbell')  (strong fit)
https://reddit.com/r/tacticalbarbell/comments/1sex5i9/over_18_months_of_tactical_barbell_observations/

> I have been doing TB for the past couple of years but thinking about migrating back to 5/3/1 system for the increased flexibility of adjusting the workload to daily recovery. My recovery is shit due to work and life. 531 gives more flexibility vs the prescribed sets of TB. How have you mitigated the "prescribed" and recovery over time with TB?

- **Plan source:** self-written (2+ years self-administering Tactical Barbell; considering switching to 5/3/1)
- **Modulation today:** Resolving the readiness-vs-plan conflict by abandoning the whole program: TB's prescribed sets won't bend to his day-to-day recovery, so he's contemplating a switch to 5/3/1 purely for daily-load flexibility. Asks a veteran how to reconcile a fixed prescription with poor recovery — has no analytical layer to do it.
- **Pains:** Prescribed/fixed program won't adapt to daily recovery state; Recovery wrecked by work and life stress; Forced to trade structure (TB) for flexibility (5/3/1) — can't have both; No method to know how to flex the prescribed numbers
- **Tools:** Tactical Barbell, 5/3/1 (considering), no readiness/HRV tool mentioned
- **Willingness:** Strong latent demand for exactly Tuwa's core: he explicitly wants daily-recovery-adjustable loading on his own plan, and is willing to abandon a system he's run for years to get it. The whole problem is 'keep my plan but let it flex to today' — no app needed if he could autoregulate it, which he can't.

### itarrow - Reddit — r/whoop  (partial fit)
https://reddit.com/r/whoop/comments/1tukbhr/whoop_ai_coach_cant_stop_proposing_plans/

> I have realized that I want my interaction with the AI coach to be about what happened and about my health and fitness data, not him trying to sell me a new improved plan vs what I am already doing by myself.

- **Plan source:** self-written ('what I am already doing by myself' — virtual cycling + strength training + skiing, own routine)
- **Modulation today:** Runs his own fixed routine and wants the wearable to surface flags/feedback on his data ('if there is anything wrong, the AI Coach can tell me') but explicitly does NOT want it to replace or re-propose his program. Currently fighting the Whoop AI coach, which keeps pushing its own plans; can't get it to respect his routine.
- **Pains:** Whoop AI coach has a 'sales guy' attitude, ends every interaction proposing a new plan; Won't respect that he already has a routine he wants to keep; No way to opt out of the plan-proposing behavior; it 'forgets' his stated preference; Wants decisions/feedback ON his data, not a competing program
- **Tools:** Whoop 5, Whoop AI Coach, tried Google Health app + Fitbit Charge
- **Willingness:** Strong anti-positioning validation — this is Tuwa's exact wedge stated by a frustrated user: he wants a layer that reads his body and flags decisions over HIS plan, and actively rejects the 'AI coach that owns the program' model. Other commenters (aurisdad, PortlandTakedown) echo the same annoyance.

### Main-Ratio4171 - Reddit — r/HybridAthlete ('So. Damn. Sore.')  (strong fit)
https://reddit.com/r/HybridAthlete/comments/1r5jfh5/so_damn_sore/

> I want to lift heavy but I feel like I'm probably going to have to back off to avoid being so sore every week.

- **Plan source:** self-written (self-chosen schedule: ~5 running days/wk at 30-40 mpw + a Push/Pull/Legs strength split)
- **Modulation today:** Default is to keep pushing heavy; resolves the conflict reactively and emotionally — frustrated by 2-4 days of DOMS that collide with running, leaning toward backing off lifting by gut feel with no framework, while explicitly not wanting to sacrifice heavy lifting.
- **Pains:** Chronic DOMS 2-4 days after leg day colliding with 30-40 mpw running; Strength visibly regressing as running volume climbs (one fatigue budget); Doesn't want to skimp on lifting heavy but feels forced to — 'something's gotta give'; No method to balance the two beyond complaining/guessing
- **Tools:** protein, creatine, no readiness or load-management tool mentioned
- **Willingness:** Implicit demand — wants to preserve heavy lifting without wrecking running; the thread's answers are all structural (change split, cut volume), nobody offers a per-session readiness tool. No explicit app interest stated.

### AM-Thoughts - Reddit — r/tacticalbarbell ('Performance seems to be getting worse?')  (strong fit)
https://reddit.com/r/tacticalbarbell/comments/1sjbyj2/performance_seems_to_be_getting_worse/

> now at the end of velocity all of my performance metrics seem to have gotten worse. Max strength went down [...] my run times also seem to have gotten worse [...] I should note that I hit every session [...] Not sure where to go from here

- **Plan source:** template app/book — bought TB Green Protocol and self-administered it to prep for a military selection (no coach)
- **Modulation today:** Zero modulation — hit every prescribed session regardless of state, only discovered the across-the-board regression at end-of-block testing. Now guessing at the cause (overreach vs under-fuel vs under-sleep vs wrong program) and crowdsourcing the diagnosis from Reddit because he has no analytical layer.
- **Pains:** Strength, bodyweight reps AND run times all regressed simultaneously — can't explain it; No mid-block signal that he was digging a fatigue hole (only found out at the test); Can't tell apart overreaching, under-recovery, 6h sleep, or program mismatch; Flying blind on what to change next — pure trial and error
- **Tools:** Tactical Barbell Green Protocol (book), end-of-block physical tests, no HRV/readiness monitoring
- **Willingness:** Latent demand for the mid/long horizons specifically — fatigue-trajectory/overreach forecast and response profiling. He has no tooling and outsources the diagnosis to a subreddit; no explicit willingness-to-pay signal.

### Top-Ant-4492 - Reddit — r/whoop  (partial fit)
https://reddit.com/r/whoop/comments/1sbmji8/i_built_a_free_running_app_that_actually_listens/

> most running apps ignore your recovery data. They simply hand you a plan and expect you to follow it even though your HRV might have tanked overnight.

- **Plan source:** self-written / self-built (built his own app 'Runphatic' with a built-in 80/20 polarized program)
- **Modulation today:** Built an app that pulls Whoop recovery/HRV before the run and steers the day's effort (red day -> easy Z1-2; green day -> full send), explicitly because 'nothing stops you from pushing when you feel okay.' Treats readiness as a pre-session gate on the planned run.
- **Pains:** Apps hand you a plan and expect compliance regardless of overnight recovery; Whoop/Strava integration only logs the past — 'doesn't change anything about how you train'; People push on red days because no system makes the case to back off; Wanted readiness used BEFORE the run, not as retrospective logging
- **Tools:** Whoop, Strava, self-built web app (Runphatic), HRV/recovery score
- **Willingness:** Strong (builder) — market-validates the 'use readiness to modulate today's planned session' thesis almost verbatim; shipped a free tool and is recruiting users. Competitor/adjacent, partial profile (runner-only, not hybrid-strength).

### diddly69 - Reddit — r/HybridAthlete (comment on 'So. Damn. Sore.')  (partial fit)
https://reddit.com/r/HybridAthlete/comments/1r5jfh5/so_damn_sore/

> Part of being a hybrid athlete is deciding what to prioritize. [...] You'll have to put all of your hard running 3-4 days after the leg day. [...] You'll need to either back off the leg work or split it up so it's not killing you.

- **Plan source:** unclear (experienced hybrid athlete giving advice; own plan not described)
- **Modulation today:** Manages one fatigue budget across running + legs entirely by hand: sequences hard runs 3-4 days after leg day to dodge overlap, and trades off priorities week to week — either accept the soreness or cut/split the leg volume.
- **Pains:** One shared fatigue budget across running and strength forces constant manual prioritization; Hard sessions must be hand-spaced around recovery windows; Trade-off is binary and manual: back off volume or accept being wrecked
- **Tools:** manual scheduling heuristics (no app mentioned)
- **Willingness:** Neutral/implicit — demonstrates the exact manual fatigue-budget juggling Tuwa would automate, but frames it as a normal skill of being a hybrid athlete; no expressed desire for software.

### MythicalStrength - Reddit — r/tacticalbarbell ('1 Year Of Tactical Barbell')  (strong fit)
https://reddit.com/r/tacticalbarbell/comments/1nh36vr/1_year_of_tactical_barbell_my_experience_and/

> I never test. I feel like testing is a waste of a session, and it tends to set my recovery back. I don't necessarily slowly increase, because sometimes UP isn't the right move for a max. I evaluate based off how the previous cycle went. I like to "own" a max before I decide to increase it.

- **Plan source:** self-written (25+ years self-coached; runs a heavily self-modified Tactical Barbell system)
- **Modulation today:** Pure by-feel autoregulation plus life-driven periodization — birthdays/holidays/seasons and strongman meets dictate his blocks; takes a 'bridge'/deload week whenever he feels he needs one; judges load by 'owning' it across a cycle. Uses zero metrics, no HRV, no wearable.
- **Pains:** Previously broke himself ('incredibly broken') self-programming 'as hard as possible' — needed prescriptive bumpers, not more decisions; Views max-testing as a recovery-costly waste of a session
- **Tools:** Tactical Barbell books, Dan John / Jim Wendler frameworks, explicitly NO wearables, HRV, or apps, intuitive eating (no calorie tracking)
- **Willingness:** DISCONFIRMING — the most serious self-coached hybrid in the sample (strongman + martial arts 3x/wk + conditioning + running) wants LESS decision-making, loves a fixed system that 'tells you EXACTLY what to do,' and autoregulates entirely by feel. Would likely see an app modulating his plan as noise. A real segment treats by-feel autoregulation as already solved.

### pulse_and_plates - Reddit — r/hyrox  (strong fit)
https://reddit.com/r/hyrox/comments/1rlumrt/anyone_else_using_like_5_apps_just_to_understand/

> I've got Strava for runs, Strong for lifting, MyFitnessPal for food, Whoop for recovery. And some half-finished Google Sheet I made a few weeks ago that I keep meaning to fix... Is my running volume too high given how much I'm lifting? No idea... Whoop tells me I'm recovered but recovered for what? It has no clue I have a long run tomorrow.

- **Plan source:** self-written (half-finished Google Sheet; first Hyrox, self-coached)
- **Modulation today:** Manually stitches 4-5 disconnected apps plus a spreadsheet each week; spent ~20 min jumping between apps and still couldn't tell if on track. No unified readiness-vs-plan decision — the recovery tool (Whoop) has no idea what the plan demands.
- **Pains:** Data fragmentation across Strava/Strong/MyFitnessPal/Whoop + spreadsheet, none talk to each other; Can't tell if running volume is too high relative to lifting load; Recovery score (Whoop) is plan-blind: 'recovered for what?'; Nutrition not aligned to current training load; Analysis paralysis — sitting on tons of data that's 'kind of useless'
- **Tools:** Strava, Strong, MyFitnessPal, Whoop, Google Sheets
- **Willingness:** Strong latent demand — explicitly wants the apps to 'talk to each other' and tell him whether he's on track given his plan; no explicit pay signal, frames it as 'maybe I'm overcomplicating this.'

### mylesbr - Reddit — r/hyrox (comment on 1rlumrt)  (strong fit)
https://reddit.com/r/hyrox/comments/1rlumrt/anyone_else_using_like_5_apps_just_to_understand/

> Hyrox training is the worst case scenario for app fragmentation because you're doing everything: running, lifting, rowing, skiing, sled work. No single app knows what to do with that... The spreadsheet is always the tell. If you need a spreadsheet to connect your apps, the apps have failed. The 'recovered but recovered for what?' question is the real issue. Whoop doesn't know your training plan. It just sees your HRV and guesses... accept you'll be flying a bit blind on the nutrition/training crossover until something better exists.

- **Plan source:** self-written (ran the same Strava/Strong/MFP/Whoop + a spreadsheet 'I kept meaning to fix')
- **Modulation today:** Ran the identical multi-app + spreadsheet stack; now advises simplifying to one recovery tool + one training log and consciously accepting he's 'flying blind' on the strength/conditioning crossover.
- **Pains:** No single app handles the full hybrid modality set (run/lift/row/ski/sled); Recovery tool is ignorant of the training plan and 'just guesses'; Spreadsheet dependence is proof the apps have failed; Blind on the nutrition/training-load crossover
- **Tools:** Strava, Strong, MyFitnessPal, Whoop, spreadsheet
- **Willingness:** Explicit latent demand — 'until something better exists' directly implies he'd adopt a tool that knows the plan; currently resigned rather than actively paying.

### Unleashed94 - Reddit — r/bevelhealth  (strong fit)
https://reddit.com/r/bevelhealth/comments/1rdb3dw/feature_request_for_hybrid_athlete_optimization/

> Bevel consistently gives me 'Red/Low' recovery scores on days when I am actually in a productive recovery phase from lifting, misinterpreting muscle repair as poor health/overtraining... the strain should be more heavily weighted by Volume (Load x Reps) + RPE, as HR is often a lagging or inaccurate indicator of lifting intensity. No App is really useful for hybrid athletes at the moment-maybe bevel can make a step here.

- **Plan source:** self-written (programs own strength + running; uses Bevel Strength Builder + manual RPE)
- **Modulation today:** Uses Bevel's recovery score to guide training but actively distrusts/overrides it because the algorithm is cardio-biased and misreads CNS/lifting fatigue; manually integrates RPE to compensate.
- **Pains:** Recovery algorithm cardio-biased: 'Lower RHR + Higher HRV = Better' is inverted for strength; Misreads muscle repair / CNS fatigue as overtraining or poor health; HR is a poor proxy for lifting intensity; No app currently serves the combined hybrid (strength + endurance) load
- **Tools:** Bevel, manual RPE, HRV/RHR wearable
- **Willingness:** Very high — already a paying Bevel user who wrote a detailed, technically literate feature request proposing a volume×RPE-weighted strain model; explicitly wants a product that fixes hybrid recovery scoring.

### Armentero - Reddit — r/hyrox  (strong fit)
https://reddit.com/r/hyrox/comments/1rg7bax/trying_to_create_an_adaptive_hyrox_training_plan/

> Not trying to replace coaching — trying to build a structured self-coaching system... every Sunday I input key metrics (fatigue, recovery status, performance data, schedule constraints, etc.) so the following week automatically adjusts to my actual condition instead of following a rigid fixed plan... Goal: Improve HYROX performance while continuing to progress as a runner without drifting into overtraining.

- **Plan source:** self-written (evidence-based ChatGPT-assisted prompt; previously had a personal coach, now wants independence)
- **Modulation today:** Weekly cadence: inputs fatigue/recovery/performance/schedule into ChatGPT every Sunday so next week auto-adjusts to actual condition vs a rigid fixed plan. Manual but systematic readiness-driven modulation of his own program.
- **Pains:** Needs independence from a coach but wants to keep structure/periodization; Risk of drifting into overtraining while balancing HYROX + trail-run fatigue; Unsure what he's 'missing or overcomplicating' methodologically; Wants decisions grounded in load-management / recovery / periodization science
- **Tools:** ChatGPT, self-tracked weekly metrics (fatigue/recovery/performance)
- **Willingness:** Extremely high — building the exact Tuwa thesis by hand; his framing ('structured self-coaching system... not trying to replace coaching') matches Tuwa positioning almost verbatim. Caveat: he's DIY-substituting with ChatGPT and wants the plan to 'automatically adjust' (blurs modulate vs rewrite).

### Tari1337 - Reddit — r/Velo  (strong fit)
https://reddit.com/r/Velo/comments/1hry8gw/adaptive_training_tools/

> No human coach is gonna change a workout at 6 am because the athlete had a rough night and needs to train before work... every time I followed the plan I ended up either injured or sick... I finally listened to my gut and started training with Garmin's workout suggestion... TrainerRoad... doesn't take into account health stats, only previous workouts and power performance, so it doesn't work for me.

- **Plan source:** previously coach-led (3 yrs, 2 coaches); now self-coaching via algorithmic tools
- **Modulation today:** Switched from human coaches to Garmin's HRV/readiness-driven daily workout suggestions, which auto-reduce volume/intensity when it detects illness or a bad night; actively trialing AI endurance platforms.
- **Pains:** Human coaches can't react to daily readiness or to fatigue from other sports; Following rigid pre-made plans repeatedly led to injury/illness (now chronic heart condition); TrainerRoad and similar ignore health/HRV stats; Tools don't account for fatigue carried in from running/dancing/gym; Scheduling unpredictability of algorithm-driven plans
- **Tools:** Garmin (watch + workout suggestions), evaluating AI Endurance / Athletica.ai / Enduco / Humango, TrainerRoad (rejected)
- **Willingness:** Very high active search for an adaptive multi-sport readiness tool; cost-sensitive ('neither have the money' for a top coach). Caveat: he wants the tool to generate/adapt the plan itself — a step beyond Tuwa's 'never writes the program.'

### txx1219 - Reddit — r/Velo  (strong fit)
https://reddit.com/r/Velo/comments/1jqouer/very_hard_to_find_balance_between_training_and/

> I feel completely wrecked in middle of week and it's very frustrating because I have this want to continue to improve in both disciplines but I feel that I'm stopped by my recovery abilities... What can I do more? Should I limit my trainings?

- **Plan source:** self-written (posts his full strength-3x + cycling-3x weekly table)
- **Modulation today:** Runs a rigid self-built plan but adjusts ride intensity 'depending on my freshness in Day 2 and Day 3'; pre-schedules a deload every 4th week (cuts strength 100%→30%, cycling to Z2 only) and started grouping strength+cycling on the same days to free up rest days.
- **Pains:** Chronically 'wrecked' mid-week; Recovery capacity is the binding constraint on improving both disciplines; Doesn't know whether/how much to cut volume; Conflicting community advice (cut strength vs cut cycling) leaves him without a clear rule
- **Tools:** macro/calorie tracking, creatine/omega-3, no readiness/HRV app
- **Willingness:** Open and asking the crowd 'what can I do more / should I limit my trainings?' — receptive to a clearer modulation rule, but no app or pay signal expressed.

### Venus_DST04 - Reddit — r/hyrox  (partial fit)
https://reddit.com/r/hyrox/comments/1sqpo6l/midcycle_training_blues_during_hyrox_prep_fatigue/

> I'm not skipping workouts, and performance hasn't fallen, but everything feels harder than it should. I'm trying to figure out what signal this actually is: Accumulated fatigue / early overreaching? Underfueling relative to training load? External stress...? ... Trying to stay intentional here vs just grinding through it blindly.

- **Plan source:** template app/classes + self (F45 Hyrox-style classes 2x + self-scheduled runs and strength; first Hyrox)
- **Modulation today:** Pushes through everything (not skipping), but can't decode the fatigue signal so is essentially grinding; crowdsources interpretation of whether to adjust training, nutrition, or recovery.
- **Pains:** Cannot distinguish accumulated fatigue/overreaching vs underfueling vs life stress; Mentally flat, no post-workout lift, everything 'harder than it should' be; Wants to act on the signal but has no read on what it is; Possible underfueling (1400-1800 kcal) for the training load
- **Tools:** calorie tracking, F45 classes, no HRV/readiness wearable mentioned
- **Willingness:** Implicit — explicitly wants to 'stay intentional vs grind blindly,' i.e. wants a decision aid to interpret readiness; no explicit app/pay signal.

### No_Buyer_9020 - Reddit — r/hyrox (comment on 1rlumrt)  (weak fit)
https://reddit.com/r/hyrox/comments/1rlumrt/anyone_else_using_like_5_apps_just_to_understand/

> lol, you are overcomplicating this or stressing out over I'm not sure what... For recovery, i just listen to my body. Am i tired? Do my legs feel ok?... I use the same 12-week Google sheet for tracking my run schedule for each hyrox race I've done... Mostly bc i love spreadsheets.

- **Plan source:** self-written (own reusable 12-week Google sheet, built before his first race in 2024, tweaked each cycle)
- **Modulation today:** Pure 'listen to my body' (tired? legs ok?) plus a fixed reusable spreadsheet and macro tracking; no readiness instrumentation and no desire for one.
- **Pains:** None expressed — actively denies the problem, sees multi-app stitching as self-inflicted stress
- **Tools:** Strava, Apple Fitness/Health, macro app, self-built Google Sheet
- **Willingness:** Refusal/disconfirming — explicitly thinks readiness/modulation tooling is overcomplication; content with feel + spreadsheet. Fits the demographic (multi-race self-coached hybrid) but rejects the value prop.

### GreenInvestigator817 - Reddit r/Garmin  (strong fit)
https://www.reddit.com/r/Garmin/comments/1tfuujo/prepping_for_a_heavy_squat_block_this_is_how_my/

> Garmin's data structure might tell me I'm "Recovered," but my central nervous system and legs are absolutely fried from a heavy deadlift session 48 hours ago. Over the last few months, I've been trying to build a manual bridge between my morning Garmin metrics and my lifting program (an Upper/Lower/Push/Pull split) to auto-regulate my weights instead of just blindly following a spreadsheet. ... If my overnight recovery metrics drop 10-15% below my 28-day norm, or if I log high lifestyle stress, I cap my lifting RPE at 8. No maximal testing, even if the program dictates it. ... instead of forcing a 145kg barbell squat and risking injury, I force myself to swap the movement for a Smith machine or heavy machine accessories, capping the RPE strictly at 7. ... I actually ended up building a private web utility that hooks into my daily Garmin health data, normalizes my readiness and sleep horizons (daily vs 7-day trend vs 28-day baseline), and gives me a concrete recommendation on whether to push, deload, or swap exercises before I even step into the gym.

- **Plan source:** self-written — Upper/Lower/Push/Pull lifting split run from a spreadsheet with planned progressions and RPE/maximal-testing targets
- **Modulation today:** Has built an explicit manual rule set bridging Garmin readiness to his own plan across three horizons: stable 7-day trend + sleep >75 -> follow plan and auto-progress +2.5kg; recovery 10-15% below 28-day norm or high life stress -> cap RPE at 8, cancel maximal testing even if the program says test; readiness -25% / red -> swap barbell squat for Smith/machine accessories and cap RPE at 7. Got tired of doing it by hand and coded a private web utility that outputs a push/deload/swap verdict before he leaves for the gym.
- **Pains:** Generic device recovery score is disconnected from heavy strength: says 'Recovered' while CNS and legs are fried 48h post-deadlift; His written program does not autoregulate — 'blindly following a spreadsheet' risks injury on low-readiness days; Has to manually reconcile daily vs 7-day vs 28-day horizons against planned weights/RPE every morning; No off-the-shelf tool connects his readiness data to his authored plan, so he built one himself
- **Tools:** Garmin (watch + recovery/readiness/sleep metrics), self-built private web utility, spreadsheet lifting program
- **Willingness:** Very high latent demand — he already built the exact product (readiness-normalized push/deload/swap verdict layered on his own plan) for himself, and ends the post asking other lifters how they translate readiness into lifting weights. Note: he is himself a DIY-builder, so this is a 'I want this so badly I made it' signal rather than a buyer signal.

### Derelicte_by_Mugatu - Reddit r/Garmin  (strong fit)
https://www.reddit.com/r/Garmin/comments/1s1az3l/how_im_using_garmin_recovery_metrics_to_decide_my/

> I'm doing exactly the same and my training is hybrid; I do strength training, swimming, running and yoga for strength and flexibility. I consider also the training readiness because it crosses HRV, body battery and sleep, adding extra texture to the readings. I really appreciated this post because I often read about people ignoring all the stats on purpose keeping the training status in constantly unproductive or strained. I balanced my training in a much better and structured way over time thanks to the insightful data offered by garmin. On top of that I am also trying to use Gemini as a copilot for my body-recomp goal ... [later] We should start a startup! :D we know what we need to integrate in the system

- **Plan source:** mixed — self-structured hybrid training (strength + swim + run + yoga); diet plan from a dietitian fed into Gemini as the reference baseline
- **Modulation today:** Uses Garmin Training Readiness (HRV + body battery + sleep) as the composite signal to balance and structure her hybrid week, and manually prompts her daily metrics + workouts into Gemini to get training and nutrition adjustments. Explicitly trusts the data over the 'ignore all the stats' crowd, and has used it to make her training more structured over time.
- **Pains:** Hybrid load is not unified — Garmin treats a swim and a squat session as different stress profiles even though the body accumulates fatigue from both (echoed by OP in the thread); Daily friction of manually prompting stats/screenshots into Gemini every day; 'I haven't found a way to streamline everything yet'; Recovery data, training, and nutrition live in separate places and don't talk to each other
- **Tools:** Garmin (Training Readiness, HRV, body battery, sleep), Gemini (LLM copilot), body composition scale, dietitian-authored diet plan
- **Willingness:** High and explicit — frustrated by the manual integration friction and literally says 'We should start a startup! we know what we need to integrate in the system,' describing a wished-for system where recovery data drives training and training drives nutrition, all adapting daily instead of a static plan.

### God-of_mischief - Reddit r/Garmin  (strong fit)
https://www.reddit.com/r/Garmin/comments/1s1az3l/how_im_using_garmin_recovery_metrics_to_decide_my/

> some mornings I feel fine but the HRV trend tells me I've been grinding for 10 days straight and I probably shouldn't do heavy singles even if the warm-up feels decent. it's the stuff you can't feel yet that gets you. ... the one that catches me more often is feeling fine but the data saying otherwise, like BB is 72 but HRV has been trending down for a week. I used to push through those days and I'd feel it by Thursday. now I trust the trend even when the morning number looks ok. ... [on his workflow] copy the numbers from garmin, paste into the prompt, tweak the output, then figure out how to actually follow it in the gym ... it's like 15 - 20 minutes before I've even started warming up.

- **Plan source:** unclear / self-coached lifting — generates each session via ChatGPT from his morning recovery metrics rather than following a fixed authored block
- **Modulation today:** Trusts the multi-day HRV trend over both how he feels and the single-day body battery number to decide whether to do heavy singles; uses the gym warm-up ramp as a tiebreaker on ambiguous days. Each morning he prompts his Garmin recovery data into ChatGPT to set session intensity and generate the workout.
- **Pains:** Work stress tanks body battery but does not mean muscles aren't recovered — 'still figuring out how to filter for that'; Garmin can't capture muscular fatigue or true resistance-training load (HR-based); Daily LLM workflow is high-friction: 15-20 minutes of copying numbers, prompting, and re-formatting before he can even warm up; Single-day numbers (body battery) mislead vs the underlying trend
- **Tools:** Garmin (HRV, body battery, training load), ChatGPT (daily session generation)
- **Willingness:** High stated demand ('recovery data driving the training... someone's going to build it eventually, might as well be us'), BUT flagged: the OP's thread reads partly like content-marketing/product seeding (polished engagement-bait replies; a commenter, nick_besbeas, openly plugs his own app 'fitMetrics' in-thread). Treat the behavior claim as real-but-possibly-promotional.

### MissRattlesnake - Reddit r/ouraring  (partial fit)
https://www.reddit.com/r/ouraring/comments/1oslvns/readiness_score_low_but_i_still_want_to_workout/

> Anyone just ignore their readiness score being low? It's been low for the past few days with nothing I can really point to. I have gym goals I'm thing to hit. And I already missed a few days in the gym this week because of other obligations. Annoyed at the readiness telling me to rest. I'm also at the end of my literal [luteal] phase right now but I can't just take 2 weeks off every month.

- **Plan source:** self-written — personal gym goals / self-directed lifting schedule
- **Modulation today:** Leaning toward overriding/ignoring a multi-day low readiness to hit her self-set gym goals; openly annoyed that the score keeps telling her to rest when she's already behind on training and can't structurally rest two weeks every luteal phase. Community piled on with 'work out, the ring is a guide not a shackle.'
- **Pains:** Readiness chronically low for days with no identifiable cause she can act on; Score conflicts with her training goals and life schedule (already missed gym days); Score doesn't account for predictable cyclical (luteal) dips — tells her to rest at a cadence that's incompatible with progressing
- **Tools:** Oura
- **Willingness:** Ambivalent / seeking permission — wants a reason to override the score rather than an app to obey it; no explicit demand for a modulation app. Reveals the trust gap: the score gives a verdict that ignores her plan and her physiology, so she discounts it.

### Kind-cheesecake-3316 - Reddit r/Garmin  (partial fit)
https://www.reddit.com/r/Garmin/comments/1rjagvc/garmin_gives_us_50_metrics_what_i_actually_wanted/

> I trust the Training Peaks Performance Management Chart more than my Garmin. 48 years of endurance sports has taught me that if I'm training for a goal event, am not injured or sick and the training plan says go then I go. There have been countless times that the mind was unwilling but the body was perfectly able. The opposite is also true - times when I'm mentally ready but the body is carrying lots of fatigue and I'm best served by a rest day. If I'm not training for an event and just maintaining then I might skip if I don't feel like it.

- **Plan source:** self-coached using a TrainingPeaks Performance Management Chart (CTL/ATL) as his planning/decision instrument
- **Modulation today:** Follows the PLAN over the daily device readiness score: if in a goal block and not injured/sick, he executes the planned session regardless of how he feels or what the watch says. Only relaxes to feel-based skipping when in a no-goal maintenance phase. Uses PMC fatigue/fitness balance, not the watch's daily verdict.
- **Pains:** Device daily readiness is noise he distrusts relative to his own longitudinal PMC; Watch readiness doesn't reflect periodization position / goal-event context
- **Tools:** TrainingPeaks (Performance Management Chart), Garmin
- **Willingness:** Disconfirming — a serious self-coached athlete who explicitly prefers his own plan + PMC over device-driven daily modulation, and would resist an app overriding a planned hard session. Notably aligns with Tuwa's 'respect the user's plan' stance but rejects daily readiness as the modulator.

### picky_dude - Reddit r/Garmin  (weak fit)
https://www.reddit.com/r/Garmin/comments/1rjagvc/garmin_gives_us_50_metrics_what_i_actually_wanted/

> Do you want your watch to decide when and how you should train? I've always thought all those metrics were mostly for beginners who haven't figured it out for themselves yet

- **Plan source:** unclear — implies self-directed / experience-based training
- **Modulation today:** Rejects the premise of a device/app deciding the go/modify/hold call; self-regulates from training experience and frames readiness metrics as a crutch outgrown by experienced athletes.
- **Pains:** Views readiness/recovery metrics as low-value for experienced trainees ('mostly for beginners')
- **Tools:** Garmin (skeptical user)
- **Willingness:** Explicit refusal — direct resistance to an app/device making training decisions. Strong disconfirming signal that the experienced self-coached cohort can perceive a modulation engine as a beginner tool / loss of autonomy.

### -Radiation - Reddit r/Garmin  (partial fit)
https://www.reddit.com/r/Garmin/comments/1s1az3l/how_im_using_garmin_recovery_metrics_to_decide_my/

> Best way is wake up and see how you feel. Then start the warm up, climb weight a bit and you'll find out pretty fast if it is a good or bad day. Garmin training load can't account for muscular fatigue, and HRV is impacted by way too many factors outside of lifting. They can be indicator but they are never as good as just lifting and see how it is going that day.

- **Plan source:** self-coached lifting (specifics unstated)
- **Modulation today:** Makes the go/modify call in-session via the warm-up ramp (load up and see how the bar moves) rather than from any morning score; treats device metrics as a weak indicator at best for strength work.
- **Pains:** Device training load can't account for muscular fatigue; HRV too confounded by non-training factors to drive lifting decisions
- **Tools:** Garmin (de-emphasized), in-session warm-up autoregulation
- **Willingness:** Disconfirming on app-verdict, but validates Tuwa's core pain: the device misses strength/muscular fatigue. He prefers in-session feel/warm-up autoregulation over any pre-session app verdict — a bar Tuwa's 'today number' must beat to win this user.

### Glass_Ad1469 - Reddit r/whoop  (weak fit)
https://www.reddit.com/r/whoop/comments/1h592zt/whoop_hrv_is_the_answer_sleeping_more_and_not/

> I had a 17km difficult elevation hike coming up and I took 2 rest days off in preparation (super spooked by my low recovery scored) and then woke up to the worst recovery score yet on the day of the hike. I nearly bailed, however I didn't want a 3rd rest day. I went… and it was EASY. I know HRV is very personal, but with scores as low as 20 I wonder if I should be concerned? ... How seriously do you take the HRV?

- **Plan source:** self-directed informal plan — training up for a 40-day Camino (20-30km/day) plus bootcamp + strength sessions
- **Modulation today:** Was spooked by persistent red recovery scores into over-resting (took extra rest days), nearly skipped her planned key hike on a red morning, overrode the score and went anyway — and the session felt easy, contradicting the score. Now openly unsure how much weight to give HRV vs her own plan/feel.
- **Pains:** Red recovery score didn't match actual performance — over-rested out of fear of the number; Doesn't know how seriously to weight HRV against her training plan; Score gives a blunt 'recover' verdict with no connection to her goal (Camino prep) or to what's actually driving the dip (heat, alcohol)
- **Tools:** Whoop
- **Willingness:** Seeking interpretation help, not an app — wants to know how much to trust the score relative to her plan. Illustrates the score-vs-plan trust gap (the verdict was wrong for her) but shows novice users may not articulate demand for a plan-aware modulation product.

### Inevitable_Brick_221 - Reddit r/HybridAthlete  (strong fit)
https://www.reddit.com/r/HybridAthlete/comments/1roi0kr/i_got_tired_of_guessing_how_much_to_take_off_the/

> every percentage-based program treats you like you exist in a vacuum. It says "Squat 80% of your max today" without caring that you ran 10km yesterday morning and rolled for an hour the night before. So I'd either go in too heavy and feel like garbage, or I'd randomly knock off weight and hope for the best. Neither felt smart. I started digging into how fatigue actually works specifically the difference between central (CNS) fatigue and local/peripheral fatigue... So I built HybridLoad. It's a free web-based barbell calculator... It changes the fatigue penalty based on what lift you're doing. A run hits your squat hard but barely affects your bench.

- **Plan source:** self-written / percentage-based template (squats+deadlifts) self-run alongside kickboxing/running/HIIT
- **Modulation today:** Was going in too heavy and feeling cooked or randomly knocking weight off and hoping; got frustrated enough to build his own tool (HybridLoad) that adjusts today's barbell number per-lift based on CNS vs peripheral fatigue from yesterday's run/sparring, using an anchor+diminishing-modifier model instead of linear penalty stacking.
- **Pains:** Percentage-based programs ignore cross-modal fatigue ('treats you like you exist in a vacuum'); Linear penalty calculators are 'way too aggressive' and ignore CNS vs local fatigue; A hard run wrecks the squat but barely touches bench; existing tools don't distinguish; Guessing how much to take off the bar after conditioning
- **Tools:** Self-built web calculator (HybridLoad / hybridload.com), percentage-based programs, planned RPE integration + training history in a 'Pro tier'
- **Willingness:** VERY HIGH — built and is monetizing (Pro tier) exactly Tuwa's 'today' horizon: adjust today's planned numbers for cross-modal fatigue. Strong validation of demand AND a direct competitor signal. Wants real-world feedback on whether the fatigue percentages match experience.

### VegaGT-VZ - Reddit r/HybridAthlete  (partial fit)
https://www.reddit.com/r/HybridAthlete/comments/1oe3njx/hybrid_athletes_whats_the_hardest_part_of/

> I think people need more help understanding how they feel and relying less on apps and data. For example sometimes my Garmin will say I got a great night sleep, but I still feel tired and shitty. Or I might not get the greatest night sleep, but then I say fuck it and smash a workout. Those are the kind of judgment calls you can't make with an app. Plus there are so many great apps already... Im also not sure we need another app hoovering up more of our data.

- **Plan source:** self-managed (lifting + cycling); says he finds little cross-discipline impact between lifting and cycling
- **Modulation today:** Overrides device readiness in BOTH directions with subjective feel — ignores Garmin's 'great sleep' when he feels bad, and trains hard despite a poor sleep score when he feels good. Treats the modify/go decision as a human judgment call, not an app output.
- **Pains:** Wearable readiness scores routinely mismatch how he actually feels; App/data overload — 'so many great apps already'; Distrust of giving more personal data to another app
- **Tools:** Garmin, intervals.icu (cycling)
- **Willingness:** RESISTANT / disconfirming — explicitly believes readiness-vs-train 'judgment calls you can't make with an app,' is skeptical the market needs another app, and raises a data-privacy/data-hoovering objection. Core anti-positioning risk for an app that automates the verdict.

### Long_Edge_8517 - Reddit r/HybridAthlete  (strong fit)
https://www.reddit.com/r/HybridAthlete/comments/1oe3njx/hybrid_athletes_whats_the_hardest_part_of/

> What's working for me right now is full body lifting 3x per week, 1 session of zone 2 spinning, 1 session of zone 4-5 running, and daily walks. I am slowly adding volume week to week, and dialing back when my body signals to me it needs rest. The hard part is feeling the difference between "you actually need rest" vs "you're tired, but suck it up and go for it " when your body starts complaining

- **Plan source:** self-written (3x full body + zone-2 spin + zone-4/5 run + daily walks)
- **Modulation today:** Progresses volume week-to-week and dials back off subjective body signals; the whole modulation hinges on a daily read of whether he genuinely needs rest or is just tired.
- **Pains:** Cannot reliably distinguish 'actually need rest' from 'tired, suck it up' — the exact go/modify/hold verdict problem; Auto-regulating volume by feel with no objective anchor
- **Tools:** body signals / subjective feel (no specific app named)
- **Willingness:** Implicit demand — names the precise decision Tuwa's 'today' verdict targets as 'the hard part,' but currently solves it by feel alone; no stated willingness to pay or use an app.

### onlygetthisone - Reddit r/HybridAthlete  (strong fit)
https://www.reddit.com/r/HybridAthlete/comments/1oe3njx/hybrid_athletes_whats_the_hardest_part_of/

> To be honest, I don't know what I'm doing. I don't feel like there's actually a good hybrid program out there at all for the regular Joe, a regular middle aged Dad with a full time job, not on PEDs, only able to commit 1.5 hours/day for lifting and aerobic maybe 4 or 5 days a week. I basically cross train cardio and Wendler 5/3/1 lift... I really struggle integrating with the right nutrition.

- **Plan source:** self-assembled from a template — Wendler 5/3/1 lifting + self-chosen cross-training cardio (swim/erg/track/bouldering/long run)
- **Modulation today:** Runs a fixed weekly split he built himself; expresses low confidence ('I don't know what I'm doing') rather than any structured readiness-based adjustment — modulation is essentially ad hoc.
- **Pains:** No good hybrid program exists for the time-capped working amateur ('regular Joe'); Balancing 5 days of lift + cardio in 1.5h/day; Integrating nutrition with the training
- **Tools:** Wendler 5/3/1 template, self-designed weekly split
- **Willingness:** Strong latent demand — open frustration that no system serves the self-coached time-limited hybrid dad; describes himself as the underserved target but states no current tool or payment intent.

### LegendOfTheFox86 - Reddit r/HybridAthlete  (strong fit)
https://www.reddit.com/r/HybridAthlete/comments/1oe3njx/hybrid_athletes_whats_the_hardest_part_of/

> I utilize Coros for all of my running. I find the lifting experience awful from all perspectives, bad UI during sessions, adjusting the program on the fly, accessing overall training load. I pretty much utilize a notepad file on my iPhone for lifting for easier management. I attempt to correlate both parts into strava for the high level training plan and execution but this is far from ideal.

- **Plan source:** self-managed hybrid (running tracked in Coros; lifting program run by hand)
- **Modulation today:** Adjusts the lifting program 'on the fly' but the tooling fights him — he can't see overall (cross-modal) training load, so he stitches running + lifting together manually in Strava and a Notes file to get a high-level picture.
- **Pains:** Lifting UX in endurance apps is 'awful' — bad in-session UI, can't adjust program on the fly; No unified view of overall training load across run + lift; Reduced to an iPhone notepad for lifting; Strava correlation 'far from ideal'
- **Tools:** Coros, Strava, iPhone Notes app (lifting log)
- **Willingness:** Strong implicit demand for a unified hybrid-load tool — pain is squarely the 'one fatigue budget across modalities' gap; no explicit pay signal but clear dissatisfaction with the current stack.

### Ghodefroy - Reddit r/weightlifting  (partial fit)
https://www.reddit.com/r/weightlifting/comments/ghzk1f/experience_with_autoregulation_and_weightlifting/

> At the beginning of 2020, I had the desire to start over weightlififting, but with the use of autoregulation (since I had so much result and pleasure doing so). I didn't find a way to use (for my liking) autoregulation with WL movement, so I used Takano Class 1 for Sn and CnJ. For squat, press and pull movements, I used autoregulation (I used BBM template...). After 3 weeks, I found using RPE with Sn/Cl deadlift wasn't effective for my liking so I started doing pull movement as prescribed from Takano Class 1.

- **Plan source:** self-fused from purchased templates — Barbell Medicine RPE/RTS templates for squat/press/pull + Takano Class 1 for the Olympic lifts
- **Modulation today:** Sophisticated manual autoregulation: runs BBM RPE protocols (e.g., single @8RPE then percentage back-off sets; ascending 6/7/8 RPE with supplemental work) and self-experiments — dropped RPE on snatch/clean deadlifts after 3 weeks when it 'wasn't effective for my liking' and reverted those to fixed prescription.
- **Pains:** No satisfying way to apply RPE-autoregulation to the technical Olympic lifts; Had to hand-fuse two incompatible programming philosophies himself; Rehabbing a herniated disc with zero professional support — taught himself from books/templates
- **Tools:** Barbell Medicine templates (RPE/RTS), Takano Class 1, Stuart McGill 'Big 3' rehab, self-estimated 1RM + RPE charts
- **Willingness:** Neutral DIY — deeply invested in autoregulation and willing to pay for templates, but defaults to building the system himself; an app would have to beat his hand-tuned hybrid of templates.

### three_white_lights - Reddit r/AdvancedFitness (Mike Tuchscherer / RTS AMA)  (partial fit)
https://www.reddit.com/r/AdvancedFitness/comments/1eqykj/im_mike_tuchscherer_ama/

> When it comes to gauging RPE do you go entirely on a subjective view? I've found in watching replays of my sets that while a give squat set may feel like it's @9 the replay suggests its closer to @7.   ...   Do you use TRAC on a daily basis? Do you find that it has a significant correlation with your training performance?

- **Plan source:** RTS / RPE-based programming (Reactive Training Systems methodology)
- **Modulation today:** Runs RPE-based autoregulation but has caught his own perceived RPE being miscalibrated against video (felt @9, replay looked @7), and probes whether RTS's daily readiness questionnaire (TRAC) actually correlates with his performance — i.e. actively cross-checking subjective readiness against objective signals.
- **Pains:** RPE is subjective and self-miscalibrated — felt-effort doesn't match bar speed on replay; Uncertain whether daily readiness tracking (TRAC) actually predicts performance
- **Tools:** RPE, TRAC (RTS readiness questionnaire), video replay / bar-speed eyeballing
- **Willingness:** Already adopts readiness-tracking tools and wants validation that they correlate with output — a primed buyer for an engine that objectively anchors the RPE/readiness call, IF it proves predictive.

### BatmanSteak - Reddit r/tacticalbarbell  (strong fit)
https://www.reddit.com/r/tacticalbarbell/comments/1pyyibq/long_term_tb_enthusiast_coming_to_a_stall_with/

> at 36, the big lifts are starting to demand long warm-ups, and I'm occasionally feeling it in my lower back, knees, neck, etc. My son just turned 3 and is an absolute tornado, so I don't always have the time or mental energy to load 350+ lbs on my back after running around all day. Sometimes it's less physical fatigue and more a focus issue... I'm looking for ideas around "maintenance-style" workouts—something I can jump into without extensive warm-ups.

- **Plan source:** Tactical Barbell (read strength + conditioning books multiple times; self-coached for ~20 years)
- **Modulation today:** After cycling through many programs, settled on TB for adherence; now modulating around life — recognizes some days the limiter is mental focus/life stress (toddler, 6-7h sleep), not physical fatigue, and is seeking lower-barrier 'maintenance' sessions he can autoregulate into on cooked days.
- **Pains:** Aging joints + long warm-up overhead on heavy lifts; Time/mental energy crunch from work + young kid; Distinguishing physical fatigue from a 'focus issue' day; Wants a graceful low-readiness fallback session, not all-or-nothing
- **Tools:** Tactical Barbell books, home gym (Echo bike, GHD, KBs, trap bar); does not track diet, ~6-7h sleep
- **Willingness:** Seeking-a-system but template-loyal — explicitly came to Reddit for structure rather than reaching for an app; values simplicity, so an app must lower friction on cooked days without adding overhead.

### MythicalStrength - Reddit (r/tacticalbarbell)  (strong fit)
https://www.reddit.com/r/tacticalbarbell/comments/1sex5i9/over_18_months_of_tactical_barbell_observations/

> What I like about this is the simplicity. I don't measure/track my calories or macros. Instead, I evaluate outcomes. I look at how my performance is doing, and how my clothes/weightbelt fit, and can adjust as needed. ... For all Tactical Barbell workouts, instead of following the Rx plan for deadlifts, I do 1 set of pulls at reps above 5 ... trying to pull from the floor with heavy weights frequently just burns me out ... Typically, we do a cruise vacation around New Years, so I make that my bridge week, but if I need one sometime before that during that block of training, I'll take it.

- **Plan source:** self-written / published system (Tactical Barbell book + Mass Protocol), heavily self-modified
- **Modulation today:** Outcome-based autoregulation: runs a periodized year (OMS) but evaluates performance + bodyweight rather than tracking; takes 'bridge'/deload weeks as needed rather than on a fixed schedule, and swaps/de-prioritizes prescribed lifts (e.g. deadlift) to manage systemic fatigue across strength + conditioning + martial arts.
- **Pains:** Following the prescribed Rx literally (pulling from floor every week) 'always a disaster' / burns him out; Has to manually engineer recovery and deload timing around a 12-month periodized plan and real life; Carries one fatigue load across lifting, conditioning, strongman events and martial arts and must hand-balance it
- **Tools:** Tactical Barbell / Mass Protocol books, self-assessment by feel and outcomes (no wearable or app mentioned)
- **Willingness:** Values a plan that is 'so prescriptive it is yet still with room to maneuver' — i.e. wants structure plus modulation latitude. No app or pay signal; trusts his own 26 years of judgment over any tool (a 'why would I need software' headwind for the advanced reference user).

### i0nkol - Reddit (r/HybridAthlete)  (strong fit)
https://www.reddit.com/r/HybridAthlete/comments/1oddwjs/twodayaweek_strength_routine_chatgpt/

> I uploaded Alex Viada's Hybrid Athlete book to ChatGPT and asked it to create a routine for me to follow two days a week for six months to complement my cycling. Here's what it came up with. What do you think? Is AI ready for this, or not yet? ... I have no problem paying, but I have a meniscus injury and I only want strength training since I prefer to ride the bike independently on Zwift.

- **Plan source:** AI-generated — ChatGPT fed Alex Viada's 'The Hybrid Athlete' book
- **Modulation today:** Relies on a static 6-month AI-authored plan; has no readiness loop. Notably the generated plan itself instructs him to 'Track recovery closely: HRV or subjective fatigue markers,' but he has no tool or method to act on that day-to-day.
- **Pains:** No access to a coach; uncertain whether the AI plan is safe or correct ('Is AI ready for this?'); Managing a meniscus injury entirely alone; Wants to keep cycling autonomy (solo Zwift) while bolting on safe strength — interference/recovery is his to figure out
- **Tools:** ChatGPT, Zwift, Alex Viada 'The Hybrid Athlete' book
- **Willingness:** Explicit willingness to pay ('I have no problem paying') but wants to preview the product before paying; is DIY-authoring a plan via AI specifically because he has no trusted affordable coaching alternative.

### decydiddly - Reddit (r/tacticalbarbell)  (strong fit)
https://www.reddit.com/r/tacticalbarbell/comments/1sex5i9/over_18_months_of_tactical_barbell_observations/

> I have been doing TB for the past couple of years but thinking about migrating back to 5/3/1 system for the increased flexibility of adjusting the workload to daily recovery. My recovery is shit due to work and life. 531 gives more flexibility vs the prescribed sets of TB. How have you mitigated the 'prescribed' and recovery over time with TB?

- **Plan source:** published systems — Tactical Barbell (current), considering migrating to 5/3/1
- **Modulation today:** Considering swapping his entire program just to gain the flexibility to adjust prescribed workload to daily recovery; currently has no mechanism to reconcile the program's prescribed sets with how recovered he actually is.
- **Pains:** Prescribed program rigidity vs real-life recovery ('the prescribed sets of TB'); Work and life wreck his recovery and the plan doesn't flex for it; Doesn't know HOW to adjust prescribed load to daily readiness — asks the author directly
- **Tools:** Tactical Barbell template, 5/3/1 template (considered)
- **Willingness:** Strong latent demand — explicitly wants 'flexibility of adjusting the workload to daily recovery,' which is precisely Tuwa's TODAY-horizon wedge. He's solving it by changing whole programs because no decision layer exists; no app referenced.

### Wtf_Sai_Official - Reddit (r/fitness40plus)  (partial fit)
https://www.reddit.com/r/fitness40plus/comments/1qvjo6r/recovery_at_40_is_a_whole_different_sport/

> I run programs I find on Boostcamp but honestly half the skill now is knowing when to back off the prescribed weights. ... Actually taking deload weeks instead of skipping them like I always used to. Listening to my body when it says not today instead of grinding through.

- **Plan source:** template app — Boostcamp programs
- **Modulation today:** Runs templated programs from an app but backs off the prescribed weights by feel; has shifted from skipping deloads to taking them; explicitly frames 'knowing when to back off the prescribed weights' as the hard, central skill the app does not provide.
- **Pains:** The program app delivers the plan but not the back-off / deload decision; Deload timing and load-modulation are pure judgment calls; Sleep, diet, work stress and an old shoulder injury all bleed into readiness and must be weighed manually
- **Tools:** Boostcamp
- **Willingness:** Names the exact unmet gap (templated program ≠ knowing when to modulate). No explicit pay signal. Credibility caveat: '_Official' handle + engagement-bait framing means this could be a content/karma post, though the quote is verbatim and publicly retrievable.

### actionjj - Reddit (r/ouraring)  (partial fit)
https://www.reddit.com/r/ouraring/comments/1svri3c/at_what_readiness_score_do_you_postpone_a/

> Last week I was sore throat / feeling run down yet getting 85-90 readiness, which I ignored and postponed training. Conversely if I got a <60 readiness score it's highly unlikely that I also feel good. ... I have asthma and so if I train with 'above the neck' it most certainly goes below the neck worse than if I back off.

- **Plan source:** self-managed scheduled training (sport mix unspecified)
- **Modulation today:** Postpones/modulates primarily by subjective feel plus illness rules (above-/below-the-neck); treats the readiness score only as weak confirmation and overrides it when score and felt state disagree.
- **Pains:** Readiness score conflicts with felt state (high score while run down) and misses context; Score ignores illness/asthma context that actually drives his back-off decision; Wants a numeric postpone threshold but concludes feel beats score
- **Tools:** Oura ring
- **Willingness:** Partly disconfirming on pure-score modulation: distrusts the lone score as authority. Implies appetite for a signal that FUSES feel + illness/context, not a number dictating the session.

### betakay - Reddit (r/ouraring)  (partial fit)
https://www.reddit.com/r/ouraring/comments/1oslvns/readiness_score_low_but_i_still_want_to_workout/

> if i feel like crap, and it's a scheduled workout day, i don't even bother looking at the oura app until i'm finished with the workout. if i were to check the app before the workout, i think it'd have a negative psychological effect on my performance.

- **Plan source:** has a scheduled program (source unspecified)
- **Modulation today:** Deliberately ignores readiness data BEFORE training to avoid a nocebo effect; follows the planned session regardless and only checks the data afterward.
- **Pains:** Pre-workout readiness scores create negative psychological priming; Does not trust a low score to override a planned session
- **Tools:** Oura ring
- **Willingness:** Disconfirming — actively avoids letting a readiness number modulate a planned session. A pre-workout 'hold/modify' verdict UX risks exactly the nocebo rejection he describes.

### Weird-Helicopter6183 - Reddit (r/fitness40plus)  (partial fit)
https://www.reddit.com/r/fitness40plus/comments/1qvjo6r/recovery_at_40_is_a_whole_different_sport/

> I can feel that this weeks work outs will require a de-load next week for sure. I agree, that's one of the hardest lessons for me. Last time I didn't listen to my own body I was wrecked for a few weeks. Dropping weight and continuing to work out is better than breaking the habit and breaking yourself.

- **Plan source:** self-managed (home-gym masters lifter)
- **Modulation today:** Forecasts a needed deload by feel a week out (proactive); when fatigued, drops weight and keeps the habit rather than skipping; learned this only after being 'wrecked' by ignoring his body.
- **Pains:** Deload timing is reactive and by-feel, and mistiming it has cost him weeks; Tension between not breaking the training habit and not breaking himself
- **Tools:** none mentioned — decisions by feel
- **Willingness:** No pay signal, but the core pain (mistimed deloads = weeks lost) is exactly the mid-term overreach-forecast value prop; he's manually doing what Tuwa's FCST horizon would automate.

### u/MythicalStrength - Reddit — r/tacticalbarbell  (strong fit)
https://www.reddit.com/r/tacticalbarbell/comments/1sex5i9/over_18_months_of_tactical_barbell_observations/

> I really no longer had a need to ever train any other way again, because the system was so comprehensive yet modular that, whatever I needed it to be, it was, and whenever I needed to pivot, it was there to pivot with me. [...] This is something that I've worked with over the years that just plain works for me, whereas trying to pull from the floor every week is always a disaster.

- **Plan source:** template (Tactical Barbell) heavily self-modified — effectively self-coached
- **Modulation today:** Runs the TB Operator-Mass-Specificity structure but autoregulates entirely by accumulated self-knowledge and life logistics: sequences phases by season + strongman competitions, caps deadlifts at 1x/week, runs a custom 6-week ROM progression and swaps front for back squat to 'spare my back for more conditioning work.' Fatigue is managed by feel + program craft; no HRV/readiness metric appears anywhere in 18 months of write-up.
- **Pains:** Rigid Rx prescriptions (e.g. weekly floor pulls) 'burn me out' — needs 'room to maneuver'; Manually juggling lower-back load between heavy gym work and strongman conditioning events so he doesn't 'overtax' himself
- **Tools:** Tactical Barbell books/system, Self-built program modifications, No wearable or readiness app referenced
- **Willingness:** No mention of any readiness/decision app. Behavior is total self-reliance — he states he 'no longer had a need to ever train any other way.' Implicitly a hard sell: he already solved modulation himself and treats bespoke program-craft as identity.

### u/Your_Good_Buddy - Reddit — r/weightroom  (strong fit)
https://www.reddit.com/r/weightroom/comments/srskk9/the_method_of_madness_one_meatheads_approach_to/

> Except for Smolov, I've never followed a program and when I am shown a spreadsheet, I just stare blankly at it. I've always preferred to do my own thing [...] There are no percentages and no RPEs. You will need to make a lot of decisions

- **Plan source:** self-authored — explicitly 'not a program at all'
- **Modulation today:** Trains with no percentages, no RPE, no spreadsheet; makes all load/volume choices in the moment by feel and ~13 years of self-knowledge. Whole post frames being his own programmer as identity ('I just stare blankly' at spreadsheets).
- **Pains:** Finds any rigid/structured prescription unusable — stares 'blankly' at spreadsheets and refuses percentage- or RPE-based schemes
- **Tools:** Nothing — pure autoregulation by feel and experience
- **Willingness:** Strong implicit refusal. An app that 'adjusts today's planned numbers' presupposes a structured numeric plan he deliberately refuses to keep. Note: strength-dominant rather than tri-modal hybrid, but a textbook 'guards own programming as identity' voice.

### u/Andejusjust - Reddit — r/HybridAthlete  (strong fit)
https://www.reddit.com/r/HybridAthlete/comments/1tftmif/comment/ombz428/

> The running plan and lifting plan I have are static, and include progressive overload so that I'm always pushing the stimulus barrier. But also I keep track of how my feet/ankles/calves are feeling and this is how I determine if running that day should be something I do or if I should crosstrain instead [...] If multiple days in a row something is wrong, I'll deload a small amount of time, and restart the plan 4 weeks and try again.

- **Plan source:** self-written (self-made 7x/week Sheiko split + own running plan, kept in a spreadsheet)
- **Modulation today:** Static progressive-overload lifting+running plan; modulates running day-to-day purely by lower-leg/joint feel — crosstrains instead of running when something hurts; if multiple bad days stack up, deloads and restarts the 4-week block. Today = feel; mid-term = manual deload trigger.
- **Pains:** Managing running impact / lower-leg niggles against a fixed weekly plan; Day-to-day run-vs-crosstrain decision is made by gut, no objective signal
- **Tools:** Self-built spreadsheet with hand-picked metrics, Manual notes, No wearable / readiness app
- **Willingness:** Already runs the exact Tuwa loop — readiness-driven modulation of a self-authored hybrid plan — manually and by feel, with zero software. Expressed no desire for an app; in a thread whose OP argued feel is a bad recovery metric, he defended his feel-based system.

### u/LordPeachez - Reddit — r/Garmin  (strong fit)
https://www.reddit.com/r/Garmin/comments/1qnoc7x/comment/o1vejgs/

> As someone who does a lot of gym work + field sports + running, I did a lot of research into tools to adequately track training load. Nothing worked great, you kind of just need to track them separately and use your own knowledge to best plan rest and future workouts. I just built my own schedule, and use the garmin data as tidbits to feed my knowledge.

- **Plan source:** self-built schedule
- **Modulation today:** Tracks gym / field-sport / running loads separately and plans rest + future sessions by his own knowledge; demotes Garmin data to 'tidbits' that merely feed his judgment rather than driving decisions.
- **Pains:** No tool adequately tracks unified training load across gym + field sports + running ('Nothing worked great'); Researched the tooling space specifically and abandoned it
- **Tools:** Garmin (downgraded to supplementary), Own self-built schedule, Separate manual per-modality tracking
- **Willingness:** Pointed disconfirmation: he actively hunted for a unified-hybrid-load tool — Tuwa's core promise — judged that none work, and settled on self-knowledge. Validates the problem is real but his resolved stance is self-reliance + skepticism software can do it.

### u/RoosterHuge4549 - Reddit — r/Garmin  (partial fit)
https://www.reddit.com/r/Garmin/comments/1ph59uy/its_just_a_watch_not_your_life_coach/

> The other day mine told me not to train, poor training readiness, super low body battery. I did one of my best long runs. Another time I'm really sick with flu and it's telling me I'm 100%. It's an aid, not an actual coach. Listen to your body.

- **Plan source:** self-directed (own training, not app-prescribed)
- **Modulation today:** Explicitly trains against the device verdict — ran one of his best long runs on a 'poor readiness / low body battery' morning, and ignores '100%' readouts when he's actually sick. Defaults to subjective feel over the score.
- **Pains:** Readiness / body-battery verdict contradicts how he actually feels and performs; Sees community over-trusting watch verdicts as a real harm (cites a chronically ill person training because the watch said to)
- **Tools:** Garmin watch (readiness explicitly ignored)
- **Willingness:** Direct disconfirmation of the go/modify/hold verdict specifically: 'It's an aid, not an actual coach.' He would override any session verdict software produced; his post (110+ comments, broad agreement) is a manifesto against letting the device decide.

### u/opholar - Reddit — r/whoop  (weak fit)
https://www.reddit.com/r/whoop/comments/1ql9wf5/comment/o1crn0i/

> There are too many companies out there offering similar products. I don't need to be doing business with one that has so little value for its customers. I will come up with a behavior model of my own. For $0/year.

- **Plan source:** n/a — used the device for behavior/recovery correlation, not a training program
- **Modulation today:** Valued Whoop's behavior→recovery correlation as its single real benefit; on cancelling, decided to replicate that model himself rather than pay for it.
- **Pains:** Subscription cost vs delivered value; Shoddy customer service / forced full-price renewal three days before a discount unlocked
- **Tools:** Whoop (cancelled)
- **Willingness:** Disconfirmation from a former fan: 'I will come up with a behavior model of my own. For $0/year.' Signals both price resistance and confidence the insight is self-replicable — a recurring threat for a paid decision-support subscription.

### u/marf_lefogg - Reddit — r/whoop  (partial fit)
https://www.reddit.com/r/whoop/comments/1ql9wf5/comment/o1cuiiz/

> I could wake up feeling rested and on top of the world and then the almighty whoop subscription I'm paying for would tell me to take it easy and that I might not be feeling up to snuff.

- **Plan source:** self-directed
- **Modulation today:** Trusts subjective feel over the recovery score; quit Whoop largely because the device told him to back off on mornings he felt great.
- **Pains:** Device verdict contradicts felt readiness; Subscription-model resentment — 'Nothing is improving month to month from our payments'
- **Tools:** Whoop (quit)
- **Willingness:** Disconfirmation: resents a paid device overriding his body's own signal. Would distrust an app's modify/hold verdict precisely on the days he feels strong — the same friction point that would undercut Tuwa's 'today' verdict.

### u/No_Safety_6803 - Reddit — r/whoop  (partial fit)
https://www.reddit.com/r/whoop/comments/1rj4smy/comment/o8bhsno/

> Flip it. Work out based mostly on how you feel, focus on trying to control/improve your recovery vs letting your recovery control you.

- **Plan source:** self-directed
- **Modulation today:** Advocates training primarily by feel and treating recovery as an input you actively manage, not a score that dictates the session.
- **Pains:** Rejects the premise of letting a readiness score govern training decisions
- **Tools:** Whoop (score deliberately demoted)
- **Willingness:** Philosophical disconfirmation aimed straight at the thesis: 'letting your recovery control you' is named as the failure mode — i.e. a readiness-driven session verdict is the thing to avoid, not adopt.

### treadmill-trash - Reddit r/HybridAthlete  (strong fit)
https://www.reddit.com/r/HybridAthlete/comments/1oe3njx/hybrid_athletes_whats_the_hardest_part_of/

> Preventing overuse. I'm incredibly injury prone and it sometimes feels like I'm managing injuries back to back... I basically just use RPE/soreness at this point. Sometimes my HRV will be normal and I'll feel ready for death, so I don't really use it anymore. [Tools:] Garmin or Strava

- **Plan source:** self-coached hybrid (rucking + running + upper/lower lifting)
- **Modulation today:** Abandoned HRV-based readiness because the score didn't match his felt state; now modulates purely on RPE and soreness to manage chronic injury risk.
- **Pains:** Back-to-back overuse injuries; injury-prone and managing it manually; HRV readiness was misleading ('normal' while feeling destroyed) so he dropped it
- **Tools:** Garmin, Strava, RPE / soreness self-assessment
- **Willingness:** DISCONFIRMING on wearable readiness specifically — churned off HRV guidance to bodily feel; the exact injury-prevention job Tuwa targets is felt acutely, but his trust in algorithmic readiness is already burned.

### alexfthenakis (thread: Cancelling TrainingPeaks Premium - what will I lose?) - TrainerRoad community forum  (partial fit)
https://www.trainerroad.com/forum/t/cancelling-trainingpeaks-premium-what-will-i-lose/100722

> thinking maybe it's time to quit paying for TrainingPeaks which I pretty much only use as an analysis/monitoring tool... I don't rely on TP for any single feature, but I do keep an eye on CTL/TSB... One of the biggest reasons I've kept TP is as an archive of all my data.

- **Plan source:** self-coached endurance (uses TrainerRoad for structure, TP only to monitor)
- **Modulation today:** Watches CTL/TSB (fitness/fatigue) as a passive monitor but the paid tool does not drive decisions; considering downgrading to free intervals.icu since TP is just an analysis/archive layer.
- **Pains:** Paying for a tool reduced to passive analysis/archive; Justifying overlapping subscriptions (TP vs TrainerRoad vs Zwift)
- **Tools:** TrainingPeaks Premium (cancelling), TrainerRoad, intervals.icu (free, considered as replacement), Garmin
- **Willingness:** Active churn from a paid plan-monitoring tool because it does not make decisions for him — and a free substitute (intervals.icu) is named as the replacement. Confirms 'TrainingPeaks = your plan, no decisions' resentment and the free-tool substitution threat.

### Anna C (thread: Returning my Whoop band... Change my mind) - StrongFirst community forum  (partial fit)
https://www.strongfirst.com/community/threads/returning-my-whoop-band-change-my-mind.23898/

> It's interesting, but I really don't find it very useful... my HRV readings just don't seem very useful with the Whoop.

- **Plan source:** self-coached strength/conditioning (StrongFirst kettlebell community)
- **Modulation today:** Trialed Whoop to inform training/recovery decisions within the 30-day return window, concluded the recovery/HRV output did not change what she does, and returned the device.
- **Pains:** Recovery/HRV score is interesting but not actionable enough to keep; Activity tracking (e.g., kettlebell swings) under-reads, noted by other repliers
- **Tools:** Whoop (returned)
- **Willingness:** Refuses the recurring fee — 'a score I don't act on' rejection. Reinforces the Whoop/Bevel 'scores without your plan' anti-positioning from the buyer's side.

### OkRoll3169 (thread: debating cancelling whoop membership) - Reddit r/whoop  (weak fit)
https://www.reddit.com/r/whoop/comments/1q2nat0/debating_cancelling_whoop_membership/

> I kept mine because I actually changed my habits based on data - slept earlier, took rest days when WHOOP said to. But I know that's not everyone's experience.

- **Plan source:** unclear (general trainee, no stated structured program)
- **Modulation today:** Acts on the readiness score — sleeps earlier and takes rest days 'when WHOOP said to'; a rare payer-who-actually-modulates, and self-aware that most users don't.
- **Pains:** Implicitly: the tool only pays off if you act on it; most around him don't
- **Tools:** Whoop (retained)
- **Willingness:** POSITIVE / confirming counter-case: keeps paying precisely because the recovery data changes his behavior (rest-day modulation). But he frames himself as the exception, underscoring that pay-retention hinges on the score driving real plan changes — exactly Tuwa's wedge, and exactly where Whoop alone is thin.
