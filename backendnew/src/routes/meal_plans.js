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

  const yearStart = new Date(d.getFullYear(), 0, 1);

  const weekNumber = Math.ceil(
    ((d - yearStart) / 86400000 + 1) / 7
  );

  return `${d.getFullYear()}-W${String(weekNumber).padStart(2, '0')}`;
}

/**
 * ============================================================
 * VALID WEEK IDENTIFIER
 * ============================================================
 */

function isValidWeekIdentifier(value) {
  return /^\d{4}-W(?:0[1-9]|[1-4]\d|5[0-3])$/.test(value);
}

/**
 * ============================================================
 * USER PROFILE
 * ============================================================
 *
 * There is intentionally NO fallback profile.
 *
 * AI generation uses the authenticated user's real
 * database profile.
 */

async function getUserProfile(userId) {
  const profileResult = await db
    .select()
    .from(profiles)
    .where(eq(profiles.userId, userId))
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
 * GROCERY ITEM VALIDATION
 * ============================================================
 *
 * Grocery items still need a minimum usable structure because
 * they are inserted into the groceryItems database table.
 */

function validateGroceryItem(item) {
  if (
    !item ||
    typeof item !== 'object' ||
    Array.isArray(item)
  ) {
    return false;
  }

  if (
    typeof item.name !== 'string' ||
    item.name.trim().length === 0
  ) {
    return false;
  }

  if (
    item.category !== undefined &&
    typeof item.category !== 'string'
  ) {
    return false;
  }

  if (
    item.quantity !== undefined &&
    typeof item.quantity !== 'string' &&
    typeof item.quantity !== 'number'
  ) {
    return false;
  }

  if (
    item.estimatedPriceEtb !== undefined &&
    (
      typeof item.estimatedPriceEtb !== 'number' ||
      !Number.isFinite(item.estimatedPriceEtb) ||
      item.estimatedPriceEtb < 0
    )
  ) {
    return false;
  }

  return true;
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
      const userId = req.user.id;

      const requestedWeek =
        !req.query.week ||
        req.query.week === 'current'
          ? getWeekIdentifier()
          : String(req.query.week).trim();

      if (!isValidWeekIdentifier(requestedWeek)) {
        return res.status(400).json({
          error: 'Invalid week identifier.',
        });
      }

      const existing = await db
        .select()
        .from(mealPlans)
        .where(
          and(
            eq(mealPlans.userId, userId),
            eq(
              mealPlans.weekIdentifier,
              requestedWeek
            )
          )
        )
        .limit(1);

      if (existing.length > 0) {
        return res.status(200).json({
          message: 'Meal plan retrieved successfully',
          plan: existing[0],
        });
      }

      return res.status(404).json({
        error: 'No meal plan exists for this week.',
        weekIdentifier: requestedWeek,
      });
    } catch (err) {
      console.error(
        'GET WEEKLY MEAL PLAN ERROR:',
        err
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
 *
 * IMPORTANT:
 *
 * The meal and exercise AI results are intentionally accepted
 * without structural validation.
 *
 * This is the temporary SOFT mode.
 *
 * The AI service decides what to return.
 * This route simply saves whatever it receives.
 */

router.post(
  '/meal-plans/generate',
  authenticateToken,
  async (req, res) => {
    try {
      const userId = req.user.id;
      const weekIdentifier = getWeekIdentifier();

      /**
       * --------------------------------------------------------
       * REAL USER PROFILE
       * --------------------------------------------------------
       */

      const profile = await getUserProfile(userId);

      /**
       * --------------------------------------------------------
       * REAL FASTING INFORMATION
       * --------------------------------------------------------
       */

      const fastingRule =
        await calculateDailyFastingRule(profile);

      /**
       * --------------------------------------------------------
       * VERIFY AI SERVICES
       * --------------------------------------------------------
       */

      if (
        typeof generateMealPlanWithAI !== 'function'
      ) {
        throw new Error(
          'generateMealPlanWithAI is not available.'
        );
      }

      if (
        typeof generateExercisePlanWithAI !== 'function'
      ) {
        throw new Error(
          'generateExercisePlanWithAI is not available.'
        );
      }

      /**
       * --------------------------------------------------------
       * GENERATE MEAL PLAN
       * --------------------------------------------------------
       *
       * SOFT MODE:
       *
       * Do NOT validate the returned structure.
       * Do NOT require planDays.
       * Do NOT require meals.
       * Do NOT require calories.
       * Do NOT require mealType.
       *
       * Whatever the AI service returns is accepted.
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
        '[Meal Plans] Meal AI result accepted in SOFT mode:',
        typeof mealPlan
      );

      /**
       * --------------------------------------------------------
       * GENERATE EXERCISE PLAN
       * --------------------------------------------------------
       *
       * SOFT MODE:
       *
       * No structure validation.
       * Whatever the AI returns is accepted.
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
        '[Meal Plans] Exercise AI result accepted in SOFT mode:',
        typeof exercisePlan
      );

      /**
       * --------------------------------------------------------
       * COMBINE
       * --------------------------------------------------------
       *
       * Keep the AI outputs exactly as returned.
       *
       * This means:
       *
       * object -> object
       * array  -> array
       * string -> string
       * number -> number
       * boolean -> boolean
       *
       * PostgreSQL JSONB can store all of these as JSON values.
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

      const inserted = await db.transaction(
        async (tx) => {
          await tx
            .delete(mealPlans)
            .where(
              and(
                eq(mealPlans.userId, userId),
                eq(
                  mealPlans.weekIdentifier,
                  weekIdentifier
                )
              )
            );

          const result = await tx
            .insert(mealPlans)
            .values({
              userId,
              weekIdentifier,
              planData: combinedPlan,
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

        plan: inserted,

        profile,

        fastingRule,

        mealPlan,

        exercisePlan,
      });
    } catch (err) {
      console.error(
        'GENERATE PERSONALIZED MEAL/EXERCISE PLAN ERROR:',
        err
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
 */

router.get(
  '/grocery/list',
  authenticateToken,
  async (req, res) => {
    try {
      const userId = req.user.id;

      const items = await db
        .select()
        .from(groceryItems)
        .where(
          eq(groceryItems.userId, userId)
        );

      const estimatedTotal = items.reduce(
        (acc, item) => {
          const price =
            Number(item.estimatedPriceEtb);

          return (
            acc +
            (
              Number.isFinite(price)
                ? price
                : 0
            )
          );
        },
        0
      );

      return res.status(200).json({
        totalItems: items.length,

        estimatedTotalEtb:
          Math.round(
            estimatedTotal * 100
          ) / 100,

        items,
      });
    } catch (err) {
      console.error(
        'GET GROCERY LIST ERROR:',
        err
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
 * Grocery generation uses the saved personalized meal plan.
 */

router.post(
  '/grocery/generate',
  authenticateToken,
  async (req, res) => {
    try {
      const userId = req.user.id;
      const weekIdentifier =
        getWeekIdentifier();

      /**
       * --------------------------------------------------------
       * GET ACTIVE MEAL PLAN
       * --------------------------------------------------------
       */

      const plans = await db
        .select()
        .from(mealPlans)
        .where(
          and(
            eq(mealPlans.userId, userId),
            eq(
              mealPlans.weekIdentifier,
              weekIdentifier
            )
          )
        )
        .limit(1);

      if (plans.length === 0) {
        return res.status(404).json({
          error:
            'Generate a meal plan before generating a grocery list.',
        });
      }

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
       * GENERATE FROM SAVED PLAN
       * --------------------------------------------------------
       */

      const generatedItems =
        await generateGroceryListWithAI(
          plans[0].planData
        );

      /**
       * Grocery generation still needs an array because
       * groceryItems is a relational table.
       */

      if (
        !Array.isArray(generatedItems) ||
        generatedItems.length === 0
      ) {
        throw new Error(
          'AI returned an empty grocery list.'
        );
      }

      /**
       * --------------------------------------------------------
       * VALIDATE GROCERY ITEMS
       * --------------------------------------------------------
       */

      const validItems =
        generatedItems.filter(
          validateGroceryItem
        );

      if (
        validItems.length !==
        generatedItems.length
      ) {
        throw new Error(
          'AI returned invalid grocery item data.'
        );
      }

      /**
       * --------------------------------------------------------
       * NORMALIZE SAFE VALUES
       * --------------------------------------------------------
       */

      const values = validItems.map(
        (item) => {
          const price =
            Number(
              item.estimatedPriceEtb
            );

          return {
            userId,

            name:
              item.name.trim(),

            category:
              typeof item.category === 'string'
                ? item.category.trim()
                : 'General',

            quantity:
              item.quantity !== undefined
                ? String(item.quantity).trim()
                : '',

            estimatedPriceEtb:
              Number.isFinite(price) &&
              price >= 0
                ? price
                : 0,

            isChecked: false,
          };
        }
      );

      /**
       * --------------------------------------------------------
       * REPLACE USER'S GROCERY LIST
       * --------------------------------------------------------
       */

      await db.transaction(
        async (tx) => {
          await tx
            .delete(groceryItems)
            .where(
              eq(
                groceryItems.userId,
                userId
              )
            );

          await tx
            .insert(groceryItems)
            .values(values);
        }
      );

      /**
       * --------------------------------------------------------
       * READ BACK SAVED DATA
       * --------------------------------------------------------
       */

      const inserted =
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
        inserted.reduce(
          (acc, item) => {
            const price =
              Number(
                item.estimatedPriceEtb
              );

            return (
              acc +
              (
                Number.isFinite(price)
                  ? price
                  : 0
              )
            );
          },
          0
        );

      return res.status(201).json({
        message:
          'Grocery list generated from active personalized meal plan',

        totalItems:
          inserted.length,

        estimatedTotalEtb:
          Math.round(
            estimatedTotal * 100
          ) / 100,

        items: inserted,
      });
    } catch (err) {
      console.error(
        'GENERATE GROCERY ERROR:',
        err
      );

      return res.status(500).json({
        error:
          'Failed to generate grocery list',
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
 */

router.patch(
  '/grocery/items/:id',
  authenticateToken,
  async (req, res) => {
    try {
      const userId = req.user.id;

      const itemId = String(
        req.params.id
      );

      const {
        isChecked,
        quantity,
      } = req.body || {};

      const updateData = {};

      if (
        typeof isChecked === 'boolean'
      ) {
        updateData.isChecked =
          isChecked;
      }

      if (
        quantity !== undefined &&
        quantity !== null
      ) {
        const normalizedQuantity =
          String(quantity).trim();

        if (
          normalizedQuantity.length === 0
        ) {
          return res.status(400).json({
            error:
              'Quantity cannot be empty.',
          });
        }

        if (
          normalizedQuantity.length > 255
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
        Object.keys(updateData).length === 0
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

        item: updated,
      });
    } catch (err) {
      console.error(
        'UPDATE GROCERY ITEM ERROR:',
        err
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
      const userId = req.user.id;

      const itemId = String(
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

        item: deleted,
      });
    } catch (err) {
      console.error(
        'DELETE GROCERY ITEM ERROR:',
        err
      );

      return res.status(500).json({
        error:
          'Failed to delete grocery item',
      });
    }
  }
);

module.exports = router;
