const express = require('express');
const router = express.Router();

const {
  eq,
  desc,
  sql,
} = require('drizzle-orm');

const {
  authenticateToken,
} = require('../middleware/auth');

const {
  db,
} = require('../db');

const {
  profiles,
  foodLogs,
  sleepLogs,
  moodLogs,
} = require('../db/schema');

// ============================================================
// AI CHAT HISTORY TABLE
// ============================================================

let chatHistoryTablePromise = null;

async function ensureChatHistoryTable() {
  if (!chatHistoryTablePromise) {
    chatHistoryTablePromise = db.execute(
      sql`
        CREATE TABLE IF NOT EXISTS ai_chat_history (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id UUID NOT NULL
            REFERENCES users(id)
            ON DELETE CASCADE,
          user_prompt TEXT NOT NULL,
          ai_response TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT NOW()
        );

        CREATE INDEX IF NOT EXISTS
        ai_chat_history_user_id_idx
        ON ai_chat_history(user_id);

        CREATE INDEX IF NOT EXISTS
        ai_chat_history_created_at_idx
        ON ai_chat_history(created_at);
      `
    ).catch((error) => {
      chatHistoryTablePromise = null;

      console.error(
        '[AI CHAT] Failed to initialize chat history table:',
        error
      );

      throw error;
    });
  }

  return chatHistoryTablePromise;
}

// ============================================================
// GET CURRENT DATE IN ETHIOPIA
// ============================================================

function getAddisAbabaDate() {
  const formatter = new Intl.DateTimeFormat(
    'en-CA',
    {
      timeZone: 'Africa/Addis_Ababa',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }
  );

  return formatter.format(new Date());
}

// ============================================================
// GET DATE FROM TIMESTAMP IN ETHIOPIA
// ============================================================

function getAddisAbabaDateFromTimestamp(timestamp) {
  if (!timestamp) {
    return null;
  }

  const date = new Date(timestamp);

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return new Intl.DateTimeFormat(
    'en-CA',
    {
      timeZone: 'Africa/Addis_Ababa',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }
  ).format(date);
}

// ============================================================
// CLEAN DATABASE VALUE
// ============================================================

function cleanValue(value) {
  if (value === null || value === undefined) {
    return null;
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  return value;
}

// ============================================================
// CLEAN DATABASE ROW
// ============================================================

function cleanRow(row) {
  if (!row || typeof row !== 'object') {
    return row;
  }

  const cleaned = {};

  for (const [key, value] of Object.entries(row)) {
    cleaned[key] = cleanValue(value);
  }

  return cleaned;
}

// ============================================================
// GET RECENT CHAT HISTORY
// ============================================================

async function getRecentChatHistory(userId, limit = 20) {
  await ensureChatHistoryTable();

  const result = await db.execute(
    sql`
      SELECT
        id,
        user_id,
        user_prompt,
        ai_response,
        created_at
      FROM ai_chat_history
      WHERE user_id = ${userId}
      ORDER BY created_at DESC
      LIMIT ${limit}
    `
  );

  const rows = result?.rows || [];

  return rows
    .map(cleanRow)
    .reverse();
}

// ============================================================
// SAVE CHAT HISTORY
// ============================================================

async function saveChatHistory(
  userId,
  userPrompt,
  aiResponse
) {
  await ensureChatHistoryTable();

  const result = await db.execute(
    sql`
      INSERT INTO ai_chat_history (
        user_id,
        user_prompt,
        ai_response
      )
      VALUES (
        ${userId},
        ${userPrompt},
        ${aiResponse}
      )
      RETURNING
        id,
        user_id,
        user_prompt,
        ai_response,
        created_at
    `
  );

  const row = result?.rows?.[0];

  if (!row) {
    throw new Error('Chat history was not saved');
  }

  return cleanRow(row);
}

// ============================================================
// GET USER PROFILE
// ============================================================

async function getUserProfile(userId) {
  const profileResult = await db
    .select()
    .from(profiles)
    .where(eq(profiles.userId, userId))
    .limit(1);

  return (
    profileResult[0] || {
      fastingPractice: 'orthodox',
      goal: 'maintain_weight',
    }
  );
}

// ============================================================
// GET TODAY'S FOOD / MEAL LOGS ONLY
// ============================================================

async function getTodayFoodHistory(userId) {
  const today = getAddisAbabaDate();

  const foodHistory = await db
    .select()
    .from(foodLogs)
    .where(eq(foodLogs.userId, userId))
    .orderBy(desc(foodLogs.loggedAt))
    .limit(100);

  return foodHistory.filter((log) => {
    return (
      getAddisAbabaDateFromTimestamp(
        log.loggedAt
      ) === today
    );
  });
}

// ============================================================
// GET TODAY'S SLEEP LOGS ONLY
// ============================================================

async function getTodaySleepHistory(userId) {
  const today = getAddisAbabaDate();

  const sleepHistory = await db
    .select()
    .from(sleepLogs)
    .where(eq(sleepLogs.userId, userId))
    .orderBy(desc(sleepLogs.createdAt))
    .limit(100);

  return sleepHistory.filter((log) => {
    return String(log.sleepDate) === today;
  });
}

// ============================================================
// GET TODAY'S MOOD LOGS ONLY
// ============================================================

async function getTodayMoodHistory(userId) {
  const today = getAddisAbabaDate();

  const moodHistory = await db
    .select()
    .from(moodLogs)
    .where(eq(moodLogs.userId, userId))
    .orderBy(desc(moodLogs.loggedAt))
    .limit(100);

  return moodHistory.filter((log) => {
    return (
      getAddisAbabaDateFromTimestamp(
        log.loggedAt
      ) === today
    );
  });
}

// ============================================================
// CALCULATE TODAY'S FOOD TOTALS
// ============================================================

function calculateTodayFoodTotals(foodHistory) {
  const today = getAddisAbabaDate();

  let calories = 0;
  let protein = 0;
  let carbs = 0;
  let fats = 0;
  let iron = 0;

  for (const log of foodHistory) {
    if (!log.loggedAt) {
      continue;
    }

    const logDate =
      getAddisAbabaDateFromTimestamp(
        log.loggedAt
      );

    if (logDate !== today) {
      continue;
    }

    calories += Number(log.calories || 0);
    protein += Number(log.proteinGrams || 0);
    carbs += Number(log.carbsGrams || 0);
    fats += Number(log.fatsGrams || 0);
    iron += Number(log.ironMg || 0);
  }

  return {
    date: today,
    calories,
    proteinGrams: protein,
    carbsGrams: carbs,
    fatsGrams: fats,
    ironMg: iron,
  };
}

// ============================================================
// PREPARE TODAY'S FOOD DATA
// ============================================================

function prepareFoodHistory(foodHistory) {
  return foodHistory.map(cleanRow);
}

// ============================================================
// PREPARE TODAY'S SLEEP DATA
// ============================================================

function prepareSleepHistory(sleepHistory) {
  return sleepHistory.map(cleanRow);
}

// ============================================================
// PREPARE TODAY'S MOOD DATA
// ============================================================

function prepareMoodHistory(moodHistory) {
  return moodHistory.map(cleanRow);
}

// ============================================================
// PREPARE CHAT HISTORY FOR AI
// ============================================================

function prepareChatHistory(chatHistory) {
  return chatHistory.map((chat) => ({
    id: chat.id,
    userPrompt: chat.userPrompt,
    aiResponse: chat.aiResponse,
    createdAt: chat.createdAt,
  }));
}

// ============================================================
// BUILD AI PROFILE CONTEXT
// ============================================================

function buildAIProfileContext(
  profile,
  todayFood,
  todaySleep,
  todayMood,
  chatHistory,
  todayTotals
) {
  return {
    ...profile,

    todayDate: todayTotals.date,

    todayFoodLogs:
      prepareFoodHistory(todayFood),

    todayFoodLogCount:
      todayFood.length,

    todaySleepLogs:
      prepareSleepHistory(todaySleep),

    todaySleepLogCount:
      todaySleep.length,

    todayMoodLogs:
      prepareMoodHistory(todayMood),

    todayMoodLogCount:
      todayMood.length,

    todayFoodTotals:
      todayTotals,

    recentChatHistory:
      prepareChatHistory(chatHistory),

    chatHistoryCount:
      chatHistory.length,

    dataContextInstruction:
      `
Use only the authenticated user's data supplied in this context.

Food, sleep, mood, and calorie data are TODAY'S records only.

Do not invent food, sleep, mood, calorie, or nutrition records.

If today's food records are empty, say there are no food records
recorded for today.

If today's sleep records are empty, say there is no sleep record
recorded for today.

If today's mood records are empty, say there are no mood records
recorded for today.

Today's calorie and nutrition totals are calculated only from
today's food records.

Previous AI conversation history may be used only for
conversational continuity.

Do not expose internal database IDs.
      `.trim(),
  };
}

// ============================================================
// POST /api/v1/ai/chat
// ============================================================

router.post(
  '/chat',
  authenticateToken,
  async (req, res) => {
    try {
      const userId = req.user.id;

      const prompt = (
        req.body.prompt ||
        req.body.message ||
        ''
      ).trim();

      if (!prompt) {
        return res.status(400).json({
          error: 'Prompt message is required',
        });
      }

      if (prompt.length > 10000) {
        return res.status(400).json({
          error: 'Prompt message is too long',
        });
      }

      await ensureChatHistoryTable();

      const [
        profile,
        todayFood,
        todaySleep,
        todayMood,
        chatHistory,
      ] = await Promise.all([
        getUserProfile(userId),
        getTodayFoodHistory(userId),
        getTodaySleepHistory(userId),
        getTodayMoodHistory(userId),
        getRecentChatHistory(userId, 20),
      ]);

      const todayTotals =
        calculateTodayFoodTotals(
          todayFood
        );

      const aiProfile =
        buildAIProfileContext(
          profile,
          todayFood,
          todaySleep,
          todayMood,
          chatHistory,
          todayTotals
        );

      const aiSleepData =
        prepareSleepHistory(
          todaySleep
        );

      const aiMoodData =
        prepareMoodHistory(
          todayMood
        );

      let conversationContext =
        '';

      if (chatHistory.length > 0) {
        conversationContext =
          chatHistory
            .map(
              (chat) => `
USER:
${chat.userPrompt}

AI:
${chat.aiResponse}
`
            )
            .join('\n')
            .trim();
      } else {
        conversationContext =
          'No previous AI conversation history is available.';
      }

      const todayFoodData =
        JSON.stringify(
          prepareFoodHistory(
            todayFood
          ),
          null,
          2
        );

      const todaySleepData =
        JSON.stringify(
          prepareSleepHistory(
            todaySleep
          ),
          null,
          2
        );

      const todayMoodData =
        JSON.stringify(
          prepareMoodHistory(
            todayMood
          ),
          null,
          2
        );

      const aiPrompt = `
CURRENT USER MESSAGE:

${prompt}

============================================================
TODAY'S DATE
============================================================

${todayTotals.date}

============================================================
CONVERSATION MEMORY
============================================================

${conversationContext}

============================================================
IMPORTANT DATA LIMIT
============================================================

You are being given ONLY today's health data.

Do not assume or invent health data from previous days.

The available health data is:

1. Today's meals / food logs
2. Today's calorie and nutrition totals
3. Today's sleep records
4. Today's mood records

Previous AI conversations are provided only for conversation
continuity.

============================================================
TODAY'S MEALS / FOOD
============================================================

Food logs recorded today:
${todayFood.length}

${todayFoodData}

============================================================
TODAY'S CALORIE / NUTRITION TOTALS
============================================================

Calories:
${todayTotals.calories}

Protein:
${todayTotals.proteinGrams} g

Carbohydrates:
${todayTotals.carbsGrams} g

Fat:
${todayTotals.fatsGrams} g

Iron:
${todayTotals.ironMg} mg

============================================================
TODAY'S SLEEP
============================================================

Sleep records recorded today:
${todaySleep.length}

${todaySleepData}

============================================================
TODAY'S MOOD
============================================================

Mood records recorded today:
${todayMood.length}

${todayMoodData}

============================================================
INSTRUCTIONS
============================================================

Answer the user's current message directly.

Use today's real meals and calorie totals when discussing food
or nutrition.

Use today's real sleep records when discussing sleep.

Use today's real mood records when discussing mood.

If the requested category has no records today, clearly say
there is no recorded data for today.

Do not invent missing information.

Do not claim to know health information from previous days.

Do not mention internal database implementation.

Do not expose database IDs.

Do not diagnose medical conditions.

Give practical personalized wellness guidance based only on the
available information.
`.trim();

      console.log(
        `[AI CHAT] user=${userId} ` +
        `today=${todayTotals.date} ` +
        `foodToday=${todayFood.length} ` +
        `sleepToday=${todaySleep.length} ` +
        `moodToday=${todayMood.length} ` +
        `chat=${chatHistory.length}`
      );

      console.log(
        '[AI CHAT] Today totals:',
        todayTotals
      );

      if (todayFood.length > 0) {
        console.log(
          '[AI CHAT] Today food:',
          todayFood
        );
      }

      if (todaySleep.length > 0) {
        console.log(
          '[AI CHAT] Today sleep:',
          todaySleep
        );
      }

      if (todayMood.length > 0) {
        console.log(
          '[AI CHAT] Today mood:',
          todayMood
        );
      }

      let aiReply = '';
      let aiAvailable = true;

      try {
        const {
          sendAiChatPrompt,
        } = require(
          '../services/openrouter_service'
        );

        if (
          typeof sendAiChatPrompt !==
          'function'
        ) {
          throw new Error(
            'sendAiChatPrompt is not available in openrouter_service'
          );
        }

        aiReply =
          await sendAiChatPrompt(
            aiPrompt,
            aiProfile,
            aiSleepData,
            aiMoodData
          );

        if (
          !aiReply ||
          typeof aiReply !== 'string' ||
          !aiReply.trim()
        ) {
          throw new Error(
            'AI returned an empty response'
          );
        }

        aiReply = aiReply.trim();

      } catch (openRouterErr) {
        aiAvailable = false;

        console.error(
          '[AI CHAT] OpenRouter failed:',
          openRouterErr?.response?.data ||
          openRouterErr?.message ||
          openRouterErr
        );

        aiReply =
          'I could not get a response from the AI service right now. Your saved health and conversation data was not lost. Please try again shortly.';
      }

      let savedChat;

      try {
        savedChat =
          await saveChatHistory(
            userId,
            prompt,
            aiReply
          );

      } catch (historyError) {
        console.error(
          '[AI CHAT] Failed to save chat history:',
          historyError
        );

        return res.status(500).json({
          error:
            'AI response generated, but chat history could not be saved',

          details:
            historyError.message,
        });
      }

     const chatCard = {
  id: savedChat.id,

  userPrompt: prompt,

  aiResponse: aiReply,

  reply: aiReply,

  suggestedCard: {
    title: aiAvailable
      ? "Today's Personalized Recommendation"
      : 'AI Temporarily Unavailable',

    foodItem: aiAvailable
      ? "Based only on today's recorded meals, calories, sleep, mood, fasting, and profile data."
      : 'Your saved records remain available for the next AI request.',

    ironMg: todayTotals.ironMg.toFixed(1),

    proteinGrams:
      todayTotals.proteinGrams.toFixed(1),
  },

  createdAt: savedChat.createdAt,

  aiAvailable,

  contextUsed: {
    todayFoodLogs: todayFood.length,

    todaySleepLogs: todaySleep.length,

    todayMoodLogs: todayMood.length,

    previousChats: chatHistory.length,

    date: todayTotals.date,
  },
};

console.log(
  '[AI CHAT] FINAL RESPONSE TO FLUTTER:',
  JSON.stringify(chatCard, null, 2)
);

return res.status(200).json(chatCard);


    } catch (err) {
      console.error(
        '[AI CHAT] ERROR:',
        err
      );

      return res.status(500).json({
        error:
          'AI Assistant temporarily unavailable',

        details:
          err.message,
      });
    }
  }
);

// ============================================================
// GET /api/v1/ai/chat/history
// ============================================================

router.get(
  '/chat/history',
  authenticateToken,
  async (req, res) => {
    try {
      const userId = req.user.id;

      await ensureChatHistoryTable();

      const result =
        await db.execute(
          sql`
            SELECT
              id,
              user_prompt,
              ai_response,
              created_at
            FROM ai_chat_history
            WHERE user_id = ${userId}
            ORDER BY created_at ASC
          `
        );

      const rows =
        result?.rows || [];

      const history = [];

      for (const row of rows) {
        const createdAt =
          row.created_at
            ? new Date(
                row.created_at
              ).toISOString()
            : new Date().toISOString();

        history.push({
          id: row.id,
          sender: 'user',
          text: row.user_prompt,
          timestamp: createdAt,
        });

        history.push({
          id: `${row.id}-ai`,
          sender: 'ai',
          text: row.ai_response,
          timestamp: createdAt,
        });
      }

      return res.status(200).json({
        history,
        persisted: true,
        count: rows.length,
      });

    } catch (err) {
      console.error(
        '[AI CHAT HISTORY] ERROR:',
        err
      );

      return res.status(500).json({
        error:
          'Failed to retrieve AI chat history',

        details:
          err.message,
      });
    }
  }
);

// ============================================================
// DELETE /api/v1/ai/chat/history
// ============================================================

router.delete(
  '/chat/history',
  authenticateToken,
  async (req, res) => {
    try {
      const userId = req.user.id;

      await ensureChatHistoryTable();

      await db.execute(
        sql`
          DELETE FROM ai_chat_history
          WHERE user_id = ${userId}
        `
      );

      return res.status(200).json({
        message:
          'AI chat history deleted successfully',
      });

    } catch (err) {
      console.error(
        '[AI CHAT HISTORY DELETE] ERROR:',
        err
      );

      return res.status(500).json({
        error:
          'Failed to delete AI chat history',

        details:
          err.message,
      });
    }
  }
);

// ============================================================
// POST /api/v1/ai/smart-recommendations
// ============================================================

router.post(
  '/smart-recommendations',
  authenticateToken,
  async (req, res) => {
    try {
      const {
        ingredients = [
          'Chickpea Flour',
          'Onions',
          'Garlic',
          'Teff Injera',
        ],
      } = req.body;

      return res.status(200).json({
        ingredientsProvided:
          ingredients,

        recommendedRecipes: [
          {
            id: 'rec-1',

            title:
              'Quick Shiro Tegabino',

            prepTimeMinutes:
              15,

            difficulty:
              'Easy',

            isVegan:
              true,

            matchingIngredientsCount:
              4,

            instructions:
              'Sauté onions and garlic in olive oil, add berbere spice, whisk chickpea flour with water, simmer in a claypot for 12 mins. Serve hot with Teff Injera.',
          },

          {
            id: 'rec-2',

            title:
              'Suf Fitfit Dip',

            prepTimeMinutes:
              10,

            difficulty:
              'Easy',

            isVegan:
              true,

            matchingIngredientsCount:
              3,

            instructions:
              'Blend roasted sunflower seeds with warm water, green chilies, and garlic. Shred Teff Injera into pieces and toss into the creamy seed juice.',
          },
        ],
      });

    } catch (err) {
      console.error(
        '[SMART RECOMMENDATIONS] ERROR:',
        err
      );

      return res.status(500).json({
        error:
          'Failed to generate recommendations',

        details:
          err.message,
      });
    }
  }
);

// ============================================================
// EXPORT
// ============================================================

module.exports = router;