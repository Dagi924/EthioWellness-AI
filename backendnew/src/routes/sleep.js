
const express = require('express');
const router = express.Router();

const { authenticateToken } = require('../middleware/auth');
const { db } = require('../db');
const { sleepLogs } = require('../db/schema');

const {
  eq,
  and,
  desc,
} = require('drizzle-orm');


// ============================================================
// GET SLEEP LOGS
// GET /api/v1/sleep/logs
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
      .from(sleepLogs)
      .where(
        eq(sleepLogs.userId, userId)
      )
      .orderBy(
        desc(sleepLogs.sleepDate)
      );

    return res.json({
      logs,
    });

  } catch (error) {
    console.error(
      'Sleep logs retrieval error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to retrieve sleep logs',
    });
  }
});


// ============================================================
// GET TODAY'S SLEEP
// GET /api/v1/sleep/today
// ============================================================

router.get('/today', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    if (!userId) {
      return res.status(401).json({
        error: 'Authenticated user ID is required',
      });
    }
const today = new Intl.DateTimeFormat(
  'en-CA',
  {
    timeZone: 'Africa/Addis_Ababa',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }
).format(new Date());

    const [log] = await db
      .select()
      .from(sleepLogs)
      .where(
        and(
          eq(sleepLogs.userId, userId),
          eq(sleepLogs.sleepDate, today)
        )
      )
      .limit(1);

    return res.json({
      log: log || null,
    });

  } catch (error) {
    console.error(
      'Today sleep retrieval error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to retrieve today sleep data',
    });
  }
});


// ============================================================
// LOG SLEEP
// POST /api/v1/sleep/log
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
      sleepDate,
      bedtime,
      wakeTime,
      durationMinutes,
      quality,
      notes,
    } = req.body;


    // --------------------------------------------------------
    // Validate sleep date
    // --------------------------------------------------------

    if (
      typeof sleepDate !== 'string' ||
      !sleepDate.trim()
    ) {
      return res.status(400).json({
        error: 'Sleep date is required',
      });
    }

    const cleanSleepDate = sleepDate.trim();

    if (!/^\d{4}-\d{2}-\d{2}$/.test(cleanSleepDate)) {
      return res.status(400).json({
        error: 'Sleep date must use YYYY-MM-DD format',
      });
    }


    // --------------------------------------------------------
    // Validate bedtime
    // --------------------------------------------------------

    if (!bedtime) {
      return res.status(400).json({
        error: 'Bedtime is required',
      });
    }

    const parsedBedtime = new Date(bedtime);

    if (Number.isNaN(parsedBedtime.getTime())) {
      return res.status(400).json({
        error: 'Invalid bedtime',
      });
    }


    // --------------------------------------------------------
    // Validate wake time
    // --------------------------------------------------------

    if (!wakeTime) {
      return res.status(400).json({
        error: 'Wake time is required',
      });
    }

    const parsedWakeTime = new Date(wakeTime);

    if (Number.isNaN(parsedWakeTime.getTime())) {
      return res.status(400).json({
        error: 'Invalid wake time',
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
        error:
          'Duration must be a valid number between 1 and 1440 minutes',
      });
    }


    // --------------------------------------------------------
    // Validate sleep quality
    // --------------------------------------------------------

    const sleepQuality = Number(
      quality ?? 3
    );

    if (
      !Number.isInteger(sleepQuality) ||
      sleepQuality < 1 ||
      sleepQuality > 5
    ) {
      return res.status(400).json({
        error:
          'Sleep quality must be an integer between 1 and 5',
      });
    }


    // --------------------------------------------------------
    // Validate notes
    // --------------------------------------------------------

    const cleanNotes =
      typeof notes === 'string'
        ? notes.trim()
        : null;


    // --------------------------------------------------------
    // Check if sleep already exists for this date
    // --------------------------------------------------------

    const [existing] = await db
      .select()
      .from(sleepLogs)
      .where(
        and(
          eq(sleepLogs.userId, userId),
          eq(
            sleepLogs.sleepDate,
            cleanSleepDate
          )
        )
      )
      .limit(1);


    // --------------------------------------------------------
    // Update existing sleep
    // --------------------------------------------------------

    if (existing) {
      const [updatedLog] = await db
        .update(sleepLogs)
        .set({
          bedtime: parsedBedtime,
          wakeTime: parsedWakeTime,
          durationMinutes: Math.round(duration),
          quality: sleepQuality,
          notes: cleanNotes || null,
        })
        .where(
          and(
            eq(sleepLogs.id, existing.id),
            eq(sleepLogs.userId, userId)
          )
        )
        .returning();

      console.log(
        `Sleep updated: ${userId} -> ${cleanSleepDate}`
      );

      return res.status(200).json({
        message: 'Sleep log updated successfully',
        log: updatedLog,
      });
    }


    // --------------------------------------------------------
    // Create new sleep log
    // --------------------------------------------------------

    const [newLog] = await db
      .insert(sleepLogs)
      .values({
        userId,
        sleepDate: cleanSleepDate,
        bedtime: parsedBedtime,
        wakeTime: parsedWakeTime,
        durationMinutes: Math.round(duration),
        quality: sleepQuality,
        notes: cleanNotes || null,
      })
      .returning();

    console.log(
      `Sleep logged: ${userId} -> ${cleanSleepDate}`
    );

    return res.status(201).json({
      message: 'Sleep logged successfully',
      log: newLog,
    });

  } catch (error) {
    console.error(
      'Sleep log error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to save sleep log',
    });
  }
});


// ============================================================
// DELETE SLEEP
// DELETE /api/v1/sleep/:id
// ============================================================

router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const sleepId = req.params.id;

    if (!userId) {
      return res.status(401).json({
        error: 'Authenticated user ID is required',
      });
    }

    if (!sleepId) {
      return res.status(400).json({
        error: 'Sleep log ID is required',
      });
    }

    const deleted = await db
      .delete(sleepLogs)
      .where(
        and(
          eq(sleepLogs.id, sleepId),
          eq(sleepLogs.userId, userId)
        )
      )
      .returning();

    if (deleted.length === 0) {
      return res.status(404).json({
        error: 'Sleep log not found',
      });
    }

    return res.json({
      message: 'Sleep log deleted successfully',
      log: deleted[0],
    });

  } catch (error) {
    console.error(
      'Sleep deletion error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to delete sleep log',
    });
  }
});


// ============================================================
// EXPORT ROUTER
// ============================================================

module.exports = router;
