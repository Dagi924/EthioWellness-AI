
// ============================================================
// ETHIONUTRI AI - OPENROUTER SERVICE
// ============================================================

const axios = require('axios');

// ============================================================
// CONFIG
// ============================================================

const OPENROUTER_URL =
  'https://openrouter.ai/api/v1/chat/completions';

const OPENROUTER_MODELS_URL =
  'https://openrouter.ai/api/v1/models';

// ============================================================
// PRIMARY MODEL
// ============================================================

const GEMMA_MODEL =
  'google/gemma-4-26b-a4b-it:free';

// ============================================================
// KNOWN FREE FALLBACK MODELS
// ============================================================

const KNOWN_FREE_FALLBACK_MODELS = [
  'google/gemma-4-31b-it:free',
  'nvidia/nemotron-3-ultra-550b-a55b:free',
];

// ============================================================
// MODEL LISTS
// ============================================================

const CHATBOT_MODELS = [
  GEMMA_MODEL,
];

const VISION_MODELS = [
  GEMMA_MODEL,
];

// ============================================================
// TIMEOUTS
// ============================================================

const REQUEST_TIMEOUT = 120000;

const CHAT_TIMEOUT = 30000;

const VISION_TIMEOUT = 60000;

const MODEL_DISCOVERY_TIMEOUT = 30000;

// ============================================================
// API KEY
// ============================================================

function getApiKey() {
  const key =
    process.env.OPENROUTER_API_KEY ||
    process.env.OPENROUTER_KEY;

  if (!key) {
    throw new Error(
      'OPENROUTER_API_KEY is not configured'
    );
  }

  return key;
}

// ============================================================
// HEADERS
// ============================================================

function getHeaders() {
  return {
    Authorization:
      `Bearer ${getApiKey()}`,

    'Content-Type':
      'application/json',

    'HTTP-Referer':
      process.env.OPENROUTER_SITE_URL ||
      'http://localhost:5000',

    'X-Title':
      process.env.OPENROUTER_SITE_NAME ||
      'EthioNutri AI',
  };
}

// ============================================================
// CURRENT WEEK
// MONDAY -> SUNDAY
// ============================================================

function getCurrentWeek() {
  const formatter =
    new Intl.DateTimeFormat(
      'en-CA',
      {
        timeZone:
          'Africa/Addis_Ababa',

        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      }
    );

  const parts =
    formatter.formatToParts(
      new Date()
    );

  const year =
    Number(
      parts.find(
        (p) => p.type === 'year'
      ).value
    );

  const month =
    Number(
      parts.find(
        (p) => p.type === 'month'
      ).value
    );

  const day =
    Number(
      parts.find(
        (p) => p.type === 'day'
      ).value
    );

  const date =
    new Date(
      Date.UTC(
        year,
        month - 1,
        day
      )
    );

  const weekday =
    date.getUTCDay();

  const diffToMonday =
    weekday === 0
      ? -6
      : 1 - weekday;

  const monday =
    new Date(date);

  monday.setUTCDate(
    monday.getUTCDate() +
      diffToMonday
  );

  const sunday =
    new Date(monday);

  sunday.setUTCDate(
    sunday.getUTCDate() + 6
  );

  const formatDate = (d) =>
    d.toISOString().slice(0, 10);

  return {
    startDate:
      formatDate(monday),

    endDate:
      formatDate(sunday),

    dates:
      Array.from(
        { length: 7 },
        (_, index) => {
          const d =
            new Date(monday);

          d.setUTCDate(
            d.getUTCDate() +
              index
          );

          return formatDate(d);
        }
      ),
  };
}

// ============================================================
// SAFE JSON
// ============================================================

function safeJson(value) {
  try {
    return JSON.stringify(value);
  } catch {
    return '{}';
  }
}

// ============================================================
// PROFILE SERIALIZATION
// ============================================================

function serializeProfile(profile) {
  if (!profile) {
    return {};
  }

  if (
    typeof profile ===
    'string'
  ) {
    try {
      return JSON.parse(
        profile
      );
    } catch {
      return {
        profile,
      };
    }
  }

  return profile;
}

// ============================================================
// FASTING SERIALIZATION
// ============================================================

function serializeFasting(fasting) {
  if (!fasting) {
    return {};
  }

  if (
    typeof fasting ===
    'string'
  ) {
    try {
      return JSON.parse(
        fasting
      );
    } catch {
      return {
        fasting,
      };
    }
  }

  return fasting;
}

// ============================================================
// PERSONALIZED CHATBOT SYSTEM PROMPT
// ============================================================
//
// IMPORTANT:
//
// This is the original chatbot behavior.
//
// The chatbot answers the user's actual question.
// It does NOT force every conversation into a meal plan.
// It does NOT force JSON.
// It does NOT generate a 7-day plan unless the user asks.
// ============================================================

function buildChatbotSystemPrompt(
  profile
) {
  const userProfile =
    serializeProfile(
      profile
    );

  return `
You are EthioNutri AI, an expert nutrition assistant
specializing in Ethiopian traditional foods and fasting.

Fasting Practice:
${userProfile.fastingPractice || 'Orthodox'}

Health Goal:
${userProfile.goal || 'General Health'}

Dietary Restrictions:
${JSON.stringify(
  userProfile.dietaryRestrictions || []
)}

Health Conditions:
${JSON.stringify(
  userProfile.healthConditions || []
)}

Give practical, concise and culturally relevant advice.

Prefer appropriate Ethiopian foods such as:
- Teff
- Injera
- Shiro
- Misir
- Gomen
- Beans
- Chickpeas
- Lentils
- Telba
- Fosolia
- Kik Alicha

Respect fasting requirements.

Do not invent medical diagnoses.
Do not claim that food can cure diseases.
When a question requires professional medical
attention, recommend a qualified healthcare professional.
`.trim();
}

// ============================================================
// GENERIC OPENROUTER CALL
// ============================================================
//
// Same request structure used by the chatbot.
//
// No response_format.
// No JSON mode.
// No structured-output requirement.
// ============================================================

async function callOpenRouter({
  messages,
  temperature = 0.5,
  maxTokens = 600,
  timeout = REQUEST_TIMEOUT,
  model = GEMMA_MODEL,
}) {
  const requestBody = {
    model,

    messages,

    temperature,

    max_tokens:
      maxTokens,
  };

  const response =
    await axios.post(
      OPENROUTER_URL,
      requestBody,
      {
        headers:
          getHeaders(),

        timeout,
      }
    );

  const choice =
    response?.data
      ?.choices?.[0];

  const content =
    choice?.message
      ?.content;

  const finishReason =
    choice?.finish_reason;

  console.log(
    `[EthioNutri AI] ${model} finish_reason:`,
    finishReason ||
      'unknown'
  );

  if (
    content ===
      undefined ||
    content === null ||
    String(content)
      .trim() === ''
  ) {
    throw new Error(
      `Model ${model} returned an empty response`
    );
  }

  return {
    content:
      String(content).trim(),

    finishReason,

    raw:
      response.data,
  };
}

// ============================================================
// UNIQUE MODELS
// ============================================================

function uniqueModels(
  models
) {
  return [
    ...new Set(
      (models || [])
        .filter(
          (model) =>
            typeof model ===
              'string' &&
            model.trim()
        )
    ),
  ];
}

// ============================================================
// GET AVAILABLE OPENROUTER MODELS
// ============================================================

async function getAvailableModels() {
  const response =
    await axios.get(
      OPENROUTER_MODELS_URL,
      {
        headers:
          getHeaders(),

        timeout:
          MODEL_DISCOVERY_TIMEOUT,
      }
    );

  return (
    response?.data?.data ||
    []
  );
}

// ============================================================
// DISCOVER FREE TEXT MODELS
// ============================================================

async function discoverFreeTextModels() {
  try {
    const models =
      await getAvailableModels();

    if (
      !Array.isArray(models)
    ) {
      return [];
    }

    const discovered =
      models
        .filter(
          (model) => {
            const id =
              model?.id;

            if (
              typeof id !==
              'string'
            ) {
              return false;
            }

            if (
              !id.endsWith(
                ':free'
              )
            ) {
              return false;
            }

            if (
              id ===
              'openrouter/free'
            ) {
              return false;
            }

            return true;
          }
        )
        .filter(
          (model) => {
            const id =
              String(
                model.id
              ).toLowerCase();

            const blocked = [
              'embedding',
              'tts',
              'speech',
              'audio',
              'transcription',
              'whisper',
              'moderation',
              'guard',
            ];

            return !blocked.some(
              (word) =>
                id.includes(word)
            );
          }
        )
        .map(
          (model) =>
            model.id
        );

    return uniqueModels(
      discovered
    );
  } catch (error) {
    console.error(
      '[EthioNutri AI] Free model discovery failed:',
      error?.message ||
        error
    );

    return [];
  }
}

// ============================================================
// ALL TEXT MODELS
// ============================================================

async function getTextModels() {
  const discovered =
    await discoverFreeTextModels();

  return uniqueModels([
    GEMMA_MODEL,

    ...KNOWN_FREE_FALLBACK_MODELS,

    ...discovered,
  ]);
}

// ============================================================
// RETRY SAME MODEL?
// ============================================================

function shouldRetrySameModel(
  error
) {
  const status =
    error?.response?.status;

  if (
    status === 429
  ) {
    return false;
  }

  if (
    status === 401 ||
    status === 403
  ) {
    return false;
  }

  if (
    status === 404
  ) {
    return false;
  }

  return true;
}

// ============================================================
// PLAIN TEXT GENERATOR
// ============================================================

async function generatePlainText({
  systemPrompt,
  userPrompt,
  maxTokens,
  retryMaxTokens,
  temperature = 0.3,
  label,
}) {
  const models =
    await getTextModels();

  console.log(
    `[EthioNutri AI] Text model fallback order for ${label}:`
  );

  console.log(
    models.join(' -> ')
  );

  let lastError =
    null;

  for (
    let modelIndex = 0;
    modelIndex < models.length;
    modelIndex++
  ) {
    const model =
      models[modelIndex];

    const attempts = [
      maxTokens,
      retryMaxTokens ||
        maxTokens,
    ];

    for (
      let attempt = 0;
      attempt < attempts.length;
      attempt++
    ) {
      const currentMaxTokens =
        attempts[attempt];

      console.log(
        `[EthioNutri AI] Trying ${label}: ${model} | attempt ${
          attempt + 1
        }/${attempts.length} | max_tokens=${currentMaxTokens}`
      );

      try {
        const result =
          await callOpenRouter({
            model,

            messages: [
              {
                role:
                  'system',

                content:
                  systemPrompt,
              },

              {
                role:
                  'user',

                content:
                  userPrompt,
              },
            ],

            temperature,

            maxTokens:
              currentMaxTokens,

            timeout:
              REQUEST_TIMEOUT,
          });

        if (
          result.finishReason ===
            'length' &&
          attempt + 1 <
            attempts.length
        ) {
          console.warn(
            `[EthioNutri AI] ${label}: ${model} reached token limit. Retrying with larger max_tokens.`
          );

          continue;
        }

        console.log(
          `[EthioNutri AI] ${label} generated successfully using ${model}`
        );

        return result.content;
      } catch (error) {
        lastError =
          error;

        const status =
          error?.response?.status ||
          'N/A';

        const apiError =
          error?.response?.data ||
          error?.message ||
          error;

        console.error(
          `[EthioNutri AI] ${label} failed: ${model} | HTTP ${status}`
        );

        console.error(
          apiError
        );

        // ------------------------------------------------------
        // 429
        // ------------------------------------------------------

        if (
          status === 429
        ) {
          console.warn(
            `[EthioNutri AI] ${model} is rate-limited. Moving to the next model.`
          );

          break;
        }

        // ------------------------------------------------------
        // AUTH
        // ------------------------------------------------------

        if (
          status === 401 ||
          status === 403
        ) {
          console.error(
            '[EthioNutri AI] OpenRouter authentication/permission error. Check OPENROUTER_API_KEY.'
          );

          break;
        }

        // ------------------------------------------------------
        // MODEL NOT FOUND
        // ------------------------------------------------------

        if (
          status === 404
        ) {
          console.warn(
            `[EthioNutri AI] Model ${model} is unavailable. Moving to next model.`
          );

          break;
        }

        // ------------------------------------------------------
        // OTHER ERRORS
        // ------------------------------------------------------

        if (
          shouldRetrySameModel(
            error
          ) &&
          attempt + 1 <
            attempts.length
        ) {
          console.warn(
            `[EthioNutri AI] Retrying ${label} with ${model}...`
          );

          continue;
        }

        break;
      }
    }
  }

  throw (
    lastError ||
    new Error(
      `${label} generation failed on all available models`
    )
  );
}

// ============================================================
// MEAL PLAN
// ============================================================

async function generateMealPlan({
  profile,
  fasting,
  preferences = {},
}) {
  const week =
    getCurrentWeek();

  console.log(
    `[EthioNutri AI] Generating meal plan: ${week.startDate} -> ${week.endDate}`
  );

  const profileData =
    serializeProfile(
      profile
    );

  const fastingData =
    serializeFasting(
      fasting
    );

  const systemPrompt =
    buildChatbotSystemPrompt(
      profileData
    );

  const userPrompt = `
Create a personalized 7-day Ethiopian meal plan for me.

CURRENT WEEK:
${week.startDate} to ${week.endDate}

DATES:
${week.dates.join(', ')}

FASTING INFORMATION:
${safeJson(
  fastingData
)}

PREFERENCES:
${safeJson(
  preferences
)}

Create a practical meal plan using realistic Ethiopian foods
and ingredients.

Respect my fasting practice, allergies, dietary restrictions,
health conditions, and the information in my profile.

Give useful nutrition information where appropriate.

Write the answer as normal readable text.

Do not return JSON.

Do not use markdown code blocks.

Do not wrap the answer in JSON.

Do not explain that you are generating a plan.

Just give me the meal plan in plain readable text.
`.trim();

  return await generatePlainText({
    systemPrompt,

    userPrompt,

    maxTokens:
      6500,

    retryMaxTokens:
      9000,

    temperature:
      0.5,

    label:
      'meal-plan',
  });
}

// ============================================================
// EXERCISE PLAN
// ============================================================

async function generateExercisePlan({
  profile,
  preferences = {},
}) {
  const week =
    getCurrentWeek();

  console.log(
    `[EthioNutri AI] Generating exercise plan: ${week.startDate} -> ${week.endDate}`
  );

  const profileData =
    serializeProfile(
      profile
    );

  const systemPrompt =
    buildChatbotSystemPrompt(
      profileData
    );

  const userPrompt = `
Create a personalized 7-day exercise plan for me.

CURRENT WEEK:
${week.startDate} to ${week.endDate}

DATES:
${week.dates.join(', ')}

PREFERENCES:
${safeJson(
  preferences
)}

Base the plan on my actual profile.

Respect known limitations or restrictions.

Keep the exercises practical and realistic.

Include rest or recovery when appropriate.

Do not invent medical conditions.

Do not prescribe treatment for medical conditions.

Write the answer as normal readable text.

Do not return JSON.

Do not use markdown code blocks.

Do not wrap the answer in JSON.

Do not explain that you are generating a plan.

Just give me the exercise plan in plain readable text.
`.trim();

  return await generatePlainText({
    systemPrompt,

    userPrompt,

    maxTokens:
      3500,

    retryMaxTokens:
      5500,

    temperature:
      0.5,

    label:
      'exercise-plan',
  });
}

// ============================================================
// CHATBOT
// ============================================================
//
// THIS IS THE IMPORTANT FIX.
//
// Before:
// Gemma -> 429 -> chatFallback()
//
// Now:
// Gemma -> 429 -> Gemma 31B -> 429 -> Nemotron -> ...
//
// The personalized chatbot prompt remains unchanged.
// ============================================================

async function chatWithAI({
  profile,
  promptMessage,
  models,
}) {
  const profileData =
    serializeProfile(
      profile
    );

  let modelList;

  if (
    Array.isArray(models) &&
    models.length > 0
  ) {
    modelList =
      uniqueModels([
        ...models,

        ...KNOWN_FREE_FALLBACK_MODELS,
      ]);
  } else {
    modelList =
      await getTextModels();
  }

  if (
    modelList.length === 0
  ) {
    modelList =
      uniqueModels([
        GEMMA_MODEL,

        ...KNOWN_FREE_FALLBACK_MODELS,
      ]);
  }

  const systemPrompt =
    buildChatbotSystemPrompt(
      profileData
    );

  const userContent =
    typeof promptMessage ===
    'string'
      ? promptMessage
      : JSON.stringify(
          promptMessage
        );

  let lastError =
    null;

  console.log(
    '[EthioNutri AI] Chat model fallback order:'
  );

  console.log(
    modelList.join(
      ' -> '
    )
  );

  for (
    const model of modelList
  ) {
    console.log(
      `[EthioNutri AI] Trying chatbot model: ${model}`
    );

    try {
      const result =
        await callOpenRouter({
          model,

          messages: [
            {
              role:
                'system',

              content:
                systemPrompt,
            },

            {
              role:
                'user',

              content:
                userContent,
            },
          ],

          temperature:
            0.6,

          maxTokens:
            700,

          timeout:
            CHAT_TIMEOUT,
        });

      console.log(
        `[EthioNutri AI] Chat succeeded using ${model}`
      );

      return result.content;
    } catch (error) {
      lastError =
        error;

      const status =
        error?.response?.status ||
        error?.response?.data?.error?.code ||
        'N/A';

      const apiError =
        error?.response?.data ||
        error?.message ||
        error;

      console.error(
        `[EthioNutri AI] Chat model failed: ${model} | HTTP ${status}`
      );

      console.error(
        apiError
      );

      // --------------------------------------------------------
      // RATE LIMIT
      // --------------------------------------------------------
      //
      // THIS FIXES YOUR 429 ERROR.
      //
      // Do not stop the chatbot.
      // Move to the next model.
      // --------------------------------------------------------

      if (
        status === 429
      ) {
        console.warn(
          `[EthioNutri AI] ${model} is rate-limited. Trying the next chatbot model.`
        );

        continue;
      }

      // --------------------------------------------------------
      // AUTHENTICATION
      // --------------------------------------------------------

      if (
        status === 401 ||
        status === 403
      ) {
        console.error(
          '[EthioNutri AI] OpenRouter authentication/permission error. Check OPENROUTER_API_KEY.'
        );

        break;
      }

      // --------------------------------------------------------
      // MODEL UNAVAILABLE
      // --------------------------------------------------------

      if (
        status === 404
      ) {
        console.warn(
          `[EthioNutri AI] Model ${model} is unavailable. Trying the next chatbot model.`
        );

        continue;
      }

      // --------------------------------------------------------
      // OTHER ERRORS
      // --------------------------------------------------------

      console.warn(
        `[EthioNutri AI] Chat failed on ${model}. Trying the next available model.`
      );
    }
  }

  console.error(
    '[EthioNutri AI] Chat completely failed on all available models:',
    lastError?.response?.data ||
      lastError?.message ||
      lastError
  );

  return chatFallback();
}

// ============================================================
// ORIGINAL CHAT FUNCTION COMPATIBILITY
// ============================================================
//
// Keeps compatibility with code that calls:
// sendAiChatPrompt(prompt, profile)
// ============================================================

async function sendAiChatPrompt(
  promptMessage,
  userProfile = {}
) {
  return chatWithAI({
    profile:
      userProfile,

    promptMessage,
  });
}

// ============================================================
// CHAT FALLBACK
// ============================================================

function chatFallback() {
  return `
For Ethiopian fasting, good plant-protein choices include
shiro, misir, beans, chickpeas and lentils paired with
teff injera.

For iron, combine legumes and leafy greens such as gomen
with vitamin-C-rich foods such as lemon and fresh vegetables.

For personalized nutrition advice, your calorie, protein,
health and dietary requirements should be considered.
`.trim();
}

// ============================================================
// IMAGE / VISION ANALYSIS
// ============================================================

async function analyzeImage({
  profile,
  imageUrl,
  prompt =
    'Analyze this image and provide useful nutrition-related information.',
}) {
  const profileData =
    serializeProfile(
      profile
    );

  const systemPrompt =
    buildChatbotSystemPrompt(
      profileData
    );

  let lastError =
    null;

  const models =
    uniqueModels([
      ...VISION_MODELS,

      ...KNOWN_FREE_FALLBACK_MODELS,
    ]);

  for (
    const model of models
  ) {
    console.log(
      `[EthioNutri AI] Trying vision model: ${model}`
    );

    try {
      const result =
        await callOpenRouter({
          model,

          messages: [
            {
              role:
                'system',

              content:
                systemPrompt,
            },

            {
              role:
                'user',

              content: [
                {
                  type:
                    'text',

                  text:
                    prompt,
                },

                {
                  type:
                    'image_url',

                  image_url: {
                    url:
                      imageUrl,
                  },
                },
              ],
            },
          ],

          temperature:
            0.4,

          maxTokens:
            800,

          timeout:
            VISION_TIMEOUT,
        });

      console.log(
        `[EthioNutri AI] Vision analysis succeeded using ${model}`
      );

      return result.content;
    } catch (error) {
      lastError =
        error;

      const status =
        error?.response
          ?.status ||
        'N/A';

      console.error(
        `[EthioNutri AI] Vision model failed: ${model} | HTTP ${status}`
      );

      if (
        status === 429
      ) {
        console.warn(
          `[EthioNutri AI] ${model} is rate-limited. Moving to next vision model.`
        );

        continue;
      }

      if (
        status === 401 ||
        status === 403
      ) {
        break;
      }

      if (
        status === 404
      ) {
        continue;
      }
    }
  }

  throw (
    lastError ||
    new Error(
      'Vision analysis failed on all available models'
    )
  );
}

// ============================================================
// EXPORTS
// ============================================================

module.exports = {
  GEMMA_MODEL,

  getCurrentWeek,

  getAvailableModels,

  callOpenRouter,

  // ----------------------------------------------------------
  // Meal plan
  // ----------------------------------------------------------

  generateMealPlan,

  generateMealPlanWithAI:
    generateMealPlan,

  // ----------------------------------------------------------
  // Exercise
  // ----------------------------------------------------------

  generateExercisePlan,

  generateExercisePlanWithAI:
    generateExercisePlan,

  // ----------------------------------------------------------
  // Chatbot
  // ----------------------------------------------------------

  chatWithAI,

  sendAiChatPrompt,

  // ----------------------------------------------------------
  // Vision
  // ----------------------------------------------------------

  analyzeImage,
};
