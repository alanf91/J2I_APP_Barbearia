require('dotenv').config();

const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const crypto = require('node:crypto');

const {
  registerPayment,
  findPaymentsForAppointment,
} = require('./payment_store');

const {
  registerMercadoPagoWebhook,
} = require('./mercado_pago_webhook');

const {
  initializeApp,
  applicationDefault,
} = require('firebase-admin/app');

const { getAuth } = require('firebase-admin/auth');

const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require('firebase-admin/firestore');

// ============================================================
// CONFIGURAÇÃO
// ============================================================

const MERCADO_PAGO_ACCESS_TOKEN =
  process.env.MERCADO_PAGO_ACCESS_TOKEN;

const MERCADO_PAGO_WEBHOOK_SECRET = String(
  process.env.MERCADO_PAGO_WEBHOOK_SECRET || '',
).trim();

const MERCADO_PAGO_TEST_MODE =
  String(process.env.MERCADO_PAGO_TEST_MODE || 'false')
    .toLowerCase() === 'true';

const MERCADO_PAGO_ORDERS_URL =
  'https://api.mercadopago.com/v1/orders';

const FIREBASE_PROJECT_ID = String(
  process.env.FIREBASE_PROJECT_ID || '',
).trim();

const PORT = Number(process.env.PORT || 8080);
const RECOVERY_EXPIRATION_MINUTES = 15;
const RECOVERY_EXPIRATION_MS =
  RECOVERY_EXPIRATION_MINUTES * 60 * 1000;

const PAYMENT_CREATION_LOCK_MS = 90 * 1000;

const RETRYABLE_PAYMENT_STATUSES = new Set([
  'failed',
  'canceled',
  'cancelled',
  'expired',
]);

if (!MERCADO_PAGO_ACCESS_TOKEN) {
  console.error(
    'ERRO: MERCADO_PAGO_ACCESS_TOKEN não configurado.',
  );
  process.exit(1);
}

if (!FIREBASE_PROJECT_ID) {
  console.error(
    'ERRO: FIREBASE_PROJECT_ID não configurado.',
  );
  process.exit(1);
}

// ============================================================
// FIREBASE
// ============================================================

initializeApp({
  credential: applicationDefault(),
  projectId: FIREBASE_PROJECT_ID,
});

const auth = getAuth();
const db = getFirestore();

// ============================================================
// EXPRESS
// ============================================================

const app = express();

app.set('trust proxy', 1);
app.use(helmet());
app.use(express.json({ limit: '20kb' }));

const recoveryLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/v1/mfa-recovery', recoveryLimiter);

// ============================================================
// UTILITÁRIOS GERAIS
// ============================================================

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function isValidEmail(email) {
  return (
    email.length >= 5 &&
    email.length <= 254 &&
    email.includes('@') &&
    email.includes('.')
  );
}

function normalizeBrazilPhone(value) {
  let digits = String(value || '').replace(/\D/g, '');

  if (
    digits.startsWith('55') &&
    (digits.length === 12 || digits.length === 13)
  ) {
    digits = digits.substring(2);
  }

  if (digits.length !== 10 && digits.length !== 11) {
    return null;
  }

  return digits;
}

function createRecoveryToken() {
  return crypto.randomBytes(32).toString('base64url');
}

function hashToken(token) {
  return crypto
    .createHash('sha256')
    .update(token)
    .digest('hex');
}

function safeCompareHashes(first, second) {
  try {
    const a = Buffer.from(first, 'hex');
    const b = Buffer.from(second, 'hex');

    if (a.length !== b.length) {
      return false;
    }

    return crypto.timingSafeEqual(a, b);
  } catch (_) {
    return false;
  }
}

function parseFirebaseTime(value) {
  if (!value) {
    return 0;
  }

  const milliseconds = Date.parse(value);

  return Number.isFinite(milliseconds)
    ? milliseconds
    : 0;
}

function getBearerToken(request) {
  const authorization = String(
    request.headers.authorization || '',
  ).trim();

  if (!authorization.startsWith('Bearer ')) {
    return null;
  }

  return authorization.substring(7).trim() || null;
}

function normalizePaymentStatus(value) {
  return String(value || '')
    .trim()
    .toLowerCase();
}

function createIdempotencyKey(value) {
  return crypto
    .createHash('sha256')
    .update(value)
    .digest('hex');
}

function getPayerEmail(decodedToken) {
  if (MERCADO_PAGO_TEST_MODE) {
    return 'test_user_br@testuser.com';
  }

  return normalizeEmail(decodedToken?.email);
}

function getAppointmentAmount(appointment) {
  const priceCents = Number(
    appointment?.priceCents,
  );

  if (
    !Number.isInteger(priceCents) ||
    priceCents <= 0
  ) {
    return null;
  }

  const realAmount =
    (priceCents / 100).toFixed(2);

  return {
    priceCents,
    realAmount,
    mercadoPagoAmount: realAmount,
  };
}

function getAppointmentExpirationMs(appointment) {
  const expirationMs =
    appointment
      ?.paymentExpiresAt
      ?.toMillis?.();

  return Number.isFinite(expirationMs)
    ? expirationMs
    : null;
}

async function readMercadoPagoResponse(response) {
  const raw =
    await response.text();

  if (!raw) {
    return {};
  }

  try {
    return JSON.parse(raw);
  } catch (_) {
    return {};
  }
}

function sendKnownError(
  response,
  result,
) {
  return response
    .status(result.statusCode)
    .json({
      ok: false,
      code: result.code,
      message: result.message,
    });
}

function handleAuthError(
  error,
  response,
) {
  if (
    error?.code ===
    'auth/id-token-revoked'
  ) {
    response
      .status(401)
      .json({
        ok: false,
        code: 'TOKEN_REVOKED',
        message:
          'Sua sessão expirou. Entre novamente.',
      });

    return true;
  }

  if (
    error?.code ===
      'auth/id-token-expired' ||
    error?.code ===
      'auth/argument-error'
  ) {
    response
      .status(401)
      .json({
        ok: false,
        code: 'UNAUTHORIZED',
        message:
          'Sua sessão não é mais válida. Entre novamente.',
      });

    return true;
  }

  return false;
}

// ============================================================
// APPOINTMENT
// ============================================================

async function validateAppointmentForPayment({
  appointmentReference,
  appointment,
}) {
  const status =
    String(
      appointment?.status || '',
    ).trim();

  if (status === 'cancelled') {
    return {
      ok: false,
      statusCode: 409,
      code: 'APPOINTMENT_CANCELLED',
      message:
        'Este agendamento foi cancelado.',
    };
  }

  if (status === 'expired') {
    return {
      ok: false,
      statusCode: 409,
      code: 'APPOINTMENT_EXPIRED',
      message:
        'A reserva deste horário expirou. Escolha o horário novamente.',
    };
  }

  if (status === 'confirmed') {
    return {
      ok: false,
      statusCode: 409,
      code:
        'APPOINTMENT_ALREADY_CONFIRMED',
      message:
        'Este agendamento já está confirmado.',
    };
  }

  if (status !== 'pending_payment') {
    return {
      ok: false,
      statusCode: 409,
      code: 'APPOINTMENT_NOT_PAYABLE',
      message:
        'Este agendamento não está disponível para pagamento.',
    };
  }

  const expirationMs =
    getAppointmentExpirationMs(
      appointment,
    );

  if (expirationMs == null) {
    return {
      ok: false,
      statusCode: 409,
      code:
        'INVALID_PAYMENT_RESERVATION',
      message:
        'A reserva do horário não possui uma validade correta.',
    };
  }

  const nowMs =
    Date.now();

  if (expirationMs <= nowMs) {
    try {
      await expirePendingAppointment({
        appointmentId:
          appointmentReference.id,
        source:
          'payment_validation',
      });
    } catch (error) {
      console.error(
        'EXPIRE APPOINTMENT ERROR:',
        {
          appointmentId:
            appointmentReference.id,
          message:
            error?.message ||
            'Unknown error',
        },
      );
    }

    return {
      ok: false,
      statusCode: 409,
      code: 'APPOINTMENT_EXPIRED',
      message:
        'A reserva de 2 minutos expirou. Escolha o horário novamente.',
    };
  }

  const startAtMs =
    appointment
      ?.startAt
      ?.toMillis?.();

  if (
    Number.isFinite(startAtMs) &&
    startAtMs <= nowMs
  ) {
    return {
      ok: false,
      statusCode: 409,
      code:
        'APPOINTMENT_ALREADY_STARTED',
      message:
        'O horário deste atendimento já começou.',
    };
  }

  return {
    ok: true,
  };
}

async function loadOwnedAppointment({
  appointmentId,
  uid,
}) {
  const reference =
    db
      .collection('appointments')
      .doc(appointmentId);

  const snapshot =
    await reference.get();

  if (!snapshot.exists) {
    return {
      ok: false,
      statusCode: 404,
      code: 'APPOINTMENT_NOT_FOUND',
      message:
        'Agendamento não encontrado.',
    };
  }

  const appointment =
    snapshot.data();

  if (!appointment) {
    return {
      ok: false,
      statusCode: 404,
      code: 'APPOINTMENT_NOT_FOUND',
      message:
        'Dados do agendamento não encontrados.',
    };
  }

  if (
    appointment.userId !== uid
  ) {
    return {
      ok: false,
      statusCode: 403,
      code: 'FORBIDDEN',
      message:
        'Você não possui acesso a este agendamento.',
    };
  }

  return {
    ok: true,
    reference,
    appointment,
  };
}

// ============================================================
// BLOQUEIO CONTRA COBRANÇA DUPLICADA
// ============================================================

function paymentRecordBlocksNewCharge(
  paymentData,
) {
  const status =
    normalizePaymentStatus(
      paymentData?.status,
    );

  if (!status) {
    return true;
  }

  return !RETRYABLE_PAYMENT_STATUSES
    .has(status);
}

async function getBlockingPaymentForAppointment(
  appointmentId,
) {
  const payments =
    await findPaymentsForAppointment({
      db,
      appointmentId,
      limit: 20,
    });

  return (
    payments.find(
      (payment) =>
        paymentRecordBlocksNewCharge(
          payment?.data,
        ),
    ) || null
  );
}

function getBlockingPaymentResponse(
  blockingPayment,
) {
  const data =
    blockingPayment?.data || {};

  const status =
    normalizePaymentStatus(
      data.status,
    );

  const statusDetail =
    normalizePaymentStatus(
      data.statusDetail,
    );

  if (
    status === 'processed' &&
    statusDetail === 'accredited'
  ) {
    return {
      ok: false,
      statusCode: 409,
      code:
        'PAYMENT_ALREADY_APPROVED',
      message:
        'Este agendamento já possui um pagamento aprovado.',
    };
  }

  return {
    ok: false,
    statusCode: 409,
    code:
      'PAYMENT_ALREADY_IN_PROGRESS',
    message:
      'Este agendamento já possui um pagamento em andamento.',
  };
}

// ============================================================
// LOCK ATÔMICO DE CRIAÇÃO DE PAGAMENTO
// ============================================================

async function acquirePaymentCreationLock({
  appointmentReference,
  uid,
  method,
}) {
  const lockId =
    crypto.randomUUID();

  return db.runTransaction(
    async (transaction) => {
      const snapshot =
        await transaction.get(
          appointmentReference,
        );

      if (!snapshot.exists) {
        return {
          ok: false,
          statusCode: 404,
          code:
            'APPOINTMENT_NOT_FOUND',
          message:
            'Agendamento não encontrado.',
        };
      }

      const appointment =
        snapshot.data() || {};

      if (
        appointment.userId !== uid
      ) {
        return {
          ok: false,
          statusCode: 403,
          code: 'FORBIDDEN',
          message:
            'Você não possui acesso a este agendamento.',
        };
      }

      if (
        String(
          appointment.status || '',
        ).trim() !==
        'pending_payment'
      ) {
        return {
          ok: false,
          statusCode: 409,
          code:
            'APPOINTMENT_NOT_PAYABLE',
          message:
            'Este agendamento não está disponível para pagamento.',
        };
      }

      const expirationMs =
        getAppointmentExpirationMs(
          appointment,
        );

      const nowMs =
        Date.now();

      if (
        expirationMs == null ||
        expirationMs <= nowMs
      ) {
        return {
          ok: false,
          statusCode: 409,
          code:
            'APPOINTMENT_EXPIRED',
          message:
            'A reserva de 2 minutos expirou. Escolha o horário novamente.',
        };
      }

      const currentLock =
        appointment
          .paymentCreationLock;

      const currentLockExpiresAtMs =
        currentLock
          ?.expiresAt
          ?.toMillis?.() ||
        0;

      if (
        currentLock?.id &&
        currentLockExpiresAtMs >
          nowMs
      ) {
        return {
          ok: false,
          statusCode: 409,
          code:
            'PAYMENT_CREATION_IN_PROGRESS',
          message:
            'Já existe uma tentativa de pagamento sendo criada para este agendamento.',
        };
      }

      transaction.set(
        appointmentReference,
        {
          paymentCreationLock: {
            id:
              lockId,

            method:
              String(
                method || '',
              ).trim(),

            createdAt:
              FieldValue
                .serverTimestamp(),

            expiresAt:
              Timestamp.fromMillis(
                nowMs +
                PAYMENT_CREATION_LOCK_MS,
              ),
          },
        },
        {
          merge: true,
        },
      );

      return {
        ok: true,
        lockId,
      };
    },
  );
}

async function releasePaymentCreationLock({
  appointmentReference,
  lockId,
}) {
  if (
    !appointmentReference ||
    !lockId
  ) {
    return;
  }

  try {
    await db.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(
            appointmentReference,
          );

        if (!snapshot.exists) {
          return;
        }

        const appointment =
          snapshot.data() || {};

        if (
          appointment
            .paymentCreationLock
            ?.id !==
          lockId
        ) {
          return;
        }

        transaction.update(
          appointmentReference,
          {
            paymentCreationLock:
              FieldValue.delete(),
          },
        );
      },
    );
  } catch (error) {
    console.error(
      'RELEASE PAYMENT LOCK ERROR:',
      {
        appointmentId:
          appointmentReference.id,

        message:
          error?.message ||
          'Unknown error',
      },
    );
  }
}

// ============================================================
// MERCADO PAGO - CONSULTAR ORDER
// ============================================================

async function getMercadoPagoOrder(
  orderId,
) {
  const normalizedOrderId =
    String(
      orderId || '',
    ).trim();

  if (!normalizedOrderId) {
    throw new Error(
      'MERCADO_PAGO_ORDER_ID_REQUIRED',
    );
  }

  const response =
    await fetch(
      `${MERCADO_PAGO_ORDERS_URL}/${encodeURIComponent(
        normalizedOrderId,
      )}`,
      {
        method: 'GET',

        headers: {
          Accept:
            'application/json',

          Authorization:
            `Bearer ${MERCADO_PAGO_ACCESS_TOKEN}`,
        },
      },
    );

  const data =
    await readMercadoPagoResponse(
      response,
    );

  if (!response.ok) {
    const error =
      new Error(
        'MERCADO_PAGO_ORDER_QUERY_FAILED',
      );

    error.status =
      response.status;

    throw error;
  }

  return data;
}

// ============================================================
// PIX SALVO
// ============================================================

function getStoredPixData(
  paymentRecord,
) {
  const paymentData =
    paymentRecord?.data || {};

  const pix =
    paymentData.pix &&
    typeof paymentData.pix ===
      'object'
      ? paymentData.pix
      : {};

  return {
    qrCode:
      String(
        pix.qrCode || '',
      ).trim(),

    qrCodeBase64:
      String(
        pix.qrCodeBase64 || '',
      ).trim(),

    ticketUrl:
      String(
        pix.ticketUrl || '',
      ).trim(),
  };
}

async function updateStoredPaymentStatus({
  paymentRecord,
  status,
  statusDetail,
}) {
  if (!paymentRecord?.id) {
    return;
  }

  await db
    .collection('payments')
    .doc(paymentRecord.id)
    .set(
      {
        status:
          String(
            status || '',
          ).trim(),

        statusDetail:
          String(
            statusDetail || '',
          ).trim(),

        updatedAt:
          FieldValue
            .serverTimestamp(),
      },
      {
        merge: true,
      },
    );
}

// ============================================================
// CONTROLE DE EXPIRAÇÃO PIX
// ============================================================

const PIX_EXPIRATION_SWEEP_INTERVAL_MS =
  5 * 1000;

const PIX_EXPIRATION_BATCH_SIZE =
  100;

const pixExpirationTimers =
  new Map();

let pixExpirationSweepRunning =
  false;

function getOrderPayment(
  order,
  expectedPaymentId = null,
) {
  const payments =
    Array.isArray(
      order
        ?.transactions
        ?.payments,
    )
      ? order.transactions.payments
      : [];

  if (expectedPaymentId) {
    const exact =
      payments.find(
        (item) =>
          String(
            item?.id || '',
          ).trim() ===
          String(
            expectedPaymentId || '',
          ).trim(),
      );

    if (exact) {
      return exact;
    }
  }

  return payments[0] || null;
}

function getOrderAndPaymentStatus(
  order,
  expectedPaymentId = null,
) {
  const payment =
    getOrderPayment(
      order,
      expectedPaymentId,
    );

  return {
    payment,

    orderStatus:
      normalizePaymentStatus(
        order?.status,
      ),

    orderStatusDetail:
      normalizePaymentStatus(
        order?.status_detail,
      ),

    paymentStatus:
      normalizePaymentStatus(
        payment?.status ||
        order?.status,
      ),

    paymentStatusDetail:
      normalizePaymentStatus(
        payment?.status_detail ||
        order?.status_detail,
      ),
  };
}

function isApprovedMercadoPagoPayment(
  status,
  statusDetail,
) {
  return (
    normalizePaymentStatus(
      status,
    ) === 'processed' &&
    normalizePaymentStatus(
      statusDetail,
    ) === 'accredited'
  );
}

function isOrderAlreadyCanceledOrExpired({
  orderStatus,
  paymentStatus,
}) {
  const terminal =
    new Set([
      'canceled',
      'cancelled',
      'expired',
    ]);

  return (
    terminal.has(
      normalizePaymentStatus(
        orderStatus,
      ),
    ) ||
    terminal.has(
      normalizePaymentStatus(
        paymentStatus,
      ),
    )
  );
}

function canCancelMercadoPagoOrder({
  orderStatus,
  paymentStatus,
}) {
  const cancellable =
    new Set([
      'created',
      'action_required',
    ]);

  return (
    cancellable.has(
      normalizePaymentStatus(
        orderStatus,
      ),
    ) ||
    cancellable.has(
      normalizePaymentStatus(
        paymentStatus,
      ),
    )
  );
}

// ============================================================
// CANCELAR ORDER PIX
// ============================================================

async function cancelMercadoPagoOrder(
  orderId,
) {
  const normalizedOrderId =
    String(
      orderId || '',
    ).trim();

  if (!normalizedOrderId) {
    throw new Error(
      'MERCADO_PAGO_ORDER_ID_REQUIRED',
    );
  }

  const response =
    await fetch(
      `${MERCADO_PAGO_ORDERS_URL}/${encodeURIComponent(
        normalizedOrderId,
      )}/cancel`,
      {
        method: 'POST',

        headers: {
          Accept:
            'application/json',

          'Content-Type':
            'application/json',

          Authorization:
            `Bearer ${MERCADO_PAGO_ACCESS_TOKEN}`,

          'X-Idempotency-Key':
            createIdempotencyKey(
              `cancel:reservation-expired:${normalizedOrderId}:v1`,
            ),
        },
      },
    );

  const data =
    await readMercadoPagoResponse(
      response,
    );

  if (!response.ok) {
    const error =
      new Error(
        'MERCADO_PAGO_ORDER_CANCEL_FAILED',
      );

    error.status =
      response.status;

    error.mercadoPagoData =
      data;

    throw error;
  }

  return data;
}

// ============================================================
// MARCAR AGENDAMENTO EXPIRADO
// ============================================================

async function markAppointmentExpiredAfterPixCancellation({
  appointmentId,
  paymentRecord = null,
  orderId = null,
  paymentStatus = null,
  paymentStatusDetail = null,
  cancellationStatus = 'not_required',
  source = 'expiration_worker',
}) {
  const appointmentReference =
    db
      .collection('appointments')
      .doc(appointmentId);

  const paymentReference =
    paymentRecord?.id
      ? db
          .collection('payments')
          .doc(paymentRecord.id)
      : null;

  return db.runTransaction(
    async (transaction) => {
      const appointmentSnapshot =
        await transaction.get(
          appointmentReference,
        );

      let paymentSnapshot =
        null;

      if (paymentReference) {
        paymentSnapshot =
          await transaction.get(
            paymentReference,
          );
      }

      if (
        !appointmentSnapshot.exists
      ) {
        return false;
      }

      const appointment =
        appointmentSnapshot
          .data() ||
        {};

      const currentStatus =
        String(
          appointment.status || '',
        ).trim();

      const expirationMs =
        getAppointmentExpirationMs(
          appointment,
        );

      if (
        currentStatus !==
          'pending_payment' ||
        expirationMs == null ||
        expirationMs >
          Date.now()
      ) {
        return false;
      }

      const normalizedPaymentStatus =
        normalizePaymentStatus(
          paymentStatus,
        );

      const normalizedPaymentStatusDetail =
        normalizePaymentStatus(
          paymentStatusDetail,
        );

      const appointmentUpdate = {
        status:
          'expired',

        expiredAt:
          FieldValue
            .serverTimestamp(),

        pixExpiration: {
          orderId:
            String(
              orderId || '',
            ).trim() ||
            null,

          cancellationStatus,

          source,

          handledAt:
            FieldValue
              .serverTimestamp(),
        },
      };

      if (
        normalizedPaymentStatus
      ) {
        appointmentUpdate[
          'payment.status'
        ] =
          normalizedPaymentStatus;
      }

      if (
        normalizedPaymentStatusDetail
      ) {
        appointmentUpdate[
          'payment.statusDetail'
        ] =
          normalizedPaymentStatusDetail;
      }

      transaction.update(
        appointmentReference,
        appointmentUpdate,
      );

      if (
        paymentReference &&
        paymentSnapshot?.exists
      ) {
        const paymentUpdate = {
          pixExpiration: {
            cancellationStatus,
            source,

            handledAt:
              FieldValue
                .serverTimestamp(),
          },

          updatedAt:
            FieldValue
              .serverTimestamp(),
        };

        if (
          normalizedPaymentStatus
        ) {
          paymentUpdate.status =
            normalizedPaymentStatus;
        }

        if (
          normalizedPaymentStatusDetail
        ) {
          paymentUpdate.statusDetail =
            normalizedPaymentStatusDetail;
        }

        transaction.set(
          paymentReference,
          paymentUpdate,
          {
            merge: true,
          },
        );
      }

      return true;
    },
  );
}

// ============================================================
// PIX APROVADO JÁ OBSERVADO
// EVITA LOOP DO WORKER
// ============================================================

async function markApprovedPixObserved({
  appointmentId,
  paymentRecord = null,
  orderId = null,
  paymentId = null,
  source = 'expiration_worker',
}) {
  const appointmentReference =
    db
      .collection('appointments')
      .doc(appointmentId);

  const paymentReference =
    paymentRecord?.id
      ? db
          .collection('payments')
          .doc(paymentRecord.id)
      : null;

  await db.runTransaction(
    async (transaction) => {
      const appointmentSnapshot =
        await transaction.get(
          appointmentReference,
        );

      let paymentSnapshot =
        null;

      if (paymentReference) {
        paymentSnapshot =
          await transaction.get(
            paymentReference,
          );
      }

      if (
        !appointmentSnapshot.exists
      ) {
        return;
      }

      const appointment =
        appointmentSnapshot
          .data() ||
        {};

      transaction.set(
        appointmentReference,
        {
          pixExpiration: {
            ...(
              appointment
                .pixExpiration ||
              {}
            ),

            approvedObserved:
              true,

            approvedObservedAt:
              FieldValue
                .serverTimestamp(),

            orderId:
              String(
                orderId || '',
              ).trim() ||
              null,

            paymentId:
              String(
                paymentId || '',
              ).trim() ||
              null,

            source,
          },
        },
        {
          merge: true,
        },
      );

      if (
        paymentReference &&
        paymentSnapshot?.exists
      ) {
        const paymentData =
          paymentSnapshot
            .data() ||
          {};

        transaction.set(
          paymentReference,
          {
            pixExpiration: {
              ...(
                paymentData
                  .pixExpiration ||
                {}
              ),

              approvedObserved:
                true,

              approvedObservedAt:
                FieldValue
                  .serverTimestamp(),

              source,
            },

            updatedAt:
              FieldValue
                .serverTimestamp(),
          },
          {
            merge: true,
          },
        );
      }
    },
  );
}

// ============================================================
// EXPIRAR RESERVA E CANCELAR PIX
// ============================================================

async function expirePendingAppointment({
  appointmentId,
  source = 'expiration_worker',
}) {
  const appointmentReference =
    db
      .collection('appointments')
      .doc(appointmentId);

  const appointmentSnapshot =
    await appointmentReference.get();

  if (!appointmentSnapshot.exists) {
    return {
      handled: false,
      reason: 'not_found',
    };
  }

  const appointment =
    appointmentSnapshot
      .data() ||
    {};

  const status =
    String(
      appointment.status || '',
    ).trim();

  const expirationMs =
    getAppointmentExpirationMs(
      appointment,
    );

  if (
    appointment
      ?.pixExpiration
      ?.approvedObserved ===
    true
  ) {
    return {
      handled: false,
      reason:
        'approved_already_observed',
    };
  }

  if (
    status !==
      'pending_payment' ||
    expirationMs == null ||
    expirationMs >
      Date.now()
  ) {
    return {
      handled: false,
      reason:
        'not_expired',
    };
  }

  const payments =
    await findPaymentsForAppointment({
      db,
      appointmentId,
      limit: 20,
    });

  const pixPayment =
    payments
      .filter(
        (record) => {
          const data =
            record?.data || {};

          return (
            String(
              data.method || '',
            )
              .trim()
              .toLowerCase() ===
              'pix' &&
            String(
              data.orderId || '',
            ).trim() &&
            paymentRecordBlocksNewCharge(
              data,
            )
          );
        },
      )
      .sort(
        (a, b) => {
          const aMs =
            a
              ?.data
              ?.updatedAt
              ?.toMillis?.() ||
            a
              ?.data
              ?.createdAt
              ?.toMillis?.() ||
            0;

          const bMs =
            b
              ?.data
              ?.updatedAt
              ?.toMillis?.() ||
            b
              ?.data
              ?.createdAt
              ?.toMillis?.() ||
            0;

          return bMs - aMs;
        },
      )[0] ||
    null;

  if (!pixPayment) {
    const marked =
      await markAppointmentExpiredAfterPixCancellation({
        appointmentId,

        cancellationStatus:
          'no_pix_created',

        source,
      });

    return {
      handled:
        marked,

      reason:
        marked
          ? 'expired_without_pix'
          : 'state_changed',
    };
  }

  const paymentData =
    pixPayment.data ||
    {};

  const orderId =
    String(
      paymentData.orderId || '',
    ).trim();

  const expectedPaymentId =
    String(
      paymentData.paymentId || '',
    ).trim();

  if (!orderId) {
    return {
      handled: false,
      reason:
        'missing_order_id',
    };
  }

  let order;

  try {
    order =
      await getMercadoPagoOrder(
        orderId,
      );
  } catch (error) {
    console.error(
      'PIX EXPIRATION ORDER QUERY ERROR:',
      {
        appointmentId,
        orderId,
        source,

        status:
          error?.status ||
          null,

        message:
          error?.message ||
          'Unknown error',
      },
    );

    return {
      handled: false,
      reason:
        'order_query_failed',
    };
  }

  const expectedExternalReference =
    `j2i_appointment_${appointmentId}`;

  if (
    String(
      order?.id || '',
    ).trim() !==
      orderId ||
    String(
      order?.external_reference ||
      '',
    ).trim() !==
      expectedExternalReference
  ) {
    console.error(
      'PIX EXPIRATION INTEGRITY ERROR:',
      {
        appointmentId,
        orderId,

        returnedOrderId:
          String(
            order?.id || '',
          ).trim(),

        externalReference:
          String(
            order?.external_reference ||
            '',
          ).trim(),
      },
    );

    return {
      handled: false,
      reason:
        'integrity_mismatch',
    };
  }

  let statusInfo =
    getOrderAndPaymentStatus(
      order,
      expectedPaymentId,
    );

  await updateStoredPaymentStatus({
    paymentRecord:
      pixPayment,

    status:
      statusInfo.paymentStatus,

    statusDetail:
      statusInfo
        .paymentStatusDetail,
  });

  // ==========================================================
  // PAGAMENTO JÁ APROVADO
  // NÃO CANCELAR
  // ==========================================================

  if (
    isApprovedMercadoPagoPayment(
      statusInfo.paymentStatus,
      statusInfo
        .paymentStatusDetail,
    )
  ) {
    await markApprovedPixObserved({
      appointmentId,

      paymentRecord:
        pixPayment,

      orderId,

      paymentId:
        expectedPaymentId,

      source,
    });

    console.log(
      'PIX EXPIRATION: PAGAMENTO JÁ APROVADO ✅',
      {
        appointmentId,
        orderId,

        paymentId:
          expectedPaymentId ||
          null,
      },
    );

    return {
      handled: true,
      reason:
        'already_approved_marked',
    };
  }

  // ==========================================================
  // ORDER JÁ CANCELADA / EXPIRADA
  // ==========================================================

  if (
    isOrderAlreadyCanceledOrExpired(
      statusInfo,
    )
  ) {
    const finalStatus =
      [
        'canceled',
        'cancelled',
        'expired',
      ].includes(
        statusInfo.orderStatus,
      )
        ? statusInfo.orderStatus
        : (
            statusInfo.paymentStatus ||
            statusInfo.orderStatus ||
            'expired'
          );

    const marked =
      await markAppointmentExpiredAfterPixCancellation({
        appointmentId,

        paymentRecord:
          pixPayment,

        orderId,

        paymentStatus:
          finalStatus,

        paymentStatusDetail:
          statusInfo
            .paymentStatusDetail ||
          statusInfo
            .orderStatusDetail,

        cancellationStatus:
          'already_closed',

        source,
      });

    return {
      handled:
        marked,

      reason:
        marked
          ? 'already_closed'
          : 'state_changed',
    };
  }

  // ==========================================================
  // ORDER AINDA NÃO CANCELÁVEL
  // ==========================================================

  if (
    !canCancelMercadoPagoOrder(
      statusInfo,
    )
  ) {
    console.warn(
      'PIX EXPIRATION: ORDER AINDA NÃO CANCELÁVEL',
      {
        appointmentId,
        orderId,

        orderStatus:
          statusInfo.orderStatus,

        paymentStatus:
          statusInfo.paymentStatus,

        paymentStatusDetail:
          statusInfo
            .paymentStatusDetail,
      },
    );

    return {
      handled: false,
      reason:
        'not_cancellable_yet',
    };
  }

  // ==========================================================
  // CANCELAR ORDER
  // ==========================================================

  let canceledOrder;

  try {
    canceledOrder =
      await cancelMercadoPagoOrder(
        orderId,
      );
  } catch (error) {
    console.warn(
      'PIX CANCEL REQUEST FAILED; RECHECKING ORDER:',
      {
        appointmentId,
        orderId,

        status:
          error?.status ||
          null,

        message:
          error?.message ||
          'Unknown error',
      },
    );

    try {
      const refreshedOrder =
        await getMercadoPagoOrder(
          orderId,
        );

      statusInfo =
        getOrderAndPaymentStatus(
          refreshedOrder,
          expectedPaymentId,
        );

      await updateStoredPaymentStatus({
        paymentRecord:
          pixPayment,

        status:
          statusInfo
            .paymentStatus,

        statusDetail:
          statusInfo
            .paymentStatusDetail,
      });

      if (
        isApprovedMercadoPagoPayment(
          statusInfo.paymentStatus,
          statusInfo
            .paymentStatusDetail,
        )
      ) {
        await markApprovedPixObserved({
          appointmentId,

          paymentRecord:
            pixPayment,

          orderId,

          paymentId:
            expectedPaymentId,

          source,
        });

        return {
          handled: true,
          reason:
            'approved_during_cancel_marked',
        };
      }

      if (
        isOrderAlreadyCanceledOrExpired(
          statusInfo,
        )
      ) {
        const marked =
          await markAppointmentExpiredAfterPixCancellation({
            appointmentId,

            paymentRecord:
              pixPayment,

            orderId,

            paymentStatus:
              statusInfo
                .paymentStatus ||
              statusInfo
                .orderStatus ||
              'expired',

            paymentStatusDetail:
              statusInfo
                .paymentStatusDetail ||
              statusInfo
                .orderStatusDetail,

            cancellationStatus:
              'closed_after_recheck',

            source,
          });

        return {
          handled:
            marked,

          reason:
            marked
              ? 'closed_after_recheck'
              : 'state_changed',
        };
      }
    } catch (recheckError) {
      console.error(
        'PIX CANCEL RECHECK ERROR:',
        {
          appointmentId,
          orderId,

          message:
            recheckError
              ?.message ||
            'Unknown error',
        },
      );
    }

    return {
      handled: false,
      reason:
        'cancel_failed',
    };
  }

  // ==========================================================
  // CANCELAMENTO CONFIRMADO
  // ==========================================================

  const canceledStatusInfo =
    getOrderAndPaymentStatus(
      canceledOrder,
      expectedPaymentId,
    );

  const finalPaymentStatus =
    [
      'canceled',
      'cancelled',
      'expired',
    ].includes(
      canceledStatusInfo
        .orderStatus,
    )
      ? canceledStatusInfo
          .orderStatus
      : (
          canceledStatusInfo
            .paymentStatus ||
          canceledStatusInfo
            .orderStatus ||
          'canceled'
        );

  const finalPaymentStatusDetail =
    canceledStatusInfo
      .orderStatusDetail ||
    canceledStatusInfo
      .paymentStatusDetail ||
    finalPaymentStatus;

  const marked =
    await markAppointmentExpiredAfterPixCancellation({
      appointmentId,

      paymentRecord:
        pixPayment,

      orderId,

      paymentStatus:
        finalPaymentStatus,

      paymentStatusDetail:
        finalPaymentStatusDetail,

      cancellationStatus:
        'canceled_at_reservation_expiry',

      source,
    });

  if (marked) {
    console.log(
      'PIX CANCELADO POR EXPIRAÇÃO DA RESERVA ✅',
      {
        appointmentId,
        orderId,

        paymentId:
          expectedPaymentId ||
          null,
      },
    );
  }

  return {
    handled:
      marked,

    reason:
      marked
        ? 'canceled'
        : 'state_changed',
  };
}

// ============================================================
// TIMER INDIVIDUAL DA RESERVA PIX
// ============================================================

function schedulePixExpiration(
  appointmentId,
  expirationMs,
) {
  const normalizedAppointmentId =
    String(
      appointmentId || '',
    ).trim();

  if (
    !normalizedAppointmentId ||
    !Number.isFinite(
      expirationMs,
    )
  ) {
    return;
  }

  const currentTimer =
    pixExpirationTimers.get(
      normalizedAppointmentId,
    );

  if (currentTimer) {
    clearTimeout(
      currentTimer,
    );
  }

  const delay =
    Math.max(
      0,

      expirationMs -
      Date.now() +
      150,
    );

  const timer =
    setTimeout(
      async () => {
        pixExpirationTimers.delete(
          normalizedAppointmentId,
        );

        try {
          await expirePendingAppointment({
            appointmentId:
              normalizedAppointmentId,

            source:
              'scheduled_timer',
          });
        } catch (error) {
          console.error(
            'PIX EXPIRATION TIMER ERROR:',
            {
              appointmentId:
                normalizedAppointmentId,

              message:
                error?.message ||
                'Unknown error',
            },
          );
        }
      },

      delay,
    );

  timer.unref?.();

  pixExpirationTimers.set(
    normalizedAppointmentId,
    timer,
  );
}

// ============================================================
// WORKER DE RECUPERAÇÃO
// ============================================================

async function sweepExpiredPendingAppointments() {
  if (
    pixExpirationSweepRunning
  ) {
    return;
  }

  pixExpirationSweepRunning =
    true;

  try {
    const snapshot =
      await db
        .collection(
          'appointments',
        )
        .where(
          'status',
          '==',
          'pending_payment',
        )
        .limit(
          PIX_EXPIRATION_BATCH_SIZE,
        )
        .get();

    const nowMs =
      Date.now();

    for (
      const document
      of snapshot.docs
    ) {
      const appointment =
        document.data() ||
        {};

      // Se já identificamos que o pagamento foi aprovado,
      // não consultar novamente a cada 5 segundos.
      if (
        appointment
          ?.pixExpiration
          ?.approvedObserved ===
        true
      ) {
        continue;
      }

      const expirationMs =
        getAppointmentExpirationMs(
          appointment,
        );

      if (
        expirationMs == null
      ) {
        continue;
      }

      if (
        expirationMs <=
        nowMs
      ) {
        try {
          await expirePendingAppointment({
            appointmentId:
              document.id,

            source:
              'periodic_sweep',
          });
        } catch (error) {
          console.error(
            'PIX EXPIRATION SWEEP ITEM ERROR:',
            {
              appointmentId:
                document.id,

              message:
                error?.message ||
                'Unknown error',
            },
          );
        }
      }
    }
  } catch (error) {
    console.error(
      'PIX EXPIRATION SWEEP ERROR:',
      {
        message:
          error?.message ||
          'Unknown error',
      },
    );
  } finally {
    pixExpirationSweepRunning =
      false;
  }
}

function startPixExpirationWorker() {
  setTimeout(
    () => {
      sweepExpiredPendingAppointments();
    },
    1000,
  ).unref?.();

  const interval =
    setInterval(
      sweepExpiredPendingAppointments,
      PIX_EXPIRATION_SWEEP_INTERVAL_MS,
    );

  interval.unref?.();
}

// ============================================================
// REUTILIZAR PIX EXISTENTE
// ============================================================

async function tryReuseExistingPix({
  blockingPayment,
  appointmentId,
  amounts,
  reservationExpiresAtMs = null,
}) {
  const stored =
    blockingPayment?.data ||
    {};

  const storedMethod =
    String(
      stored.method || '',
    )
      .trim()
      .toLowerCase();

  if (storedMethod !== 'pix') {
    return {
      action: 'block',

      conflict:
        getBlockingPaymentResponse(
          blockingPayment,
        ),
    };
  }

  const storedPix =
    getStoredPixData(
      blockingPayment,
    );

  if (!storedPix.qrCode) {
    return {
      action: 'block',

      conflict: {
        ok: false,
        statusCode: 409,
        code:
          'PIX_QR_NOT_STORED',

        message:
          'Este Pix foi criado antes da recuperação automática do QR Code. ' +
          'Crie um novo agendamento para testar esta correção.',
      },
    };
  }

  const orderId =
    String(
      stored.orderId || '',
    ).trim();

  const storedPaymentId =
    String(
      stored.paymentId || '',
    ).trim();

  if (
    !orderId ||
    !storedPaymentId
  ) {
    return {
      action: 'block',

      conflict: {
        ok: false,
        statusCode: 409,
        code:
          'PIX_REFERENCE_INCOMPLETE',

        message:
          'O Pix existente está sem identificação completa.',
      },
    };
  }

  let order;

  try {
    order =
      await getMercadoPagoOrder(
        orderId,
      );
  } catch (error) {
    console.error(
      'REUSE PIX ORDER QUERY ERROR:',
      {
        appointmentId,
        orderId,

        status:
          error?.status ||
          null,

        message:
          error?.message ||
          'Unknown error',
      },
    );

    return {
      action: 'block',

      conflict: {
        ok: false,
        statusCode: 502,
        code:
          'PIX_REUSE_CHECK_FAILED',

        message:
          'Não foi possível consultar o Pix existente agora. ' +
          'Tente novamente em alguns segundos.',
      },
    };
  }

  if (
    String(
      order?.id || '',
    ).trim() !==
    orderId
  ) {
    return {
      action: 'block',

      conflict: {
        ok: false,
        statusCode: 409,
        code:
          'PIX_ORDER_MISMATCH',

        message:
          'A cobrança Pix retornada não corresponde ao registro salvo.',
      },
    };
  }

  const expectedExternalReference =
    `j2i_appointment_${appointmentId}`;

  if (
    String(
      order?.external_reference ||
      '',
    ).trim() !==
    expectedExternalReference
  ) {
    return {
      action: 'block',

      conflict: {
        ok: false,
        statusCode: 409,
        code:
          'PIX_APPOINTMENT_MISMATCH',

        message:
          'A cobrança Pix não pertence a este agendamento.',
      },
    };
  }

  const payments =
    Array.isArray(
      order
        ?.transactions
        ?.payments,
    )
      ? order.transactions.payments
      : [];

  const payment =
    payments.find(
      (item) =>
        String(
          item?.id || '',
        ).trim() ===
        storedPaymentId,
    ) ||
    payments[0] ||
    null;

  if (!payment) {
    return {
      action: 'block',

      conflict: {
        ok: false,
        statusCode: 502,
        code:
          'PIX_PAYMENT_NOT_FOUND',

        message:
          'O Mercado Pago não retornou o pagamento Pix da cobrança existente.',
      },
    };
  }

  if (
    String(
      payment.id || '',
    ).trim() !==
    storedPaymentId
  ) {
    return {
      action: 'block',

      conflict: {
        ok: false,
        statusCode: 409,
        code:
          'PIX_PAYMENT_MISMATCH',

        message:
          'O pagamento Pix retornado não corresponde ao registro salvo.',
      },
    };
  }

  const status =
    normalizePaymentStatus(
      payment.status ||
      order.status,
    );

  const statusDetail =
    normalizePaymentStatus(
      payment.status_detail ||
      order.status_detail,
    );

  await updateStoredPaymentStatus({
    paymentRecord:
      blockingPayment,

    status,

    statusDetail,
  });

  if (
    RETRYABLE_PAYMENT_STATUSES
      .has(status)
  ) {
    return {
      action: 'retry',
    };
  }

  const approved =
    status === 'processed' &&
    statusDetail === 'accredited';

  return {
    action: 'reuse',

    result: {
      ok: true,

      reused: true,

      approved,

      appointmentId,

      reservationExpiresAtMs:
        Number.isFinite(
          reservationExpiresAtMs,
        )
          ? reservationExpiresAtMs
          : null,

      orderId,

      paymentId:
        storedPaymentId,

      paymentRecorded:
        true,

      paymentRecordId:
        blockingPayment.id,

      status,

      statusDetail,

      amount:
        amounts
          .mercadoPagoAmount,

      realAppointmentAmount:
        amounts
          .realAmount,

      testMode:
        MERCADO_PAGO_TEST_MODE,

      pix: {
        qrCode:
          storedPix.qrCode,

        qrCodeBase64:
          storedPix.qrCodeBase64,

        ticketUrl:
          storedPix.ticketUrl,
      },
    },
  };
}

// ============================================================
// HEALTH
// ============================================================

app.get(
  '/health',
  (
    request,
    response,
  ) => {
    response.json({
      ok: true,
      service:
        'j2i-mfa-recovery',
    });
  },
);

// ============================================================
// WEBHOOK MERCADO PAGO
// ============================================================

registerMercadoPagoWebhook({
  app,
  db,

  accessToken:
    MERCADO_PAGO_ACCESS_TOKEN,

  webhookSecret:
    MERCADO_PAGO_WEBHOOK_SECRET,

  testMode:
    MERCADO_PAGO_TEST_MODE,
});

// ============================================================
// MFA - INICIAR RECUPERAÇÃO
// ============================================================

app.post(
  '/v1/mfa-recovery/start',

  async (
    request,
    response,
  ) => {
    const email =
      normalizeEmail(
        request.body?.email,
      );

    if (!isValidEmail(email)) {
      return response
        .status(400)
        .json({
          ok: false,

          message:
            'Informe um e-mail válido.',
        });
    }

    const requestId =
      crypto.randomUUID();

    const recoveryToken =
      createRecoveryToken();

    const tokenHash =
      hashToken(
        recoveryToken,
      );

    const expiresAtMs =
      Date.now() +
      RECOVERY_EXPIRATION_MS;

    try {
      const user =
        await auth.getUserByEmail(
          email,
        );

      if (
        user.emailVerified
      ) {
        const baselineTokensValidAfterMs =
          parseFirebaseTime(
            user
              .tokensValidAfterTime,
          );

        await db
          .collection(
            'mfa_recovery_requests',
          )
          .doc(requestId)
          .set({
            uid:
              user.uid,

            email,

            tokenHash,

            baselineTokensValidAfterMs,

            status:
              'waiting_password_reset',

            createdAt:
              FieldValue
                .serverTimestamp(),

            expiresAt:
              Timestamp.fromMillis(
                expiresAtMs,
              ),
          });
      }
    } catch (error) {
      if (
        error?.code !==
        'auth/user-not-found'
      ) {
        console.error(
          'START RECOVERY ERROR:',
          error,
        );
      }
    }

    return response.json({
      ok: true,

      requestId,

      recoveryToken,

      expiresInMinutes:
        RECOVERY_EXPIRATION_MINUTES,

      message:
        'Se a conta for válida, siga as instruções enviadas ao e-mail.',
    });
  },
);

// ============================================================
// MFA - CONCLUIR RECUPERAÇÃO
// ============================================================

app.post(
  '/v1/mfa-recovery/complete',

  async (
    request,
    response,
  ) => {
    const requestId =
      String(
        request
          .body
          ?.requestId ||
        '',
      ).trim();

    const recoveryToken =
      String(
        request
          .body
          ?.recoveryToken ||
        '',
      ).trim();

    if (
      requestId.length < 10 ||
      recoveryToken.length < 20
    ) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_RECOVERY',

          message:
            'Não foi possível validar a recuperação.',
        });
    }

    const reference =
      db
        .collection(
          'mfa_recovery_requests',
        )
        .doc(requestId);

    const snapshot =
      await reference.get();

    if (!snapshot.exists) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_RECOVERY',

          message:
            'Não foi possível validar a recuperação.',
        });
    }

    const data =
      snapshot.data();

    if (!data) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_RECOVERY',

          message:
            'Não foi possível validar a recuperação.',
        });
    }

    if (
      data.status !==
      'waiting_password_reset'
    ) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'RECOVERY_ALREADY_USED',

          message:
            'Esta recuperação já foi utilizada ou não está mais disponível.',
        });
    }

    const expiresAtMs =
      data
        .expiresAt
        ?.toMillis?.() ||
      0;

    if (
      expiresAtMs <=
      Date.now()
    ) {
      await reference.update({
        status:
          'expired',

        expiredAt:
          FieldValue
            .serverTimestamp(),
      });

      return response
        .status(400)
        .json({
          ok: false,

          code:
            'RECOVERY_EXPIRED',

          message:
            'A solicitação expirou. Inicie uma nova recuperação.',
        });
    }

    const receivedHash =
      hashToken(
        recoveryToken,
      );

    if (
      !safeCompareHashes(
        receivedHash,

        String(
          data.tokenHash || '',
        ),
      )
    ) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_RECOVERY',

          message:
            'Não foi possível validar a recuperação.',
        });
    }

    const uid =
      String(
        data.uid || '',
      );

    if (!uid) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_RECOVERY',

          message:
            'Não foi possível validar a recuperação.',
        });
    }

    const user =
      await auth.getUser(
        uid,
      );

    const currentTokensValidAfterMs =
      parseFirebaseTime(
        user.tokensValidAfterTime,
      );

    const baselineTokensValidAfterMs =
      Number(
        data
          .baselineTokensValidAfterMs ||
        0,
      );

    if (
      currentTokensValidAfterMs <=
      baselineTokensValidAfterMs
    ) {
      return response
        .status(409)
        .json({
          ok: false,

          code:
            'PASSWORD_RESET_NOT_DETECTED',

          message:
            'Ainda não detectamos a redefinição da senha. ' +
            'Abra o e-mail, defina uma nova senha e tente novamente.',
        });
    }

    const oldFactors =
      user
        .multiFactor
        ?.enrolledFactors ||
      [];

    await auth.updateUser(
      uid,
      {
        phoneNumber:
          null,

        multiFactor: {
          enrolledFactors:
            null,
        },
      },
    );

    await db
      .collection('users')
      .doc(uid)
      .set(
        {
          phone:
            '',

          mfaRecoveryRequired:
            true,

          mfaRecoveryAt:
            FieldValue
              .serverTimestamp(),
        },
        {
          merge: true,
        },
      );

    await auth
      .revokeRefreshTokens(
        uid,
      );

    await reference.update({
      status:
        'completed',

      completedAt:
        FieldValue
          .serverTimestamp(),

      factorsRemoved:
        oldFactors.length,
    });

    return response.json({
      ok: true,

      code:
        'RECOVERY_COMPLETED',

      message:
        'Recuperação confirmada. ' +
        'Entre novamente e cadastre um novo telefone de segurança.',
    });
  },
);

// ============================================================
// MFA - FINALIZAR NOVO TELEFONE
// ============================================================

app.post(
  '/v1/mfa-recovery/finalize-phone',

  async (
    request,
    response,
  ) => {
    const idToken =
      getBearerToken(
        request,
      );

    if (!idToken) {
      return response
        .status(401)
        .json({
          ok: false,

          code:
            'UNAUTHORIZED',

          message:
            'Autenticação necessária.',
        });
    }

    const requestedPhone =
      normalizeBrazilPhone(
        request
          .body
          ?.phoneNumber,
      );

    if (!requestedPhone) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_PHONE',

          message:
            'O telefone informado é inválido.',
        });
    }

    try {
      const decodedToken =
        await auth.verifyIdToken(
          idToken,
          true,
        );

      const uid =
        decodedToken.uid;

      const user =
        await auth.getUser(
          uid,
        );

      const factors =
        user
          .multiFactor
          ?.enrolledFactors ||
        [];

      const matchingFactor =
        factors.find(
          (factor) => {
            if (
              factor.factorId !==
              'phone'
            ) {
              return false;
            }

            return (
              normalizeBrazilPhone(
                factor
                  .phoneNumber,
              ) ===
              requestedPhone
            );
          },
        );

      if (!matchingFactor) {
        return response
          .status(409)
          .json({
            ok: false,

            code:
              'MFA_PHONE_NOT_ENROLLED',

            message:
              'O novo telefone ainda não foi confirmado como fator de segurança.',
          });
      }

      const userReference =
        db
          .collection('users')
          .doc(uid);

      const userSnapshot =
        await userReference.get();

      if (!userSnapshot.exists) {
        return response
          .status(404)
          .json({
            ok: false,

            code:
              'USER_PROFILE_NOT_FOUND',

            message:
              'Perfil do usuário não encontrado.',
          });
      }

      const userData =
        userSnapshot.data();

      if (
        userData
          ?.mfaRecoveryRequired !==
        true
      ) {
        return response
          .status(409)
          .json({
            ok: false,

            code:
              'RECOVERY_NOT_REQUIRED',

            message:
              'Esta conta não está aguardando recuperação de MFA.',
          });
      }

      await userReference.set(
        {
          phone:
            requestedPhone,

          mfaRecoveryRequired:
            false,

          mfaRecoveryCompletedAt:
            FieldValue
              .serverTimestamp(),

          updatedAt:
            FieldValue
              .serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      await auth
        .revokeRefreshTokens(
          uid,
        );

      return response.json({
        ok: true,

        code:
          'RECOVERY_PHONE_COMPLETED',

        message:
          'Novo telefone de segurança cadastrado com sucesso.',
      });
    } catch (error) {
      console.error(
        'FINALIZE RECOVERY PHONE ERROR:',
        error,
      );

      if (
        handleAuthError(
          error,
          response,
        )
      ) {
        return;
      }

      return response
        .status(500)
        .json({
          ok: false,

          code:
            'FINALIZE_PHONE_ERROR',

          message:
            'Não foi possível finalizar o novo telefone.',
        });
    }
  },
);

// ============================================================
// CARTÃO - PREPARAR
// ============================================================

app.post(
  '/v1/payments/card/prepare',

  async (
    request,
    response,
  ) => {
    const idToken =
      getBearerToken(
        request,
      );

    const appointmentId =
      String(
        request
          .body
          ?.appointmentId ||
        '',
      ).trim();

    if (!idToken) {
      return response
        .status(401)
        .json({
          ok: false,

          code:
            'UNAUTHORIZED',

          message:
            'Usuário não autenticado.',
        });
    }

    if (!appointmentId) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'APPOINTMENT_REQUIRED',

          message:
            'Agendamento não informado.',
        });
    }

    try {
      const decodedToken =
        await auth.verifyIdToken(
          idToken,
          true,
        );

      const loaded =
        await loadOwnedAppointment({
          appointmentId,

          uid:
            decodedToken.uid,
        });

      if (!loaded.ok) {
        return sendKnownError(
          response,
          loaded,
        );
      }

      const eligibility =
        await validateAppointmentForPayment({
          appointmentReference:
            loaded.reference,

          appointment:
            loaded.appointment,
        });

      if (!eligibility.ok) {
        return sendKnownError(
          response,
          eligibility,
        );
      }

      const blockingPayment =
        await getBlockingPaymentForAppointment(
          appointmentId,
        );

      if (blockingPayment) {
        return sendKnownError(
          response,

          getBlockingPaymentResponse(
            blockingPayment,
          ),
        );
      }

      const amounts =
        getAppointmentAmount(
          loaded.appointment,
        );

      if (!amounts) {
        return response
          .status(409)
          .json({
            ok: false,

            code:
              'INVALID_APPOINTMENT_PRICE',

            message:
              'O agendamento não possui um valor válido.',
          });
      }

      return response.json({
        ok: true,

        appointmentId,

        amount:
          amounts
            .mercadoPagoAmount,

        realAppointmentAmount:
          amounts
            .realAmount,

        testMode:
          MERCADO_PAGO_TEST_MODE,
      });
    } catch (error) {
      console.error(
        'PREPARE CARD PAYMENT ERROR:',
        {
          name:
            error?.name ||
            'Error',

          code:
            error?.code ||
            null,

          message:
            error?.message ||
            'Unknown error',

          appointmentId,
        },
      );

      if (
        handleAuthError(
          error,
          response,
        )
      ) {
        return;
      }

      return response
        .status(500)
        .json({
          ok: false,

          code:
            'PREPARE_CARD_PAYMENT_ERROR',

          message:
            'Não foi possível preparar o pagamento com cartão.',
        });
    }
  },
);

// ============================================================
// PIX - CRIAR OU REAPRESENTAR
// ============================================================

app.post(
  '/v1/payments/pix',

  async (
    request,
    response,
  ) => {
    const idToken =
      getBearerToken(
        request,
      );

    const appointmentId =
      String(
        request
          .body
          ?.appointmentId ||
        '',
      ).trim();

    if (!idToken) {
      return response
        .status(401)
        .json({
          ok: false,

          code:
            'UNAUTHORIZED',

          message:
            'Usuário não autenticado.',
        });
    }

    if (!appointmentId) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'APPOINTMENT_REQUIRED',

          message:
            'Agendamento não informado.',
        });
    }

    let paymentCreationLockId =
      null;

    let appointmentReferenceForLock =
      null;

    let keepPaymentCreationLock =
      false;

    try {
      const decodedToken =
        await auth.verifyIdToken(
          idToken,
          true,
        );

      const uid =
        decodedToken.uid;

      const loaded =
        await loadOwnedAppointment({
          appointmentId,
          uid,
        });

      if (!loaded.ok) {
        return sendKnownError(
          response,
          loaded,
        );
      }

      const eligibility =
        await validateAppointmentForPayment({
          appointmentReference:
            loaded.reference,

          appointment:
            loaded.appointment,
        });

      if (!eligibility.ok) {
        return sendKnownError(
          response,
          eligibility,
        );
      }

      const amounts =
        getAppointmentAmount(
          loaded.appointment,
        );

      if (!amounts) {
        return response
          .status(409)
          .json({
            ok: false,

            code:
              'INVALID_APPOINTMENT_PRICE',

            message:
              'O agendamento não possui um valor válido.',
          });
      }

      // ========================================================
      // TENTAR RECUPERAR PIX EXISTENTE
      // ========================================================

      const blockingPayment =
        await getBlockingPaymentForAppointment(
          appointmentId,
        );

      if (blockingPayment) {
        const existingPix =
          await tryReuseExistingPix({
            blockingPayment,

            appointmentId,

            amounts,

            reservationExpiresAtMs:
              getAppointmentExpirationMs(
                loaded.appointment,
              ),
          });

        if (
          existingPix.action ===
          'reuse'
        ) {
          schedulePixExpiration(
            appointmentId,

            getAppointmentExpirationMs(
              loaded.appointment,
            ),
          );

          return response.json(
            existingPix.result,
          );
        }

        if (
          existingPix.action ===
          'block'
        ) {
          return sendKnownError(
            response,
            existingPix.conflict,
          );
        }
      }

      // ========================================================
      // LOCK
      // ========================================================

      appointmentReferenceForLock =
        loaded.reference;

      const paymentLock =
        await acquirePaymentCreationLock({
          appointmentReference:
            loaded.reference,

          uid,

          method:
            'pix',
        });

      if (!paymentLock.ok) {
        return sendKnownError(
          response,
          paymentLock,
        );
      }

      paymentCreationLockId =
        paymentLock.lockId;

      const payerEmail =
        getPayerEmail(
          decodedToken,
        );

      if (
        !MERCADO_PAGO_TEST_MODE &&
        !payerEmail
      ) {
        return response
          .status(409)
          .json({
            ok: false,

            code:
              'EMAIL_REQUIRED',

            message:
              'A conta não possui e-mail válido.',
          });
      }

      // ========================================================
      // IDEMPOTÊNCIA
      // ========================================================

      const idempotencyKey =
        createIdempotencyKey(
          `pix:${uid}:${appointmentId}:v1`,
        );

      const externalReference =
        `j2i_appointment_${appointmentId}`;

      // ========================================================
      // BODY PIX
      //
      // IMPORTANTE:
      //
      // NÃO EXISTE MAIS:
      //
      // payer.first_name = 'APRO'
      //
      // portanto o Pix NÃO deve mais ser aprovado
      // automaticamente só por estar em modo de teste.
      // ========================================================

      const mercadoPagoBody = {
        type:
          'online',

        external_reference:
          externalReference,

        processing_mode:
          'automatic',

        total_amount:
          amounts
            .mercadoPagoAmount,

        payer: {
          email:
            payerEmail,
        },

        transactions: {
          payments: [
            {
              amount:
                amounts
                  .mercadoPagoAmount,

              payment_method: {
                id:
                  'pix',

                type:
                  'bank_transfer',
              },

              expiration_time:
                'PT30M',
            },
          ],
        },
      };

      // ========================================================
      // CRIAR PIX
      // ========================================================

      const mercadoPagoResponse =
        await fetch(
          MERCADO_PAGO_ORDERS_URL,
          {
            method: 'POST',

            headers: {
              Accept:
                'application/json',

              'Content-Type':
                'application/json',

              Authorization:
                `Bearer ${MERCADO_PAGO_ACCESS_TOKEN}`,

              'X-Idempotency-Key':
                idempotencyKey,
            },

            body:
              JSON.stringify(
                mercadoPagoBody,
              ),
          },
        );

      const mercadoPagoData =
        await readMercadoPagoResponse(
          mercadoPagoResponse,
        );

      if (
        !mercadoPagoResponse.ok
      ) {
        console.error(
          'MERCADO PAGO PIX ERROR:',
          {
            status:
              mercadoPagoResponse.status,

            appointmentId,

            response:
              mercadoPagoData,
          },
        );

        return response
          .status(502)
          .json({
            ok: false,

            code:
              'MERCADO_PAGO_ERROR',

            message:
              'Não foi possível gerar o Pix.',

            mercadoPagoStatus:
              mercadoPagoResponse
                .status,
          });
      }

      const payment =
        mercadoPagoData
          ?.transactions
          ?.payments?.[0];

      const paymentMethod =
        payment
          ?.payment_method;

      if (
        !mercadoPagoData.id ||
        !payment?.id ||
        !paymentMethod?.qr_code
      ) {
        console.error(
          'INVALID MERCADO PAGO PIX RESPONSE:',
          mercadoPagoData,
        );

        return response
          .status(502)
          .json({
            ok: false,

            code:
              'INVALID_PIX_RESPONSE',

            message:
              'O Mercado Pago não retornou os dados completos do Pix.',
          });
      }

      // ========================================================
      // SALVAR PAYMENT + QR ORIGINAL
      // ========================================================

      let paymentRecorded =
        true;

      let paymentRecordId =
        null;

      try {
        const registration =
          await registerPayment({
            db,

            appointmentId,

            userId:
              uid,

            provider:
              'mercado_pago',

            method:
              'pix',

            orderId:
              mercadoPagoData.id,

            paymentId:
              payment.id,

            status:
              payment.status ||
              '',

            statusDetail:
              payment
                .status_detail ||
              '',

            amount:
              amounts
                .mercadoPagoAmount,

            amountCents:
              amounts
                .priceCents,

            realAppointmentAmount:
              amounts
                .realAmount,

            realAppointmentAmountCents:
              amounts
                .priceCents,

            testMode:
              MERCADO_PAGO_TEST_MODE,

            paymentMethodId:
              'pix',

            paymentMethodType:
              'bank_transfer',

            installments:
              1,

            pixQrCode:
              paymentMethod
                .qr_code,

            pixQrCodeBase64:
              paymentMethod
                .qr_code_base64 ||
              '',

            pixTicketUrl:
              paymentMethod
                .ticket_url ||
              '',
          });

        paymentRecordId =
          registration
            .paymentDocumentId;

        schedulePixExpiration(
          appointmentId,

          getAppointmentExpirationMs(
            loaded.appointment,
          ),
        );
      } catch (error) {
        paymentRecorded =
          false;

        keepPaymentCreationLock =
          true;

        console.error(
          'SAVE PIX PAYMENT ERROR:',
          {
            appointmentId,

            paymentId:
              payment.id,

            message:
              error?.message ||
              'Unknown error',
          },
        );
      }

      return response.json({
        ok: true,

        reused:
          false,

        // Não considerar aprovado só porque criamos o QR.
        approved:
          false,

        appointmentId,

        // O Flutter usa este horário EXATO.
        // Ao sair e voltar o contador NÃO reinicia.
        reservationExpiresAtMs:
          getAppointmentExpirationMs(
            loaded.appointment,
          ),

        orderId:
          mercadoPagoData.id,

        paymentId:
          payment.id,

        paymentRecorded,

        paymentRecordId,

        status:
          payment.status,

        statusDetail:
          payment
            .status_detail,

        amount:
          amounts
            .mercadoPagoAmount,

        realAppointmentAmount:
          amounts
            .realAmount,

        testMode:
          MERCADO_PAGO_TEST_MODE,

        pix: {
          qrCode:
            paymentMethod
              .qr_code,

          qrCodeBase64:
            paymentMethod
              .qr_code_base64 ||
            '',

          ticketUrl:
            paymentMethod
              .ticket_url ||
            '',
        },
      });
    } catch (error) {
      console.error(
        'CREATE PIX ERROR:',
        {
          name:
            error?.name ||
            'Error',

          code:
            error?.code ||
            null,

          message:
            error?.message ||
            'Unknown error',

          appointmentId,
        },
      );

      if (
        handleAuthError(
          error,
          response,
        )
      ) {
        return;
      }

      return response
        .status(500)
        .json({
          ok: false,

          code:
            'CREATE_PIX_ERROR',

          message:
            'Não foi possível gerar o pagamento Pix.',
        });
    } finally {
      if (
        !keepPaymentCreationLock
      ) {
        await releasePaymentCreationLock({
          appointmentReference:
            appointmentReferenceForLock,

          lockId:
            paymentCreationLockId,
        });
      }
    }
  },
);

// ============================================================
// CARTÃO - CRIAR
// ============================================================

app.post(
  '/v1/payments/card',

  async (
    request,
    response,
  ) => {
    const idToken =
      getBearerToken(
        request,
      );

    const appointmentId =
      String(
        request
          .body
          ?.appointmentId ||
        '',
      ).trim();

    if (!idToken) {
      return response
        .status(401)
        .json({
          ok: false,

          code:
            'UNAUTHORIZED',

          message:
            'Usuário não autenticado.',
        });
    }

    if (!appointmentId) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'APPOINTMENT_REQUIRED',

          message:
            'Agendamento não informado.',
        });
    }

    const cardToken =
      String(
        request
          .body
          ?.cardToken ||
        '',
      ).trim();

    if (
      cardToken.length < 10 ||
      cardToken.length > 512 ||
      /\s/.test(cardToken)
    ) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_CARD_TOKEN',

          message:
            'Token do cartão inválido.',
        });
    }

    const paymentMethodId =
      String(
        request
          .body
          ?.paymentMethodId ||
        '',
      )
        .trim()
        .toLowerCase();

    if (
      !/^[a-z0-9_-]{2,40}$/
        .test(
          paymentMethodId,
        )
    ) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_PAYMENT_METHOD',

          message:
            'Meio de pagamento inválido.',
        });
    }

    const paymentMethodType =
      String(
        request
          .body
          ?.paymentMethodType ||
        '',
      )
        .trim()
        .toLowerCase();

    const allowedPaymentMethodTypes =
      new Set([
        'credit_card',
        'debit_card',
        'prepaid_card',
      ]);

    if (
      !allowedPaymentMethodTypes
        .has(
          paymentMethodType,
        )
    ) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_PAYMENT_METHOD_TYPE',

          message:
            'Tipo de cartão inválido.',
        });
    }

    const installments =
      Number(
        request
          .body
          ?.installments,
      );

    if (
      !Number.isInteger(
        installments,
      ) ||
      installments < 1 ||
      installments > 24
    ) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_INSTALLMENTS',

          message:
            'Quantidade de parcelas inválida.',
        });
    }

    if (
      paymentMethodType !==
        'credit_card' &&
      installments !== 1
    ) {
      return response
        .status(400)
        .json({
          ok: false,

          code:
            'INVALID_INSTALLMENTS_FOR_CARD_TYPE',

          message:
            'Cartão de débito ou pré-pago deve ser pago em uma parcela.',
        });
    }

    let paymentCreationLockId =
      null;

    let appointmentReferenceForLock =
      null;

    let keepPaymentCreationLock =
      false;

    try {
      const decodedToken =
        await auth.verifyIdToken(
          idToken,
          true,
        );

      const uid =
        decodedToken.uid;

      const loaded =
        await loadOwnedAppointment({
          appointmentId,
          uid,
        });

      if (!loaded.ok) {
        return sendKnownError(
          response,
          loaded,
        );
      }

      const eligibility =
        await validateAppointmentForPayment({
          appointmentReference:
            loaded.reference,

          appointment:
            loaded.appointment,
        });

      if (!eligibility.ok) {
        return sendKnownError(
          response,
          eligibility,
        );
      }

      const blockingPayment =
        await getBlockingPaymentForAppointment(
          appointmentId,
        );

      if (blockingPayment) {
        return sendKnownError(
          response,

          getBlockingPaymentResponse(
            blockingPayment,
          ),
        );
      }

      appointmentReferenceForLock =
        loaded.reference;

      const paymentLock =
        await acquirePaymentCreationLock({
          appointmentReference:
            loaded.reference,

          uid,

          method:
            'card',
        });

      if (!paymentLock.ok) {
        return sendKnownError(
          response,
          paymentLock,
        );
      }

      paymentCreationLockId =
        paymentLock.lockId;

      const amounts =
        getAppointmentAmount(
          loaded.appointment,
        );

      if (!amounts) {
        return response
          .status(409)
          .json({
            ok: false,

            code:
              'INVALID_APPOINTMENT_PRICE',

            message:
              'O agendamento não possui um valor válido.',
          });
      }

      const payerEmail =
        getPayerEmail(
          decodedToken,
        );

      if (
        !MERCADO_PAGO_TEST_MODE &&
        !payerEmail
      ) {
        return response
          .status(409)
          .json({
            ok: false,

            code:
              'EMAIL_REQUIRED',

            message:
              'A conta não possui e-mail válido.',
          });
      }

      const cardTokenFingerprint =
        hashToken(
          cardToken,
        );

      const idempotencyKey =
        createIdempotencyKey(
          `card:${uid}:${appointmentId}:${cardTokenFingerprint}:v1`,
        );

      const mercadoPagoBody = {
        type:
          'online',

        external_reference:
          `j2i_appointment_${appointmentId}`,

        processing_mode:
          'automatic',

        total_amount:
          amounts
            .mercadoPagoAmount,

        payer: {
          email:
            payerEmail,
        },

        transactions: {
          payments: [
            {
              amount:
                amounts
                  .mercadoPagoAmount,

              payment_method: {
                id:
                  paymentMethodId,

                type:
                  paymentMethodType,

                token:
                  cardToken,

                installments,
              },
            },
          ],
        },
      };

      const mercadoPagoResponse =
        await fetch(
          MERCADO_PAGO_ORDERS_URL,
          {
            method: 'POST',

            headers: {
              Accept:
                'application/json',

              'Content-Type':
                'application/json',

              Authorization:
                `Bearer ${MERCADO_PAGO_ACCESS_TOKEN}`,

              'X-Idempotency-Key':
                idempotencyKey,
            },

            body:
              JSON.stringify(
                mercadoPagoBody,
              ),
          },
        );

      const mercadoPagoData =
        await readMercadoPagoResponse(
          mercadoPagoResponse,
        );

      if (
        !mercadoPagoResponse.ok
      ) {
        console.error(
          'MERCADO PAGO CARD ERROR:',
          {
            status:
              mercadoPagoResponse.status,

            appointmentId,

            paymentMethodId,

            paymentMethodType,

            installments,

            mercadoPagoError:
              mercadoPagoData?.error ||
              mercadoPagoData?.code ||
              null,

            mercadoPagoMessage:
              mercadoPagoData?.message ||
              null,
          },
        );

        return response
          .status(502)
          .json({
            ok: false,

            code:
              'MERCADO_PAGO_CARD_ERROR',

            message:
              'Não foi possível processar o cartão.',

            mercadoPagoStatus:
              mercadoPagoResponse.status,
          });
      }

      const payment =
        mercadoPagoData
          ?.transactions
          ?.payments?.[0];

      if (
        !mercadoPagoData.id ||
        !payment?.id
      ) {
        console.error(
          'INVALID MERCADO PAGO CARD RESPONSE:',
          {
            appointmentId,

            hasOrderId:
              Boolean(
                mercadoPagoData.id,
              ),

            hasPaymentId:
              Boolean(
                payment?.id,
              ),
          },
        );

        return response
          .status(502)
          .json({
            ok: false,

            code:
              'INVALID_CARD_RESPONSE',

            message:
              'O Mercado Pago não retornou os dados completos do pagamento.',
          });
      }

      const paymentStatus =
        String(
          payment.status ||
          mercadoPagoData.status ||
          '',
        );

      const paymentStatusDetail =
        String(
          payment.status_detail ||
          mercadoPagoData
            .status_detail ||
          '',
        );

      const approved =
        paymentStatus ===
          'processed' &&
        paymentStatusDetail ===
          'accredited';

      const requiresAction =
        paymentStatus ===
        'action_required';

      let paymentRecorded =
        true;

      let paymentRecordId =
        null;

      try {
        const registration =
          await registerPayment({
            db,

            appointmentId,

            userId:
              uid,

            provider:
              'mercado_pago',

            method:
              'card',

            orderId:
              mercadoPagoData.id,

            paymentId:
              payment.id,

            status:
              paymentStatus,

            statusDetail:
              paymentStatusDetail,

            amount:
              amounts
                .mercadoPagoAmount,

            amountCents:
              amounts
                .priceCents,

            realAppointmentAmount:
              amounts
                .realAmount,

            realAppointmentAmountCents:
              amounts
                .priceCents,

            testMode:
              MERCADO_PAGO_TEST_MODE,

            paymentMethodId:
              payment
                ?.payment_method
                ?.id ||
              paymentMethodId,

            paymentMethodType:
              payment
                ?.payment_method
                ?.type ||
              paymentMethodType,

            installments:
              Number(
                payment
                  ?.payment_method
                  ?.installments ||
                installments,
              ),
          });

        paymentRecordId =
          registration
            .paymentDocumentId;
      } catch (error) {
        paymentRecorded =
          false;

        keepPaymentCreationLock =
          true;

        console.error(
          'SAVE CARD PAYMENT ERROR:',
          {
            appointmentId,

            paymentId:
              payment.id,

            message:
              error?.message ||
              'Unknown error',
          },
        );
      }

      return response.json({
        ok: true,

        appointmentId,

        orderId:
          mercadoPagoData.id,

        paymentId:
          payment.id,

        paymentRecorded,

        paymentRecordId,

        status:
          paymentStatus,

        statusDetail:
          paymentStatusDetail,

        orderStatus:
          mercadoPagoData.status ||
          '',

        orderStatusDetail:
          mercadoPagoData
            .status_detail ||
          '',

        approved,

        requiresAction,

        amount:
          amounts
            .mercadoPagoAmount,

        realAppointmentAmount:
          amounts
            .realAmount,

        testMode:
          MERCADO_PAGO_TEST_MODE,

        card: {
          paymentMethodId:
            payment
              ?.payment_method
              ?.id ||
            paymentMethodId,

          paymentMethodType:
            payment
              ?.payment_method
              ?.type ||
            paymentMethodType,

          installments:
            Number(
              payment
                ?.payment_method
                ?.installments ||
              installments,
            ),
        },
      });
    } catch (error) {
      console.error(
        'CREATE CARD PAYMENT ERROR:',
        {
          name:
            error?.name ||
            'Error',

          code:
            error?.code ||
            null,

          message:
            error?.message ||
            'Unknown error',

          appointmentId,
        },
      );

      if (
        handleAuthError(
          error,
          response,
        )
      ) {
        return;
      }

      return response
        .status(500)
        .json({
          ok: false,

          code:
            'CREATE_CARD_PAYMENT_ERROR',

          message:
            'Não foi possível processar o pagamento com cartão.',
        });
    } finally {
      if (
        !keepPaymentCreationLock
      ) {
        await releasePaymentCreationLock({
          appointmentReference:
            appointmentReferenceForLock,

          lockId:
            paymentCreationLockId,
        });
      }
    }
  },
);

// ============================================================
// ERRO GLOBAL
// ============================================================

app.use(
  (
    error,
    request,
    response,
    next,
  ) => {
    console.error(
      'SERVER ERROR:',
      error,
    );

    if (
      response.headersSent
    ) {
      return next(error);
    }

    return response
      .status(500)
      .json({
        ok: false,

        code:
          'INTERNAL_ERROR',

        message:
          'Erro interno do servidor.',
      });
  },
);

// ============================================================
// START
// ============================================================

app.listen(
  PORT,
  () => {
    console.log(
      '============================================',
    );

    console.log(
      'J2I MFA Recovery Backend',
    );

    console.log(
      `Servidor: http://localhost:${PORT}`,
    );

    console.log(
      `Health:   http://localhost:${PORT}/health`,
    );

    console.log(
      'Pix: cancelamento automático após 2 minutos ATIVO ✅',
    );

    console.log(
      '============================================',
    );

    startPixExpirationWorker();
  },
);