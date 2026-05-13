// Deploy: supabase functions deploy parse-workout
// Or paste into Supabase Dashboard > Edge Functions > New Function
// Required secret: supabase secrets set OPENAI_API_KEY=sk-...

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_PROMPT = `You are a workout parser. Extract ONLY exercises, sets, reps, and weights that are explicitly stated in the text. Do NOT invent or hallucinate any values.

Rules:
- Convert all weights to kilograms. If the weight appears to be in pounds (lbs), multiply by 0.453592 to convert to kg.
- Use null for any field not explicitly mentioned in the text. Never guess reps, weights, or durations.
- Infer sport_type from context if obvious (e.g. "bench press" = lifting, "5k run" = running). Default to "lifting".
- Infer session_type from context if obvious (e.g. "recovery session" = recovery, "speed work" = cardio). Default to "strength".
- Group exercises by day or section headers if present. If no grouping structure exists, use a single group named "Main".
- Mark sets as warmup only if explicitly labeled as warmup in the text.
- exercise_category should reflect the movement type: compound (multi-joint), isolation (single-joint), cardio, bodyweight, plyometric, drill, or interval.
- muscle_group should be the primary muscle targeted. Use null if unclear or not applicable.`;

const WORKOUT_SCHEMA = {
  type: "object" as const,
  properties: {
    workout_name: { type: "string" as const },
    sport_type: {
      type: "string" as const,
      enum: [
        "lifting",
        "running",
        "cycling",
        "teamSport",
        "crossfit",
        "swimming",
        "custom",
      ],
    },
    session_type: {
      type: "string" as const,
      enum: ["strength", "skill", "cardio", "match", "recovery"],
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
                  enum: [
                    "compound",
                    "isolation",
                    "cardio",
                    "bodyweight",
                    "plyometric",
                    "drill",
                    "interval",
                  ],
                },
                muscle_group: {
                  type: ["string", "null"] as const,
                  enum: [
                    "chest",
                    "back",
                    "legs",
                    "shoulders",
                    "arms",
                    "core",
                    "fullBody",
                    null,
                  ],
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

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { workout_text } = await req.json();

    // Input validation
    if (!workout_text || typeof workout_text !== "string") {
      return new Response(
        JSON.stringify({ error: "workout_text is required and must be a string" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    if (workout_text.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "workout_text must not be empty" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    if (workout_text.length > 10_000) {
      return new Response(
        JSON.stringify({ error: "workout_text must not exceed 10,000 characters" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Read API key from environment
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "OpenAI API key not configured" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Call OpenAI with structured output enforcement
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
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const data = await openaiResponse.json();
    const content = data.choices?.[0]?.message?.content;

    if (!content) {
      return new Response(
        JSON.stringify({ error: "Failed to parse workout" }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const parsed = JSON.parse(content);

    return new Response(JSON.stringify(parsed), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("parse-workout error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to parse workout" }),
      { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
