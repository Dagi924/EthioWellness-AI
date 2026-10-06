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
} = require('../db/schema');

const {
  eq,
  and,
  desc,
  asc,
} = require('drizzle-orm');


/*
|--------------------------------------------------------------------------
| GET /api/v1/supervision/nutritionist/:id
|--------------------------------------------------------------------------
| Get a nutritionist profile.
|
| :id = nutritionists.id
|--------------------------------------------------------------------------
*/

router.get(
  '/nutritionist/:id',
  authenticateToken,
  async (req, res) => {
    try {
      const nutritionistId = req.params.id;

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
        .innerJoin(
          users,
          eq(nutritionists.userId, users.id)
        )
        .where(
          eq(nutritionists.id, nutritionistId)
        )
        .limit(1);

      if (result.length === 0) {
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
      console.error(
        '[SUPERVISION] Get nutritionist error:',
        error
      );

      return res.status(500).json({
        error: 'Failed to load nutritionist',
      });
    }
  }
);


/*
|--------------------------------------------------------------------------
| POST /api/v1/supervision/appointments
|--------------------------------------------------------------------------
| Create appointment for authenticated patient.
|--------------------------------------------------------------------------
*/

router.post(
  '/appointments',
  authenticateToken,
  requireRole('user'),
  async (req, res) => {
    try {
      const userId = req.user.id;

      const {
        nutritionistId,
        scheduledAt,
        notes,
      } = req.body;

      if (!nutritionistId) {
        return res.status(400).json({
          error: 'nutritionistId is required',
        });
      }

      if (!scheduledAt) {
        return res.status(400).json({
          error: 'scheduledAt is required',
        });
      }

      const appointmentDate = new Date(scheduledAt);

      if (Number.isNaN(appointmentDate.getTime())) {
        return res.status(400).json({
          error: 'Invalid scheduledAt date',
        });
      }

      const nutritionist = await db
        .select({
          id: nutritionists.id,
        })
        .from(nutritionists)
        .where(
          eq(nutritionists.id, nutritionistId)
        )
        .limit(1);

      if (nutritionist.length === 0) {
        return res.status(404).json({
          error: 'Nutritionist not found',
        });
      }

      const inserted = await db
        .insert(appointments)
        .values({
          userId,
          nutritionistId,
          scheduledAt: appointmentDate,
          status: 'confirmed',
          notes:
            notes ||
            'Fasting nutrition optimization & iron target review',
        })
        .returning();

      return res.status(201).json({
        message:
          'Consultation appointment booked successfully',
        appointment: inserted[0],
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Create appointment error:',
        error
      );

      return res.status(500).json({
        error: 'Failed to create appointment',
      });
    }
  }
);


/*
|--------------------------------------------------------------------------
| POST /api/v1/supervision/consent
|--------------------------------------------------------------------------
| Currently validates consent preferences.
|
| NOTE:
| No consent table exists in the supplied schema.
|--------------------------------------------------------------------------
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
      console.error(
        '[SUPERVISION] Consent error:',
        error
      );

      return res.status(500).json({
        error: 'Failed to save consent preferences',
      });
    }
  }
);


/*
|--------------------------------------------------------------------------
| GET /api/v1/supervision/chat/history
|--------------------------------------------------------------------------
| Get all supervision messages for the authenticated patient.
|--------------------------------------------------------------------------
*/

router.get(
  '/chat/history',
  authenticateToken,
  requireRole('user'),
  async (req, res) => {
    try {
      const userId = req.user.id;

      const messages = await db
        .select({
          id: supervisionMessages.id,
          userId: supervisionMessages.userId,
          nutritionistId:
            supervisionMessages.nutritionistId,
          senderRole:
            supervisionMessages.senderRole,
          message:
            supervisionMessages.message,
          mediaUrl:
            supervisionMessages.mediaUrl,
          sentAt:
            supervisionMessages.sentAt,
        })
        .from(supervisionMessages)
        .where(
          eq(
            supervisionMessages.userId,
            userId
          )
        )
        .orderBy(
          asc(supervisionMessages.sentAt)
        );

      return res.json({
        messages,
      });
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
|--------------------------------------------------------------------------
| POST /api/v1/supervision/chat/send
|--------------------------------------------------------------------------
| General chat endpoint.
|
| Patient:
| {
|   "nutritionistId": "...",
|   "message": "Hello"
| }
|
| Nutritionist:
| {
|   "userId": "...",
|   "message": "Hello"
| }
|--------------------------------------------------------------------------
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

      if (
        !message ||
        typeof message !== 'string' ||
        message.trim().length === 0
      ) {
        return res.status(400).json({
          error: 'Message is required',
        });
      }

      if (message.trim().length > 5000) {
        return res.status(400).json({
          error:
            'Message cannot exceed 5000 characters',
        });
      }

      let patientId;
      let targetNutritionistId;

      /*
       * PATIENT SENDING
       */

      if (senderRole === 'user') {
        patientId = senderId;
        targetNutritionistId = nutritionistId;

        if (!targetNutritionistId) {
          return res.status(400).json({
            error:
              'nutritionistId is required',
          });
        }

        const nutritionist = await db
          .select({
            id: nutritionists.id,
            isApproved:
              nutritionists.isApproved,
          })
          .from(nutritionists)
          .where(
            eq(
              nutritionists.id,
              targetNutritionistId
            )
          )
          .limit(1);

        if (nutritionist.length === 0) {
          return res.status(404).json({
            error: 'Nutritionist not found',
          });
        }

        if (!nutritionist[0].isApproved) {
          return res.status(403).json({
            error:
              'This nutritionist is not currently approved',
          });
        }
      }

      /*
       * NUTRITIONIST SENDING
       */

      else if (senderRole === 'nutritionist') {
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
          })
          .from(nutritionists)
          .where(
            eq(
              nutritionists.userId,
              senderId
            )
          )
          .limit(1);

        if (nutritionist.length === 0) {
          return res.status(404).json({
            error:
              'Nutritionist profile not found',
          });
        }

        targetNutritionistId =
          nutritionist[0].id;

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

        if (patient.length === 0) {
          return res.status(404).json({
            error: 'Patient not found',
          });
        }

        if (patient[0].role !== 'user') {
          return res.status(400).json({
            error:
              'Selected account is not a patient',
          });
        }
      }

      else {
        return res.status(403).json({
          error: 'Unauthorized chat role',
        });
      }

      /*
       * SAVE MESSAGE
       */

      const created = await db
        .insert(supervisionMessages)
        .values({
          userId: patientId,
          nutritionistId:
            targetNutritionistId,
          senderRole:
            senderRole === 'nutritionist'
              ? 'nutritionist'
              : 'user',
          message: message.trim(),
          mediaUrl: mediaUrl || null,
        })
        .returning();

      const createdMessage = created[0];

      return res.status(201).json({
        message: createdMessage,
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
|--------------------------------------------------------------------------
| GET /api/v1/supervision/messages/:nutritionistId
|--------------------------------------------------------------------------
| Patient gets conversation with a specific nutritionist.
|--------------------------------------------------------------------------
*/

router.get(
  '/messages/:nutritionistId',
  authenticateToken,
  requireRole('user'),
  async (req, res) => {
    try {
      const userId = req.user.id;
      const nutritionistId =
        req.params.nutritionistId;

      const messages = await db
        .select({
          id: supervisionMessages.id,
          userId: supervisionMessages.userId,
          nutritionistId:
            supervisionMessages.nutritionistId,
          senderRole:
            supervisionMessages.senderRole,
          message:
            supervisionMessages.message,
          mediaUrl:
            supervisionMessages.mediaUrl,
          sentAt:
            supervisionMessages.sentAt,
        })
        .from(supervisionMessages)
        .where(
          and(
            eq(
              supervisionMessages.userId,
              userId
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
        messages,
      });
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
|--------------------------------------------------------------------------
| POST /api/v1/supervision/messages
|--------------------------------------------------------------------------
| Patient sends message to nutritionist.
|--------------------------------------------------------------------------
*/

router.post(
  '/messages',
  authenticateToken,
  requireRole('user'),
  async (req, res) => {
    try {
      const userId = req.user.id;

      const {
        nutritionistId,
        message,
        mediaUrl,
      } = req.body;

      if (!nutritionistId) {
        return res.status(400).json({
          error:
            'Nutritionist ID is required',
        });
      }

      if (
        !message ||
        typeof message !== 'string' ||
        message.trim().length === 0
      ) {
        return res.status(400).json({
          error: 'Message cannot be empty',
        });
      }

      if (message.trim().length > 5000) {
        return res.status(400).json({
          error:
            'Message cannot exceed 5000 characters',
        });
      }

      /*
       * Verify nutritionist.
       */

      const nutritionist = await db
        .select({
          id: nutritionists.id,
          isApproved:
            nutritionists.isApproved,
        })
        .from(nutritionists)
        .where(
          eq(
            nutritionists.id,
            nutritionistId
          )
        )
        .limit(1);

      if (nutritionist.length === 0) {
        return res.status(404).json({
          error: 'Nutritionist not found',
        });
      }

      if (!nutritionist[0].isApproved) {
        return res.status(403).json({
          error:
            'This nutritionist is not currently approved',
        });
      }

      /*
       * Save to supervisionMessages.
       */

      const created = await db
        .insert(supervisionMessages)
        .values({
          userId,
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
|--------------------------------------------------------------------------
| GET /api/v1/supervision/dietitian/dashboard
|--------------------------------------------------------------------------
| Nutritionist dashboard.
|--------------------------------------------------------------------------
*/

router.get(
  '/dietitian/dashboard',
  authenticateToken,
  requireRole('nutritionist'),
  async (req, res) => {
    try {
      const nutritionistUserId =
        req.user.id;

      /*
       * Find nutritionist profile.
       */

      const nutritionistResult =
        await db
          .select({
            id: nutritionists.id,
            userId: nutritionists.userId,
            name: users.name,
            email: users.email,
            credentials:
              nutritionists.credentials,
            bio: nutritionists.bio,
            specializations:
              nutritionists.specializations,
            hourlyRateEtb:
              nutritionists.hourlyRateEtb,
            isApproved:
              nutritionists.isApproved,
          })
          .from(nutritionists)
          .innerJoin(
            users,
            eq(
              nutritionists.userId,
              users.id
            )
          )
          .where(
            eq(
              nutritionists.userId,
              nutritionistUserId
            )
          )
          .limit(1);

      if (nutritionistResult.length === 0) {
        return res.status(404).json({
          error:
            'Nutritionist profile not found',
        });
      }

      const nutritionist =
        nutritionistResult[0];

      /*
       * Get patients.
       */

      const patientRows = await db
        .select({
          id: users.id,
          name: users.name,
          email: users.email,

          fastingPractice:
            profiles.fastingPractice,

          healthConditions:
            profiles.healthConditions,

          age: profiles.age,
          gender: profiles.gender,
          weightKg:
            profiles.weightKg,
          targetWeightKg:
            profiles.targetWeightKg,
          heightCm:
            profiles.heightCm,
          goal: profiles.goal,
          budgetLevel:
            profiles.budgetLevel,
        })
        .from(users)
        .leftJoin(
          profiles,
          eq(
            users.id,
            profiles.userId
          )
        )
        .where(
          eq(users.role, 'user')
        );

      /*
       * Calculate risk.
       */

      const triagedPatients =
        patientRows
          .map((patient) => {
            const rawConditions =
              patient.healthConditions;

            const conditions =
              Array.isArray(rawConditions)
                ? rawConditions
                : [];

            let riskScore = 0;
            let riskReason = 'Low Risk';

            if (
              conditions.includes('anemia')
            ) {
              riskScore += 3;
              riskReason =
                'High Risk - Anemia Deficiency';
            }

            if (
              conditions.includes('diabetes')
            ) {
              riskScore += 3;
              riskReason =
                'High Risk - Diabetes Care';
            }

            if (
              conditions.includes('pregnancy')
            ) {
              riskScore += 4;
              riskReason =
                'Critical Risk - Maternal Nutrition';
            }

            const riskLevel =
              riskScore >= 4
                ? 'Critical Risk'
                : riskScore >= 3
                  ? 'High Risk'
                  : 'Normal';

            return {
              id: patient.id,
              name: patient.name,
              email: patient.email,

              fastingPractice:
                patient.fastingPractice ||
                'orthodox',

              healthConditions:
                conditions,

              age: patient.age,
              gender: patient.gender,

              weightKg:
                patient.weightKg,

              targetWeightKg:
                patient.targetWeightKg,

              heightCm:
                patient.heightCm,

              goal: patient.goal,

              budgetLevel:
                patient.budgetLevel,

              riskScore,
              riskLevel,
              riskReason,

              lastActive: 'Today',
            };
          })
          .sort(
            (a, b) =>
              b.riskScore -
              a.riskScore
          );

      /*
       * Get appointments.
       */

      const appointmentRows =
        await db
          .select({
            id: appointments.id,

            userId:
              appointments.userId,

            userName:
              users.name,

            userEmail:
              users.email,

            nutritionistId:
              appointments.nutritionistId,

            scheduledAt:
              appointments.scheduledAt,

            status:
              appointments.status,

            notes:
              appointments.notes,

            createdAt:
              appointments.createdAt,
          })
          .from(appointments)
          .innerJoin(
            users,
            eq(
              appointments.userId,
              users.id
            )
          )
          .where(
            eq(
              appointments.nutritionistId,
              nutritionist.id
            )
          )
          .orderBy(
            appointments.scheduledAt
          );

      /*
       * Count unread messages.
       *
       * Since the current table does not contain
       * an isRead column, we count all patient
       * messages for this nutritionist.
       *
       * You can later add isRead to make this
       * a real unread notification count.
       */

      const patientMessageRows =
        await db
          .select({
            id:
              supervisionMessages.id,
            userId:
              supervisionMessages.userId,
            nutritionistId:
              supervisionMessages.nutritionistId,
            senderRole:
              supervisionMessages.senderRole,
            message:
              supervisionMessages.message,
            sentAt:
              supervisionMessages.sentAt,
          })
          .from(supervisionMessages)
          .where(
            and(
              eq(
                supervisionMessages
                  .nutritionistId,
                nutritionist.id
              ),
              eq(
                supervisionMessages
                  .senderRole,
                'user'
              )
            )
          )
          .orderBy(
            desc(
              supervisionMessages.sentAt
            )
          );

      /*
       * Attach message information to each patient.
       */

      const patientsWithMessages =
        triagedPatients.map(
          (patient) => {
            const patientMessages =
              patientMessageRows.filter(
                (message) =>
                  message.userId ===
                  patient.id
              );

            return {
              ...patient,

              messageCount:
                patientMessages.length,

              hasMessages:
                patientMessages.length >
                0,

              lastMessage:
                patientMessages.length >
                0
                  ? patientMessages[0]
                      .message
                  : null,

              lastMessageAt:
                patientMessages.length >
                0
                  ? patientMessages[0]
                      .sentAt
                  : null,
            };
          }
        );

      const highRiskCount =
        patientsWithMessages.filter(
          (patient) =>
            patient.riskLevel ===
              'High Risk' ||
            patient.riskLevel ===
              'Critical Risk'
        ).length;

      /*
       * Total patient messages.
       */

      const totalPatientMessages =
        patientMessageRows.length;

      return res.json({
        dietitian: {
          id: nutritionist.id,
          userId: nutritionist.userId,
          name: nutritionist.name,
          email: nutritionist.email,
          credentials:
            nutritionist.credentials,
          bio: nutritionist.bio,
          specializations:
            nutritionist.specializations,
          hourlyRateEtb:
            nutritionist.hourlyRateEtb,
          isApproved:
            nutritionist.isApproved,

          status: 'Live Online',

          activeSessionRoom:
            `ethionutri-room-${nutritionist.id}`,
        },

        totalPatients:
          patientsWithMessages.length,

        highRiskCount,

        totalPatientMessages,

        patients:
          patientsWithMessages,

        upcomingAppointments:
          appointmentRows,
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Nutritionist dashboard error:',
        error
      );

      return res.status(500).json({
        error:
          'Failed to load nutritionist dashboard',
      });
    }
  }
);


/*
|--------------------------------------------------------------------------
| GET /api/v1/supervision/dietitian/patients/:patientId/messages
|--------------------------------------------------------------------------
| Nutritionist gets complete conversation with one patient.
|--------------------------------------------------------------------------
*/

router.get(
  '/dietitian/patients/:patientId/messages',
  authenticateToken,
  requireRole('nutritionist'),
  async (req, res) => {
    try {
      const nutritionistUserId =
        req.user.id;

      const patientId =
        req.params.patientId;

      /*
       * Find nutritionist profile.
       */

      const nutritionist =
        await db
          .select({
            id: nutritionists.id,
          })
          .from(nutritionists)
          .where(
            eq(
              nutritionists.userId,
              nutritionistUserId
            )
          )
          .limit(1);

      if (nutritionist.length === 0) {
        return res.status(404).json({
          error:
            'Nutritionist profile not found',
        });
      }

      const nutritionistId =
        nutritionist[0].id;

      /*
       * Verify patient.
       */

      const patient =
        await db
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

      if (patient.length === 0) {
        return res.status(404).json({
          error: 'Patient not found',
        });
      }

      /*
       * Get messages from supervisionMessages.
       */

      const messages =
        await db
          .select({
            id:
              supervisionMessages.id,

            userId:
              supervisionMessages.userId,

            nutritionistId:
              supervisionMessages.nutritionistId,

            senderRole:
              supervisionMessages.senderRole,

            message:
              supervisionMessages.message,

            mediaUrl:
              supervisionMessages.mediaUrl,

            sentAt:
              supervisionMessages.sentAt,
          })
          .from(supervisionMessages)
          .where(
            and(
              eq(
                supervisionMessages.userId,
                patientId
              ),
              eq(
                supervisionMessages
                  .nutritionistId,
                nutritionistId
              )
            )
          )
          .orderBy(
            asc(
              supervisionMessages.sentAt
            )
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
        error:
          'Failed to load patient conversation',
      });
    }
  }
);


/*
|--------------------------------------------------------------------------
| POST /api/v1/supervision/dietitian/patients/:patientId/messages
|--------------------------------------------------------------------------
| Nutritionist sends message to a patient.
|--------------------------------------------------------------------------
*/

router.post(
  '/dietitian/patients/:patientId/messages',
  authenticateToken,
  requireRole('nutritionist'),
  async (req, res) => {
    try {
      const nutritionistUserId =
        req.user.id;

      const patientId =
        req.params.patientId;

      const {
        message,
        mediaUrl,
      } = req.body;

      /*
       * Validate message.
       */

      if (
        !message ||
        typeof message !== 'string' ||
        message.trim().length === 0
      ) {
        return res.status(400).json({
          error:
            'Message cannot be empty',
        });
      }

      if (message.trim().length > 5000) {
        return res.status(400).json({
          error:
            'Message cannot exceed 5000 characters',
        });
      }

      /*
       * Find nutritionist.
       */

      const nutritionist =
        await db
          .select({
            id: nutritionists.id,
            isApproved:
              nutritionists.isApproved,
          })
          .from(nutritionists)
          .where(
            eq(
              nutritionists.userId,
              nutritionistUserId
            )
          )
          .limit(1);

      if (nutritionist.length === 0) {
        return res.status(404).json({
          error:
            'Nutritionist profile not found',
        });
      }

      if (!nutritionist[0].isApproved) {
        return res.status(403).json({
          error:
            'Nutritionist account is not approved',
        });
      }

      const nutritionistId =
        nutritionist[0].id;

      /*
       * Verify patient.
       */

      const patient =
        await db
          .select({
            id: users.id,
            name: users.name,
            role: users.role,
          })
          .from(users)
          .where(
            eq(users.id, patientId)
          )
          .limit(1);

      if (patient.length === 0) {
        return res.status(404).json({
          error: 'Patient not found',
        });
      }

      if (patient[0].role !== 'user') {
        return res.status(400).json({
          error:
            'Selected account is not a patient',
        });
      }

      /*
       * Save to supervisionMessages.
       */

      const created =
        await db
          .insert(supervisionMessages)
          .values({
            userId: patientId,

            nutritionistId,

            senderRole:
              'nutritionist',

            message:
              message.trim(),

            mediaUrl:
              mediaUrl || null,
          })
          .returning();

      /*
       * IMPORTANT:
       * Flutter expects response['message'].
       */

      return res.status(201).json({
        message: created[0],
      });
    } catch (error) {
      console.error(
        '[SUPERVISION] Dietitian send message error:',
        error
      );

      return res.status(500).json({
        error:
          'Failed to send message',
      });
    }
  }
);


module.exports = router;
