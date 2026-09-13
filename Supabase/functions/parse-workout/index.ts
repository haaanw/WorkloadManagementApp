// Deploy: supabase functions deploy parse-workout
// Or paste into Supabase Dashboard > Edge Functions > New Function
// Required secrets:
//   supabase secrets set OPENAI_API_KEY=sk-...     (plan mode — OpenAI gpt-4o-mini)
//   supabase secrets set DEEPSEEK_API_KEY=sk-...    (log mode — DeepSeek)
// Optional secret:
//   supabase secrets set PARSE_DAILY_LIMIT=40       (per-user daily parse cap; defaults to 40)
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are auto-injected
// into every edge function's runtime environment — nothing to set for those.
// Requires migration 008_parse_quota.sql (llm_parse_usage table + increment_parse_usage RPC).

import { createClient } from "jsr:@supabase/supabase-js@2";

// ─────────────────────────────────────────────────────────────────────────
// CORS
// ─────────────────────────────────────────────────────────────────────────
// Mobile-only endpoint: restrict CORS to prevent unauthorized web usage.
// Mobile apps do not send CORS preflight, so this primarily blocks browser callers.
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://tuwa.app",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

// ─────────────────────────────────────────────────────────────────────────
// Shared enum vocab — plan schema (OpenAI) and log schema (DeepSeek) both
// draw from these. Never fork the lists; add a value here and both modes
// see it.
// ─────────────────────────────────────────────────────────────────────────
const SPORT_TYPES = [
  "lifting",
  "running",
  "cycling",
  "teamSport",
  "crossfit",
  "swimming",
  "custom",
] as const;

const SESSION_TYPES = [
  "strength",
  "skill",
  "cardio",
  "match",
  "recovery",
] as const;

const EXERCISE_CATEGORIES = [
  "compound",
  "isolation",
  "cardio",
  "bodyweight",
  "plyometric",
  "drill",
  "interval",
] as const;

// Coarse region values first (backward compatible), then the Phase 22
// specific-muscle taxonomy.
const MUSCLE_GROUPS = [
  "chest",
  "back",
  "legs",
  "shoulders",
  "arms",
  "core",
  "fullBody",
  "quads",
  "hamstrings",
  "glutes",
  "calves",
  "hipFlexors",
  "psoas",
  "adductors",
  "hipRotators",
  "tibialisAnterior",
  "lats",
  "trapsUpper",
  "trapsMid",
  "trapsLower",
  "rhomboids",
  "erectors",
  "pecsUpper",
  "pecsLower",
  "anteriorDelts",
  "lateralDelts",
  "posteriorDelts",
  "biceps",
  "triceps",
  "forearms",
  "rectusAbdominis",
  "obliques",
  "transverseAbdominis",
] as const;

type SportType = (typeof SPORT_TYPES)[number];
type SessionType = (typeof SESSION_TYPES)[number];
type ExerciseCategory = (typeof EXERCISE_CATEGORIES)[number];
type MuscleGroup = (typeof MUSCLE_GROUPS)[number];

// ─────────────────────────────────────────────────────────────────────────
// Plan mode (OpenAI) — unchanged behavior, byte-for-byte, from the original
// single-mode version of this function. Only the enum arrays now point at
// the shared consts above instead of being hand-duplicated.
// ─────────────────────────────────────────────────────────────────────────
const SYSTEM_PROMPT = `You are a workout parser. Extract ONLY exercises, sets, reps, and weights that are explicitly stated in the text. Do NOT invent or hallucinate any values.

Rules:
- Convert all weights to kilograms. If the weight appears to be in pounds (lbs), multiply by 0.453592 to convert to kg.
- Use null for any field not explicitly mentioned in the text. Never guess reps, weights, or durations.
- Infer sport_type from context if obvious (e.g. "bench press" = lifting, "5k run" = running). Default to "lifting".
- Infer session_type from context if obvious (e.g. "recovery session" = recovery, "speed work" = cardio). Default to "strength".
- Group exercises by day or section headers if present. If no grouping structure exists, use a single group named "Main".
- Mark sets as warmup only if explicitly labeled as warmup in the text.
- exercise_category should reflect the movement type: compound (multi-joint), isolation (single-joint), cardio, bodyweight, plyometric, drill, or interval.
- muscle_group should be the most specific primary muscle targeted when identifiable (e.g. "quads" not just "legs", "lats" not just "back", "biceps" not just "arms", "pecsUpper"/"pecsLower" for chest, "lateralDelts"/"anteriorDelts"/"posteriorDelts" for shoulders). Fall back to the coarse region value (chest, back, legs, shoulders, arms, core, fullBody) only when the specific muscle is ambiguous, or use null if unclear or not applicable.`;

const WORKOUT_SCHEMA = {
  type: "object" as const,
  properties: {
    workout_name: { type: "string" as const },
    sport_type: {
      type: "string" as const,
      enum: [...SPORT_TYPES],
    },
    session_type: {
      type: "string" as const,
      enum: [...SESSION_TYPES],
    },
    groups: {
      type: "array" as const,
      items: {
        type: "object" as const,
        properties: {
          group_name: { type: "string" as const },
          exercises: {
            type: "array" as const,
            items: {
              type: "object" as const,
              properties: {
                exercise_name: { type: "string" as const },
                exercise_category: {
                  type: "string" as const,
                  enum: [...EXERCISE_CATEGORIES],
                },
                muscle_group: {
                  type: ["string", "null"] as const,
                  enum: [...MUSCLE_GROUPS, null],
                },
                sets: {
                  type: "array" as const,
                  items: {
                    type: "object" as const,
                    properties: {
                      target_reps: { type: ["integer", "null"] as const },
                      target_weight_kg: { type: ["number", "null"] as const },
                      target_duration_seconds: {
                        type: ["integer", "null"] as const,
                      },
                      target_rpe: { type: ["number", "null"] as const },
                      is_warmup: { type: "boolean" as const },
                    },
                    required: [
                      "target_reps",
                      "target_weight_kg",
                      "target_duration_seconds",
                      "target_rpe",
                      "is_warmup",
                    ],
                    additionalProperties: false,
                  },
                },
              },
              required: [
                "exercise_name",
                "exercise_category",
                "muscle_group",
                "sets",
              ],
              additionalProperties: false,
            },
          },
        },
        required: ["group_name", "exercises"],
        additionalProperties: false,
      },
    },
  },
  required: ["workout_name", "sport_type", "session_type", "groups"],
  additionalProperties: false,
};

async function handlePlanMode(workout_text: string): Promise<Response> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "OpenAI API key not configured" }),
      { status: 500, headers: JSON_HEADERS }
    );
  }

  const openaiResponse = await fetch(
    "https://api.openai.com/v1/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: workout_text },
        ],
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "parsed_workout",
            schema: WORKOUT_SCHEMA,
            strict: true,
          },
        },
      }),
    }
  );

  if (!openaiResponse.ok) {
    const errorBody = await openaiResponse.text();
    console.error("OpenAI API error:", openaiResponse.status, errorBody);
    return new Response(
      JSON.stringify({ error: "Failed to parse workout" }),
      { status: 502, headers: JSON_HEADERS }
    );
  }

  const data = await openaiResponse.json();
  const content = data.choices?.[0]?.message?.content;

  if (!content) {
    return new Response(
      JSON.stringify({ error: "Failed to parse workout" }),
      { status: 502, headers: JSON_HEADERS }
    );
  }

  const parsed = JSON.parse(content);

  return new Response(JSON.stringify(parsed), { headers: JSON_HEADERS });
}

// ─────────────────────────────────────────────────────────────────────────
// Program mode (OpenAI) — v1.7.3 feature 6, epic 1. The text is a whole
// multi-week training block; the response preserves its week/day structure
// instead of flattening days into groups. Plan mode above stays untouched:
// shipped 1.7.2 clients decode its flat shape, so the structured shape is a
// NEW mode, never a change to the old one. Same enum vocab, same no-invention
// rules, and the schema + the Swift decoder (ParsedProgramResponse in
// WorkoutLLMImportService) must move together (strict: true).
// ─────────────────────────────────────────────────────────────────────────
const PROGRAM_SYSTEM_PROMPT = `You are a training-program parser. The text is an athlete's multi-week training program. Extract ONLY what is explicitly stated. Do NOT invent or hallucinate any values — the program's numbers belong to its author.

Rules:
- Convert all weights to kilograms. If the weight appears to be in pounds (lbs), multiply by 0.453592 to convert to kg.
- Use null for any field not explicitly mentioned in the text. Never guess reps, weights, or durations.
- Infer sport_type and session_type from context if obvious. Default to "lifting" / "strength".
- Preserve the program's week structure: one entry per training week, in order, numbered from 1. If the text has day headers but no week structure, emit a single week 1 holding those days. If it has neither, emit week 1 with a single day titled "Main".
- Each day gets its own entry with a short title taken from the text's own words ("Upper", "Heavy lower", "Day 3 - Full body"). Number days within their week from 1 in order of appearance.
- duration_weeks: the block length in weeks ONLY when the text states or clearly implies it (e.g. it lists 6 distinct weeks, or says "8-week block"); otherwise null.
- phases: ONLY when the text names phase/block bands (e.g. intro, build, peak, deload, accumulation, intensification, taper, test). Use the text's own phase names and 1-based inclusive week ranges. An unnamed program gets an empty array.
- Emit one entry per training week in order, but write out the days ONLY for a week whose content differs from every earlier week. A week that repeats an earlier week EXACTLY (same days, same exercises, same sets, same numbers — "weeks 2-4 same as week 1", "repeat week 1") gets an empty days array and repeat_of_week set to that earlier week's number. Write out the days and set repeat_of_week to null whenever anything at all changes (a different weight, one added set, a different day title). repeat_of_week must always point to an EARLIER week, never to itself and never to a later one.
- Mark sets as warmup only if explicitly labeled as warmup in the text.
- exercise_category should reflect the movement type: compound (multi-joint), isolation (single-joint), cardio, bodyweight, plyometric, drill, or interval.
- muscle_group should be the most specific primary muscle targeted when identifiable. Fall back to the coarse region value only when the specific muscle is ambiguous, or use null.`;

const PROGRAM_EXERCISE_SCHEMA = {
  type: "object" as const,
  properties: {
    exercise_name: { type: "string" as const },
    exercise_category: {
      type: "string" as const,
      enum: [...EXERCISE_CATEGORIES],
    },
    muscle_group: {
      type: ["string", "null"] as const,
      enum: [...MUSCLE_GROUPS, null],
    },
    sets: {
      type: "array" as const,
      items: {
        type: "object" as const,
        properties: {
          target_reps: { type: ["integer", "null"] as const },
          target_weight_kg: { type: ["number", "null"] as const },
          target_duration_seconds: { type: ["integer", "null"] as const },
          target_rpe: { type: ["number", "null"] as const },
          is_warmup: { type: "boolean" as const },
        },
        required: [
          "target_reps",
          "target_weight_kg",
          "target_duration_seconds",
          "target_rpe",
          "is_warmup",
        ],
        additionalProperties: false,
      },
    },
  },
  required: ["exercise_name", "exercise_category", "muscle_group", "sets"],
  additionalProperties: false,
};

const PROGRAM_SCHEMA = {
  type: "object" as const,
  properties: {
    program_name: { type: "string" as const },
    sport_type: {
      type: "string" as const,
      enum: [...SPORT_TYPES],
    },
    session_type: {
      type: "string" as const,
      enum: [...SESSION_TYPES],
    },
    duration_weeks: { type: ["integer", "null"] as const },
    phases: {
      type: "array" as const,
      items: {
        type: "object" as const,
        properties: {
          name: { type: "string" as const },
          start_week: { type: "integer" as const },
          end_week: { type: "integer" as const },
        },
        required: ["name", "start_week", "end_week"],
        additionalProperties: false,
      },
    },
    weeks: {
      type: "array" as const,
      items: {
        type: "object" as const,
        properties: {
          week_number: { type: "integer" as const },
          // Compact output (U13): a week identical to an earlier one carries
          // no days and points at that week's 1-based number instead. The
          // Swift decoder expands it back before anything is built, so the
          // athlete's program is unchanged — only the tokens are saved.
          repeat_of_week: { type: ["integer", "null"] as const },
          days: {
            type: "array" as const,
            items: {
              type: "object" as const,
              properties: {
                day_number: { type: "integer" as const },
                title: { type: "string" as const },
                exercises: {
                  type: "array" as const,
                  items: PROGRAM_EXERCISE_SCHEMA,
                },
              },
              required: ["day_number", "title", "exercises"],
              additionalProperties: false,
            },
          },
        },
        required: ["week_number", "repeat_of_week", "days"],
        additionalProperties: false,
      },
    },
  },
  required: [
    "program_name",
    "sport_type",
    "session_type",
    "duration_weeks",
    "phases",
    "weeks",
  ],
  additionalProperties: false,
};

// Program mode is output-bound, not input-bound: the wait an athlete feels is
// the model writing the weeks out one token at a time (U13). These three
// settings are the lever — the model, the ceiling on what it may write, and a
// low temperature so it writes the program once instead of wandering.
const PROGRAM_MODEL = "gpt-4o-mini";
// A 4-day / 6-exercise / 4-set week costs ~3,600 output tokens. With repeats
// collapsed into repeat_of_week, a typical block emits 2-3 DISTINCT weeks, so
// 8,000 covers it with room to spare while halving the worst-case wait against
// the model's own 16k ceiling. A response that still hits the cap is truncated
// mid-JSON — we say what to do about it instead of failing on JSON.parse.
const PROGRAM_MAX_COMPLETION_TOKENS = 8000;
const PROGRAM_TRUNCATED_MESSAGE =
  "program too long for one read — import a few weeks at a time";

async function handleProgramMode(workout_text: string): Promise<Response> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "OpenAI API key not configured" }),
      { status: 500, headers: JSON_HEADERS }
    );
  }

  // Timing instrumentation. Sizes and durations only — the program text and
  // the parsed program never reach the log.
  const startedAt = performance.now();
  const openaiResponse = await fetch(
    "https://api.openai.com/v1/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: PROGRAM_MODEL,
        temperature: 0.2,
        max_completion_tokens: PROGRAM_MAX_COMPLETION_TOKENS,
        messages: [
          { role: "system", content: PROGRAM_SYSTEM_PROMPT },
          { role: "user", content: workout_text },
        ],
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "parsed_program",
            schema: PROGRAM_SCHEMA,
            strict: true,
          },
        },
      }),
    }
  );
  const elapsedMs = Math.round(performance.now() - startedAt);

  if (!openaiResponse.ok) {
    const errorBody = await openaiResponse.text();
    console.error("OpenAI API error (program):", openaiResponse.status, errorBody);
    console.log(
      `[timing] program model=${PROGRAM_MODEL} input_chars=${workout_text.length} openai_ms=${elapsedMs} http_status=${openaiResponse.status}`
    );
    return new Response(
      JSON.stringify({ error: "Failed to parse program" }),
      { status: 502, headers: JSON_HEADERS }
    );
  }

  const data = await openaiResponse.json();
  const choice = data.choices?.[0];
  const usage = data.usage ?? {};
  console.log(
    `[timing] program model=${PROGRAM_MODEL} input_chars=${workout_text.length}` +
      ` openai_ms=${elapsedMs} prompt_tokens=${usage.prompt_tokens ?? "?"}` +
      ` completion_tokens=${usage.completion_tokens ?? "?"}` +
      ` finish_reason=${choice?.finish_reason ?? "?"}`
  );

  // The cap was hit: the JSON stops mid-object. Tell the athlete what to do
  // rather than letting JSON.parse throw into the generic 502.
  if (choice?.finish_reason === "length") {
    return new Response(
      JSON.stringify({ error: PROGRAM_TRUNCATED_MESSAGE }),
      { status: 422, headers: JSON_HEADERS }
    );
  }

  const content = choice?.message?.content;
  if (!content) {
    return new Response(
      JSON.stringify({ error: "Failed to parse program" }),
      { status: 502, headers: JSON_HEADERS }
    );
  }

  // strict json_schema guarantees the shape, so a parse failure here is a
  // truncated body in practice — same actionable copy, not a 502.
  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch (error) {
    console.error("Program content was not valid JSON:", error);
    return new Response(
      JSON.stringify({ error: PROGRAM_TRUNCATED_MESSAGE }),
      { status: 422, headers: JSON_HEADERS }
    );
  }

  return new Response(JSON.stringify(parsed), { headers: JSON_HEADERS });
}

// ─────────────────────────────────────────────────────────────────────────
// Log mode (DeepSeek) — the text describes work already performed, not a
// plan. DeepSeek's json_object response_format does not enforce a schema
// (see DEEPSEEK_DOCS_NOTES below), so the shape is spelled out in the
// prompt and re-checked server-side by validateLoggedWorkout().
// ─────────────────────────────────────────────────────────────────────────

// DeepSeek docs findings (checked 2026-08-17 against api-docs.deepseek.com):
// - Chat completions endpoint: https://api.deepseek.com/chat/completions
//   (no /v1 segment in the current docs' own curl/SDK examples).
// - Legacy model names `deepseek-chat` / `deepseek-reasoner` were retired
//   2026-07-24; the current models are `deepseek-v4-flash` (cost/latency
//   optimized, the direct successor to deepseek-chat for general use) and
//   `deepseek-v4-pro` (heavier reasoning). This function uses
//   deepseek-v4-flash for extraction.
// - V4 models default to "thinking" mode (reasoning_effort: high). For a
//   deterministic extraction task we don't want the extra latency/cost or
//   a reasoning_content field in the response, so thinking is explicitly
//   disabled via `thinking: { type: "disabled" }`.
// - response_format: { type: "json_object" } is supported, but strict
//   json_schema (OpenAI-style) is NOT documented for DeepSeek as of this
//   check — hence the validator below instead of a schema. The docs
//   require the word "json" to appear in the prompt plus an example of the
//   desired shape, or the model may emit empty/whitespace output.
// - Docs recommend temperature ~0.2 for focused/deterministic output
//   (temperature 0 is not called out as special-cased, so 0.2 is used).

const LOG_SYSTEM_PROMPT = `You are a workout logger. The text describes exercise work the athlete has ALREADY PERFORMED — every number is an actual (what they did), never a target or a goal. Respond with a single JSON object and nothing else — no markdown fences, no commentary outside the JSON.

Rules:
- Convert all weights to kilograms. "lbs" or 磅 → multiply by 0.453592. "kg" or 公斤 is already kilograms.
- Expand shorthand into individual set objects: "3 sets of 8 at 80" becomes three set objects, each with reps 8 and weight_kg 80.
- "same weight" (or 同样重量 / 同重量) inherits the immediately previous set's weight_kg, but ONLY within the same exercise. Moving to a different exercise never inherits a weight — use null there unless a new weight is stated.
- Chinese quantity words: 公斤 = kg, 磅 = lbs, 次 = reps, 组 = sets. RPE may appear in English ("RPE 8") or Chinese ("RPE8", "感觉像9分", "自觉用力度9").
- Extract ONLY what the text states. Use null for any of reps, weight_kg, duration_seconds, or rpe that is not explicitly mentioned. Never guess or infer a number that was not said.
- Bodyweight exercises with no stated added weight get weight_kg null (never 0).
- Mark a set is_warmup true only if the text explicitly calls it a warmup (or 热身组); otherwise false.
- exercise_category is one of: compound (multi-joint), isolation (single-joint), cardio, bodyweight, plyometric, drill, interval.
- muscle_group is the most specific primary muscle when identifiable (e.g. "quads", "lats", "pecsUpper", "lateralDelts"), falling back to the coarse region (chest, back, legs, shoulders, arms, core, fullBody) when the specific muscle is ambiguous, or null if unclear.
- Group exercises under spoken section headers if present; otherwise put everything in one group named "Main".
- session_rpe (an integer 1-10) is set ONLY when the athlete states an OVERALL session effort ("felt like a 9 overall", "today was RPE 8 overall", "整体RPE9"). A single set's RPE is NOT the session RPE — leave session_rpe null unless overall effort is stated.
- session_duration_minutes is set ONLY when a total session duration is stated ("about 45 minutes", "练了一个小时", "大概45分钟"). Otherwise null.
- Infer sport_type (default "lifting") and session_type (default "strength") from context, same as you would for a training plan.

Reply with valid JSON matching EXACTLY this shape — same keys, same nesting, no extra keys, no missing keys:

{
  "workout_name": string,
  "sport_type": one of ${JSON.stringify(SPORT_TYPES)},
  "session_type": one of ${JSON.stringify(SESSION_TYPES)},
  "session_rpe": integer 1-10 or null,
  "session_duration_minutes": integer or null,
  "groups": [
    {
      "group_name": string,
      "exercises": [
        {
          "exercise_name": string,
          "exercise_category": one of ${JSON.stringify(EXERCISE_CATEGORIES)},
          "muscle_group": one of the known muscle names or null,
          "sets": [
            { "reps": integer or null, "weight_kg": number or null, "duration_seconds": integer or null, "rpe": number or null, "is_warmup": boolean }
          ]
        }
      ]
    }
  ]
}

Example JSON output for "Squats three sets of five at sixty kilos, bodyweight pull-ups three sets of ten, third set of squats felt heavy, RPE 8":
{
  "workout_name": "Logged Workout",
  "sport_type": "lifting",
  "session_type": "strength",
  "session_rpe": null,
  "session_duration_minutes": null,
  "groups": [
    {
      "group_name": "Main",
      "exercises": [
        {
          "exercise_name": "Squat",
          "exercise_category": "compound",
          "muscle_group": "quads",
          "sets": [
            { "reps": 5, "weight_kg": 60, "duration_seconds": null, "rpe": null, "is_warmup": false },
            { "reps": 5, "weight_kg": 60, "duration_seconds": null, "rpe": null, "is_warmup": false },
            { "reps": 5, "weight_kg": 60, "duration_seconds": null, "rpe": 8, "is_warmup": false }
          ]
        },
        {
          "exercise_name": "Pull-up",
          "exercise_category": "bodyweight",
          "muscle_group": "lats",
          "sets": [
            { "reps": 10, "weight_kg": null, "duration_seconds": null, "rpe": null, "is_warmup": false },
            { "reps": 10, "weight_kg": null, "duration_seconds": null, "rpe": null, "is_warmup": false },
            { "reps": 10, "weight_kg": null, "duration_seconds": null, "rpe": null, "is_warmup": false }
          ]
        }
      ]
    }
  ]
}`;

const LOG_RETRY_SUFFIX = `

Your previous reply did not parse as valid JSON matching the required shape above. Reply again with ONLY the JSON object — no markdown code fences, no explanation, no trailing text — matching every key exactly.`;

interface LoggedSet {
  reps: number | null;
  weight_kg: number | null;
  duration_seconds: number | null;
  rpe: number | null;
  is_warmup: boolean;
}

interface LoggedExercise {
  exercise_name: string;
  exercise_category: ExerciseCategory;
  muscle_group: MuscleGroup | null;
  sets: LoggedSet[];
}

interface LoggedGroup {
  group_name: string;
  exercises: LoggedExercise[];
}

interface LoggedWorkout {
  workout_name: string;
  sport_type: SportType;
  session_type: SessionType;
  session_rpe: number | null;
  session_duration_minutes: number | null;
  groups: LoggedGroup[];
}

// Clamps a possibly-out-of-range number to null; passes through a clean
// number; passes through null/undefined as null. Never throws — this is a
// sanitizer, not a validator.
function clampNullableNumber(
  value: unknown,
  opts: { min?: number; max?: number; integer?: boolean } = {}
): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  if (opts.integer && !Number.isInteger(value)) return null;
  if (opts.min !== undefined && value < opts.min) return null;
  if (opts.max !== undefined && value > opts.max) return null;
  return value;
}

// Structural validation of a DeepSeek json_object response against the
// LoggedWorkout shape. Required keys/types/enum-membership failures are
// hard failures (triggers the one retry, then 502). Out-of-range numbers
// and unrecognized-but-nullable enum values (muscle_group) are clamped to
// null rather than failing the whole parse — quota is a cost cap and a
// single bad number in an otherwise-good parse shouldn't force a retry.
function validateLoggedWorkout(
  raw: unknown
): { ok: true; data: LoggedWorkout } | { ok: false; reason: string } {
  if (typeof raw !== "object" || raw === null) {
    return { ok: false, reason: "response is not a JSON object" };
  }
  const root = raw as Record<string, unknown>;

  if (typeof root.workout_name !== "string") {
    return { ok: false, reason: "workout_name missing or not a string" };
  }
  if (
    typeof root.sport_type !== "string" ||
    !(SPORT_TYPES as readonly string[]).includes(root.sport_type)
  ) {
    return { ok: false, reason: "sport_type missing or not a known value" };
  }
  if (
    typeof root.session_type !== "string" ||
    !(SESSION_TYPES as readonly string[]).includes(root.session_type)
  ) {
    return { ok: false, reason: "session_type missing or not a known value" };
  }
  if (!Array.isArray(root.groups)) {
    return { ok: false, reason: "groups missing or not an array" };
  }

  const groups: LoggedGroup[] = [];
  for (const rawGroup of root.groups) {
    if (typeof rawGroup !== "object" || rawGroup === null) {
      return { ok: false, reason: "a group entry is not an object" };
    }
    const group = rawGroup as Record<string, unknown>;
    if (typeof group.group_name !== "string") {
      return { ok: false, reason: "group_name missing or not a string" };
    }
    if (!Array.isArray(group.exercises)) {
      return { ok: false, reason: "exercises missing or not an array" };
    }

    const exercises: LoggedExercise[] = [];
    for (const rawExercise of group.exercises) {
      if (typeof rawExercise !== "object" || rawExercise === null) {
        return { ok: false, reason: "an exercise entry is not an object" };
      }
      const exercise = rawExercise as Record<string, unknown>;
      if (typeof exercise.exercise_name !== "string") {
        return { ok: false, reason: "exercise_name missing or not a string" };
      }
      if (
        typeof exercise.exercise_category !== "string" ||
        !(EXERCISE_CATEGORIES as readonly string[]).includes(
          exercise.exercise_category
        )
      ) {
        return {
          ok: false,
          reason: "exercise_category missing or not a known value",
        };
      }
      // muscle_group is nullable and low-stakes: clamp unknowns to null
      // rather than failing the whole parse.
      const muscleGroup =
        typeof exercise.muscle_group === "string" &&
        (MUSCLE_GROUPS as readonly string[]).includes(exercise.muscle_group)
          ? (exercise.muscle_group as MuscleGroup)
          : null;

      if (!Array.isArray(exercise.sets)) {
        return { ok: false, reason: "sets missing or not an array" };
      }

      const sets: LoggedSet[] = [];
      for (const rawSet of exercise.sets) {
        if (typeof rawSet !== "object" || rawSet === null) {
          return { ok: false, reason: "a set entry is not an object" };
        }
        const set = rawSet as Record<string, unknown>;
        sets.push({
          reps: clampNullableNumber(set.reps, { min: 0, integer: true }),
          weight_kg: clampNullableNumber(set.weight_kg, { min: 0 }),
          duration_seconds: clampNullableNumber(set.duration_seconds, {
            min: 0,
            integer: true,
          }),
          rpe: clampNullableNumber(set.rpe, { min: 1, max: 10 }),
          // is_warmup is required-but-defaultable: a missing/malformed flag
          // is treated as "not a warmup" rather than failing the parse.
          is_warmup: set.is_warmup === true,
        });
      }

      exercises.push({
        exercise_name: exercise.exercise_name,
        exercise_category: exercise.exercise_category as ExerciseCategory,
        muscle_group: muscleGroup,
        sets,
      });
    }

    groups.push({ group_name: group.group_name, exercises });
  }

  return {
    ok: true,
    data: {
      workout_name: root.workout_name,
      sport_type: root.sport_type as SportType,
      session_type: root.session_type as SessionType,
      session_rpe: clampNullableNumber(root.session_rpe, { min: 1, max: 10 }),
      session_duration_minutes: clampNullableNumber(
        root.session_duration_minutes,
        { min: 0, integer: true }
      ),
      groups,
    },
  };
}

async function callDeepSeek(
  apiKey: string,
  workout_text: string,
  extraInstruction: string
): Promise<LoggedWorkout | null> {
  const deepseekResponse = await fetch(
    "https://api.deepseek.com/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "deepseek-v4-flash",
        thinking: { type: "disabled" },
        temperature: 0.2,
        messages: [
          { role: "system", content: LOG_SYSTEM_PROMPT + extraInstruction },
          { role: "user", content: workout_text },
        ],
        response_format: { type: "json_object" },
      }),
    }
  );

  if (!deepseekResponse.ok) {
    const errorBody = await deepseekResponse.text();
    console.error("DeepSeek API error:", deepseekResponse.status, errorBody);
    return null;
  }

  const data = await deepseekResponse.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) {
    console.error("DeepSeek response had no content");
    return null;
  }

  let raw: unknown;
  try {
    raw = JSON.parse(content);
  } catch (error) {
    console.error("DeepSeek content was not valid JSON:", error);
    return null;
  }

  const validated = validateLoggedWorkout(raw);
  if (!validated.ok) {
    console.error("DeepSeek content failed validation:", validated.reason);
    return null;
  }
  return validated.data;
}

async function handleLogMode(workout_text: string): Promise<Response> {
  const apiKey = Deno.env.get("DEEPSEEK_API_KEY");
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "DeepSeek API key not configured" }),
      { status: 500, headers: JSON_HEADERS }
    );
  }

  let result = await callDeepSeek(apiKey, workout_text, "");
  if (!result) {
    result = await callDeepSeek(apiKey, workout_text, LOG_RETRY_SUFFIX);
  }

  if (!result) {
    return new Response(
      JSON.stringify({ error: "Failed to parse workout" }),
      { status: 502, headers: JSON_HEADERS }
    );
  }

  return new Response(JSON.stringify(result), { headers: JSON_HEADERS });
}

// ─────────────────────────────────────────────────────────────────────────
// Auth + quota (both modes)
// ─────────────────────────────────────────────────────────────────────────

// Verifies the caller's Supabase session JWT (forwarded automatically by
// supabase-swift's functions.invoke — no client change needed). Returns the
// authenticated user id, or null if the token is missing/invalid.
async function authenticateRequest(req: Request): Promise<string | null> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    console.error("SUPABASE_URL / SUPABASE_ANON_KEY not set in environment");
    return null;
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    global: {
      headers: { Authorization: req.headers.get("Authorization") ?? "" },
    },
  });

  const { data, error } = await authClient.auth.getUser();
  if (error || !data?.user) {
    return null;
  }
  return data.user.id;
}

// Increments today's parse count for this user via the service-role RPC and
// reports whether they're still under PARSE_DAILY_LIMIT (default 40). This
// is a cost cap, not a security boundary: if the RPC itself errors (e.g. the
// migration hasn't run yet), we log and FAIL OPEN so a broken quota table
// never takes down logging.
async function checkQuota(userId: string): Promise<boolean> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error(
      "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set in environment; failing open on quota"
    );
    return true;
  }

  try {
    const serviceClient = createClient(supabaseUrl, serviceRoleKey);
    const { data, error } = await serviceClient.rpc("increment_parse_usage", {
      p_user_id: userId,
    });

    if (error) {
      console.error("increment_parse_usage RPC error, failing open:", error);
      return true;
    }

    const limit = Number(Deno.env.get("PARSE_DAILY_LIMIT") ?? "40");
    const count = data as number;
    return count <= limit;
  } catch (error) {
    console.error("Quota check threw, failing open:", error);
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { workout_text, mode: rawMode } = await req.json();

    // Mode validation
    const mode = rawMode ?? "plan";
    if (mode !== "plan" && mode !== "log" && mode !== "program") {
      return new Response(
        JSON.stringify({ error: 'mode must be "plan", "log" or "program"' }),
        { status: 400, headers: JSON_HEADERS }
      );
    }

    // Input validation
    if (!workout_text || typeof workout_text !== "string") {
      return new Response(
        JSON.stringify({ error: "workout_text is required and must be a string" }),
        { status: 400, headers: JSON_HEADERS }
      );
    }

    if (workout_text.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "workout_text must not be empty" }),
        { status: 400, headers: JSON_HEADERS }
      );
    }

    // Plan/program modes accept whole multi-week program extractions (PDFs
    // routinely exceed 10k chars); log mode stays tight — a spoken session is short.
    const maxChars = mode === "log" ? 10_000 : 60_000;
    if (workout_text.length > maxChars) {
      return new Response(
        JSON.stringify({
          error: `workout_text must not exceed ${maxChars.toLocaleString("en-US")} characters for ${mode} mode`,
        }),
        { status: 400, headers: JSON_HEADERS }
      );
    }

    // JWT verification (both modes)
    const authStartedAt = performance.now();
    const userId = await authenticateRequest(req);
    const authMs = Math.round(performance.now() - authStartedAt);
    if (!userId) {
      console.log(`[timing] mode=${mode} auth_ms=${authMs} outcome=unauthorized`);
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: JSON_HEADERS,
      });
    }

    // Per-user daily quota (both modes)
    const quotaStartedAt = performance.now();
    const withinQuota = await checkQuota(userId);
    const quotaMs = Math.round(performance.now() - quotaStartedAt);
    console.log(
      `[timing] mode=${mode} input_chars=${workout_text.length}` +
        ` auth_ms=${authMs} quota_ms=${quotaMs} within_quota=${withinQuota}`
    );
    if (!withinQuota) {
      return new Response(JSON.stringify({ error: "quota_exceeded" }), {
        status: 429,
        headers: JSON_HEADERS,
      });
    }

    // Provider routing
    const routeStartedAt = performance.now();
    let response: Response;
    if (mode === "plan") {
      response = await handlePlanMode(workout_text);
    } else if (mode === "program") {
      response = await handleProgramMode(workout_text);
    } else {
      response = await handleLogMode(workout_text);
    }
    console.log(
      `[timing] mode=${mode} provider_ms=${Math.round(performance.now() - routeStartedAt)}` +
        ` status=${response.status}`
    );
    return response;
  } catch (error) {
    console.error("parse-workout error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to parse workout" }),
      { status: 502, headers: JSON_HEADERS }
    );
  }
});
