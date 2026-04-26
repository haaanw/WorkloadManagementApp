# App Store Connect Metadata -- Tonus

> Single source of truth for all App Store Connect fields. Copy each section directly into App Store Connect.

---

## App Information

### Title (30 characters max)

**Characters used:** 28 / 30

```
Tonus: Training Load Tracker
```

### Subtitle (30 characters max)

**Characters used:** 27 / 30

```
Recovery, ACWR & Readiness
```

### Primary Category

```
Health & Fitness
```

### Secondary Category

```
Sports
```

---

## Version Information

### Keywords (100 characters max)

**Characters used:** 97 / 100

Comma-separated, no spaces after commas (Apple strips leading spaces):

```
training load,ACWR,recovery score,HRV tracking,workout log,overtraining,readiness,coach athlete
```

### Promotional Text (170 characters max)

**Characters used:** 136 / 170

Promotional text can be updated without a new app review.

```
Recovery + training load in one place. Know your readiness score every morning. Built for athletes and coaches who train with intention.
```

### Description

Copy this:

```
Train smarter. Recover better.

Tonus combines recovery scoring with training load tracking to give you a daily readiness picture and long-term insight into how your body responds to training.

DAILY READINESS SCORE
Your recovery score synthesizes HRV, resting heart rate, and sleep data from Apple Health into a single number. Know at a glance whether to push hard or back off.

TRAINING LOAD MONITORING
Track your Acute:Chronic Workload Ratio (ACWR) using exponentially weighted moving averages. Spot overtraining risk before it becomes an injury.

WORKOUT LOGGING
Log sessions with exercises, sets, reps, and RPE. Personal records detected automatically. Training stress calculated from every session.

AUTOREGULATION
Get evidence-based recommendations that adapt to your current recovery state and recent training load. Not generic advice -- guidance specific to your data.

COACH MODE
Coaches can monitor multiple athletes from a single dashboard. View individual readiness scores, assign workouts, and generate multi-athlete PDF reports.

PDF REPORTS
Export professional training reports with recovery trends, workload charts, and personal records. Share with coaches, physios, or keep for your records.

Built for serious athletes who want to understand their training, not just track it.

Tonus Pro unlocks full workout history, overload suggestions, custom exercises, personal records, and PDF export. Coach subscription adds multi-athlete management and team reporting.

Privacy first: raw HealthKit data never leaves your device. Only composite scores sync to your account.
```

---

## Age Rating

**Rating:** 4+

Complete the age rating questionnaire with all answers set to **"None"** to receive a 4+ rating. The app contains no objectionable content -- health data is the user's own.

---

## Screenshots

### Screenshot Sequence (6 screens)

| # | Screen | Caption | Subcaption |
|---|--------|---------|------------|
| 1 | Dashboard (hero readiness) | Know when to push, when to rest | Daily readiness from HRV, sleep, and training load |
| 2 | Workload charts | Track your training load over time | ACWR and EWMA workload monitoring |
| 3 | Recovery view | Recovery scores from your real data | HRV, resting heart rate, and sleep analysis |
| 4 | Workout log | Log sessions in seconds | Exercises, sets, reps, and RPE |
| 5 | Coach roster | Built for coaches and athletes | Multi-athlete roster with individual dashboards |
| 6 | PDF export | Share professional reports | PDF export for athletes and coaches |

### Required Device Sizes

| Device Class | Resolution | Reference Device |
|--------------|------------|------------------|
| 6.7-inch | 1290 x 2796px | iPhone 15 Pro Max / iPhone 16 Pro Max |
| 6.5-inch | 1284 x 2778px | iPhone 11 Pro Max |

### Screenshot Composition Spec

Each screenshot is a marketing asset composed of a caption area and an app screenshot:

- **Background:** solid `#0B0B0A` (dark mode app background)
- **Device frame:** none (frameless per modern ASO best practice)
- **Caption position:** top 15% of canvas, centered horizontally
- **Caption typography:** DM Sans Medium, 56pt, `#C2BEB7`, centered
- **Subcaption:** DM Sans Regular, 28pt, `#7C7972`, centered, 16pt below caption
- **App screenshot:** centered below caption area, scaled to fit remaining 80% of canvas height, 32pt horizontal padding on each side
- **No decorative elements:** no gradients, no device bezels, no drop shadows

---

## Screenshot Capture Commands

### Step 1: Run screenshot tests on both simulators

```bash
# 6.7-inch (iPhone 15 Pro Max)
xcodebuild test \
  -project "workload management/workload management.xcodeproj" \
  -scheme "ScreenshotTests" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro Max" \
  -resultBundlePath /tmp/screenshots-6.7.xcresult

# 6.5-inch (iPhone 11 Pro Max)
xcodebuild test \
  -project "workload management/workload management.xcodeproj" \
  -scheme "ScreenshotTests" \
  -destination "platform=iOS Simulator,name=iPhone 11 Pro Max" \
  -resultBundlePath /tmp/screenshots-6.5.xcresult
```

### Step 2: Extract screenshots

```bash
xcparse screenshots /tmp/screenshots-6.7.xcresult ~/Desktop/AppStoreScreenshots/6.7
xcparse screenshots /tmp/screenshots-6.5.xcresult ~/Desktop/AppStoreScreenshots/6.5
```

### Step 3: Compose final images

Use the composition spec above to add captions to each raw screenshot. This can be done manually in a design tool or scripted with ImageMagick / a Swift script.

---

## App Store Connect Entry Checklist

Use this checklist when entering metadata in App Store Connect.

**Note:** App Store Connect UI may differ from these exact field locations. Confirm what you see before pasting.

- [ ] **App Information > Name:** paste title ("Tonus: Training Load Tracker")
- [ ] **App Information > Subtitle:** paste subtitle ("Recovery, ACWR & Readiness")
- [ ] **App Information > Primary Category:** select Health & Fitness
- [ ] **App Information > Secondary Category:** select Sports
- [ ] **Version page > Keywords:** paste keyword field (comma-separated, 97 chars)
- [ ] **Version page > Description:** paste full description
- [ ] **Version page > Promotional Text:** paste promotional text
- [ ] **Version page > Screenshots:** upload composed images for 6.7" and 6.5" sizes
- [ ] **Age Rating:** complete questionnaire (all "None" for 4+)
- [ ] **Save** all changes

---

*Generated from: 07-UI-SPEC.md, 07-CONTEXT.md*
*Phase: 07-app-store-metadata, Plan: 03*
