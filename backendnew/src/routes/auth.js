const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');

const {
  generateTokens,
  verifyRefreshToken,
} = require('../middleware/auth');

const { db } = require('../db');

const {
  users,
  profiles,
} = require('../db/schema');

const { eq } = require('drizzle-orm');


// ============================================================
// POST /api/v1/auth/register
// ============================================================

router.post('/register', async (req, res) => {
  try {
    const {
      email,
      password,
      name,
      phone,

      fastingPractice,
      healthConditions,
      language,
      theme,
      notificationsEnabled,

      age,
      gender,
      weightKg,
      targetWeightKg,
      heightCm,
      goal,
      budgetLevel,

      dailyCalorieTarget,
      dailyProteinTarget,
      dailyCarbsTarget,
      dailyFatsTarget,
      dailyWaterTarget,
    } = req.body;


    // --------------------------------------------------------
    // Validate required fields
    // --------------------------------------------------------

    if (!email || !password || !name) {
      return res.status(400).json({
        error: 'Email, password, and name are required',
      });
    }


    // --------------------------------------------------------
    // Validate basic input types
    // --------------------------------------------------------

    if (
      typeof email !== 'string' ||
      typeof password !== 'string' ||
      typeof name !== 'string'
    ) {
      return res.status(400).json({
        error: 'Invalid registration data',
      });
    }


    const normalizedEmail =
      email.trim().toLowerCase();

    const normalizedName =
      name.trim();


    if (!normalizedEmail || !normalizedName) {
      return res.status(400).json({
        error: 'Email and name cannot be empty',
      });
    }


    // --------------------------------------------------------
    // Check if user already exists
    // --------------------------------------------------------

    const existingUsers = await db
      .select({
        id: users.id,
      })
      .from(users)
      .where(eq(users.email, normalizedEmail))
      .limit(1);

    if (existingUsers.length > 0) {
      return res.status(409).json({
        error: 'User with this email already exists',
      });
    }


    // --------------------------------------------------------
    // Hash password
    // --------------------------------------------------------

    const passwordHash =
      await bcrypt.hash(password, 12);


    // --------------------------------------------------------
    // Create normal user
    //
    // IMPORTANT:
    // The client cannot choose the role.
    // --------------------------------------------------------

    const insertedUsers = await db
      .insert(users)
      .values({
        email: normalizedEmail,
        phone: phone || null,
        passwordHash,
        name: normalizedName,

        // Never accept role from public registration.
        role: 'user',

        isPremium: false,
        paymentStatus: 'free_tier',
      })
      .returning();


    const newUser = insertedUsers[0];


    if (!newUser) {
      throw new Error('User was not created');
    }


    // --------------------------------------------------------
    // Create profile
    // --------------------------------------------------------

    const insertedProfiles = await db
      .insert(profiles)
      .values({
        userId: newUser.id,

        fastingPractice:
          fastingPractice || 'orthodox',

        healthConditions:
          healthConditions || [],

        language:
          language || 'en',

        theme:
          theme || 'light',

        notificationsEnabled:
          notificationsEnabled ?? true,

        age:
          age ?? 28,

        gender:
          gender || 'other',

        weightKg:
          weightKg ?? 68,

        targetWeightKg:
          targetWeightKg ?? 65,

        heightCm:
          heightCm ?? 172,

        goal:
          goal || 'lose_weight',

        budgetLevel:
          budgetLevel || 'medium',

        dailyCalorieTarget:
          dailyCalorieTarget ?? 2000,

        dailyProteinTarget:
          dailyProteinTarget ?? 60,

        dailyCarbsTarget:
          dailyCarbsTarget ?? 220,

        dailyFatsTarget:
          dailyFatsTarget ?? 50,

        dailyWaterTarget:
          dailyWaterTarget ?? 2.5,

        onboardingCompleted: true,
      })
      .returning();


    const newProfile =
      insertedProfiles[0] || null;


    // --------------------------------------------------------
    // Generate JWT tokens
    // --------------------------------------------------------

    const tokens = generateTokens({
      id: newUser.id,
      email: newUser.email,
      role: newUser.role,
    });


    // --------------------------------------------------------
    // Response
    // --------------------------------------------------------

    return res.status(201).json({
      message: 'User registered successfully',

      user: {
        id: newUser.id,
        email: newUser.email,
        name: newUser.name,
        role: newUser.role,
        isPremium: newUser.isPremium,
        paymentStatus: newUser.paymentStatus,
      },

      profile: newProfile,

      ...tokens,
    });

  } catch (err) {
    console.error(
      'REGISTER ERROR:',
      err
    );

    return res.status(500).json({
      error: 'Registration failed',
    });
  }
});


// ============================================================
// POST /api/v1/auth/login
// ============================================================

router.post('/login', async (req, res) => {
  try {
    const {
      email,
      password,
    } = req.body;


    // --------------------------------------------------------
    // Validate required fields
    // --------------------------------------------------------

    if (!email || !password) {
      return res.status(400).json({
        error: 'Email and password are required',
      });
    }


    if (
      typeof email !== 'string' ||
      typeof password !== 'string'
    ) {
      return res.status(400).json({
        error: 'Invalid login data',
      });
    }


    const normalizedEmail =
      email.trim().toLowerCase();


    // --------------------------------------------------------
    // Fetch user
    // --------------------------------------------------------

    const result = await db
      .select()
      .from(users)
      .where(eq(users.email, normalizedEmail))
      .limit(1);


    if (result.length === 0) {
      return res.status(401).json({
        error: 'Invalid email or password',
      });
    }


    const user = result[0];


    // --------------------------------------------------------
    // Compare password
    // --------------------------------------------------------

    const passwordMatches =
      await bcrypt.compare(
        password,
        user.passwordHash
      );


    if (!passwordMatches) {
      return res.status(401).json({
        error: 'Invalid email or password',
      });
    }


    // --------------------------------------------------------
    // Fetch profile
    // --------------------------------------------------------

    const profileResult = await db
      .select()
      .from(profiles)
      .where(eq(profiles.userId, user.id))
      .limit(1);


    const profile =
      profileResult[0] || null;


    // --------------------------------------------------------
    // Generate tokens
    // --------------------------------------------------------

    const tokens = generateTokens({
      id: user.id,
      email: user.email,
      role: user.role,
    });


    // --------------------------------------------------------
    // Response
    // --------------------------------------------------------

    return res.json({
      message: 'Login successful',

      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        isPremium: user.isPremium,
        paymentStatus: user.paymentStatus,
      },

      profile,

      ...tokens,
    });

  } catch (err) {
    console.error(
      'LOGIN ERROR:',
      err
    );

    return res.status(500).json({
      error: 'Login failed',
    });
  }
});


// ============================================================
// POST /api/v1/auth/refresh
// ============================================================

router.post('/refresh', async (req, res) => {
  try {
    const {
      refreshToken,
    } = req.body;


    // --------------------------------------------------------
    // Validate refresh token
    // --------------------------------------------------------

    if (
      !refreshToken ||
      typeof refreshToken !== 'string'
    ) {
      return res.status(400).json({
        error: 'Refresh token is required',
      });
    }


    // --------------------------------------------------------
    // Verify refresh token signature and expiry
    // --------------------------------------------------------

    const decoded =
      verifyRefreshToken(refreshToken);


    // --------------------------------------------------------
    // Fetch current user from database
    //
    // Do not trust role/email from the refresh token.
    // This allows current database authorization state
    // to be reflected when new access tokens are issued.
    // --------------------------------------------------------

    const result = await db
      .select({
        id: users.id,
        email: users.email,
        role: users.role,
      })
      .from(users)
      .where(eq(users.id, decoded.id))
      .limit(1);


    if (result.length === 0) {
      return res.status(401).json({
        error: 'User associated with refresh token no longer exists',
      });
    }


    const user = result[0];


    // --------------------------------------------------------
    // Generate new tokens
    // --------------------------------------------------------

    const tokens = generateTokens({
      id: user.id,
      email: user.email,
      role: user.role,
    });


    return res.json(tokens);

  } catch (error) {
    console.error(
      'REFRESH TOKEN ERROR:',
      error.message
    );

    return res.status(401).json({
      error: 'Invalid or expired refresh token',
    });
  }
});


module.exports = router;