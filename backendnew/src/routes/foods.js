const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const upload = multer({
  dest: path.join(__dirname, '../../uploads/'),
  limits: {
    fileSize: 10 * 1024 * 1024,
  },
});

const {
  eq,
  and,
  desc,
  gte,
  lte,
} = require('drizzle-orm');

const { authenticateToken } = require('../middleware/auth');
const { db } = require('../db');
const { foodLogs, profiles } = require('../db/schema');

const { extractFood, loadFoods } = require('../../extract-food');

// ============================================================
// HELPERS
// ============================================================

function numberValue(value, fallback = 0) {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }

  const number = Number(value);

  return Number.isFinite(number) ? number : fallback;
}

function roundTo(value, decimalPlaces = 1) {
  const factor = 10 ** decimalPlaces;
  return Math.round((value + Number.EPSILON) * factor) / factor;
}

// ============================================================
// GET /api/v1/foods/search?query=
// Public food search.
// An empty query returns the first 20 foods.
// ============================================================

router.get('/foods/search', (req, res) => {
  try {
    const query = String(req.query.query || '').trim();

    const foods = query
      ? extractFood(query)
      : loadFoods().slice(0, 20);

    return res.status(200).json({
      success: true,
      query,
      total: foods.length,
      foods,
    });
  } catch (error) {
    console.error('FOOD SEARCH ERROR:', error);

    return res.status(500).json({
      success: false,
      message: 'Failed to search foods.',
    });
  }
});

// ============================================================
// GET /api/v1/food-logs/today
// ============================================================

router.get('/food-logs/today', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const now = new Date();

    const startOfDay = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
      0, 0, 0, 0
    );

    const endOfDay = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
      23, 59, 59, 999
    );

    const logs = await db
      .select()
      .from(foodLogs)
      .where(
        and(
          eq(foodLogs.userId, userId),
          gte(foodLogs.loggedAt, startOfDay),
          lte(foodLogs.loggedAt, endOfDay)
        )
      )
      .orderBy(desc(foodLogs.loggedAt));

    const totals = logs.reduce(
      (acc, log) => {
        // Water logs count toward hydration, not food nutrition.
        if (log.logType === 'water') {
          acc.waterMl += numberValue(log.waterMl);
          return acc;
        }

        acc.calories += numberValue(log.calories);
        acc.proteinGrams += numberValue(log.proteinGrams);
        acc.carbsGrams += numberValue(log.carbsGrams);
        acc.fatsGrams += numberValue(log.fatsGrams);

        // Use iron only if the database schema stores it.
        acc.ironMg += numberValue(log.ironMg);

        return acc;
      },
      {
        calories: 0,
        proteinGrams: 0,
        carbsGrams: 0,
        fatsGrams: 0,
        ironMg: 0,
        waterMl: 0,
      }
    );

    return res.status(200).json({
      success: true,
      date: [
        now.getFullYear(),
        String(now.getMonth() + 1).padStart(2, '0'),
        String(now.getDate()).padStart(2, '0'),
      ].join('-'),

      totals: {
        calories: Math.round(totals.calories),
        proteinGrams: roundTo(totals.proteinGrams),
        carbsGrams: roundTo(totals.carbsGrams),
        fatsGrams: roundTo(totals.fatsGrams),
        ironMg: roundTo(totals.ironMg, 2),
        waterMl: Math.round(totals.waterMl),
      },

      logs,
    });
  } catch (err) {
    console.error('GET TODAY FOOD LOGS ERROR:', err);

    return res.status(500).json({
      error: 'Failed to retrieve today logs.',
    });
  }
});

// ============================================================
// POST /api/v1/food-logs/manual
// ============================================================

router.post('/food-logs/manual', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const {
      foodName,
      portionGrams,
      calories,
      proteinGrams,
      carbsGrams,
      fatsGrams,
      ironMg,
      mealType,
      foodId,
      isVegan,
    } = req.body;

    if (
      typeof foodName !== 'string' ||
      !foodName.trim() ||
      calories === undefined ||
      !Number.isFinite(Number(calories)) ||
      Number(calories) < 0
    ) {
      return res.status(400).json({
        error: 'A valid foodName and non-negative calories are required.',
      });
    }

    const portion = numberValue(portionGrams, 150);

    if (portion <= 0) {
      return res.status(400).json({
        error: 'portionGrams must be greater than zero.',
      });
    }

    const logValues = {
      userId,
      foodName: foodName.trim(),
      portionGrams: portion,
      calories: numberValue(calories),
      proteinGrams: numberValue(proteinGrams),
      carbsGrams: numberValue(carbsGrams),
      fatsGrams: numberValue(fatsGrams),
      waterMl: 0,
      logType: 'manual',
      loggedAt: new Date(),
    };

    /*
     * IMPORTANT:
     * Add ironMg, mealType, foodId and isVegan here only after
     * confirming those columns exist in src/db/schema.js and
     * in your actual database.
     *
     * Otherwise Drizzle may reject this insert.
     */

    const [newLog] = await db
      .insert(foodLogs)
      .values(logValues)
      .returning();

    return res.status(201).json({
      success: true,
      message: 'Meal logged successfully.',
      log: newLog,
    });
  } catch (err) {
    console.error('MANUAL FOOD LOG ERROR:', err);

    return res.status(500).json({
      error: 'Failed to log meal.',
    });
  }
});

// ============================================================
// POST /api/v1/food-logs/water
// ============================================================

router.post('/food-logs/water', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const amountMl = Number(req.body.amountMl);

    if (!Number.isFinite(amountMl) || amountMl <= 0) {
      return res.status(400).json({
        error: 'amountMl must be a positive number.',
      });
    }

    const [waterLog] = await db
      .insert(foodLogs)
      .values({
        userId,
        foodName: 'Water Hydration',
        portionGrams: amountMl,
        calories: 0,
        proteinGrams: 0,
        carbsGrams: 0,
        fatsGrams: 0,
        waterMl: amountMl,
        logType: 'water',
        loggedAt: new Date(),
      })
      .returning();

    return res.status(201).json({
      success: true,
      message: `Water intake updated (+${amountMl}ml).`,
      log: waterLog,
    });
  } catch (err) {
    console.error('WATER LOG ERROR:', err);

    return res.status(500).json({
      error: 'Failed to log water.',
    });
  }
});

// ============================================================
// POST /api/v1/food-logs/scan
// Multipart form field: image
// Alternatively, JSON/form field: imageUrl
// ============================================================

router.post(
  '/food-logs/scan',
  authenticateToken,
  upload.single('image'),
  async (req, res) => {
    try {
      const userId = req.user.id;

      const profileResult = await db
        .select()
        .from(profiles)
        .where(eq(profiles.userId, userId))
        .limit(1);

      const profile = profileResult[0] || {};

      const imageInput =
        req.body.imageUrl ||
        (req.file ? req.file.path : null);

      if (!imageInput) {
        return res.status(400).json({
          error: 'Provide an image file or imageUrl.',
        });
      }

      let aiAnalysis;

      try {
        const {
          analyzeMealImageWithAI,
        } = require('../services/openrouter_service');

        if (typeof analyzeMealImageWithAI === 'function') {
          aiAnalysis = await analyzeMealImageWithAI(
            imageInput,
            profile
          );
        }
      } catch (error) {
        console.error('MEAL IMAGE AI ERROR:', error.message);
      }

      if (!aiAnalysis || !aiAnalysis.foodName) {
        return res.status(503).json({
          error: 'Meal image analysis is unavailable or did not identify a food. No food log was created.',
        });
      }

      const calories = numberValue(aiAnalysis.calories, NaN);

      if (!Number.isFinite(calories) || calories < 0) {
        return res.status(502).json({
          error: 'AI returned invalid nutrition data. No food log was created.',
        });
      }

      const [recognizedDish] = await db
        .insert(foodLogs)
        .values({
          userId,
          foodName: String(aiAnalysis.foodName),
          portionGrams: numberValue(aiAnalysis.portionGrams, 250),
          calories,
          proteinGrams: numberValue(aiAnalysis.proteinGrams),
          carbsGrams: numberValue(aiAnalysis.carbsGrams),
          fatsGrams: numberValue(aiAnalysis.fatsGrams),
          waterMl: 0,
          logType: 'scan',
          loggedAt: new Date(),
        })
        .returning();

      return res.status(201).json({
        success: true,
        message: 'Meal recognized and logged.',
        log: recognizedDish,
      });
    } catch (err) {
      console.error('SCAN MEAL ERROR:', err);

      return res.status(500).json({
        error: 'Failed to process meal scan.',
      });
    } finally {
      // Remove temporary uploads after analysis.
      if (req.file?.path) {
        fs.promises.unlink(req.file.path).catch((error) => {
          console.error('TEMP IMAGE CLEANUP ERROR:', error.message);
        });
      }
    }
  }
);

// ============================================================
// DELETE /api/v1/food-logs/:id
// Users can delete only their own logs.
// ============================================================

router.delete('/food-logs/:id', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const logId = req.params.id;

    const [deleted] = await db
      .delete(foodLogs)
      .where(
        and(
          eq(foodLogs.id, logId),
          eq(foodLogs.userId, userId)
        )
      )
      .returning();

    if (!deleted) {
      return res.status(404).json({
        error: 'Food log not found.',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Food log deleted successfully.',
      deletedId: logId,
    });
  } catch (err) {
    console.error('DELETE FOOD LOG ERROR:', err);

    return res.status(500).json({
      error: 'Failed to delete food log.',
    });
  }
});

module.exports = router;
