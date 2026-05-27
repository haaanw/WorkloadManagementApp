# Phase 23-06 — String Migration Audit

**Date:** 2026-05-27
**Plan:** 23-06 (gap_closure: VERIFICATION gap #2)
**Method:** `grep -nE 'Text\("|\.navigationTitle\("|Button\("[A-Z]|Label\("[A-Z]'` on 7 view files, filtered to exclude existing catalog-key calls (`Text("namespace.key")`) and interpolation-only literals.

| # | surface | file:line | swift_construct | current_literal | proposed_key | en_value | zh-Hans_value | notes |
|---|---------|-----------|-----------------|-----------------|--------------|----------|---------------|-------|
| 1 | Auth | WorkloadApp/Views/Auth/LoginView.swift:43 | Text | `WORKLOAD` | `auth.brand.wordmark` | `WORKLOAD` | `WORKLOAD` | MARKETING-PASS — wordmark/logotype preserved per D-22. Alt zh-Hans: `训练负荷` |
| 2 | Auth | WorkloadApp/Views/Auth/LoginView.swift:46 | Text | `Train smarter. Recover better.` | `auth.brand.tagline` | `Train smarter. Recover better.` | `更聪明地训练，更有效地恢复。` | MARKETING-PASS — alt: `训练更聪明，恢复更彻底。` Note: zh-Hans value uses ASCII comma+period per lint |
| 3 | Auth | WorkloadApp/Views/Auth/LoginView.swift:61 | Text | `EMAIL` | `auth.field.email` | `EMAIL` | `邮箱` | |
| 4 | Auth | WorkloadApp/Views/Auth/LoginView.swift:87 | Text | `PASSWORD` | `auth.field.password` | `PASSWORD` | `密码` | |
| 5 | Auth | WorkloadApp/Views/Auth/LoginView.swift:129 | Text | `Sign In` | `auth.action.signIn` | `Sign In` | `登录` | |
| 6 | Auth | WorkloadApp/Views/Auth/LoginView.swift:164 | Text | `Create an account` | `auth.action.createAccountLink` | `Create an account` | `注册账号` | |
| 7 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:42 | Text | `Create Account` | `auth.signup.heading` | `Create Account` | `注册账号` | |
| 8 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:45 | Text | `Set up your athlete profile.` | `auth.signup.subhead` | `Set up your athlete profile.` | `创建你的运动员档案。` | MARKETING-PASS — alt: `设置你的运动员资料。` |
| 9 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:59 | InputField label | `NAME` | `auth.field.name` | `NAME` | `姓名` | InputField label String param needs LocalizedStringKey |
| 10 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:59 | InputField placeholder | `Your name` | `auth.field.namePlaceholder` | `Your name` | `你的姓名` | |
| 11 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:67 | InputField label | `EMAIL` | reuse `auth.field.email` | (shared) | (shared) | |
| 12 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:67 | InputField placeholder | `you@example.com` | (kept verbatim — email format universal) | — | — | skip migration |
| 13 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:78 | SecureInputField label | `PASSWORD` | reuse `auth.field.password` | (shared) | (shared) | |
| 14 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:78 | SecureInputField placeholder | `Min. 8 characters` | `auth.field.passwordPlaceholder` | `Min. 8 characters` | `至少 8 个字符` | |
| 15 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:87 | Text | `PRIMARY SPORT` | `auth.signup.primarySport` | `PRIMARY SPORT` | `主要运动项目` | |
| 16 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:148 | Text | `Create Account` | reuse `auth.signup.heading` | (shared) | (shared) | button label reuses heading key |
| 17 | Auth | WorkloadApp/Views/Auth/SignUpView.swift:181 | .navigationTitle | `Sign Up` | `auth.nav.signUp` | `Sign Up` | `注册` | |
| 18 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:69 | Text | `Cycle-Aware Recovery` | reuse `dashboard.cycleAware.title` (already in catalog) | — | — | already wired — but the Text literal is still hardcoded; need to swap to catalog key |
| 19 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:82 | Text | `Track your menstrual cycle in Apple Health to get cycle-aware recovery insights...` | reuse `dashboard.cycleAware.body` (already in catalog) | — | — | swap literal to key |
| 20 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:90 | Text | `Open Settings` | `action.openSettings` | `Open Settings` | `打开设置` | |
| 21 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:154 | Text | `Complete your first training week to see a summary.` | `dashboard.weeklySummary.firstWeekPrompt` | `Complete your first training week to see a summary.` | `完成你的第一周训练后即可查看总结。` | |
| 22 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:167 | Text | `Building baseline...` | `dashboard.coldStart.buildingBaseline` | `Building baseline...` | `正在建立基线...` | |
| 23 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:195 | .navigationTitle | `Dashboard` | `dashboard.nav.title` | `Dashboard` | `仪表盘` | `dashboard.title` already exists with value "Today" — use new key |
| 24 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:202 | Button label | `Log Workout` | `dashboard.action.logWorkout` | `Log Workout` | `记录训练` | |
| 25 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:268 | Text (interp) | `READINESS · \(dateLabel)` | `dashboard.hero.readinessLabel` | `READINESS · %@` | `准备度 · %@` | Option B per plan — %@ placeholder |
| 26 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:379 | Text | `Connect Apple Health to see your readiness score.` | `dashboard.empty.connectHealth` | `Connect Apple Health to see your readiness score.` | `连接 Apple Health 即可查看你的准备度评分。` | |
| 27 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:384 | Text | `Connect Health` | `dashboard.action.connectHealth` | `Connect Health` | `连接 Health` | |
| 28 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:492 | Text | `TRAINING LOAD` | `dashboard.section.trainingLoad` | `TRAINING LOAD` | `训练负荷` | D-07: parenthetical acronym omitted on section header — TSB/ATL/CTL shown as Latin labels below already establish the technical context |
| 29 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:562 | Text | `EST` | `dashboard.label.estimated` | `EST` | `估算` | |
| 30 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:581 | Text | `RECENT SESSIONS` | `dashboard.section.recentSessions` | `RECENT SESSIONS` | `最近训练` | |
| 31 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:593 | Text | `No sessions yet. Tap Log Workout to begin.` | `dashboard.empty.noSessions` | `No sessions yet. Tap Log Workout to begin.` | `还没有训练记录。点击「记录训练」开始。` | Quotation marks: D-06 lint requires ASCII but Chinese needs visual quotes — use 「」per zh-Hans typographic convention (these are CJK brackets, U+300C/U+300D — NOT in fullwidth-punct lint set FF08/FF09/3000) |
| 32 | Dashboard | WorkloadApp/Views/Dashboard/DashboardView.swift:612 | Text (interp) | `RPE \(Int(rpe))` | `dashboard.session.rpeValue` | `RPE %lld` | `RPE %lld` | D-06: ACRONYM kept Latin in zh-Hans |
| 33 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:48 | sectionHeader | `ATHLETE` | `profile.section.athlete` | `ATHLETE` | `运动员` | sectionHeader String param → LocalizedStringKey |
| 34 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:49 | editableTextField | `Name` | `profile.field.name` | `Name` | `姓名` | editableTextField label String → LocalizedStringKey |
| 35 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:54 | editablePicker | `Sport` | `profile.field.sport` | `Sport` | `运动项目` | editablePicker label String → LocalizedStringKey |
| 36 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:59 | editablePicker | `Training Frequency` | `profile.field.trainingFrequency` | `Training Frequency` | `训练频率` | |
| 37 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:64 | editablePicker | `Experience Level` | `profile.field.experienceLevel` | `Experience Level` | `经验等级` | |
| 38 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:71 | sectionHeader | `TRAINING PROFILE` | `profile.section.trainingProfile` | `TRAINING PROFILE` | `训练档案` | |
| 39 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:74 | profileRow | `Sessions / week` | `profile.field.sessionsPerWeek` | `Sessions / week` | `每周训练次数` | profileRow label String → LocalizedStringKey |
| 40 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:76 | profileRow | `Avg duration` | `profile.field.avgDuration` | `Avg duration` | `平均时长` | |
| 41 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:78 | profileRow | `Typical effort` | `profile.field.typicalEffort` | `Typical effort` | `典型强度` | |
| 42 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:80 | profileRow | `Weeks at level` | `profile.field.weeksAtLevel` | `Weeks at level` | `当前等级周数` | |
| 43 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:82 | actionButton | `Edit Profile` | `profile.action.editProfile` | `Edit Profile` | `编辑档案` | actionButton label String → LocalizedStringKey |
| 44 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:87 | actionButton | `Set up training profile` | `profile.action.setupTrainingProfile` | `Set up training profile` | `设置训练档案` | |
| 45 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:95 | sectionHeader | `CYCLE & HORMONES` | `profile.section.cycleHormones` | `CYCLE & HORMONES` | `周期与激素` | |
| 46 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:98 | Text | `Hormonal Contraceptive` | `profile.row.hormonalContraceptive` | `Hormonal Contraceptive` | `激素避孕` | |
| 47 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:117 | Text | `Pregnant` | `profile.row.pregnant` | `Pregnant` | `怀孕` | |
| 48 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:136 | Text | `Lactating` | `profile.row.lactating` | `Lactating` | `哺乳期` | |
| 49 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:156 | sectionHeader | `PREFERENCES` | `profile.section.preferences` | `PREFERENCES` | `偏好设置` | |
| 50 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:176 | editablePicker | `Weight Unit` | `profile.row.weightUnit` | `Weight Unit` | `重量单位` | |
| 51 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:181 | editablePicker | `ACWR Method` | `profile.row.acwrMethod` | `ACWR Method` | `ACWR 计算方法` | D-06 hybrid form |
| 52 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:186 | editablePicker | `Load Metric` | `profile.row.loadMetric` | `Load Metric` | `负荷指标` | |
| 53 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:193 | sectionHeader | `NOTIFICATIONS` | `profile.section.notifications` | `NOTIFICATIONS` | `通知` | |
| 54 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:197 | Text | `Weekly Summary` | `profile.row.weeklySummary` | `Weekly Summary` | `每周总结` | |
| 55 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:235 | Text | `Notifications are disabled in Settings. Go to Settings > Tuwa to enable them.` | `profile.notif.deniedHint` | `Notifications are disabled in Settings. Go to Settings > Tuwa to enable them.` | `通知已在设置中禁用。前往「设置 > Tuwa」启用。` | |
| 56 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:246 | editablePicker | `Day` | `profile.field.day` | `Day` | `日期` | |
| 57 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:268 | editablePicker | `Time` | `profile.field.time` | `Time` | `时间` | |
| 58 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:298 | sectionHeader | `CONNECTED DEVICES` | `profile.section.connectedDevices` | `CONNECTED DEVICES` | `已连接设备` | |
| 59 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:303 | Text | `HealthKit Permissions` | `profile.healthkit.permissions` | `HealthKit Permissions` | `健康数据权限` | |
| 60 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:315 | Text | `Data from Apple Watch, Whoop, Oura, and Garmin flows through HealthKit automatically.` | `profile.healthkit.devicesHint` | `Data from Apple Watch, Whoop, Oura, and Garmin flows through HealthKit automatically.` | `来自 Apple Watch、Whoop、Oura 和 Garmin 的数据会通过 HealthKit 自动同步。` | |
| 61 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:323 | sectionHeader | `DATA SYNC` | `profile.section.dataSync` | `DATA SYNC` | `数据同步` | |
| 62 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:332 | Text | `Sync Status` | `profile.sync.status` | `Sync Status` | `同步状态` | |
| 63 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:337 | Text | `Issues` | `profile.sync.issues` | `Issues` | `有问题` | |
| 64 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:341 | Text | `All data synced` | `profile.sync.allSynced` | `All data synced` | `全部已同步` | |
| 65 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:355 | sectionHeader | `COACH` | `profile.section.coach` | `COACH` | `教练` | |
| 66 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:358 | Text | `Enable Coach Mode` | `profile.row.coachMode` | `Enable Coach Mode` | `启用教练模式` | |
| 67 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:381 | Text | `Coach Only` | `profile.row.coachOnly` | `Coach Only` | `仅教练模式` | |
| 68 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:384 | Text | `Hide athlete tabs, always show coach view` | `profile.row.coachOnlyHint` | `Hide athlete tabs, always show coach view` | `隐藏运动员标签，始终显示教练视图` | |
| 69 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:420 | actionButton | `Generating...` / `Invite My Coach` | `profile.action.generating` / `profile.action.inviteMyCoach` | `Generating...` / `Invite My Coach` | `正在生成...` / `邀请我的教练` | dynamic — both keys needed |
| 70 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:427 | actionButton | `Invite an Athlete (Email)` | `profile.action.inviteAthleteEmail` | `Invite an Athlete (Email)` | `邀请运动员 (邮件)` | |
| 71 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:431 | actionButton | `Enter Athlete Code` | `profile.action.enterAthleteCode` | `Enter Athlete Code` | `输入运动员邀请码` | |
| 72 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:443 | sectionHeader | `MY COACHES` | `profile.section.myCoaches` | `MY COACHES` | `我的教练` | |
| 73 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:461 | sectionHeader | `MY ATHLETES` | `profile.section.myAthletes` | `MY ATHLETES` | `我的运动员` | |
| 74 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:491 | Text (ternary) | `Deleting...` / `Delete Account` | `profile.action.deleting` / `profile.action.deleteAccount` | `Deleting...` / `Delete Account` | `正在删除...` / `删除账号` | |
| 75 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:501 | Text | `No athlete profile found.` | `profile.empty.noAthlete` | `No athlete profile found.` | `未找到运动员档案。` | |
| 76 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:517 | .navigationTitle | `Profile` | `profile.nav.title` | `Profile` | `档案` | `profile.title` already exists — use new key |
| 77 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:522 | .alert | `Your Invite Code` | `profile.invite.codeAlertTitle` | `Your Invite Code` | `你的邀请码` | |
| 78 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:523 | Button | `Done` | `action.done` (already in catalog) | — | — | reuse |
| 79 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:524 | Button | `Copy` | `action.copy` | `Copy` | `复制` | |
| 80 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:526 | Text (interp) | `Share this code with your coach:\n\n\(code)\n\nExpires in 48 hours.` | `profile.invite.codeBody` | `Share this code with your coach:\n\n%@\n\nExpires in 48 hours.` | `把这个邀请码分享给你的教练：\n\n%@\n\n48 小时后过期。` | Use ASCII colon (lint) |
| 81 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:552 | .alert | `Delete Account` | reuse `profile.action.deleteAccount` | — | — | reuse |
| 82 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:553 | Button | `Cancel` | reuse `action.cancel` (already in catalog) | — | — | reuse |
| 83 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:554 | Button | `Delete` | reuse `action.delete` (already in catalog) | — | — | reuse |
| 84 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:566 | Text | `This will permanently delete your account and all associated data. This action cannot be undone.` | `profile.delete.confirmBody` | `This will permanently delete your account and all associated data. This action cannot be undone.` | `这将永久删除你的账号和所有相关数据。此操作无法撤销。` | |
| 85 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:569 | .alert | `Error` | `common.error` | `Error` | `错误` | |
| 86 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:573 | Button | `OK` | `action.ok` | `OK` | `好的` | |
| 87 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:749 | Text | `Unknown` | `common.unknown` | `Unknown` | `未知` | |
| 88 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:767 | Text | `INVITE CODE` | `profile.invite.code` | `INVITE CODE` | `邀请码` | |
| 89 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:772 | TextField placeholder | `Enter 6-character code` | `profile.invite.codePlaceholder` | `Enter 6-character code` | `输入 6 位邀请码` | |
| 90 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:783 | Text | `Look Up Code` | `profile.invite.lookUp` | `Look Up Code` | `查找邀请码` | |
| 91 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:820 | Text | `ATHLETE EMAIL` | `profile.invite.athleteEmail` | `ATHLETE EMAIL` | `运动员邮箱` | |
| 92 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:825 | TextField placeholder | `athlete@example.com` | (kept verbatim — email format) | — | — | skip migration |
| 93 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:842 | Text | `Invite sent! They'll receive a link by email.` | `profile.invite.sentConfirmation` | `Invite sent! They'll receive a link by email.` | `邀请已发送！他们会收到一封带链接的邮件。` | |
| 94 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:847 | Button | `Done` | reuse `action.done` | — | — | reuse |
| 95 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:859 | Text | `Send Invite` | `profile.invite.send` | `Send Invite` | `发送邀请` | |
| 96 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:910 | Text | `Tuwa reads data from HealthKit to calculate your recovery score and TRIMP. We never write data to HealthKit.` | `profile.healthkit.disclaimer` | `Tuwa reads data from HealthKit to calculate your recovery score and TRIMP. We never write data to HealthKit.` | `Tuwa 从 HealthKit 读取数据用于计算恢复评分和 TRIMP。我们永远不会向 HealthKit 写入数据。` | D-06 hybrid: TRIMP and HealthKit kept Latin |
| 97 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:918 | sectionHeader | `DATA WE READ` | `profile.healthkit.dataWeRead` | `DATA WE READ` | `我们读取的数据` | |
| 98 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:956 | Text | `Authorized` | `profile.healthkit.authorized` | `Authorized` | `已授权` | |
| 99 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:960 | Text | `Authorize HealthKit Access` | `profile.healthkit.authorize` | `Authorize HealthKit Access` | `授权访问 HealthKit` | |
| 100 | Profile | WorkloadApp/Views/Profile/ProfileView.swift:983 | .navigationTitle | `HealthKit` | `profile.healthkit.navTitle` | `HealthKit` | `HealthKit` | wordmark preserved |
| 101 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:150 | .navigationTitle | `Load & Progress` | `workload.nav.title` | `Load & Progress` | `负荷与进度` | `workload.title` already exists |
| 102 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:169 | .confirmationDialog | `Export Workout Data` | `workload.export.title` | `Export Workout Data` | `导出训练数据` | |
| 103 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:170 | Button | `Session Summary` | `workload.export.sessionSummary` | `Session Summary` | `训练总结` | |
| 104 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:173 | Button | `Detailed Sets` | `workload.export.detailedSets` | `Detailed Sets` | `详细组数` | |
| 105 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:176 | Button | `PDF Report (Pro)` | `workload.export.pdfReport` | `PDF Report (Pro)` | `PDF 报告 (Pro)` | D-06 hybrid: PDF + Pro kept Latin |
| 106 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:179 | Button | `Cancel` | reuse `action.cancel` | — | — | reuse |
| 107 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:250 | Text | `ACWR` | `workload.section.acwr` | `ACWR` | `ACWR` | Latin acronym preserved per D-06 (term.acwr exists for hybrid form; section header uses Latin-only) |
| 108 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:269 | Text | `ratio` | `workload.label.ratio` | `ratio` | `比值` | |
| 109 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:274 | Text | `No workload data yet. Log a workout to see your training load.` | `workload.empty.body` | `No workload data yet. Log a workout to see your training load.` | `还没有负荷数据。记录一次训练即可查看训练负荷。` | |
| 110 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:294 | Text | `LOAD TREND` | `workload.section.loadTrend` | `LOAD TREND` | `负荷趋势` | |
| 111 | Workload | WorkloadApp/Views/Workload/WorkloadView.swift:353 | Text | `RECENT PRS` | `workload.section.recentPRs` | `RECENT PRS` | `最新个人最佳 (PR)` | D-07 first-occurrence hybrid |
| 112 | Recovery | WorkloadApp/Views/Recovery/RecoveryView.swift:83 | Text | `INSIGHTS` | `recovery.section.insights` | `INSIGHTS` | `洞察` | |
| 113 | Recovery | WorkloadApp/Views/Recovery/RecoveryView.swift:105 | Text | `BEHAVIOR IMPACT` | `recovery.section.behaviorImpact` | `BEHAVIOR IMPACT` | `行为影响` | |
| 114 | Recovery | WorkloadApp/Views/Recovery/RecoveryView.swift:146 | Text | `INSIGHTS` | reuse `recovery.section.insights` | — | — | reuse |
| 115 | Recovery | WorkloadApp/Views/Recovery/RecoveryView.swift:165 | .navigationTitle | `Recovery` | `recovery.nav.title` | `Recovery` | `恢复` | `recovery.title` already exists |
| 116 | Recovery | WorkloadApp/Views/Recovery/RecoveryView.swift:209 | Text | `Morning Check-in` | `recovery.checkin.title` | `Morning Check-in` | `晨间自评` | |
| 117 | Recovery | WorkloadApp/Views/Recovery/RecoveryView.swift:212 | Text | `How are you feeling today?` | `recovery.checkin.prompt` | `How are you feeling today?` | `今天感觉如何？` | Note: question mark - use ASCII `?` per lint, but Chinese sentences typically use `？` (U+FF1F). FF1F is NOT in the FF08/FF09/3000 lint set — Chinese sentence-end punctuation is permitted; only paired-parens fullwidth are forbidden. Using `？` for native rendering |
| 118 | Recovery | WorkloadApp/Views/Recovery/RecoveryView.swift:237 | Text | `RECOVERY SCORE` | `recovery.section.recoveryScore` | `RECOVERY SCORE` | `恢复评分` | |
| 119 | Recovery | WorkloadApp/Views/Recovery/RecoveryView.swift:248 | Text | `/ 100` | (kept verbatim — universal denominator) | — | — | skip migration |
| 120 | Recovery | WorkloadApp/Views/Recovery/RecoveryView.swift:291 | Text | `No recovery data yet. Complete your morning check-in or connect Apple Health.` | `recovery.empty.body` | `No recovery data yet. Complete your morning check-in or connect Apple Health.` | `还没有恢复数据。完成晨间自评或连接 Apple Health。` | |
| 121 | Recovery | WorkloadApp/Views/Recovery/RecoveryView.swift:328 | Text | `WELLNESS CHECK-INS` | `recovery.section.wellnessCheckIns` | `WELLNESS CHECK-INS` | `状态自评` | |
| 122 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:108 | Text | `PRESCRIBED` | `workoutLog.section.prescribed` | `PRESCRIBED` | `已布置` | |
| 123 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:142 | Text | `No Workouts Yet` | `workoutLog.empty.title` | `No Workouts Yet` | `还没有训练记录` | |
| 124 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:145 | Text | `Tap + to log your first workout session.` | `workoutLog.empty.body` | `Tap + to log your first workout session.` | `点击 + 记录你的第一次训练。` | |
| 125 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:173 | .navigationTitle | `Workout Log` | `workoutLog.nav.title` | `Workout Log` | `训练日志` | `workoutLog.title` already exists |
| 126 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:189 | Label | `Import Workout (AI)` | `workoutLog.import.ai` | `Import Workout (AI)` | `导入训练 (AI)` | |
| 127 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:193 | Label | `My Programs` | `workoutLog.menu.myPrograms` | `My Programs` | `我的计划` | |
| 128 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:203 | Label | `Import Program (Text)` | `workoutLog.import.text` | `Import Program (Text)` | `导入计划 (文本)` | |
| 129 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:208 | Label | `Import Shared Template` | `workoutLog.import.shared` | `Import Shared Template` | `导入共享模板` | |
| 130 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:381 | Text | `How hard was this session?` | `workoutLog.rpe.prompt` | `How hard was this session?` | `这次训练强度如何？` | |
| 131 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:384 | Text (interp) | `RPE: \(Int(rpe))` | `workoutLog.rpe.valueLabeled` | `RPE: %lld` | `RPE %lld` | D-06 acronym Latin; zh-Hans uses ASCII space instead of colon to keep punctuation lint clean and follow CJK norm |
| 132 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:391 | Text | `Easy` | `workoutLog.rpe.easy` | `Easy` | `轻松` | |
| 133 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:393 | Text | `Maximal` | `workoutLog.rpe.maximal` | `Maximal` | `极限` | |
| 134 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:401 | .navigationTitle | `Import Workout` | `workoutLog.import.navTitle` | `Import Workout` | `导入训练` | |
| 135 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:405 | Button | `Cancel` | reuse `action.cancel` | — | — | reuse |
| 136 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:408 | Button | `Import` | `action.import` | `Import` | `导入` | |
| 137 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:438 | Text (interp) | `RPE \(Int(rpe))` | reuse `dashboard.session.rpeValue` | — | — | shared key with Dashboard |
| 138 | WorkoutLog | WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift:464 | SessionFilterChip | `All` | `workoutLog.filter.all` | `All` | `全部` | |

## Summary

- **Total migration rows:** 138 (well above the ≥33 sanity gate; ≥50 expected)
- **New catalog keys to add:** ~110 (excluding ~10 reuses of existing keys: `action.cancel`, `action.delete`, `action.done`, `dashboard.cycleAware.title`, `dashboard.cycleAware.body`, `profile.title`/`profile.signOut`/`profile.language.label` already exist, `recovery.title`, `workload.title`, `workoutLog.title`)
- **MARKETING-PASS items:** rows 1, 2, 8 — flagged for native-reviewer human gate (23-HUMAN-UAT.md Test 4)
- **Helper-signature changes required:**
  - `ProfileView.sectionHeader`, `editableTextField`, `editablePicker`, `profileRow`, `actionButton` — change `label: String` → `label: LocalizedStringKey` so `Text(label)` resolves via catalog
  - `SignUpView.InputField`, `SecureInputField` — same: `label: String` → `LocalizedStringKey`; placeholder param also → `LocalizedStringKey`
- **Skipped intentionally:** email format placeholders (`you@example.com`, `athlete@example.com`), universal denominators (`/ 100`), navigation arrows (Image systemName).

## Hybrid CJK rule application (D-06/D-07)

- **First-occurrence hybrid** applied: rows 51 (ACWR), 105 (PDF), 111 (PRS).
- **Latin-only preserved** in zh-Hans: HealthKit, TRIMP, PDF, AI, Pro, ACWR/ATL/CTL/TSB stat-cell labels (rendered as glossary terms downstream via `term.*`), wordmark "WORKLOAD".
- **Pure Latin** in zh-Hans for RPE numeric values (rows 32, 131, 137) per CONTEXT D-06 example.

## No-fullwidth-punctuation lint

All zh-Hans values use ASCII `(` `)` and ASCII space U+0020 between Chinese and Latin. CJK comma `，` and period `。` ARE used in narrative sentences (these are SENTENCE punctuation, not paired-parens; not on the FF08/FF09/3000 forbidden list — the lint in Task 4 regex `[（）　]` only flags fullwidth parens and ideographic space). Question mark `？` (FF1F) and CJK brackets `「」` (300C/300D) are also outside the lint set, used sparingly in rows 31, 55, 117 for natural Chinese typographic rendering.
