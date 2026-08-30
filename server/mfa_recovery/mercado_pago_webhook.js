const {
  WebhookSignatureValidator,
  InvalidWebhookSignatureError,
} = require('mercadopago');

const {
  FieldValue,
} = require('firebase-admin/firestore');

const {
  registerPayment,
} = require('./payment_store');

const {
  queueAppointmentConfirmationNotification,
} = require('./notification_store');

// ============================================================
// MERCADO PAGO
// ============================================================

const MERCADO_PAGO_ORDERS_URL =
  'https://api.mercadopago.com/v1/orders';

// ============================================================
// UTILITÁRIOS
// ============================================================

function normalizeString(value) {
  return String(value || '').trim();
}

function normalizeNullableString(value) {
  const normalized =
    normalizeString(value);

  return normalized || null;
}

function amountToCents(value) {
  const amount =
    Number(value);

  if (
    !Number.isFinite(amount) ||
    amount <= 0
  ) {
    return null;
  }

  return Math.round(
    amount * 100,
  );
}

function timestampToMillis(value) {
  const milliseconds =
    value?.toMillis?.();

  if (
    !Number.isFinite(
      milliseconds,
    )
  ) {
    return null;
  }

  return milliseconds;
}

function uniqueStrings(values) {
  return [
    ...new Set(
      values
        .map(normalizeString)
        .filter(Boolean),
    ),
  ];
}

function safeDocumentId(value) {
  const safe =
    normalizeString(value)
      .replace(
        /[^a-zA-Z0-9_-]/g,
        '_',
      );

  return safe || 'unknown';
}

// ============================================================
// BODY.DATA
// ============================================================

function parseNotificationData(body) {
  const rawData =
    body?.data;

  if (!rawData) {
    return {};
  }

  if (
    typeof rawData === 'object' &&
    !Array.isArray(rawData)
  ) {
    return rawData;
  }

  if (
    typeof rawData === 'string'
  ) {
    try {
      const parsed =
        JSON.parse(rawData);

      if (
        parsed &&
        typeof parsed === 'object' &&
        !Array.isArray(parsed)
      ) {
        return parsed;
      }
    } catch (_) {
      return {};
    }
  }

  return {};
}

// ============================================================
// APPOINTMENT ID
// ============================================================

function getAppointmentIdFromExternalReference(
  externalReference,
) {
  const value =
    normalizeString(
      externalReference,
    );

  const prefix =
    'j2i_appointment_';

  if (
    !value.startsWith(prefix)
  ) {
    return null;
  }

  const appointmentId =
    value
      .substring(prefix.length)
      .trim();

  return appointmentId || null;
}

// ============================================================
// DETECTAR PIX OU CARTÃO
// ============================================================

function detectMethod(payment) {
  const paymentMethodId =
    normalizeString(
      payment
        ?.payment_method
        ?.id,
    ).toLowerCase();

  const paymentMethodType =
    normalizeString(
      payment
        ?.payment_method
        ?.type,
    ).toLowerCase();

  if (
    paymentMethodId === 'pix' ||
    paymentMethodType ===
      'bank_transfer'
  ) {
    return 'pix';
  }

  return 'card';
}

// ============================================================
// PAGAMENTO APROVADO
// ============================================================

function isApprovedPayment(
  status,
  statusDetail,
) {
  return (
    normalizeString(status) ===
      'processed' &&
    normalizeString(statusDetail) ===
      'accredited'
  );
}

// ============================================================
// CONSULTAR ORDER
// ============================================================

async function getMercadoPagoOrder({
  orderId,
  accessToken,
}) {
  const mercadoPagoResponse =
    await fetch(
      `${MERCADO_PAGO_ORDERS_URL}/${encodeURIComponent(orderId)}`,
      {
        method: 'GET',

        headers: {
          Accept:
            'application/json',

          Authorization:
            `Bearer ${accessToken}`,
        },
      },
    );

  const raw =
    await mercadoPagoResponse.text();

  let data = {};

  try {
    data =
      raw
        ? JSON.parse(raw)
        : {};
  } catch (_) {
    data = {};
  }

  if (
    !mercadoPagoResponse.ok
  ) {
    const error =
      new Error(
        'MERCADO_PAGO_ORDER_QUERY_FAILED',
      );

    error.status =
      mercadoPagoResponse.status;

    error.mercadoPagoData =
      data;

    throw error;
  }

  return data;
}

// ============================================================
// LOCALIZAR PAGAMENTOS DA ORDER
// ============================================================

async function findExistingPaymentsByOrderId({
  db,
  orderId,
}) {
  const snapshot =
    await db
      .collection('payments')
      .where(
        'orderId',
        '==',
        orderId,
      )
      .limit(10)
      .get();

  return snapshot.docs.map(
    (document) => ({
      id:
        document.id,

      data:
        document.data(),
    }),
  );
}

// ============================================================
// AUDITORIA DO WEBHOOK
// ============================================================
//
// NÃO salvamos:
//
// token do cartão
// access token
// secret
// x-signature
//
// ============================================================

async function registerWebhookAudit({
  db,

  orderId,
  paymentId,
  appointmentId,

  externalReference,

  applicationId,
  liveMode,

  status,
  statusDetail,

  paymentAmountCents,
  appointmentAmountCents,

  integrityStatus,
  integrityIssues,

  confirmationEligible,
  confirmationApplied,
  confirmationAlreadyApplied,
  confirmationBlockedReason,

  requiresManualReview,
}) {
  const auditId = [
    'mercado_pago_webhook',
    safeDocumentId(orderId),
    safeDocumentId(paymentId),
  ].join('_');

  const reference =
    db
      .collection('audit_logs')
      .doc(auditId);

  const snapshot =
    await reference.get();

  const data = {
    type:
      'mercado_pago_webhook',

    provider:
      'mercado_pago',

    orderId:
      normalizeString(orderId),

    paymentId:
      normalizeString(paymentId),

    appointmentId:
      normalizeNullableString(
        appointmentId,
      ),

    externalReference:
      normalizeNullableString(
        externalReference,
      ),

    applicationId:
      normalizeNullableString(
        applicationId,
      ),

    liveMode:
      liveMode === true,

    status:
      normalizeString(status),

    statusDetail:
      normalizeString(statusDetail),

    paymentAmountCents:
      Number.isInteger(
        paymentAmountCents,
      )
        ? paymentAmountCents
        : null,

    appointmentAmountCents:
      Number.isInteger(
        appointmentAmountCents,
      )
        ? appointmentAmountCents
        : null,

    integrityStatus:
      normalizeString(
        integrityStatus,
      ),

    integrityIssues:
      uniqueStrings(
        integrityIssues || [],
      ),

    confirmationEligible:
      confirmationEligible === true,

    confirmationApplied:
      confirmationApplied === true,

    confirmationAlreadyApplied:
      confirmationAlreadyApplied ===
      true,

    confirmationBlockedReason:
      normalizeNullableString(
        confirmationBlockedReason,
      ),

    requiresManualReview:
      requiresManualReview === true,

    lastSeenAt:
      FieldValue.serverTimestamp(),

    deliveryCount:
      FieldValue.increment(1),
  };

  if (
    !snapshot.exists
  ) {
    data.firstSeenAt =
      FieldValue.serverTimestamp();
  }

  await reference.set(
    data,
    {
      merge: true,
    },
  );
}

// ============================================================
// MARCAR RESERVA EXPIRADA
// ============================================================

async function markAppointmentExpiredIfNeeded({
  db,
  appointmentReference,
}) {
  await db.runTransaction(
    async (transaction) => {
      const snapshot =
        await transaction.get(
          appointmentReference,
        );

      if (
        !snapshot.exists
      ) {
        return;
      }

      const appointment =
        snapshot.data() || {};

      const status =
        normalizeString(
          appointment.status,
        );

      const expirationMs =
        timestampToMillis(
          appointment.paymentExpiresAt,
        );

      if (
        status ===
          'pending_payment' &&
        expirationMs != null &&
        expirationMs <= Date.now()
      ) {
        transaction.update(
          appointmentReference,
          {
            status:
              'expired',

            expiredAt:
              FieldValue
                .serverTimestamp(),
          },
        );
      }
    },
  );
}

// ============================================================
// SLOTS DO AGENDAMENTO
// ============================================================

function getAppointmentSlotStarts({
  startMinutes,
  endMinutes,
}) {
  const start =
    Number(startMinutes);

  const end =
    Number(endMinutes);

  if (
    !Number.isInteger(start) ||
    !Number.isInteger(end) ||
    start < 0 ||
    end > 1440 ||
    end <= start
  ) {
    return [];
  }

  const slots = [];

  for (
    let current = start;
    current < end;
    current += 15
  ) {
    slots.push(current);
  }

  return slots;
}

// ============================================================
// ETAPA 33
// CONFIRMAR AGENDAMENTO APÓS PAGAMENTO APROVADO
// ============================================================
//
// A confirmação acontece em uma transação.
//
// Revalidamos:
//
// - appointment existe
// - status ainda é pending_payment
// - reserva de 2 minutos ainda está válida
// - atendimento ainda não começou
// - todos os slots ainda pertencem ao appointment
//
// A mesma transação altera:
//
// appointments:
// pending_payment -> confirmed
//
// slots:
// pending_payment -> confirmed
//
// ============================================================

async function confirmAppointmentAfterApprovedPayment({
  db,
  appointmentReference,
  appointmentId,
  orderId,
  paymentId,
  method,
  amountCents,
}) {
  return db.runTransaction(
    async (transaction) => {
      const snapshot =
        await transaction.get(
          appointmentReference,
        );

      if (
        !snapshot.exists
      ) {
        return {
          confirmed: false,
          alreadyConfirmed: false,
          blockedReason:
            'appointment_not_found',
          requiresManualReview: true,
        };
      }

      const appointment =
        snapshot.data() || {};

      const appointmentStatus =
        normalizeString(
          appointment.status,
        );

      const existingConfirmation =
        appointment.confirmation &&
        typeof appointment.confirmation ===
          'object'
          ? appointment.confirmation
          : {};

      const existingOrderId =
        normalizeString(
          existingConfirmation.orderId,
        );

      const existingPaymentId =
        normalizeString(
          existingConfirmation.paymentId,
        );

      // ========================================================
      // IDEMPOTÊNCIA
      // ========================================================

      if (
        appointmentStatus ===
        'confirmed'
      ) {
        const sameOrder =
          Boolean(existingOrderId) &&
          existingOrderId ===
            normalizeString(orderId);

        const samePayment =
          Boolean(existingPaymentId) &&
          existingPaymentId ===
            normalizeString(paymentId);

        if (
          sameOrder &&
          samePayment
        ) {
          return {
            confirmed: true,
            alreadyConfirmed: true,
            blockedReason: null,
            requiresManualReview: false,
          };
        }

        return {
          confirmed: false,
          alreadyConfirmed: false,
          blockedReason:
            'appointment_confirmed_by_different_payment',
          requiresManualReview: true,
        };
      }

      if (
        appointmentStatus !==
        'pending_payment'
      ) {
        return {
          confirmed: false,
          alreadyConfirmed: false,

          blockedReason:
            appointmentStatus ===
              'expired'
              ? 'appointment_expired'
              : appointmentStatus ===
                  'cancelled'
                ? 'appointment_cancelled'
                : 'appointment_status_not_payable',

          requiresManualReview: true,
        };
      }

      const nowMs =
        Date.now();

      // ========================================================
      // VALIDAR EXPIRAÇÃO DOS 2 MINUTOS
      // ========================================================

      const expirationMs =
        timestampToMillis(
          appointment.paymentExpiresAt,
        );

      if (
        expirationMs == null
      ) {
        return {
          confirmed: false,
          alreadyConfirmed: false,
          blockedReason:
            'appointment_expiration_invalid',
          requiresManualReview: true,
        };
      }

      if (
        expirationMs <= nowMs
      ) {
        transaction.update(
          appointmentReference,
          {
            status:
              'expired',

            expiredAt:
              FieldValue
                .serverTimestamp(),
          },
        );

        return {
          confirmed: false,
          alreadyConfirmed: false,
          blockedReason:
            'appointment_expired',
          requiresManualReview: true,
        };
      }

      // ========================================================
      // O HORÁRIO NÃO PODE TER COMEÇADO
      // ========================================================

      const startAtMs =
        timestampToMillis(
          appointment.startAt,
        );

      if (
        startAtMs != null &&
        startAtMs <= nowMs
      ) {
        return {
          confirmed: false,
          alreadyConfirmed: false,
          blockedReason:
            'appointment_already_started',
          requiresManualReview: true,
        };
      }

      // ========================================================
      // DADOS DO SLOT
      // ========================================================

      const professionalId =
        normalizeString(
          appointment.professionalId,
        );

      const dateKey =
        normalizeString(
          appointment.dateKey,
        );

      const startMinutes =
        Number(
          appointment.startMinutes,
        );

      const endMinutes =
        Number(
          appointment.endMinutes,
        );

      if (
        !professionalId ||
        !dateKey ||
        !Number.isInteger(
          startMinutes,
        ) ||
        !Number.isInteger(
          endMinutes,
        )
      ) {
        return {
          confirmed: false,
          alreadyConfirmed: false,
          blockedReason:
            'appointment_slot_data_invalid',
          requiresManualReview: true,
        };
      }

      const slotStarts =
        getAppointmentSlotStarts({
          startMinutes,
          endMinutes,
        });

      if (
        slotStarts.length === 0
      ) {
        return {
          confirmed: false,
          alreadyConfirmed: false,
          blockedReason:
            'appointment_slots_not_found',
          requiresManualReview: true,
        };
      }

      const slotReferences =
        slotStarts.map(
          (slotStart) => {
            const slotId =
              slotStart
                .toString()
                .padStart(
                  4,
                  '0',
                );

            return db
              .collection(
                'professionals',
              )
              .doc(
                professionalId,
              )
              .collection(
                'booked_days',
              )
              .doc(
                dateKey,
              )
              .collection(
                'slots',
              )
              .doc(
                slotId,
              );
          },
        );

      // ========================================================
      // LEITURAS DOS SLOTS
      // ========================================================

      const slotSnapshots = [];

      for (
        const slotReference
        of slotReferences
      ) {
        slotSnapshots.push(
          await transaction.get(
            slotReference,
          ),
        );
      }

      // ========================================================
      // VALIDAR CADA SLOT
      // ========================================================

      for (
        let index = 0;
        index <
          slotSnapshots.length;
        index += 1
      ) {
        const slotSnapshot =
          slotSnapshots[index];

        const expectedSlotStart =
          slotStarts[index];

        if (
          !slotSnapshot.exists
        ) {
          return {
            confirmed: false,
            alreadyConfirmed: false,
            blockedReason:
              'appointment_slot_missing',
            requiresManualReview: true,
          };
        }

        const slot =
          slotSnapshot.data() || {};

        const slotAppointmentId =
          normalizeString(
            slot.appointmentId,
          );

        const slotProfessionalId =
          normalizeString(
            slot.professionalId,
          );

        const slotDateKey =
          normalizeString(
            slot.dateKey,
          );

        const slotStatus =
          normalizeString(
            slot.status,
          );

        const slotStartMinutes =
          Number(
            slot.startMinutes,
          );

        if (
          slotAppointmentId !==
            appointmentId ||
          slotProfessionalId !==
            professionalId ||
          slotDateKey !==
            dateKey ||
          slotStartMinutes !==
            expectedSlotStart
        ) {
          return {
            confirmed: false,
            alreadyConfirmed: false,
            blockedReason:
              'appointment_slot_mismatch',
            requiresManualReview: true,
          };
        }

        if (
          slotStatus !==
          'pending_payment'
        ) {
          return {
            confirmed: false,
            alreadyConfirmed: false,
            blockedReason:
              'appointment_slot_status_invalid',
            requiresManualReview: true,
          };
        }

        const slotExpirationMs =
          timestampToMillis(
            slot.paymentExpiresAt,
          );

        if (
          slotExpirationMs == null ||
          slotExpirationMs <= nowMs
        ) {
          return {
            confirmed: false,
            alreadyConfirmed: false,
            blockedReason:
              'appointment_slot_expired',
            requiresManualReview: true,
          };
        }
      }

      // ========================================================
      // CONFIRMAR APPOINTMENT
      // ========================================================

      transaction.update(
        appointmentReference,
        {
          status:
            'confirmed',

          confirmedAt:
            FieldValue
              .serverTimestamp(),

          confirmedBy:
            'mercado_pago_webhook',

          confirmation: {
            provider:
              'mercado_pago',

            orderId:
              normalizeString(
                orderId,
              ),

            paymentId:
              normalizeString(
                paymentId,
              ),

            method:
              normalizeString(
                method,
              ),

            amountCents:
              Number.isInteger(
                amountCents,
              )
                ? amountCents
                : null,

            confirmedAt:
              FieldValue
                .serverTimestamp(),
          },
        },
      );

      // ========================================================
      // CONFIRMAR SLOTS
      // ========================================================

      for (
        const slotReference
        of slotReferences
      ) {
        transaction.update(
          slotReference,
          {
            status:
              'confirmed',

            confirmedAt:
              FieldValue
                .serverTimestamp(),
          },
        );
      }

      return {
        confirmed: true,
        alreadyConfirmed: false,
        blockedReason: null,
        requiresManualReview: false,
      };
    },
  );
}

// ============================================================
// PROCESSAR ORDER
// ============================================================

async function processOrder({
  db,
  order,
  configuredTestMode,
  notificationMeta = {},
}) {
  // ==========================================================
  // ORDER
  // ==========================================================

  const orderId =
    normalizeString(
      order?.id,
    );

  if (
    !orderId
  ) {
    throw new Error(
      'ORDER_ID_NOT_FOUND',
    );
  }

  const externalReference =
    normalizeString(
      order?.external_reference,
    );

  const externalAppointmentId =
    getAppointmentIdFromExternalReference(
      externalReference,
    );

  // ==========================================================
  // PAYMENT
  // ==========================================================

  const payment =
    order
      ?.transactions
      ?.payments?.[0];

  if (
    !payment?.id
  ) {
    throw new Error(
      'ORDER_PAYMENT_NOT_FOUND',
    );
  }

  const paymentId =
    normalizeString(
      payment.id,
    );

  const paymentAmount =
    normalizeString(
      payment.amount ||
      order.total_amount,
    );

  const paymentAmountCents =
    amountToCents(
      paymentAmount,
    );

  const status =
    normalizeString(
      payment.status ||
      order.status,
    );

  const statusDetail =
    normalizeString(
      payment.status_detail ||
      order.status_detail,
    );

  const paymentMethodId =
    normalizeString(
      payment
        ?.payment_method
        ?.id,
    );

  const paymentMethodType =
    normalizeString(
      payment
        ?.payment_method
        ?.type,
    );

  const installmentsValue =
    Number(
      payment
        ?.payment_method
        ?.installments ||
      1,
    );

  const installments =
    Number.isInteger(
      installmentsValue,
    ) &&
    installmentsValue > 0
      ? installmentsValue
      : 1;

  const method =
    detectMethod(payment);

  const testMode =
    order.live_mode === false ||
    configuredTestMode === true;

  const approved =
    isApprovedPayment(
      status,
      statusDetail,
    );

  // ==========================================================
  // PAGAMENTOS JÁ EXISTENTES
  // ==========================================================

  const existingPayments =
    await findExistingPaymentsByOrderId({
      db,
      orderId,
    });

  const existingPayment =
    existingPayments[0] || null;

  const existingAppointmentId =
    normalizeString(
      existingPayment
        ?.data
        ?.appointmentId,
    );

  // ==========================================================
  // INTEGRIDADE
  // ==========================================================

  const integrityIssues = [];

  if (
    !externalReference
  ) {
    integrityIssues.push(
      'external_reference_missing',
    );
  } else if (
    !externalAppointmentId
  ) {
    integrityIssues.push(
      'external_reference_invalid',
    );
  }

  if (
    externalAppointmentId &&
    existingAppointmentId &&
    externalAppointmentId !==
      existingAppointmentId
  ) {
    integrityIssues.push(
      'appointment_id_mismatch_with_existing_payment',
    );
  }

  if (
    existingPayments.length > 1
  ) {
    integrityIssues.push(
      'multiple_payment_records_for_same_order',
    );
  }

  // ==========================================================
  // DETERMINAR APPOINTMENT
  // ==========================================================

  const appointmentId =
    externalAppointmentId ||
    existingAppointmentId ||
    null;

  // ==========================================================
  // SEM APPOINTMENT
  // ==========================================================

  if (
    !appointmentId
  ) {
    integrityIssues.push(
      'appointment_id_not_found',
    );

    await registerWebhookAudit({
      db,

      orderId,
      paymentId,

      appointmentId: null,

      externalReference,

      applicationId:
        notificationMeta.applicationId,

      liveMode:
        notificationMeta.liveMode,

      status,
      statusDetail,

      paymentAmountCents,

      appointmentAmountCents:
        null,

      integrityStatus:
        'invalid',

      integrityIssues,

      confirmationEligible:
        false,

      confirmationApplied:
        false,

      confirmationAlreadyApplied:
        false,

      confirmationBlockedReason:
        'appointment_id_not_found',

      requiresManualReview:
        approved,
    });

    return {
      processed: false,
      appointmentId: null,
      orderId,
      paymentId,
      method,
      status,
      statusDetail,

      integrityStatus:
        'invalid',

      integrityIssues:
        uniqueStrings(
          integrityIssues,
        ),

      confirmationEligible:
        false,

      confirmationApplied:
        false,

      confirmationAlreadyApplied:
        false,

      confirmationBlockedReason:
        'appointment_id_not_found',

      requiresManualReview:
        approved,

      notificationQueued:
        false,

      notificationAlreadyQueued:
        false,

      notificationId:
        null,
    };
  }

  // ==========================================================
  // BUSCAR APPOINTMENT
  // ==========================================================

  const appointmentReference =
    db
      .collection('appointments')
      .doc(appointmentId);

  let appointmentSnapshot =
    await appointmentReference.get();

  if (
    !appointmentSnapshot.exists
  ) {
    integrityIssues.push(
      'appointment_not_found',
    );

    await registerWebhookAudit({
      db,

      orderId,
      paymentId,
      appointmentId,

      externalReference,

      applicationId:
        notificationMeta.applicationId,

      liveMode:
        notificationMeta.liveMode,

      status,
      statusDetail,

      paymentAmountCents,

      appointmentAmountCents:
        null,

      integrityStatus:
        'invalid',

      integrityIssues,

      confirmationEligible:
        false,

      confirmationApplied:
        false,

      confirmationAlreadyApplied:
        false,

      confirmationBlockedReason:
        'appointment_not_found',

      requiresManualReview:
        approved,
    });

    return {
      processed: false,
      appointmentId,
      orderId,
      paymentId,
      method,
      status,
      statusDetail,

      integrityStatus:
        'invalid',

      integrityIssues:
        uniqueStrings(
          integrityIssues,
        ),

      confirmationEligible:
        false,

      confirmationApplied:
        false,

      confirmationAlreadyApplied:
        false,

      confirmationBlockedReason:
        'appointment_not_found',

      requiresManualReview:
        approved,

      notificationQueued:
        false,

      notificationAlreadyQueued:
        false,

      notificationId:
        null,
    };
  }

  let appointment =
    appointmentSnapshot.data();

  if (
    !appointment
  ) {
    throw new Error(
      'APPOINTMENT_DATA_NOT_FOUND',
    );
  }

  // ==========================================================
  // USER
  // ==========================================================

  const userId =
    normalizeString(
      appointment.userId,
    );

  if (
    !userId
  ) {
    integrityIssues.push(
      'appointment_user_not_found',
    );
  }

  if (
    existingPayment
      ?.data
      ?.userId &&
    normalizeString(
      existingPayment.data.userId,
    ) !== userId
  ) {
    integrityIssues.push(
      'payment_user_mismatch',
    );
  }

  // ==========================================================
  // VALOR DO APPOINTMENT
  // ==========================================================

  const appointmentPriceCents =
    Number(
      appointment.priceCents,
    );

  const validAppointmentPrice =
    Number.isInteger(
      appointmentPriceCents,
    ) &&
    appointmentPriceCents > 0;

  if (
    !validAppointmentPrice
  ) {
    integrityIssues.push(
      'appointment_price_invalid',
    );
  }

  // ==========================================================
  // VALOR DO PAGAMENTO
  // ==========================================================

  if (
    paymentAmountCents == null
  ) {
    integrityIssues.push(
      'payment_amount_invalid',
    );
  }

  if (
    validAppointmentPrice &&
    paymentAmountCents != null &&
    paymentAmountCents !==
      appointmentPriceCents
  ) {
    integrityIssues.push(
      'payment_amount_mismatch',
    );
  }

  const realAppointmentAmountCents =
    validAppointmentPrice
      ? appointmentPriceCents
      : Number(
          existingPayment
            ?.data
            ?.realAppointmentAmountCents,
        );

  const realAppointmentAmount =
    Number.isInteger(
      realAppointmentAmountCents,
    ) &&
    realAppointmentAmountCents > 0
      ? (
          realAppointmentAmountCents /
          100
        ).toFixed(2)
      : '';

  // ==========================================================
  // STATUS
  // ==========================================================

  let appointmentStatus =
    normalizeString(
      appointment.status,
    );

  let confirmationEligible =
    false;

  let confirmationApplied =
    false;

  let confirmationAlreadyApplied =
    false;

  let confirmationBlockedReason =
    null;

  let requiresManualReview =
    false;

  const expirationMs =
    timestampToMillis(
      appointment.paymentExpiresAt,
    );

  const startAtMs =
    timestampToMillis(
      appointment.startAt,
    );

  // ==========================================================
  // EXPIRAR SE NECESSÁRIO
  // ==========================================================

  if (
    appointmentStatus ===
      'pending_payment' &&
    expirationMs != null &&
    expirationMs <= Date.now()
  ) {
    await markAppointmentExpiredIfNeeded({
      db,
      appointmentReference,
    });

    appointmentSnapshot =
      await appointmentReference.get();

    appointment =
      appointmentSnapshot.data() ||
      appointment;

    appointmentStatus =
      normalizeString(
        appointment.status,
      );
  }

  // ==========================================================
  // INTEGRIDADE FINAL
  // ==========================================================

  const criticalIntegrityIssues =
    uniqueStrings(
      integrityIssues,
    );

  const integrityStatus =
    criticalIntegrityIssues.length ===
    0
      ? 'valid'
      : 'invalid';

  // ==========================================================
  // ELEGIBILIDADE
  // ==========================================================

  if (
    integrityStatus !== 'valid'
  ) {
    confirmationBlockedReason =
      'payment_integrity_failed';

    if (
      approved
    ) {
      requiresManualReview =
        true;
    }
  } else if (
    !approved
  ) {
    confirmationBlockedReason =
      'payment_not_approved';
  } else if (
    appointmentStatus ===
      'cancelled'
  ) {
    confirmationBlockedReason =
      'appointment_cancelled';

    requiresManualReview =
      true;
  } else if (
    appointmentStatus ===
      'expired'
  ) {
    confirmationBlockedReason =
      'appointment_expired';

    requiresManualReview =
      true;
  } else if (
    appointmentStatus ===
      'confirmed'
  ) {
    // ========================================================
    // PODE SER WEBHOOK REPETIDO
    // ========================================================

    const existingConfirmation =
      appointment.confirmation &&
      typeof appointment.confirmation ===
        'object'
        ? appointment.confirmation
        : {};

    const confirmedOrderId =
      normalizeString(
        existingConfirmation.orderId,
      );

    const confirmedPaymentId =
      normalizeString(
        existingConfirmation.paymentId,
      );

    const sameOrder =
      Boolean(confirmedOrderId) &&
      confirmedOrderId === orderId;

    const samePayment =
      Boolean(confirmedPaymentId) &&
      confirmedPaymentId ===
        paymentId;

    if (
      sameOrder &&
      samePayment
    ) {
      confirmationEligible =
        true;
    } else {
      confirmationBlockedReason =
        'appointment_confirmed_by_different_payment';

      requiresManualReview =
        true;
    }
  } else if (
    appointmentStatus !==
      'pending_payment'
  ) {
    confirmationBlockedReason =
      'appointment_status_not_payable';

    requiresManualReview =
      true;
  } else if (
    expirationMs == null
  ) {
    confirmationBlockedReason =
      'appointment_expiration_invalid';

    requiresManualReview =
      true;
  } else if (
    expirationMs <= Date.now()
  ) {
    confirmationBlockedReason =
      'appointment_expired';

    requiresManualReview =
      true;
  } else if (
    startAtMs != null &&
    startAtMs <= Date.now()
  ) {
    confirmationBlockedReason =
      'appointment_already_started';

    requiresManualReview =
      true;
  } else {
    confirmationEligible =
      true;
  }

  // ==========================================================
  // SALVAR PAYMENT
  // ==========================================================

  const canPersistPayment =
    userId &&
    paymentAmountCents != null &&
    Number.isInteger(
      realAppointmentAmountCents,
    ) &&
    realAppointmentAmountCents > 0;

  let registration = null;

  if (
    canPersistPayment
  ) {
    registration =
      await registerPayment({
        db,

        appointmentId,
        userId,

        provider:
          'mercado_pago',

        method,

        orderId,
        paymentId,

        status,
        statusDetail,

        amount:
          paymentAmount,

        amountCents:
          paymentAmountCents,

        realAppointmentAmount,

        realAppointmentAmountCents,

        testMode,

        paymentMethodId,

        paymentMethodType,

        installments,

        source:
          'mercado_pago_webhook',

        integrityStatus,

        integrityIssues:
          criticalIntegrityIssues,

        confirmationEligible,

        confirmationApplied,

        confirmationAlreadyApplied,

        confirmationBlockedReason,

        requiresManualReview,

        attachToAppointment:
          integrityStatus === 'valid',
      });
  }

  // ==========================================================
  // RESULTADO DA ETAPA 34.1
  // ==========================================================

  let notificationQueued =
    false;

  let notificationAlreadyQueued =
    false;

  let notificationId =
    null;

  // ==========================================================
  // ETAPA 33
  // CONFIRMAR APPOINTMENT
  // ==========================================================

  if (
    confirmationEligible
  ) {
    const confirmationResult =
      await confirmAppointmentAfterApprovedPayment({
        db,

        appointmentReference,
        appointmentId,

        orderId,
        paymentId,

        method,

        amountCents:
          paymentAmountCents,
      });

    confirmationApplied =
      confirmationResult.confirmed ===
      true;

    confirmationAlreadyApplied =
      confirmationResult
        .alreadyConfirmed === true;

    if (
      confirmationApplied
    ) {
      appointmentStatus =
        'confirmed';

      confirmationBlockedReason =
        null;

      requiresManualReview =
        false;
    } else {
      confirmationEligible =
        false;

      confirmationBlockedReason =
        normalizeNullableString(
          confirmationResult
            .blockedReason,
        ) ||
        'appointment_confirmation_failed';

      requiresManualReview =
        confirmationResult
          .requiresManualReview === true;
    }
  }

  // ==========================================================
  // ETAPA 34.1
  // CRIAR NOTIFICAÇÃO PENDENTE NO OUTBOX
  // ==========================================================
  //
  // Ainda NÃO enviamos SMS aqui.
  //
  // Só criamos a intenção de envio depois que a Etapa 33
  // confirmou o agendamento com sucesso.
  //
  // O notification_store usa um ID determinístico por
  // appointment, então webhooks repetidos não criam mensagens
  // duplicadas.
  //
  // Se houver uma falha técnica ao criar o outbox, lançamos o
  // erro para o webhook responder 500.
  // ==========================================================

  if (
    confirmationApplied &&
    appointmentStatus === 'confirmed' &&
    requiresManualReview === false
  ) {
    try {
      const notificationResult =
        await queueAppointmentConfirmationNotification({
          db,

          appointmentId,
          userId,

          serviceName:
            appointment.serviceName,

          professionalName:
            appointment.professionalName,

          startAt:
            appointment.startAt,

          endAt:
            appointment.endAt,

          dateKey:
            appointment.dateKey,

          startMinutes:
            appointment.startMinutes,

          endMinutes:
            appointment.endMinutes,

          orderId,
          paymentId,
        });

      notificationQueued =
        notificationResult.queued ===
        true;

      notificationAlreadyQueued =
        notificationResult
          .alreadyQueued === true;

      notificationId =
        normalizeNullableString(
          notificationResult
            .notificationId,
        );
    } catch (error) {
      console.error(
        'NOTIFICATION OUTBOX ERROR:',
        {
          appointmentId,
          orderId,
          paymentId,

          name:
            error?.name ||
            'Error',

          message:
            error?.message ||
            'Unknown error',
        },
      );

      throw error;
    }
  }

  // ==========================================================
  // ATUALIZAR PAYMENT COM RESULTADO
  // ==========================================================

  if (
    registration
      ?.paymentDocumentId
  ) {
    await db
      .collection('payments')
      .doc(
        registration.paymentDocumentId,
      )
      .set(
        {
          confirmationEligible,

          confirmationApplied,

          confirmationAlreadyApplied,

          confirmationBlockedReason:
            normalizeNullableString(
              confirmationBlockedReason,
            ),

          requiresManualReview,

          notificationQueued,

          notificationAlreadyQueued,

          notificationId:
            normalizeNullableString(
              notificationId,
            ),

          appointmentStatusAfterWebhook:
            appointmentStatus,

          confirmationProcessedAt:
            FieldValue
              .serverTimestamp(),
        },
        {
          merge: true,
        },
      );
  }

  // ==========================================================
  // WEBHOOK NO APPOINTMENT
  // ==========================================================

  await appointmentReference.set(
    {
      paymentWebhook: {
        provider:
          'mercado_pago',

        signatureValid:
          true,

        verifiedByApi:
          true,

        orderId,

        paymentId,

        externalReference:
          normalizeNullableString(
            externalReference,
          ),

        status,

        statusDetail,

        amountCents:
          paymentAmountCents,

        expectedAmountCents:
          validAppointmentPrice
            ? appointmentPriceCents
            : null,

        integrityStatus,

        integrityIssues:
          criticalIntegrityIssues,

        confirmationEligible,

        confirmationApplied,

        confirmationAlreadyApplied,

        confirmationBlockedReason:
          normalizeNullableString(
            confirmationBlockedReason,
          ),

        requiresManualReview,

        notificationQueued,

        notificationAlreadyQueued,

        notificationId:
          normalizeNullableString(
            notificationId,
          ),

        receivedAt:
          FieldValue
            .serverTimestamp(),
      },
    },
    {
      merge: true,
    },
  );

  // ==========================================================
  // AUDITORIA
  // ==========================================================

  await registerWebhookAudit({
    db,

    orderId,
    paymentId,
    appointmentId,

    externalReference,

    applicationId:
      notificationMeta.applicationId,

    liveMode:
      notificationMeta.liveMode,

    status,
    statusDetail,

    paymentAmountCents,

    appointmentAmountCents:
      validAppointmentPrice
        ? appointmentPriceCents
        : null,

    integrityStatus,

    integrityIssues:
      criticalIntegrityIssues,

    confirmationEligible,

    confirmationApplied,

    confirmationAlreadyApplied,

    confirmationBlockedReason,

    requiresManualReview,
  });

  // ==========================================================
  // RESULTADO
  // ==========================================================

  return {
    processed: true,

    appointmentId,

    orderId,

    paymentId,

    paymentRecordId:
      registration
        ?.paymentDocumentId ||
      null,

    method,

    status,

    statusDetail,

    integrityStatus,

    integrityIssues:
      criticalIntegrityIssues,

    confirmationEligible,

    confirmationApplied,

    confirmationAlreadyApplied,

    confirmationBlockedReason,

    requiresManualReview,

    notificationQueued,

    notificationAlreadyQueued,

    notificationId,
  };
}

// ============================================================
// REGISTRAR WEBHOOK NO EXPRESS
// ============================================================

function registerMercadoPagoWebhook({
  app,
  db,
  accessToken,
  webhookSecret,
  testMode,
}) {
  // ==========================================================
  // VALIDAÇÕES
  // ==========================================================

  if (
    !app
  ) {
    throw new Error(
      'WEBHOOK_APP_REQUIRED',
    );
  }

  if (
    !db
  ) {
    throw new Error(
      'WEBHOOK_FIRESTORE_REQUIRED',
    );
  }

  if (
    !accessToken
  ) {
    throw new Error(
      'WEBHOOK_ACCESS_TOKEN_REQUIRED',
    );
  }

  // ==========================================================
  // ROTA
  // ==========================================================

  app.post(
    '/v1/webhooks/mercado-pago',

    async (
      request,
      response,
    ) => {
      // ========================================================
      // TIPO
      // ========================================================

      const type =
        normalizeString(
          request.query?.type ||
          request.body?.type,
        ).toLowerCase();

      if (
        type &&
        type !== 'order'
      ) {
        return response
          .status(200)
          .json({
            ok: true,
            ignored: true,
            type,
          });
      }

      // ========================================================
      // SECRET
      // ========================================================

      const secret =
        normalizeString(
          webhookSecret,
        );

      if (
        !secret
      ) {
        console.error(
          'MERCADO PAGO WEBHOOK SECRET NÃO CONFIGURADO.',
        );

        return response
          .status(503)
          .json({
            ok: false,

            code:
              'WEBHOOK_SECRET_NOT_CONFIGURED',
          });
      }

      // ========================================================
      // DATA.ID ASSINADO
      // ========================================================

      const dataId =
        normalizeString(
          request
            .query
            ?.['data.id'],
        );

      if (
        !dataId
      ) {
        return response
          .status(400)
          .json({
            ok: false,

            code:
              'WEBHOOK_DATA_ID_REQUIRED',
          });
      }

      // ========================================================
      // HEADERS
      // ========================================================

      const xSignature =
        request.headers[
          'x-signature'
        ];

      const xRequestId =
        request.headers[
          'x-request-id'
        ];

      if (
        !xSignature ||
        !xRequestId
      ) {
        console.warn(
          'MERCADO PAGO WEBHOOK: HEADERS DE ASSINATURA AUSENTES.',
        );

        return response
          .status(401)
          .json({
            ok: false,

            code:
              'INVALID_WEBHOOK_SIGNATURE',
          });
      }

      // ========================================================
      // DADOS DA NOTIFICAÇÃO
      // ========================================================

      const notificationData =
        parseNotificationData(
          request.body,
        );

      const bodyOrderId =
        normalizeString(
          notificationData.id,
        );

      const applicationId =
        normalizeString(
          request.body
            ?.application_id,
        );

      const liveMode =
        request.body?.live_mode;

      console.log(
        'WEBHOOK ORIGEM:',
        {
          applicationId:
            applicationId || null,

          liveMode:
            liveMode ?? null,

          type:
            request.body?.type ??
            request.query?.type ??
            null,

          queryDataId:
            dataId,

          bodyDataId:
            bodyOrderId || null,
        },
      );

      // ========================================================
      // VALIDAR ASSINATURA OFICIAL
      // ========================================================

      try {
        WebhookSignatureValidator
          .validate({
            xSignature,

            xRequestId,

            dataId,

            secret,
          });
      } catch (
        error
      ) {
        console.warn(
          'MERCADO PAGO WEBHOOK: ASSINATURA INVÁLIDA.',
          {
            name:
              error?.name ||
              'Error',

            message:
              error?.message ||
              'Invalid signature',

            applicationId:
              applicationId ||
              null,

            liveMode:
              liveMode ??
              null,

            dataId,
          },
        );

        if (
          error instanceof
          InvalidWebhookSignatureError
        ) {
          return response
            .status(401)
            .json({
              ok: false,

              code:
                'INVALID_WEBHOOK_SIGNATURE',
            });
        }

        throw error;
      }

      // ========================================================
      // ASSINATURA VÁLIDA
      // ========================================================

      console.log(
        'MERCADO PAGO WEBHOOK: ASSINATURA VÁLIDA ✅',
        {
          dataId,

          applicationId:
            applicationId || null,

          liveMode:
            liveMode ?? null,
        },
      );

      // ========================================================
      // SIMULADOR
      // ========================================================

      const notificationId =
        normalizeString(
          request.body?.id,
        );

      const isSimulator =
        notificationId ===
        '123456';

      if (
        isSimulator
      ) {
        console.log(
          'MERCADO PAGO WEBHOOK SIMULADOR OK ✅',
        );

        return response
          .status(200)
          .json({
            ok: true,
            simulated: true,
          });
      }

      // ========================================================
      // ORDER ID CANÔNICO
      // ========================================================

      const orderId =
        dataId;

      if (
        bodyOrderId &&
        bodyOrderId !== orderId
      ) {
        console.warn(
          'MERCADO PAGO WEBHOOK: BODY DATA.ID DIFERENTE DO DATA.ID ASSINADO.',
          {
            queryDataId:
              orderId,

            bodyDataId:
              bodyOrderId,
          },
        );
      }

      // ========================================================
      // CONSULTAR ORDER NA API
      // ========================================================

      try {
        const order =
          await getMercadoPagoOrder({
            orderId,
            accessToken,
          });

        const verifiedOrderId =
          normalizeString(
            order?.id,
          );

        if (
          verifiedOrderId !== orderId
        ) {
          throw new Error(
            'ORDER_ID_MISMATCH',
          );
        }

        // ======================================================
        // PROCESSAR
        // ======================================================

        const result =
          await processOrder({
            db,

            order,

            configuredTestMode:
              testMode,

            notificationMeta: {
              applicationId,
              liveMode,
            },
          });

        // ======================================================
        // LOG
        // ======================================================

        console.log(
          'MERCADO PAGO WEBHOOK OK ✅',
          {
            signatureValid:
              true,

            verifiedByApi:
              true,

            processed:
              result.processed,

            appointmentId:
              result.appointmentId,

            orderId:
              result.orderId,

            paymentId:
              result.paymentId,

            method:
              result.method,

            status:
              result.status,

            statusDetail:
              result.statusDetail,

            integrityStatus:
              result.integrityStatus,

            integrityIssues:
              result.integrityIssues,

            confirmationEligible:
              result.confirmationEligible,

            confirmationApplied:
              result.confirmationApplied,

            confirmationAlreadyApplied:
              result
                .confirmationAlreadyApplied,

            confirmationBlockedReason:
              result
                .confirmationBlockedReason,

            requiresManualReview:
              result
                .requiresManualReview,

            notificationQueued:
              result
                .notificationQueued,

            notificationAlreadyQueued:
              result
                .notificationAlreadyQueued,

            notificationId:
              result
                .notificationId,
          },
        );

        // ======================================================
        // RESPOSTA
        // ======================================================

        return response
          .status(200)
          .json({
            ok: true,

            processed:
              result.processed,

            integrityStatus:
              result.integrityStatus,

            confirmationEligible:
              result.confirmationEligible,

            confirmationApplied:
              result.confirmationApplied,

            notificationQueued:
              result.notificationQueued,

            notificationAlreadyQueued:
              result.notificationAlreadyQueued,

            notificationId:
              result.notificationId,
          });
      } catch (
        error
      ) {
        // ======================================================
        // ERRO TÉCNICO REAL
        // ======================================================

        console.error(
          'MERCADO PAGO WEBHOOK ERROR:',
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

            orderId,

            status:
              error?.status ||
              null,
          },
        );

        return response
          .status(500)
          .json({
            ok: false,

            code:
              'WEBHOOK_PROCESSING_ERROR',
          });
      }
    },
  );
}

// ============================================================
// EXPORT
// ============================================================

module.exports = {
  registerMercadoPagoWebhook,
};