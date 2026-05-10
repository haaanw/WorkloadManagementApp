# Privacy Policy — Tuwa

**Last updated:** March 27, 2026

Tuwa ("the app") is developed by Hanwen Ma. This policy explains what data the app collects, how it is used, and your rights.

## What Data We Collect

### Data you provide
- **Account information:** Email address and display name (used for authentication and coach-athlete pairing)
- **Workout logs:** Exercises, sets, reps, weights, RPE, session duration, and notes you enter
- **Wellness check-ins:** Self-reported sleep quality, soreness, energy, and stress ratings

### Data from HealthKit (read-only)
- Heart rate variability (HRV)
- Resting heart rate
- Sleep duration
- Body temperature
- VO2 Max
- Workout heart rate

Tuwa **never writes** data to HealthKit. HealthKit access is optional and requires your explicit permission.

### Data we compute
- Recovery scores, ACWR (Acute:Chronic Workload Ratio), training stress, and personal records are calculated on your device from the data above.

## How Data Is Stored

- **On your device:** All data is stored locally using SwiftData. The app works fully offline.
- **In the cloud:** Composite scores (recovery score, workload snapshots, wellness ratings, workout session headers, and personal records) sync to Supabase (hosted on AWS) for coach-athlete features and multi-device access.
- **Raw HealthKit data is never uploaded.** Only computed scores derived from HealthKit data are synced.

## Coach-Athlete Data Sharing

If you link with a coach, they can view:
- Your recovery scores and ACWR trends
- Workout session summaries
- Personal records
- Wellness check-in ratings

Coaches cannot access your raw HealthKit data, and you can unlink from a coach at any time.

## Third-Party Services

- **Supabase** (authentication and cloud sync): [supabase.com/privacy](https://supabase.com/privacy)
- **RevenueCat** (subscription management): [revenuecat.com/privacy](https://www.revenuecat.com/privacy)

We do not use any advertising networks, analytics trackers, or third-party data brokers.

## Data Retention and Deletion

Your data is retained as long as your account exists. To delete all your data:

1. Go to **Profile → Sign Out** in the app
2. Contact us at the email below to request full account and data deletion from our servers

Upon deletion, all your data — including workout logs, scores, and coach relationships — is permanently removed from our servers.

## Your Rights

You have the right to:
- Access the data we store about you
- Request correction of inaccurate data
- Request deletion of your account and all associated data
- Withdraw HealthKit permissions at any time via iOS Settings → Privacy & Security → Health

## Children

Tuwa is not directed at children under 13. We do not knowingly collect data from children.

## Changes to This Policy

We may update this policy from time to time. Changes will be posted to this page with an updated date.

## Contact

For privacy questions or data deletion requests:

**Email:** hanwenma09@gmail.com
