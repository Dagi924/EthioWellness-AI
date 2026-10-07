const jwt = require('jsonwebtoken');

// ============================================================
// JWT CONFIGURATION
// ============================================================

// Production must provide these through environment variables.
// Do not use hardcoded fallback secrets.
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;

if (!JWT_SECRET) {
  throw new Error(
    'JWT_SECRET environment variable is required'
  );
}

if (!JWT_REFRESH_SECRET) {
  throw new Error(
    'JWT_REFRESH_SECRET environment variable is required'
  );
}


// ============================================================
// GENERATE TOKENS
// ============================================================

function generateTokens(userPayload) {
  const accessToken = jwt.sign(
    {
      id: userPayload.id,
      email: userPayload.email,
      role: userPayload.role || 'user',
    },
    JWT_SECRET,
    {
      expiresIn:
        process.env.JWT_EXPIRES_IN || '1d',
    }
  );

  const refreshToken = jwt.sign(
    {
      id: userPayload.id,
    },
    JWT_REFRESH_SECRET,
    {
      expiresIn:
        process.env.JWT_REFRESH_EXPIRES_IN || '7d',
    }
  );

  return {
    accessToken,
    refreshToken,
  };
}


// ============================================================
// AUTHENTICATE ACCESS TOKEN
// ============================================================

function authenticateToken(req, res, next) {
  const authHeader = req.headers.authorization;

  // ----------------------------------------------------------
  // Authorization header required
  // ----------------------------------------------------------

  if (!authHeader) {
    return res.status(401).json({
      error: 'Authentication required',
    });
  }

  // ----------------------------------------------------------
  // Require Bearer authentication scheme
  // ----------------------------------------------------------

  const parts = authHeader.trim().split(/\s+/);

  if (
    parts.length !== 2 ||
    parts[0].toLowerCase() !== 'bearer' ||
    !parts[1]
  ) {
    return res.status(401).json({
      error: 'Invalid authorization header format',
    });
  }

  const token = parts[1];

  // ----------------------------------------------------------
  // Verify access token
  // ----------------------------------------------------------

  try {
    const decoded = jwt.verify(
      token,
      JWT_SECRET
    );

    // --------------------------------------------------------
    // Basic token payload validation
    // --------------------------------------------------------

    if (
      !decoded ||
      typeof decoded !== 'object' ||
      !decoded.id ||
      !decoded.email ||
      !decoded.role
    ) {
      return res.status(401).json({
        error: 'Invalid access token',
      });
    }

    req.user = {
      id: decoded.id,
      email: decoded.email,
      role: decoded.role,
    };

    next();
  } catch (error) {
    return res.status(401).json({
      error: 'Invalid or expired access token',
    });
  }
}


// ============================================================
// VERIFY REFRESH TOKEN
// ============================================================

function verifyRefreshToken(refreshToken) {
  if (!refreshToken) {
    throw new Error('Refresh token is required');
  }

  const decoded = jwt.verify(
    refreshToken,
    JWT_REFRESH_SECRET
  );

  if (
    !decoded ||
    typeof decoded !== 'object' ||
    !decoded.id
  ) {
    throw new Error('Invalid refresh token');
  }

  return decoded;
}


// ============================================================
// EXPORTS
// ============================================================

module.exports = {
  generateTokens,
  authenticateToken,
  verifyRefreshToken,
  JWT_SECRET,
  JWT_REFRESH_SECRET,
};