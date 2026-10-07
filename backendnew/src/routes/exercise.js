const express = require('express');
const router = express.Router();

const { authenticateToken } = require('../middleware/auth');
const { db } = require('../db');
const { exerciseLogs } = require('../db/schema');

const {
  eq,
  and,
  gte,
  lt,
  desc,
} = require('drizzle-orm');

// ============================================================
// GET EXERCISE PLAN
// GET /api/v1/exercise/plan
// ============================================================

router.get('/plan', authenticateToken, async (req, res) => {
  try {
    res.json({
      fastingAdaptedPlan: {
        intensityLevel: 'Gentle / Active Recovery (Adapted to Fasting)',

        recommendedWorkouts: [
          {
            id: 'w-1',
            name: 'Post-Iftar / Post-Fast Evening Walk',
            durationMinutes: 30,
            targetCalories: 120,
            notes: 'Ideal low-glycemic exercise',
          },
          {
            id: 'w-2',
            name: 'Gentle Mobility & Stretching',
            durationMinutes: 20,
            targetCalories: 80,
            notes: 'Promotes blood circulation without muscle stress',
          },
          {
            id: 'w-3',
            name: 'Core & Posture Routine',
            durationMinutes: 15,
            targetCalories: 90,
            notes: 'Perform 1 hour after breaking fast',
          },
        ],
      },
    });
  } catch (error) {
    console.error('Exercise plan error:', error);

    res.status(500).json({
      error: 'Failed to retrieve exercise plan',
    });
  }
});


// ============================================================
// LOG EXERCISE
// POST /api/v1/exercise/log
// ============================================================

router.post('/log', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const {
      workoutName,
      durationMinutes,
      caloriesBurned,
      intensity,
    } = req.body;

    // --------------------------------------------------------
    // Validate workout name
    // --------------------------------------------------------

    const cleanWorkoutName =
      typeof workoutName === 'string'
        ? workoutName.trim()
        : '';

    if (!cleanWorkoutName) {
      return res.status(400).json({
        error: 'Workout name is required',
      });
    }

    if (cleanWorkoutName.length > 255) {
      return res.status(400).json({
        error: 'Workout name must be 255 characters or less',
      });
    }

    // --------------------------------------------------------
    // Validate duration
    // --------------------------------------------------------

    const duration = Number(durationMinutes);

    if (
      !Number.isFinite(duration) ||
      duration <= 0 ||
      duration > 1440
    ) {
      return res.status(400).json({
        error: 'Duration must be a valid number between 1 and 1440 minutes',
      });
    }

    // --------------------------------------------------------
    // Validate calories
    // --------------------------------------------------------

    const calories = Number(caloriesBurned);

    if (
      !Number.isFinite(calories) ||
      calories < 0 ||
      calories > 100000
    ) {
      return res.status(400).json({
        error: 'Calories burned must be a valid non-negative number',
      });
    }

    // --------------------------------------------------------
    // Validate intensity
    // --------------------------------------------------------

    const allowedIntensities = [
      'Light',
      'Moderate',
      'High',
    ];

    const cleanIntensity =
      typeof intensity === 'string' &&
      allowedIntensities.includes(intensity)
        ? intensity
        : 'Moderate';

    // --------------------------------------------------------
    // Make sure authenticated user has an ID
    // --------------------------------------------------------

    if (!userId) {
      return res.status(401).json({
        error: 'Authenticated user ID is required',
      });
    }

    // --------------------------------------------------------
    // Insert into PostgreSQL using Drizzle
    // --------------------------------------------------------

    const [newLog] = await db
      .insert(exerciseLogs)
      .values({
        userId,
        workoutName: cleanWorkoutName,
        durationMinutes: Math.round(duration),
        caloriesBurned: calories,
        intensity: cleanIntensity,
      })
      .returning();

    console.log(
      `Exercise logged: ${userId} -> ${cleanWorkoutName}`
    );

    return res.status(201).json({
      message: 'Workout logged successfully',
      log: newLog,
    });

  } catch (error) {
    console.error('Exercise log error:', error);

    return res.status(500).json({
      error: 'Failed to log exercise',
    });
  }
});


// ============================================================
// GET TODAY'S EXERCISES
// GET /api/v1/exercise/today
// ============================================================

router.get('/today', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    if (!userId) {
      return res.status(401).json({
        error: 'Authenticated user ID is required',
      });
    }

    // --------------------------------------------------------
    // Start of today
    // --------------------------------------------------------

    const now = new Date();

    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);

    // --------------------------------------------------------
    // Start of tomorrow
    // --------------------------------------------------------

    const startOfTomorrow = new Date(startOfDay);
    startOfTomorrow.setDate(
      startOfTomorrow.getDate() + 1
    );

    // --------------------------------------------------------
    // Query only the authenticated user's exercises
    // --------------------------------------------------------

    const exercises = await db
      .select()
      .from(exerciseLogs)
      .where(
        and(
          eq(exerciseLogs.userId, userId),
          gte(exerciseLogs.loggedAt, startOfDay),
          lt(exerciseLogs.loggedAt, startOfTomorrow)
        )
      )
      .orderBy(
        desc(exerciseLogs.loggedAt)
      );

    // --------------------------------------------------------
    // Calculate today's totals
    // --------------------------------------------------------

    const totals = exercises.reduce(
      (acc, exercise) => {
        acc.durationMinutes += Number(
          exercise.durationMinutes || 0
        );

        acc.caloriesBurned += Number(
          exercise.caloriesBurned || 0
        );

        return acc;
      },
      {
        durationMinutes: 0,
        caloriesBurned: 0,
      }
    );

    return res.json({
      exercises,
      totals,
    });

  } catch (error) {
    console.error(
      'Today exercise retrieval error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to retrieve today exercise data',
    });
  }
});


// ============================================================
// GET ALL USER EXERCISES
// GET /api/v1/exercise/history
// ============================================================

router.get('/history', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    if (!userId) {
      return res.status(401).json({
        error: 'Authenticated user ID is required',
      });
    }

    const exercises = await db
      .select()
      .from(exerciseLogs)
      .where(
        eq(exerciseLogs.userId, userId)
      )
      .orderBy(
        desc(exerciseLogs.loggedAt)
      );

    return res.json({
      exercises,
    });

  } catch (error) {
    console.error(
      'Exercise history error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to retrieve exercise history',
    });
  }
});


// ============================================================
// DELETE EXERCISE
// DELETE /api/v1/exercise/:id
// ============================================================

router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const exerciseId = req.params.id;

    if (!userId) {
      return res.status(401).json({
        error: 'Authenticated user ID is required',
      });
    }

    if (!exerciseId) {
      return res.status(400).json({
        error: 'Exercise ID is required',
      });
    }

    // --------------------------------------------------------
    // Delete only if the exercise belongs to the user
    // --------------------------------------------------------

    const deleted = await db
      .delete(exerciseLogs)
      .where(
        and(
          eq(exerciseLogs.id, exerciseId),
          eq(exerciseLogs.userId, userId)
        )
      )
      .returning();

    if (deleted.length === 0) {
      return res.status(404).json({
        error: 'Exercise log not found',
      });
    }

    return res.json({
      message: 'Exercise log deleted successfully',
      log: deleted[0],
    });

  } catch (error) {
    console.error(
      'Exercise deletion error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to delete exercise log',
    });
  }
});


// ============================================================
// EXPORT ROUTER
// ============================================================

module.exports = router;