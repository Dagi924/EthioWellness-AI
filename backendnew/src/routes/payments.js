
const express = require('express');
const router = express.Router();
const { eq } = require('drizzle-orm');

const { authenticateToken } = require('../middleware/auth');
const { db } = require('../db');
const { users, payments } = require('../db/schema');

const {
  initializeChapaPayment,
  verifyChapaPayment
} = require('../services/chapa_service');

// ============================================================
// INITIALIZE CHAPA PAYMENT
// POST /api/v1/payments/chapa/initialize
// ============================================================

router.post(
  '/chapa/initialize',
  authenticateToken,
  async (req, res) => {
    try {
      const userId = req.user.id;

      const {
        amountEtb = 799,
        phoneNumber
      } = req.body;

      const amount = Number(amountEtb);

      if (!Number.isFinite(amount) || amount <= 0) {
        return res.status(400).json({
          success: false,
          error: 'Invalid payment amount'
        });
      }

      const userResult = await db
        .select()
        .from(users)
        .where(eq(users.id, userId))
        .limit(1);

      const user = userResult[0];

      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'User not found'
        });
      }

      const txRef =
        `ethionutri-tx-${Date.now()}-${Math.random()
          .toString(36)
          .slice(2, 8)}`;

      const paymentResult = await initializeChapaPayment({
        txRef,
        amountEtb: amount,
        email: user.email,
        name: user.name,
        phoneNumber
      });

      if (!paymentResult?.checkoutUrl) {
        throw new Error(
          'Chapa did not return a checkout URL'
        );
      }

      await db
        .insert(payments)
        .values({
          userId,
          txRef,
          amountEtb: amount,
          status: 'pending',
          paymentMethod: 'chapa',
          rawResponse: paymentResult.raw || {}
        });

      return res.status(200).json({
        success: true,
        status: 'success',
        message: 'Payment initialized successfully',
        checkoutUrl: paymentResult.checkoutUrl,
        txRef,
        isSimulation: paymentResult.isSimulation || false
      });
    } catch (err) {
      console.error('Payment Initialization Error:', err);

      return res.status(500).json({
        success: false,
        error: 'Failed to initialize payment',
        details: err.message
      });
    }
  }
);

// ============================================================
// VERIFY PAYMENT
// GET /api/v1/payments/chapa/verify/:txRef
// ============================================================

router.get(
  '/chapa/verify/:txRef',
  authenticateToken,
  async (req, res) => {
    try {
      const { txRef } = req.params;

      // Find the payment first and confirm ownership.
      const paymentResult = await db
        .select()
        .from(payments)
        .where(eq(payments.txRef, txRef))
        .limit(1);

      const paymentRecord = paymentResult[0];

      if (!paymentRecord) {
        return res.status(404).json({
          verified: false,
          error: 'Payment record not found'
        });
      }

      if (paymentRecord.userId !== req.user.id) {
        return res.status(403).json({
          verified: false,
          error: 'You do not own this transaction'
        });
      }

      // Verify with Chapa; never trust the browser redirect.
      const chapaResult = await verifyChapaPayment(txRef);

      console.log('Verification result:', chapaResult);

      if (!chapaResult?.verified) {
        return res.status(200).json({
          verified: false,
          status: chapaResult?.status || 'pending',
          message: 'Payment has not been confirmed by Chapa.',
          txRef
        });
      }

      await db
        .update(payments)
        .set({
          status: 'success'
        })
        .where(eq(payments.txRef, txRef));

      await db
        .update(users)
        .set({
          isPremium: true,
          paymentStatus: 'active_premium'
        })
        .where(eq(users.id, paymentRecord.userId));

      return res.status(200).json({
        verified: true,
        status: 'success',
        isPremiumActive: true,
        message:
          'Payment verified successfully. EthioWellness Premium is now active.',
        txRef
      });
    } catch (err) {
      console.error('Payment Verification Error:', err);

      return res.status(500).json({
        verified: false,
        error: 'Payment verification failed',
        details: err.message
      });
    }
  }
);

// ============================================================
// CHAPA CALLBACK
// POST /api/v1/payments/chapa/callback
// ============================================================

router.post(
  '/chapa/callback',
  async (req, res) => {
    try {
      console.log('Chapa callback received:', req.body);

      const txRef =
        req.body?.tx_ref ||
        req.body?.trx_ref;

      if (!txRef) {
        return res.status(400).json({
          error: 'Transaction reference missing'
        });
      }

      // Verify the transaction directly with Chapa.
      const chapaResult = await verifyChapaPayment(txRef);

      if (!chapaResult?.verified) {
        return res.status(200).json({
          status: 'pending'
        });
      }

      const paymentResult = await db
        .select()
        .from(payments)
        .where(eq(payments.txRef, txRef))
        .limit(1);

      const payment = paymentResult[0];

      if (!payment) {
        console.warn(
          `Verified Chapa transaction has no local record: ${txRef}`
        );

        return res.status(404).json({
          status: 'error',
          error: 'Payment record not found'
        });
      }

      await db
        .update(payments)
        .set({
          status: 'success'
        })
        .where(eq(payments.txRef, txRef));

      await db
        .update(users)
        .set({
          isPremium: true,
          paymentStatus: 'active_premium'
        })
        .where(eq(users.id, payment.userId));

      return res.status(200).json({
        status: 'success'
      });
    } catch (err) {
      console.error('Chapa Callback Error:', err);

      return res.status(500).json({
        error: 'Callback processing failed'
      });
    }
  }
);

// ============================================================
// SUCCESS RETURN
// GET /api/v1/payments/success
//
// This page is served by Express itself.
// It does not redirect to localhost:3000.
// It does NOT independently activate Premium.
// ============================================================

router.get('/success', (req, res) => {
  const txRef = req.query.tx_ref;

  if (!txRef || typeof txRef !== 'string') {
    return res.status(400).send(`
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>EthioWellness AI</title>
        </head>
        <body>
          <h2>Missing transaction reference</h2>
          <p>Please return to EthioWellness AI and check your payment status.</p>
        </body>
      </html>
    `);
  }

  res.set('Cache-Control', 'no-store');

  return res.status(200).send(`
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Payment Return - EthioWellness AI</title>
        <style>
          * { box-sizing: border-box; }

          body {
            font-family: Arial, sans-serif;
            background: #f4f7f5;
            color: #1b3327;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
          }

          main {
            background: #fff;
            padding: 32px;
            border-radius: 16px;
            text-align: center;
            width: 100%;
            max-width: 440px;
            box-shadow: 0 8px 30px rgba(0, 0, 0, .08);
          }

          h1 { color: #16834a; }

          p {
            line-height: 1.6;
            overflow-wrap: anywhere;
          }

          .reference {
            font-size: 13px;
            color: #52665a;
          }

          button {
            background: #16834a;
            color: white;
            border: 0;
            border-radius: 8px;
            padding: 12px 20px;
            font-size: 16px;
            cursor: pointer;
          }
        </style>
      </head>
      <body>
        <main>
          <h1>Payment Return Received</h1>

          <p>
            Chapa has returned you to EthioWellness AI.
            Return to the app to check your verified
            payment status and Premium access.
          </p>

          <p class="reference">
            Transaction reference:
            <strong id="txRef"></strong>
          </p>

          <button onclick="window.close()">
            Close Page
          </button>
        </main>

        <script>
          document.getElementById('txRef').textContent =
            new URLSearchParams(window.location.search)
              .get('tx_ref') || '';
        </script>
      </body>
    </html>
  `);
});

module.exports = router;