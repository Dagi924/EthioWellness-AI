const express = require('express');
const router = express.Router();

const { authenticateToken } = require('../middleware/auth');
const { db } = require('../db');
const { moodLogs } = require('../db/schema');

const {
  eq,
  and,
  gte,
  lt,
  desc,
} = require('drizzle-orm');


// ============================================================
// GET MOOD LOGS
// GET /api/v1/mood/logs
// ============================================================

router.get('/logs', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    if (!userId) {
      return res.status(401).json({
        error: 'Authenticated user ID is required',
      });
    }

    const logs = await db
      .select()
      .from(moodLogs)
      .where(
        eq(moodLogs.userId, userId)
      )
      .orderBy(
        desc(moodLogs.loggedAt)
      );

    return res.json({
      logs,
    });

  } catch (error) {
    console.error(
      'Mood logs retrieval error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to retrieve mood logs',
    });
  }
});


// ============================================================
// GET TODAY'S MOOD
// GET /api/v1/mood/today
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
    startOfDay.setHours(
      0,
      0,
      0,
      0
    );


    // --------------------------------------------------------
    // Start of tomorrow
    // --------------------------------------------------------

    const startOfTomorrow = new Date(
      startOfDay
    );

    startOfTomorrow.setDate(
      startOfTomorrow.getDate() + 1
    );


    // --------------------------------------------------------
    // Get today's mood logs
    // --------------------------------------------------------

    const logs = await db
      .select()
      .from(moodLogs)
      .where(
        and(
          eq(moodLogs.userId, userId),
          gte(
            moodLogs.loggedAt,
            startOfDay
          ),
          lt(
            moodLogs.loggedAt,
            startOfTomorrow
          )
        )
      )
      .orderBy(
        desc(moodLogs.loggedAt)
      );

    return res.json({
      logs,
    });

  } catch (error) {
    console.error(
      'Today mood retrieval error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to retrieve today mood data',
    });
  }
});


// ============================================================
// LOG MOOD
// POST /api/v1/mood/log
// ============================================================

router.post('/log', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    if (!userId) {
      return res.status(401).json({
        error: 'Authenticated user ID is required',
      });
    }

    const {
      mood,
      moodScore,
      note,
    } = req.body;


    // --------------------------------------------------------
    // Validate mood
    // --------------------------------------------------------

    const cleanMood =
      typeof mood === 'string'
        ? mood.trim()
        : '';

    if (!cleanMood) {
      return res.status(400).json({
        error: 'Mood is required',
      });
    }

    if (cleanMood.length > 50) {
      return res.status(400).json({
        error: 'Mood must be 50 characters or less',
      });
    }


    // --------------------------------------------------------
    // Validate mood score
    // --------------------------------------------------------

    const score = Number(moodScore);

    if (
      !Number.isInteger(score) ||
      score < 1 ||
      score > 5
    ) {
      return res.status(400).json({
        error:
          'Mood score must be an integer between 1 and 5',
      });
    }


    // --------------------------------------------------------
    // Validate note
    // --------------------------------------------------------

    const cleanNote =
      typeof note === 'string'
        ? note.trim()
        : null;

    if (
      cleanNote &&
      cleanNote.length > 2000
    ) {
      return res.status(400).json({
        error: 'Mood note must be 2000 characters or less',
      });
    }


    // --------------------------------------------------------
    // Insert mood log
    // --------------------------------------------------------

    const [newLog] = await db
      .insert(moodLogs)
      .values({
        userId,
        mood: cleanMood,
        moodScore: score,
        note: cleanNote || null,
      })
      .returning();

    console.log(
      `Mood logged: ${userId} -> ${cleanMood}`
    );

    return res.status(201).json({
      message: 'Mood logged successfully',
      log: newLog,
    });

  } catch (error) {
    console.error(
      'Mood log error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to save mood log',
    });
  }
});


// ============================================================
// DELETE MOOD
// DELETE /api/v1/mood/:id
// ============================================================

router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const moodId = req.params.id;

    if (!userId) {
      return res.status(401).json({
        error: 'Authenticated user ID is required',
      });
    }

    if (!moodId) {
      return res.status(400).json({
        error: 'Mood log ID is required',
      });
    }

    const deleted = await db
      .delete(moodLogs)
      .where(
        and(
          eq(moodLogs.id, moodId),
          eq(moodLogs.userId, userId)
        )
      )
      .returning();

    if (deleted.length === 0) {
      return res.status(404).json({
        error: 'Mood log not found',
      });
    }

    return res.json({
      message: 'Mood log deleted successfully',
      log: deleted[0],
    });

  } catch (error) {
    console.error(
      'Mood deletion error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to delete mood log',
    });
  }
});


// ============================================================
// EXPORT ROUTER
// ============================================================

module.exports = router;
