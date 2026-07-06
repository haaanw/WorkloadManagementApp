# Tuwa

Plan-aware decision support for self-coached athletes: the athlete authors the training program; Tuwa fuses it with physiology and issues daily verdicts. Beachhead niche: amateur competitive basketball players who also strength-train.

## Language

**Beachhead athlete**:
The launch target user — an amateur competitive basketball player who also strength-trains seriously and self-manages conditioning/rehab, without professional support staff.
_Avoid_: Hybrid athlete (market term meaning endurance+strength, e.g. Hyrox/run+lift — a different body and community)

**Sport-skill-primary athlete**:
An athlete whose identity sport is a skill sport (basketball, climbing, martial arts); strength, conditioning, and rehab exist to serve it. The generalization of the beachhead athlete that the engine must support long-term.

**Verdict**:
The daily go/modify/hold decision for today's planned session, with an adjusted number and a one-line reason. Suggest-and-confirm — the athlete always decides.
_Avoid_: Recommendation, prescription, gate

**Strike zone**:
The optimal training-intensity band for today, which moves daily with the athlete's state. The verdict nudges today's planned session into it.

**Carry**:
Directional cross-modal fatigue carry-over — how a session in one modality loads specific muscle regions for later sessions (last night's game hits today's squat, spares bench).
_Avoid_: Interference (research term, not user-facing)

**Match**:
An organized in-season game on a league schedule — the highest-stakes session in the athlete's life; the thing the verdict protects. Top of the match tier.
_Avoid_: Game (as a domain term; UI copy may still say "game")

**Scrimmage**:
A regulated practice game (e.g. playoff-season scrimmages) — more serious than a pickup, less than a match. Treated as conditioning-plus-big-workout: a fatigue input, not a protection target. Middle of the match tier.

**Pickup**:
Casual recurring play (e.g. Friday-night runs). A fatigue input like any training session; never something the plan tapers for. Bottom of the match tier.

**Match tier**:
The seriousness ladder pickup → scrimmage → match. Tier decides *protection* (does the verdict taper toward it), not fatigue accounting — all three produce carry. Protection is binary: only a scheduled match triggers proximity. A scrimmage that deserves protection is *promoted* — the athlete schedules it as a match; the app never weighs tiers.

**Microdose**:
The match-proximity trim shape: the athlete's own planned session reduced to 1–2 capped top sets, no back-offs (~20 min). The verdict's "modify" framing near a match — never an app-initiated session.
_Avoid_: Primer (intraday timing concept, out of scope), mini-session

**Match proximity**:
How close the next *scheduled match* is. When near, the verdict tightens to protect match freshness; scrimmages and pickups do not trigger proximity. With no scheduled match, the verdict is backward-only.
