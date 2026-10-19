const express = require('express');
const router = express.Router();

const { authenticateToken } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const { db } = require('../db');

const {
  users,
  profiles,
  nutritionists,
  appointments,
  supervisionMessages,
  sleepLogs,
  moodLogs,
} = require('../db/schema');

const { eq, and, desc, asc, inArray } = require('drizzle-orm');

// ============================================================
// NUTRITIONIST WORKING HOURS
// Addis Ababa time: 09:00–17:00
// Consultation duration: 30 minutes
// ============================================================

const WORK_START_HOUR = 9;
const WORK_END_HOUR = 17;
const APPOINTMENT_DURATION_MINUTES = 30;
const TIME_ZONE = 'Africa/Addis_Ababa';

function getAddisDateParts(date) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);

  const values = {};

  for (const part of parts) {
    if (part.type !== 'literal') {
      values[part.type] = part.value;
    }
  }

  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
    hour: Number(values.hour),
    minute: Number(values.minute),
    date: `${values.year}-${values.month}-${values.day}`,
  };
}

function isValidDateString(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value || '')) {
    return false;
  }

  const [year, month, day] = value.split('-').map(Number);

  const date = new Date(Date.UTC(year, month - 1, day));

  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day
  );
}

// Ethiopia uses UTC+03:00 year-round.
function addisSlotToUtc(dateString, hour, minute) {
  const [year, month, day] = dateString.split('-').map(Number);

  return new Date(
    Date.UTC(year, month - 1, day, hour - 3, minute)
  );
}

function isActiveAppointment(status) {
  return !['cancelled', 'canceled', 'rejected'].includes(
    String(status || '').toLowerCase()
  );
}

function overlaps(startA, endA, startB, endB) {
  return startA < endB && startB < endA;
}

/*
 * GET /api/v1/supervision/nutritionist/:id
 */

router.get('/nutritionist/:id', authenticateToken, async (req, res) => {
  try {
    const result = await db
      .select({
        id: nutritionists.id,
        userId: nutritionists.userId,
        name: users.name,
        email: users.email,
        credentials: nutritionists.credentials,
        bio: nutritionists.bio,
        specializations: nutritionists.specializations,
        hourlyRateEtb: nutritionists.hourlyRateEtb,
        isApproved: nutritionists.isApproved,
      })
      .from(nutritionists)
      .innerJoin(users, eq(nutritionists.userId, users.id))
      .where(eq(nutritionists.id, req.params.id))
      .limit(1);

    if (!result.length) {
      return res.status(404).json({
        error: 'Nutritionist not found',
      });
    }

    return res.json({
      nutritionist: {
        ...result[0],
        availableSlots: [
          '09:00 AM',
          '11:30 AM',
          '02:00 PM',
          '04:30 PM',
        ],
      },
    });
  } catch (error) {
    console.error('[SUPERVISION] Get nutritionist error:', error);

    return res.status(500).json({
      error: 'Failed to load nutritionist',
    });
  }
});

// ============================================================
// GET NUTRITIONIST AVAILABILITY FOR A SPECIFIC DATE
// ============================================================

router.get(
  '/nutritionists/:id/availability',
  authenticateToken,
  async (req, res) => {
    try {
      const { id } = req.params;
      const { date } = req.query;

      if (!isValidDateString(date)) {
        return res.status(400).json({
          success: false,
          error: 'A valid date is required in YYYY-MM-DD format',
        });
      }

      const nutritionistRows = await db
        .select({
          id: nutritionists.id,
          name: users.name,
          isApproved: nutritionists.isApproved,
        })
        .from(nutritionists)
        .innerJoin(
          users,
          eq(nutritionists.userId, users.id)
        )
        .where(eq(nutritionists.id, id))
        .limit(1);

      if (!nutritionistRows.length) {
        return res.status(404).json({
          success: false,
          error: 'Nutritionist not found',
        });
      }

      if (!nutritionistRows[0].isApproved) {
        return res.status(403).json({
          success: false,
          error: 'This nutritionist is not approved',
        });
      }

      const appointmentRows = await db
        .select({
          id: appointments.id,
          scheduledAt: appointments.scheduledAt,
          status: appointments.status,
        })
        .from(appointments)
        .where(
          eq(appointments.nutritionistId, id)
        );

      const now = new Date();
      const slots = [];

      for (
        let minutes = WORK_START_HOUR * 60;
        minutes + APPOINTMENT_DURATION_MINUTES <= WORK_END_HOUR * 60;
        minutes += APPOINTMENT_DURATION_MINUTES
      ) {
        const hour = Math.floor(minutes / 60);
        const minute = minutes % 60;

        const start = addisSlotToUtc(date, hour, minute);

        const end = new Date(
          start.getTime() +
          APPOINTMENT_DURATION_MINUTES * 60 * 1000
        );

        const booked = appointmentRows.some((appointment) => {
          if (!isActiveAppointment(appointment.status)) {
            return false;
          }

          const bookedStart = new Date(appointment.scheduledAt);

          const bookedEnd = new Date(
            bookedStart.getTime() +
            APPOINTMENT_DURATION_MINUTES * 60 * 1000
          );

          return overlaps(
            start.getTime(),
            end.getTime(),
            bookedStart.getTime(),
            bookedEnd.getTime()
          );
        });

        const available = start > now && !booked;

        slots.push({
          startTime: `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`,

          endTime: (() => {
            const endMinutes =
              minutes + APPOINTMENT_DURATION_MINUTES;

            const endHour = Math.floor(endMinutes / 60);
            const endMinute = endMinutes % 60;

            return `${String(endHour).padStart(2, '0')}:${String(endMinute).padStart(2, '0')}`;
          })(),

          scheduledAt: start.toISOString(),
          endsAt: end.toISOString(),
          available,

          status: booked
            ? 'booked'
            : start <= now
              ? 'past'
              : 'available',
        });
      }

      const availableSlots = slots.filter(
        (slot) => slot.available
      );

      return res.status(200).json({
        success: true,
        nutritionistId: id,
        nutritionistName: nutritionistRows[0].name,
        date,
        timeZone: TIME_ZONE,

        workingHours: {
          start: '09:00',
          end: '17:00',
        },

        appointmentDurationMinutes:
          APPOINTMENT_DURATION_MINUTES,

        availableSlots,
        allSlots: slots,
        availableCount: availableSlots.length,
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Availability check error:',
        error
      );

      return res.status(500).json({
        success: false,
        error: 'Failed to check nutritionist availability',
      });
    }
  }
);

// ============================================================
// POST /api/v1/supervision/appointments
// BOOK AN APPOINTMENT
// ============================================================

router.post(
  '/appointments',
  authenticateToken,
  requireRole('user'),
  async (req, res) => {
    try {
      const {
        nutritionistId,
        scheduledAt,
        notes,
      } = req.body || {};

      if (!nutritionistId || !scheduledAt) {
        return res.status(400).json({
          success: false,
          error: 'nutritionistId and scheduledAt are required',
        });
      }

      if (typeof scheduledAt !== 'string') {
        return res.status(400).json({
          success: false,
          error: 'scheduledAt must be an ISO date-time string',
        });
      }

      const appointmentDate = new Date(scheduledAt);

      if (Number.isNaN(appointmentDate.getTime())) {
        return res.status(400).json({
          success: false,
          error: 'Invalid scheduledAt date',
        });
      }

      const local = getAddisDateParts(appointmentDate);

      const minuteOfDay =
        local.hour * 60 + local.minute;

      const isOnSlotBoundary =
        local.minute === 0 || local.minute === 30;

      const fitsWorkingHours =
        minuteOfDay >= WORK_START_HOUR * 60 &&
        minuteOfDay + APPOINTMENT_DURATION_MINUTES <=
          WORK_END_HOUR * 60;

      if (!fitsWorkingHours || !isOnSlotBoundary) {
        return res.status(400).json({
          success: false,
          error:
            'Appointments must start on a 30-minute boundary between 09:00 and 16:30 Addis Ababa time',
        });
      }

      if (appointmentDate <= new Date()) {
        return res.status(400).json({
          success: false,
          error: 'Appointments must be scheduled in the future',
        });
      }

      const appointmentEnd = new Date(
        appointmentDate.getTime() +
        APPOINTMENT_DURATION_MINUTES * 60 * 1000
      );

      // Lock the nutritionist row inside the transaction so concurrent
      // bookings for this nutritionist are serialized through this endpoint.
      const inserted = await db.transaction(async (tx) => {
        const nutritionistRows = await tx
          .select({
            id: nutritionists.id,
            isApproved: nutritionists.isApproved,
          })
          .from(nutritionists)
          .where(eq(nutritionists.id, nutritionistId))
          .limit(1)
          .for('update');

        if (!nutritionistRows.length) {
          const error = new Error('Nutritionist not found');
          error.statusCode = 404;
          throw error;
        }

        if (!nutritionistRows[0].isApproved) {
          const error = new Error(
            'This nutritionist is not approved'
          );

          error.statusCode = 403;
          throw error;
        }

        const existingAppointments = await tx
          .select({
            id: appointments.id,
            scheduledAt: appointments.scheduledAt,
            status: appointments.status,
          })
          .from(appointments)
          .where(
            eq(appointments.nutritionistId, nutritionistId)
          );

        const conflict = existingAppointments.some(
          (appointment) => {
            if (!isActiveAppointment(appointment.status)) {
              return false;
            }

            const existingStart = new Date(
              appointment.scheduledAt
            );

            const existingEnd = new Date(
              existingStart.getTime() +
              APPOINTMENT_DURATION_MINUTES * 60 * 1000
            );

            return overlaps(
              appointmentDate.getTime(),
              appointmentEnd.getTime(),
              existingStart.getTime(),
              existingEnd.getTime()
            );
          }
        );

        if (conflict) {
          const error = new Error(
            'This time slot is already booked. Please choose another available time.'
          );

          error.statusCode = 409;
          throw error;
        }

        const rows = await tx
          .insert(appointments)
          .values({
            userId: req.user.id,
            nutritionistId,
            scheduledAt: appointmentDate,
            status: 'confirmed',

            notes:
              typeof notes === 'string' && notes.trim()
                ? notes.trim().slice(0, 2000)
                : 'Fasting nutrition optimization & iron target review',
          })
          .returning();

        return rows[0];
      });

      if (!inserted) {
        throw new Error(
          'Appointment insert returned no record'
        );
      }

      return res.status(201).json({
        success: true,
        message: 'Consultation appointment booked successfully',

        appointment: {
          ...inserted,

          scheduledAt: new Date(
            inserted.scheduledAt || appointmentDate
          ).toISOString(),

          endsAt: appointmentEnd.toISOString(),

          roomName: `ethionutri-room-${nutritionistId}`,
        },
      });
    } catch (error) {
      if (error.statusCode) {
        return res.status(error.statusCode).json({
          success: false,
          error: error.message,
        });
      }

      console.error(
        '[SUPERVISION] Create appointment error:',
        error
      );

      return res.status(500).json({
        success: false,
        error: 'Failed to create appointment',
      });
    }
  }
);

/*
 * POST /api/v1/supervision/consent
 *
 * Consent is not persisted because no consent table is currently used here.
 */

router.post(
  '/consent',
  authenticateToken,
  requireRole('user'),
  async (req, res) => {
    try {
      const {
        shareTelemetry,
        shareFastingCompliance,
        shareDeficiencyAlerts,
      } = req.body;

      return res.json({
        message:
          'Data privacy & clinical supervision consent preferences received',

        consent: {
          shareTelemetry:
            shareTelemetry !== undefined
              ? Boolean(shareTelemetry)
              : true,

          shareFastingCompliance:
            shareFastingCompliance !== undefined
              ? Boolean(shareFastingCompliance)
              : true,

          shareDeficiencyAlerts:
            shareDeficiencyAlerts !== undefined
              ? Boolean(shareDeficiencyAlerts)
              : true,
        },

        persisted: false,

        note:
          'Consent is not persisted because there is no consent table in the current database schema.',
      });
    } catch (error) {
      console.error('[SUPERVISION] Consent error:', error);

      return res.status(500).json({
        error: 'Failed to save consent preferences',
      });
    }
  }
);

/*
 * GET /api/v1/supervision/chat/history
 */

router.get(
  '/chat/history',
  authenticateToken,
  requireRole('user'),
  async (req, res) => {
    try {
      const messages = await db
        .select({
          id: supervisionMessages.id,
          userId: supervisionMessages.userId,
          nutritionistId: supervisionMessages.nutritionistId,
          senderRole: supervisionMessages.senderRole,
          message: supervisionMessages.message,
          mediaUrl: supervisionMessages.mediaUrl,
          sentAt: supervisionMessages.sentAt,
        })
        .from(supervisionMessages)
        .where(
          eq(supervisionMessages.userId, req.user.id)
        )
        .orderBy(
          asc(supervisionMessages.sentAt)
        );

      return res.json({ messages });
    } catch (error) {
      console.error(
        '[SUPERVISION] Chat history error:',
        error
      );

      return res.status(500).json({
        error: 'Failed to load chat history',
      });
    }
  }
);

/*
 * POST /api/v1/supervision/chat/send
 */

router.post(
  '/chat/send',
  authenticateToken,
  async (req, res) => {
    try {
      const senderId = req.user.id;
      const senderRole = req.user.role || 'user';

      const {
        userId,
        nutritionistId,
        message,
        mediaUrl,
      } = req.body;

      if (typeof message !== 'string' || !message.trim()) {
        return res.status(400).json({
          error: 'Message is required',
        });
      }

      if (message.trim().length > 5000) {
        return res.status(400).json({
          error: 'Message cannot exceed 5000 characters',
        });
      }

      let patientId;
      let targetNutritionistId;

      if (senderRole === 'user') {
        patientId = senderId;
        targetNutritionistId = nutritionistId;

        if (!targetNutritionistId) {
          return res.status(400).json({
            error: 'nutritionistId is required',
          });
        }

        const nutritionist = await db
          .select({
            id: nutritionists.id,
            isApproved: nutritionists.isApproved,
          })
          .from(nutritionists)
          .where(
            eq(nutritionists.id, targetNutritionistId)
          )
          .limit(1);

        if (!nutritionist.length) {
          return res.status(404).json({
            error: 'Nutritionist not found',
          });
        }

        if (!nutritionist[0].isApproved) {
          return res.status(403).json({
            error: 'This nutritionist is not currently approved',
          });
        }
      } else if (senderRole === 'nutritionist') {
        patientId = userId;

        if (!patientId) {
          return res.status(400).json({
            error:
              'userId is required when a nutritionist sends a message',
          });
        }

        const nutritionist = await db
          .select({
            id: nutritionists.id,
            isApproved: nutritionists.isApproved,
          })
          .from(nutritionists)
          .where(
            eq(nutritionists.userId, senderId)
          )
          .limit(1);

        if (!nutritionist.length) {
          return res.status(404).json({
            error: 'Nutritionist profile not found',
          });
        }

        if (!nutritionist[0].isApproved) {
          return res.status(403).json({
            error: 'Nutritionist account is not approved',
          });
        }

        targetNutritionistId = nutritionist[0].id;

        const patient = await db
          .select({
            id: users.id,
            role: users.role,
          })
          .from(users)
          .where(eq(users.id, patientId))
          .limit(1);

        if (!patient.length) {
          return res.status(404).json({
            error: 'Patient not found',
          });
        }

        if (patient[0].role !== 'user') {
          return res.status(400).json({
            error: 'Selected account is not a patient',
          });
        }
      } else {
        return res.status(403).json({
          error: 'Unauthorized chat role',
        });
      }

      const created = await db
        .insert(supervisionMessages)
        .values({
          userId: patientId,
          nutritionistId: targetNutritionistId,

          senderRole:
            senderRole === 'nutritionist'
              ? 'nutritionist'
              : 'user',

          message: message.trim(),
          mediaUrl: mediaUrl || null,
        })
        .returning();

      return res.status(201).json({
        message: created[0],
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Send chat error:',
        error
      );

      return res.status(500).json({
        error: 'Failed to send message',
      });
    }
  }
);

/*
 * GET /api/v1/supervision/messages/:nutritionistId
 */

router.get(
  '/messages/:nutritionistId',
  authenticateToken,
  requireRole('user'),
  async (req, res) => {
    try {
      const messages = await db
        .select({
          id: supervisionMessages.id,
          userId: supervisionMessages.userId,
          nutritionistId: supervisionMessages.nutritionistId,
          senderRole: supervisionMessages.senderRole,
          message: supervisionMessages.message,
          mediaUrl: supervisionMessages.mediaUrl,
          sentAt: supervisionMessages.sentAt,
        })
        .from(supervisionMessages)
        .where(
          and(
            eq(
              supervisionMessages.userId,
              req.user.id
            ),

            eq(
              supervisionMessages.nutritionistId,
              req.params.nutritionistId
            )
          )
        )
        .orderBy(
          asc(supervisionMessages.sentAt)
        );

      return res.json({ messages });
    } catch (error) {
      console.error(
        '[SUPERVISION] Patient messages error:',
        error
      );

      return res.status(500).json({
        error: 'Failed to load conversation',
      });
    }
  }
);

/*
 * POST /api/v1/supervision/messages
 */

router.post(
  '/messages',
  authenticateToken,
  requireRole('user'),
  async (req, res) => {
    try {
      const {
        nutritionistId,
        message,
        mediaUrl,
      } = req.body;

      if (!nutritionistId) {
        return res.status(400).json({
          error: 'Nutritionist ID is required',
        });
      }

      if (typeof message !== 'string' || !message.trim()) {
        return res.status(400).json({
          error: 'Message cannot be empty',
        });
      }

      if (message.trim().length > 5000) {
        return res.status(400).json({
          error: 'Message cannot exceed 5000 characters',
        });
      }

      const nutritionist = await db
        .select({
          id: nutritionists.id,
          isApproved: nutritionists.isApproved,
        })
        .from(nutritionists)
        .where(
          eq(nutritionists.id, nutritionistId)
        )
        .limit(1);

      if (!nutritionist.length) {
        return res.status(404).json({
          error: 'Nutritionist not found',
        });
      }

      if (!nutritionist[0].isApproved) {
        return res.status(403).json({
          error: 'This nutritionist is not currently approved',
        });
      }

      const created = await db
        .insert(supervisionMessages)
        .values({
          userId: req.user.id,
          nutritionistId,
          senderRole: 'user',
          message: message.trim(),
          mediaUrl: mediaUrl || null,
        })
        .returning();

      return res.status(201).json({
        message: created[0],
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Patient send message error:',
        error
      );

      return res.status(500).json({
        error: 'Failed to send message',
      });
    }
  }
);

/*
 * GET /api/v1/supervision/dietitian/dashboard
 *
 * Adds each patient's latest sleep and mood records, plus up to five
 * recent records for each type.
 */

router.get(
  '/dietitian/dashboard',
  authenticateToken,
  requireRole('nutritionist'),
  async (req, res) => {
    try {
      const nutritionistUserId = req.user.id;

      const nutritionistResult = await db
        .select({
          id: nutritionists.id,
          userId: nutritionists.userId,
          name: users.name,
          email: users.email,
          credentials: nutritionists.credentials,
          bio: nutritionists.bio,
          specializations: nutritionists.specializations,
          hourlyRateEtb: nutritionists.hourlyRateEtb,
          isApproved: nutritionists.isApproved,
        })
        .from(nutritionists)
        .innerJoin(
          users,
          eq(nutritionists.userId, users.id)
        )
        .where(
          eq(
            nutritionists.userId,
            nutritionistUserId
          )
        )
        .limit(1);

      if (!nutritionistResult.length) {
        return res.status(404).json({
          error: 'Nutritionist profile not found',
        });
      }

      const nutritionist = nutritionistResult[0];

      const patientRows = await db
        .select({
          id: users.id,
          name: users.name,
          email: users.email,
          fastingPractice: profiles.fastingPractice,
          healthConditions: profiles.healthConditions,
          age: profiles.age,
          gender: profiles.gender,
          weightKg: profiles.weightKg,
          targetWeightKg: profiles.targetWeightKg,
          heightCm: profiles.heightCm,
          goal: profiles.goal,
          budgetLevel: profiles.budgetLevel,
        })
        .from(users)
        .leftJoin(
          profiles,
          eq(users.id, profiles.userId)
        )
        .where(eq(users.role, 'user'));

      /*
       * Fetch real sleep and mood records for the dashboard patients.
       *
       * Expected schema:
       * sleepLogs: userId, sleepDate, bedtime, wakeTime,
       *            durationMinutes, quality, notes
       * moodLogs:  userId, mood, moodScore, note, loggedAt
       */

      const patientIds = patientRows.map(
        (patient) => patient.id
      );

      let sleepRows = [];
      let moodRows = [];

      if (
        patientIds.length > 0 &&
        sleepLogs &&
        moodLogs
      ) {
        [sleepRows, moodRows] = await Promise.all([
          db
            .select({
              id: sleepLogs.id,
              userId: sleepLogs.userId,
              sleepDate: sleepLogs.sleepDate,
              bedtime: sleepLogs.bedtime,
              wakeTime: sleepLogs.wakeTime,
              durationMinutes: sleepLogs.durationMinutes,
              quality: sleepLogs.quality,
              notes: sleepLogs.notes,
            })
            .from(sleepLogs)
            .where(
              inArray(
                sleepLogs.userId,
                patientIds
              )
            )
            .orderBy(
              desc(sleepLogs.sleepDate)
            ),

          db
            .select({
              id: moodLogs.id,
              userId: moodLogs.userId,
              mood: moodLogs.mood,
              moodScore: moodLogs.moodScore,
              note: moodLogs.note,
              loggedAt: moodLogs.loggedAt,
            })
            .from(moodLogs)
            .where(
              inArray(
                moodLogs.userId,
                patientIds
              )
            )
            .orderBy(
              desc(moodLogs.loggedAt)
            ),
        ]);
      }

      const triagedPatients = patientRows
        .map((patient) => {
          const rawConditions =
            patient.healthConditions;

          const conditions = Array.isArray(rawConditions)
            ? rawConditions
            : [];

          let riskScore = 0;
          let riskReason = 'Low Risk';

          if (conditions.includes('anemia')) {
            riskScore += 3;
            riskReason = 'High Risk - Anemia Deficiency';
          }

          if (conditions.includes('diabetes')) {
            riskScore += 3;
            riskReason = 'High Risk - Diabetes Care';
          }

          if (conditions.includes('pregnancy')) {
            riskScore += 4;
            riskReason = 'Critical Risk - Maternal Nutrition';
          }

          const riskLevel =
            riskScore >= 4
              ? 'Critical Risk'
              : riskScore >= 3
                ? 'High Risk'
                : 'Normal';

          const patientSleep = sleepRows
            .filter(
              (row) => row.userId === patient.id
            )
            .slice(0, 5);

          const patientMood = moodRows
            .filter(
              (row) => row.userId === patient.id
            )
            .slice(0, 5);

          return {
            id: patient.id,
            name: patient.name,
            email: patient.email,

            fastingPractice:
              patient.fastingPractice || 'orthodox',

            healthConditions: conditions,
            age: patient.age,
            gender: patient.gender,
            weightKg: patient.weightKg,
            targetWeightKg: patient.targetWeightKg,
            heightCm: patient.heightCm,
            goal: patient.goal,
            budgetLevel: patient.budgetLevel,

            riskScore,
            riskLevel,
            riskReason,

            lastActive: 'Today',

            // Sleep tracking
            recentSleepLogs: patientSleep,
            latestSleep: patientSleep[0] || null,

            // Mood tracking
            recentMoodLogs: patientMood,
            latestMood: patientMood[0] || null,
          };
        })
        .sort(
          (a, b) => b.riskScore - a.riskScore
        );

      const appointmentRows = await db
        .select({
          id: appointments.id,
          userId: appointments.userId,
          userName: users.name,
          userEmail: users.email,
          nutritionistId: appointments.nutritionistId,
          scheduledAt: appointments.scheduledAt,
          status: appointments.status,
          notes: appointments.notes,
          createdAt: appointments.createdAt,
        })
        .from(appointments)
        .innerJoin(
          users,
          eq(appointments.userId, users.id)
        )
        .where(
          eq(
            appointments.nutritionistId,
            nutritionist.id
          )
        )
        .orderBy(
          asc(appointments.scheduledAt)
        );

      const patientMessageRows = await db
        .select({
          id: supervisionMessages.id,
          userId: supervisionMessages.userId,
          nutritionistId: supervisionMessages.nutritionistId,
          senderRole: supervisionMessages.senderRole,
          message: supervisionMessages.message,
          sentAt: supervisionMessages.sentAt,
        })
        .from(supervisionMessages)
        .where(
          and(
            eq(
              supervisionMessages.nutritionistId,
              nutritionist.id
            ),
            eq(
              supervisionMessages.senderRole,
              'user'
            )
          )
        )
        .orderBy(
          desc(supervisionMessages.sentAt)
        );

      const patientsWithMessages = triagedPatients.map(
        (patient) => {
          const patientMessages = patientMessageRows.filter(
            (message) => message.userId === patient.id
          );

          return {
            ...patient,

            messageCount: patientMessages.length,

            hasMessages:
              patientMessages.length > 0,

            lastMessage:
              patientMessages.length
                ? patientMessages[0].message
                : null,

            lastMessageAt:
              patientMessages.length
                ? patientMessages[0].sentAt
                : null,
          };
        }
      );

      const highRiskCount = patientsWithMessages.filter(
        (patient) =>
          patient.riskLevel === 'High Risk' ||
          patient.riskLevel === 'Critical Risk'
      ).length;

      return res.json({
        dietitian: {
          id: nutritionist.id,
          userId: nutritionist.userId,
          name: nutritionist.name,
          email: nutritionist.email,
          credentials: nutritionist.credentials,
          bio: nutritionist.bio,
          specializations: nutritionist.specializations,
          hourlyRateEtb: nutritionist.hourlyRateEtb,
          isApproved: nutritionist.isApproved,

          status: 'Live Online',

          activeSessionRoom:
            `ethionutri-room-${nutritionist.id}`,
        },

        totalPatients: patientsWithMessages.length,
        highRiskCount,
        totalPatientMessages: patientMessageRows.length,
        patients: patientsWithMessages,
        upcomingAppointments: appointmentRows,
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Nutritionist dashboard error:',
        error
      );

      return res.status(500).json({
        error: 'Failed to load nutritionist dashboard',
      });
    }
  }
);

/*
 * GET /api/v1/supervision/dietitian/patients/:patientId/messages
 */

router.get(
  '/dietitian/patients/:patientId/messages',
  authenticateToken,
  requireRole('nutritionist'),
  async (req, res) => {
    try {
      const patientId = req.params.patientId;

      const nutritionist = await db
        .select({
          id: nutritionists.id,
        })
        .from(nutritionists)
        .where(
          eq(
            nutritionists.userId,
            req.user.id
          )
        )
        .limit(1);

      if (!nutritionist.length) {
        return res.status(404).json({
          error: 'Nutritionist profile not found',
        });
      }

      const nutritionistId = nutritionist[0].id;

      const patient = await db
        .select({
          id: users.id,
          name: users.name,
          email: users.email,
        })
        .from(users)
        .where(
          and(
            eq(users.id, patientId),
            eq(users.role, 'user')
          )
        )
        .limit(1);

      if (!patient.length) {
        return res.status(404).json({
          error: 'Patient not found',
        });
      }

      const messages = await db
        .select({
          id: supervisionMessages.id,
          userId: supervisionMessages.userId,
          nutritionistId: supervisionMessages.nutritionistId,
          senderRole: supervisionMessages.senderRole,
          message: supervisionMessages.message,
          mediaUrl: supervisionMessages.mediaUrl,
          sentAt: supervisionMessages.sentAt,
        })
        .from(supervisionMessages)
        .where(
          and(
            eq(
              supervisionMessages.userId,
              patientId
            ),
            eq(
              supervisionMessages.nutritionistId,
              nutritionistId
            )
          )
        )
        .orderBy(
          asc(supervisionMessages.sentAt)
        );

      return res.json({
        patient: patient[0],
        patientId,
        nutritionistId,
        messages,
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Dietitian load messages error:',
        error
      );

      return res.status(500).json({
        error: 'Failed to load patient conversation',
      });
    }
  }
);

/*
 * POST /api/v1/supervision/dietitian/patients/:patientId/messages
 */

router.post(
  '/dietitian/patients/:patientId/messages',
  authenticateToken,
  requireRole('nutritionist'),
  async (req, res) => {
    try {
      const patientId = req.params.patientId;
      const { message, mediaUrl } = req.body;

      if (
        typeof message !== 'string' ||
        !message.trim()
      ) {
        return res.status(400).json({
          error: 'Message cannot be empty',
        });
      }

      if (message.trim().length > 5000) {
        return res.status(400).json({
          error: 'Message cannot exceed 5000 characters',
        });
      }

      const nutritionist = await db
        .select({
          id: nutritionists.id,
          isApproved: nutritionists.isApproved,
        })
        .from(nutritionists)
        .where(
          eq(
            nutritionists.userId,
            req.user.id
          )
        )
        .limit(1);

      if (!nutritionist.length) {
        return res.status(404).json({
          error: 'Nutritionist profile not found',
        });
      }

      if (!nutritionist[0].isApproved) {
        return res.status(403).json({
          error: 'Nutritionist account is not approved',
        });
      }

      const patient = await db
        .select({
          id: users.id,
          role: users.role,
        })
        .from(users)
        .where(
          eq(users.id, patientId)
        )
        .limit(1);

      if (!patient.length) {
        return res.status(404).json({
          error: 'Patient not found',
        });
      }

      if (patient[0].role !== 'user') {
        return res.status(400).json({
          error: 'Selected account is not a patient',
        });
      }

      const created = await db
        .insert(supervisionMessages)
        .values({
          userId: patientId,
          nutritionistId: nutritionist[0].id,
          senderRole: 'nutritionist',
          message: message.trim(),
          mediaUrl: mediaUrl || null,
        })
        .returning();

      return res.status(201).json({
        message: created[0],
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Dietitian send message error:',
        error
      );

      return res.status(500).json({
        error: 'Failed to send message',
      });
    }
  }
);

// ============================================================
// GET /api/v1/supervision/my-appointments
// Get appointments belonging to the authenticated patient
// ============================================================

router.get(
  '/my-appointments',
  authenticateToken,
  requireRole('user'),
  async (req, res) => {
    try {
      const patientId = req.user.id;

      const rows = await db
        .select({
          id: appointments.id,
          userId: appointments.userId,
          nutritionistId: appointments.nutritionistId,
          scheduledAt: appointments.scheduledAt,
          status: appointments.status,
          notes: appointments.notes,
          createdAt: appointments.createdAt,
          nutritionistName: users.name,
          nutritionistEmail: users.email,
        })
        .from(appointments)
        .innerJoin(
          nutritionists,
          eq(
            appointments.nutritionistId,
            nutritionists.id
          )
        )
        .innerJoin(
          users,
          eq(
            nutritionists.userId,
            users.id
          )
        )
        .where(
          eq(
            appointments.userId,
            patientId
          )
        )
        .orderBy(
          desc(appointments.scheduledAt)
        );

      const appointmentList = rows.map((row) => {
        const scheduledAt = new Date(
          row.scheduledAt
        );

        const endsAt = new Date(
          scheduledAt.getTime() +
          30 * 60 * 1000
        );

        return {
          // Standard appointment fields
          id: row.id,
          appointmentId: row.id,
          userId: row.userId,
          nutritionistId: row.nutritionistId,
          scheduledAt: scheduledAt.toISOString(),
          endsAt: endsAt.toISOString(),
          status: row.status,
          notes: row.notes,
          createdAt: row.createdAt,

          // Nutritionist details
          nutritionistName: row.nutritionistName,
          nutritionistEmail: row.nutritionistEmail,

          // Fields needed to launch the video-call screen
          roomName:
            `ethionutri-room-${row.nutritionistId}`,

          participantName:
            row.nutritionistName,

          participantEmail:
            row.nutritionistEmail,
        };
      });

      return res.status(200).json({
        success: true,
        appointments: appointmentList,
        count: appointmentList.length,
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Get patient appointments error:',
        error
      );

      return res.status(500).json({
        success: false,
        error: 'Failed to load your appointments',
      });
    }
  }
);

// ============================================================
// GET /api/v1/supervision/nutritionists
// GET ALL AVAILABLE NUTRITIONISTS
// ============================================================

router.get(
  '/nutritionists',
  authenticateToken,
  async (req, res) => {
    try {
      const rows = await db
        .select({
          id: nutritionists.id,
          userId: users.id,
          name: users.name,
          email: users.email,
        })
        .from(nutritionists)
        .innerJoin(
          users,
          eq(nutritionists.userId, users.id)
        )
        .where(
          eq(nutritionists.isApproved, true)
        );

      const nutritionistList = rows.map((row) => ({
        id: row.id,
        nutritionistId: row.id,
        userId: row.userId,

        name: row.name || 'Nutritionist',
        email: row.email || null,

        nutritionistName:
          row.name || 'Nutritionist',

        nutritionistEmail:
          row.email || null,

        roomName:
          `ethionutri-room-${row.id}`,
      }));

      return res.status(200).json({
        success: true,
        nutritionists: nutritionistList,
        count: nutritionistList.length,
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Get nutritionists error:',
        error
      );

      return res.status(500).json({
        success: false,
        error: 'Failed to load nutritionists',
      });
    }
  }
);

module.exports = router;