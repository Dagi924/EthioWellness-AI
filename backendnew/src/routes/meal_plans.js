
const express = require('express');
const router = express.Router();

const { eq, and } = require('drizzle-orm');

const { authenticateToken } = require('../middleware/auth');
const { db } = require('../db');

const {
  profiles,
  mealPlans,
  groceryItems,
} = require('../db/schema');

const {
  calculateDailyFastingRule,
} = require('../services/fasting_engine');

const {
  generateMealPlanWithAI,
  generateExercisePlanWithAI,
  generateGroceryListWithAI,
} = require('../services/openrouter_service');

/**
 * ============================================================
 * WEEK IDENTIFIER
 * ============================================================
 */

function getWeekIdentifier(date = new Date()) {
  const d = new Date(date);

  if (Number.isNaN(d.getTime())) {
    throw new Error('Invalid date.');
  }

  const day = d.getDay() || 7;

  d.setDate(d.getDate() + 4 - day);

  const yearStart = new Date(
    d.getFullYear(),
    0,
    1
  );

  const weekNumber = Math.ceil(
    ((d - yearStart) / 86400000 + 1) / 7
  );

  return `${d.getFullYear()}-W${String(
    weekNumber
  ).padStart(2, '0')}`;
}

/**
 * ============================================================
 * VALID WEEK IDENTIFIER
 * ============================================================
 */

function isValidWeekIdentifier(value) {
  return /^\d{4}-W(?:0[1-9]|[1-4]\d|5[0-3])$/.test(
    value
  );
}

/**
 * ============================================================
 * USER PROFILE
 * ============================================================
 */

async function getUserProfile(userId) {
  const profileResult = await db
    .select()
    .from(profiles)
    .where(
      eq(
        profiles.userId,
        userId
      )
    )
    .limit(1);

  if (profileResult.length === 0) {
    const error = new Error(
      'User profile is required before generating a personalized plan.'
    );

    error.statusCode = 404;

    throw error;
  }

  return profileResult[0];
}

/**
 * ============================================================
 * SAFE VALUE DECODER
 * ============================================================
 *
 * Used only for extracting the saved meal plan.
 *
 * Grocery generation itself does NOT use JSON parsing.
 */

function decodePossibleJson(value) {
  if (typeof value !== 'string') {
    return value;
  }

  const text = value.trim();

  if (!text) {
    return '';
  }

  try {
    return JSON.parse(text);
  } catch (_) {
    return text;
  }
}

/**
 * ============================================================
 * EXTRACT ONLY MEAL PLAN
 * ============================================================
 *
 * The database stores:
 *
 * {
 *   mealPlan: ...,
 *   exercisePlan: ...
 * }
 *
 * Grocery generation must NEVER send exercisePlan.
 */

function extractMealPlan(planData) {
  let current =
    decodePossibleJson(
      planData
    );

  /**
   * ----------------------------------------------------------
   * Direct mealPlan
   * ----------------------------------------------------------
   */

  if (
    current &&
    typeof current === 'object' &&
    !Array.isArray(current) &&
    Object.prototype.hasOwnProperty.call(
      current,
      'mealPlan'
    )
  ) {
    return extractMealPlan(
      current.mealPlan
    );
  }

  /**
   * ----------------------------------------------------------
   * Nested planData
   * ----------------------------------------------------------
   */

  if (
    current &&
    typeof current === 'object' &&
    !Array.isArray(current) &&
    Object.prototype.hasOwnProperty.call(
      current,
      'planData'
    )
  ) {
    return extractMealPlan(
      current.planData
    );
  }

  /**
   * ----------------------------------------------------------
   * Raw AI fields
   * ----------------------------------------------------------
   */

  if (
    current &&
    typeof current === 'object' &&
    !Array.isArray(current)
  ) {
    if (
      typeof current.rawAiText ===
      'string'
    ) {
      return current.rawAiText;
    }

    if (
      typeof current.rawAiResponse ===
      'string'
    ) {
      return current.rawAiResponse;
    }

    if (
      typeof current.text ===
      'string'
    ) {
      return current.text;
    }

    if (
      typeof current.content ===
      'string'
    ) {
      return current.content;
    }
  }

  /**
   * ----------------------------------------------------------
   * Otherwise preserve the meal plan.
   * ----------------------------------------------------------
   */

  return current;
}

/**
 * ============================================================
 * CONVERT MEAL PLAN TO SAFE AI INPUT
 * ============================================================
 *
 * This does NOT mean grocery output is JSON.
 *
 * We only serialize the saved meal plan if it is an object
 * because the AI needs to receive its contents.
 */

function mealPlanForAI(mealPlan) {
  if (
    typeof mealPlan ===
      'string'
  ) {
    return mealPlan;
  }

  try {
    return JSON.stringify(
      mealPlan,
      null,
      2
    );
  } catch (_) {
    return String(
      mealPlan
    );
  }
}

/**
 * ============================================================
 * GET WEEKLY MEAL PLAN
 * ============================================================
 *
 * GET /api/v1/meal-plans/weekly?week=current
 */

router.get(
  '/meal-plans/weekly',
  authenticateToken,
  async (req, res) => {
    try {
      const userId =
        req.user.id;

      const requestedWeek =
        !req.query.week ||
        req.query.week === 'current'
          ? getWeekIdentifier()
          : String(
              req.query.week
            ).trim();

      if (
        !isValidWeekIdentifier(
          requestedWeek
        )
      ) {
        return res.status(400).json({
          error:
            'Invalid week identifier.',
        });
      }

      const existing =
        await db
          .select()
          .from(mealPlans)
          .where(
            and(
              eq(
                mealPlans.userId,
                userId
              ),
              eq(
                mealPlans.weekIdentifier,
                requestedWeek
              )
            )
          )
          .limit(1);

      if (
        existing.length > 0
      ) {
        return res.status(200).json({
          message:
            'Meal plan retrieved successfully',

          plan:
            existing[0],
        });
      }

      return res.status(404).json({
        error:
          'No meal plan exists for this week.',

        weekIdentifier:
          requestedWeek,
      });
    } catch (err) {
      console.error(
        'GET WEEKLY MEAL PLAN ERROR:',
        err?.message || err
      );

      return res.status(
        err.statusCode || 500
      ).json({
        error:
          err.statusCode === 404
            ? err.message
            : 'Failed to retrieve meal plan',
      });
    }
  }
);

/**
 * ============================================================
 * GENERATE PERSONALIZED MEAL + EXERCISE PLAN
 * ============================================================
 *
 * POST /api/v1/meal-plans/generate
 */

router.post(
  '/meal-plans/generate',
  authenticateToken,
  async (req, res) => {
    try {
      const userId =
        req.user.id;

      const weekIdentifier =
        getWeekIdentifier();

      /**
       * --------------------------------------------------------
       * USER PROFILE
       * --------------------------------------------------------
       */

      const profile =
        await getUserProfile(
          userId
        );

      /**
       * --------------------------------------------------------
       * FASTING INFORMATION
       * --------------------------------------------------------
       */

      const fastingRule =
        await calculateDailyFastingRule(
          profile
        );

      /**
       * --------------------------------------------------------
       * VERIFY AI SERVICES
       * --------------------------------------------------------
       */

      if (
        typeof generateMealPlanWithAI !==
        'function'
      ) {
        throw new Error(
          'generateMealPlanWithAI is not available.'
        );
      }

      if (
        typeof generateExercisePlanWithAI !==
        'function'
      ) {
        throw new Error(
          'generateExercisePlanWithAI is not available.'
        );
      }

      /**
       * --------------------------------------------------------
       * MEAL PLAN
       * --------------------------------------------------------
       */

      console.log(
        `[Meal Plans] Generating meal plan for ${weekIdentifier}`
      );

      const mealPlan =
        await generateMealPlanWithAI({
          profile,
          fastingRule,
          userId,
          weekIdentifier,
        });

      console.log(
        '[Meal Plans] Meal AI result accepted:',
        typeof mealPlan
      );

      /**
       * --------------------------------------------------------
       * EXERCISE PLAN
       * --------------------------------------------------------
       */

      console.log(
        `[Meal Plans] Generating exercise plan for ${weekIdentifier}`
      );

      const exercisePlan =
        await generateExercisePlanWithAI({
          profile,
          fastingRule,
          userId,
          weekIdentifier,
        });

      console.log(
        '[Meal Plans] Exercise AI result accepted:',
        typeof exercisePlan
      );

      /**
       * --------------------------------------------------------
       * COMBINE
       * --------------------------------------------------------
       */

      const combinedPlan = {
        mealPlan,
        exercisePlan,
      };

      /**
       * --------------------------------------------------------
       * SAVE
       * --------------------------------------------------------
       */

      const inserted =
        await db.transaction(
          async (tx) => {
            await tx
              .delete(mealPlans)
              .where(
                and(
                  eq(
                    mealPlans.userId,
                    userId
                  ),
                  eq(
                    mealPlans.weekIdentifier,
                    weekIdentifier
                  )
                )
              );

            const result =
              await tx
                .insert(mealPlans)
                .values({
                  userId,
                  weekIdentifier,
                  planData:
                    combinedPlan,
                })
                .returning();

            if (!result[0]) {
              throw new Error(
                'Failed to save generated meal plan.'
              );
            }

            return result[0];
          }
        );

      /**
       * --------------------------------------------------------
       * RESPONSE
       * --------------------------------------------------------
       */

      return res.status(201).json({
        message:
          'Personalized meal and exercise plans generated successfully',

        plan:
          inserted,

        profile,

        fastingRule,

        mealPlan,

        exercisePlan,
      });
    } catch (err) {
      console.error(
        'GENERATE PERSONALIZED MEAL/EXERCISE PLAN ERROR:',
        err?.message || err
      );

      return res.status(
        err.statusCode || 500
      ).json({
        error:
          err.statusCode === 404
            ? err.message
            : 'Failed to generate personalized meal and exercise plan',
      });
    }
  }
);

/**
 * ============================================================
 * GET GROCERY LIST
 * ============================================================
 *
 * GET /api/v1/grocery/list
 *
 * NOTE:
 *
 * Grocery generation is now SOFT TEXT.
 *
 * This endpoint is kept for compatibility with the existing
 * database/frontend.
 */

router.get(
  '/grocery/list',
  authenticateToken,
  async (req, res) => {
    try {
      const userId =
        req.user.id;

      const items =
        await db
          .select()
          .from(groceryItems)
          .where(
            eq(
              groceryItems.userId,
              userId
            )
          );

      const estimatedTotal =
        items.reduce(
          (acc, item) => {
            const price =
              Number(
                item.estimatedPriceEtb
              );

            return (
              acc +
              (
                Number.isFinite(
                  price
                )
                  ? price
                  : 0
              )
            );
          },
          0
        );

      return res.status(200).json({
        totalItems:
          items.length,

        estimatedTotalEtb:
          Math.round(
            estimatedTotal * 100
          ) / 100,

        items,
      });
    } catch (err) {
      console.error(
        'GET GROCERY LIST ERROR:',
        err?.message || err
      );

      return res.status(500).json({
        error:
          'Failed to retrieve grocery list',
      });
    }
  }
);

/**
 * ============================================================
 * GENERATE GROCERY LIST
 * ============================================================
 *
 * POST /api/v1/grocery/generate
 *
 * NEW SOFT FLOW:
 *
 * 1. Get current week.
 * 2. Load saved meal plan.
 * 3. Extract ONLY mealPlan.
 * 4. Completely ignore exercisePlan.
 * 5. Send meal plan to AI.
 * 6. AI returns NORMAL TEXT.
 * 7. Return AI text directly.
 *
 * IMPORTANT:
 *
 * There is NO:
 *
 * JSON.parse()
 * items validation
 * price validation
 * groceryItems insertion
 * JSON schema requirement
 *
 * The grocery AI response is treated exactly like chatbot text.
 */

router.post(
  '/grocery/generate',
  authenticateToken,
  async (req, res) => {
    try {
      const userId =
        req.user.id;

      const weekIdentifier =
        getWeekIdentifier();

      console.log(
        `[Grocery] Generating grocery list for ${weekIdentifier}`
      );

      /**
       * --------------------------------------------------------
       * GET CURRENT WEEK MEAL PLAN
       * --------------------------------------------------------
       */

      const plans =
        await db
          .select()
          .from(mealPlans)
          .where(
            and(
              eq(
                mealPlans.userId,
                userId
              ),
              eq(
                mealPlans.weekIdentifier,
                weekIdentifier
              )
            )
          )
          .limit(1);

      if (
        plans.length === 0
      ) {
        return res.status(404).json({
          error:
            'Generate a meal plan before generating a grocery list.',
        });
      }

      /**
       * --------------------------------------------------------
       * EXTRACT ONLY MEAL PLAN
       * --------------------------------------------------------
       */

      const savedPlan =
        plans[0].planData;

      const mealPlan =
        extractMealPlan(
          savedPlan
        );

      if (
        mealPlan === null ||
        mealPlan === undefined ||
        (
          typeof mealPlan ===
            'string' &&
          mealPlan.trim().length === 0
        )
      ) {
        return res.status(400).json({
          error:
            'The current weekly meal plan contains no usable meal data.',
        });
      }

      /**
       * --------------------------------------------------------
       * SAFE LOGGING
       * --------------------------------------------------------
       */

      console.log(
        '[Grocery] Current meal plan extracted successfully.'
      );

      console.log(
        '[Grocery] Exercise plan excluded from grocery prompt.'
      );

      /**
       * --------------------------------------------------------
       * VERIFY AI SERVICE
       * --------------------------------------------------------
       */

      if (
        typeof generateGroceryListWithAI !==
        'function'
      ) {
        throw new Error(
          'generateGroceryListWithAI is not available.'
        );
      }

      /**
       * --------------------------------------------------------
       * PREPARE MEAL PLAN
       * --------------------------------------------------------
       */

      const aiMealPlan =
        mealPlanForAI(
          mealPlan
        );

      /**
       * --------------------------------------------------------
       * GENERATE PLAIN-TEXT GROCERY LIST
       * --------------------------------------------------------
       */

      const groceryText =
        await generateGroceryListWithAI({
          mealPlan:
            aiMealPlan,

          userId,

          weekIdentifier,
        });

      /**
       * --------------------------------------------------------
       * VERIFY TEXT
       * --------------------------------------------------------
       *
       * No JSON parsing.
       * No item validation.
       * No price validation.
       */

      if (
        typeof groceryText !==
        'string'
      ) {
        throw new Error(
          'AI grocery response was not text.'
        );
      }

      const cleanedText =
        groceryText.trim();

      if (
        cleanedText.length ===
        0
      ) {
        throw new Error(
          'AI returned an empty grocery list.'
        );
      }

      console.log(
        `[Grocery] Plain-text grocery list generated successfully (${cleanedText.length} characters).`
      );

      /**
       * --------------------------------------------------------
       * RETURN DIRECTLY
       * --------------------------------------------------------
       *
       * This is the important part.
       *
       * The frontend receives:
       *
       * groceryText
       *
       * and can display it directly.
       *
       * Nothing is converted into JSON grocery items.
       */

      return res.status(201).json({
        message:
          'Grocery list generated successfully.',

        weekIdentifier,

        groceryText:
          cleanedText,
      });

    } catch (err) {
      /**
       * IMPORTANT:
       *
       * Do not dump complete Axios/OpenRouter errors.
       *
       * They may contain authorization information.
       */

      console.error(
        'GENERATE GROCERY ERROR:',
        err?.message || err
      );

      return res.status(
        err.statusCode || 500
      ).json({
        error:
          err.statusCode
            ? err.message
            : 'Failed to generate grocery list',
      });
    }
  }
);

/**
 * ============================================================
 * UPDATE GROCERY ITEM
 * ============================================================
 *
 * PATCH /api/v1/grocery/items/:id
 *
 * Kept for compatibility with the existing structured grocery
 * database and older frontend.
 */

router.patch(
  '/grocery/items/:id',
  authenticateToken,
  async (req, res) => {
    try {
      const userId =
        req.user.id;

      const itemId =
        String(
          req.params.id
        );

      const {
        isChecked,
        quantity,
      } = req.body || {};

      const updateData = {};

      if (
        typeof isChecked ===
        'boolean'
      ) {
        updateData.isChecked =
          isChecked;
      }

      if (
        quantity !== undefined &&
        quantity !== null
      ) {
        const normalizedQuantity =
          String(
            quantity
          ).trim();

        if (
          normalizedQuantity.length ===
          0
        ) {
          return res.status(400).json({
            error:
              'Quantity cannot be empty.',
          });
        }

        if (
          normalizedQuantity.length >
          255
        ) {
          return res.status(400).json({
            error:
              'Quantity is too long.',
          });
        }

        updateData.quantity =
          normalizedQuantity;
      }

      if (
        Object.keys(
          updateData
        ).length === 0
      ) {
        return res.status(400).json({
          error:
            'No valid fields supplied for update.',
        });
      }

      const [updated] =
        await db
          .update(groceryItems)
          .set(updateData)
          .where(
            and(
              eq(
                groceryItems.id,
                itemId
              ),
              eq(
                groceryItems.userId,
                userId
              )
            )
          )
          .returning();

      if (!updated) {
        return res.status(404).json({
          error:
            'Grocery item not found',
        });
      }

      return res.status(200).json({
        message:
          'Grocery item updated',

        item:
          updated,
      });
    } catch (err) {
      console.error(
        'UPDATE GROCERY ITEM ERROR:',
        err?.message || err
      );

      return res.status(500).json({
        error:
          'Failed to update grocery item',
      });
    }
  }
);

/**
 * ============================================================
 * DELETE GROCERY ITEM
 * ============================================================
 *
 * DELETE /api/v1/grocery/items/:id
 */

router.delete(
  '/grocery/items/:id',
  authenticateToken,
  async (req, res) => {
    try {
      const userId =
        req.user.id;

      const itemId =
        String(
          req.params.id
        );

      const [deleted] =
        await db
          .delete(groceryItems)
          .where(
            and(
              eq(
                groceryItems.id,
                itemId
              ),
              eq(
                groceryItems.userId,
                userId
              )
            )
          )
          .returning();

      if (!deleted) {
        return res.status(404).json({
          error:
            'Grocery item not found',
        });
      }

      return res.status(200).json({
        message:
          'Grocery item deleted',

        item:
          deleted,
      });
    } catch (err) {
      console.error(
        'DELETE GROCERY ITEM ERROR:',
        err?.message || err
      );

      return res.status(500).json({
        error:
          'Failed to delete grocery item',
      });
    }
  }
);

/**
 * ============================================================
 * EXPORT ROUTER
 * ============================================================
 */

module.exports = router;
