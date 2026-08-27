const {
  FieldValue,
} = require('firebase-admin/firestore');

// ============================================================
// NORMALIZAÇÃO
// ============================================================

function normalizeString(value) {
  return String(value || '').trim();
}

function normalizeNullableString(value) {
  const normalized = normalizeString(value);

  return normalized || null;
}

function normalizePositiveInteger(value) {
  const number = Number(value);

  if (
    !Number.isInteger(number) ||
    number < 1
  ) {
    return null;
  }

  return number;
}

function normalizeInteger(value) {
  const number = Number(value);

  if (!Number.isInteger(number)) {
    return null;
  }

  return number;
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return [
    ...new Set(
      value
        .map(normalizeString)
        .filter(Boolean),
    ),
  ];
}

// ============================================================
// ID SEGURO DO DOCUMENTO
// ============================================================

function createPaymentDocumentId(
  provider,
  paymentId,
) {
  const safeProvider =
    normalizeString(provider)
      .replace(
        /[^a-zA-Z0-9_-]/g,
        '_',
      );

  const safePaymentId =
    normalizeString(paymentId)
      .replace(
        /[^a-zA-Z0-9_-]/g,
        '_',
      );

  if (
    !safeProvider ||
    !safePaymentId
  ) {
    throw new Error(
      'INVALID_PAYMENT_DOCUMENT_ID',
    );
  }

  return `${safeProvider}_${safePaymentId}`;
}

// ============================================================
// LOCALIZAR PAGAMENTOS DO AGENDAMENTO
// ============================================================
//
// Este helper será usado pelo server.js no próximo ajuste.
//
// Objetivo:
//
// appointment
//     ↓
// já possui pagamento relevante?
//     ↓
// SIM → não criar uma nova cobrança desnecessariamente
// ============================================================

async function findPaymentsForAppointment({
  db,
  appointmentId,
  limit = 10,
}) {
  const normalizedAppointmentId =
    normalizeString(
      appointmentId,
    );

  if (
    !db ||
    !normalizedAppointmentId
  ) {
    throw new Error(
      'INVALID_PAYMENT_LOOKUP',
    );
  }

  const safeLimit =
    Number.isInteger(limit) &&
    limit > 0 &&
    limit <= 50
      ? limit
      : 10;

  const snapshot =
    await db
      .collection('payments')
      .where(
        'appointmentId',
        '==',
        normalizedAppointmentId,
      )
      .limit(
        safeLimit,
      )
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
// REGISTRAR PAGAMENTO
// ============================================================

async function registerPayment({
  db,

  appointmentId,
  userId,

  provider =
    'mercado_pago',

  method,

  orderId,
  paymentId,

  status,
  statusDetail,

  amount,
  amountCents,

  realAppointmentAmount,
  realAppointmentAmountCents,

  testMode,

  paymentMethodId =
    null,

  paymentMethodType =
    null,

  installments =
    null,

  // ==========================================================
  // SEGURANÇA / INTEGRIDADE
  // ==========================================================

  source =
    'payment_api',

  integrityStatus =
    'valid',

  integrityIssues =
    [],

  confirmationEligible =
    false,

  confirmationBlockedReason =
    null,

  requiresManualReview =
    false,

  attachToAppointment =
    true,
}) {
  // ==========================================================
  // NORMALIZAR CAMPOS
  // ==========================================================

  const normalizedAppointmentId =
    normalizeString(
      appointmentId,
    );

  const normalizedUserId =
    normalizeString(
      userId,
    );

  const normalizedProvider =
    normalizeString(
      provider,
    );

  const normalizedMethod =
    normalizeString(
      method,
    );

  const normalizedOrderId =
    normalizeString(
      orderId,
    );

  const normalizedPaymentId =
    normalizeString(
      paymentId,
    );

  if (
    !db ||
    !normalizedAppointmentId ||
    !normalizedUserId ||
    !normalizedProvider ||
    !normalizedMethod ||
    !normalizedOrderId ||
    !normalizedPaymentId
  ) {
    throw new Error(
      'INVALID_PAYMENT_RECORD',
    );
  }

  const normalizedAmountCents =
    normalizeInteger(
      amountCents,
    );

  const normalizedRealAmountCents =
    normalizeInteger(
      realAppointmentAmountCents,
    );

  if (
    normalizedAmountCents == null ||
    normalizedAmountCents <= 0 ||
    normalizedRealAmountCents == null ||
    normalizedRealAmountCents <= 0
  ) {
    throw new Error(
      'INVALID_PAYMENT_AMOUNT',
    );
  }

  const normalizedIntegrityStatus =
    normalizeString(
      integrityStatus,
    ) || 'valid';

  const normalizedIntegrityIssues =
    normalizeStringArray(
      integrityIssues,
    );

  const normalizedBlockedReason =
    normalizeNullableString(
      confirmationBlockedReason,
    );

  const normalizedSource =
    normalizeString(
      source,
    ) || 'payment_api';

  // ==========================================================
  // REFERÊNCIAS
  // ==========================================================

  const paymentDocumentId =
    createPaymentDocumentId(
      normalizedProvider,
      normalizedPaymentId,
    );

  const paymentReference =
    db
      .collection('payments')
      .doc(
        paymentDocumentId,
      );

  const appointmentReference =
    db
      .collection('appointments')
      .doc(
        normalizedAppointmentId,
      );

  // ==========================================================
  // DADOS DO PAGAMENTO
  // ==========================================================

  const paymentData = {
    provider:
      normalizedProvider,

    method:
      normalizedMethod,

    appointmentId:
      normalizedAppointmentId,

    userId:
      normalizedUserId,

    orderId:
      normalizedOrderId,

    paymentId:
      normalizedPaymentId,

    status:
      normalizeString(
        status,
      ),

    statusDetail:
      normalizeString(
        statusDetail,
      ),

    amount:
      normalizeString(
        amount,
      ),

    amountCents:
      normalizedAmountCents,

    realAppointmentAmount:
      normalizeString(
        realAppointmentAmount,
      ),

    realAppointmentAmountCents:
      normalizedRealAmountCents,

    testMode:
      testMode === true,

    paymentMethodId:
      normalizeNullableString(
        paymentMethodId,
      ),

    paymentMethodType:
      normalizeNullableString(
        paymentMethodType,
      ),

    installments:
      normalizePositiveInteger(
        installments,
      ),

    source:
      normalizedSource,

    integrityStatus:
      normalizedIntegrityStatus,

    integrityIssues:
      normalizedIntegrityIssues,

    confirmationEligible:
      confirmationEligible === true,

    confirmationBlockedReason:
      normalizedBlockedReason,

    requiresManualReview:
      requiresManualReview === true,

    updatedAt:
      FieldValue
        .serverTimestamp(),
  };

  // ==========================================================
  // TRANSAÇÃO FIRESTORE
  // ==========================================================
  //
  // Agora garantimos:
  //
  // - appointment existe;
  // - payment pertence ao usuário correto;
  // - paymentId não pode mudar de appointment;
  // - paymentId não pode mudar de Order;
  // - Webhooks repetidos são idempotentes;
  // - pagamento inconsistente continua registrado em payments;
  // - pagamento inconsistente NÃO substitui appointment.payment.
  //
  // NÃO altera appointment.status.
  // ==========================================================

  await db.runTransaction(
    async (
      transaction,
    ) => {
      // ========================================================
      // LEITURAS
      // ========================================================

      const appointmentSnapshot =
        await transaction.get(
          appointmentReference,
        );

      const existingPayment =
        await transaction.get(
          paymentReference,
        );

      if (
        !appointmentSnapshot.exists
      ) {
        throw new Error(
          'APPOINTMENT_NOT_FOUND',
        );
      }

      const appointmentData =
        appointmentSnapshot.data();

      if (
        !appointmentData
      ) {
        throw new Error(
          'APPOINTMENT_DATA_NOT_FOUND',
        );
      }

      // ========================================================
      // VERIFICAR USUÁRIO
      // ========================================================

      if (
        normalizeString(
          appointmentData.userId,
        ) !==
        normalizedUserId
      ) {
        throw new Error(
          'PAYMENT_USER_MISMATCH',
        );
      }

      // ========================================================
      // PAYMENT JÁ EXISTE
      // ========================================================
      //
      // paymentId é imutável em relação a:
      //
      // appointment
      // user
      // provider
      // order
      // ========================================================

      if (
        existingPayment.exists
      ) {
        const existingData =
          existingPayment.data() ||
          {};

        const immutableChecks = [
          [
            'appointmentId',

            normalizeString(
              existingData.appointmentId,
            ),

            normalizedAppointmentId,
          ],
          [
            'userId',

            normalizeString(
              existingData.userId,
            ),

            normalizedUserId,
          ],
          [
            'provider',

            normalizeString(
              existingData.provider,
            ),

            normalizedProvider,
          ],
          [
            'paymentId',

            normalizeString(
              existingData.paymentId,
            ),

            normalizedPaymentId,
          ],
          [
            'orderId',

            normalizeString(
              existingData.orderId,
            ),

            normalizedOrderId,
          ],
        ];

        for (
          const [
            field,
            oldValue,
            newValue,
          ]
          of immutableChecks
        ) {
          if (
            oldValue &&
            oldValue !== newValue
          ) {
            const error =
              new Error(
                `PAYMENT_IMMUTABLE_FIELD_MISMATCH:${field}`,
              );

            error.code =
              'PAYMENT_IMMUTABLE_FIELD_MISMATCH';

            error.field =
              field;

            throw error;
          }
        }
      } else {
        paymentData.createdAt =
          FieldValue
            .serverTimestamp();
      }

      // ========================================================
      // SALVAR PAYMENT
      // ========================================================

      transaction.set(
        paymentReference,
        paymentData,
        {
          merge:
            true,
        },
      );

      // ========================================================
      // ASSOCIAR AO APPOINTMENT
      // ========================================================
      //
      // Se o Webhook detectou problema sério, como:
      //
      // valor diferente
      // external_reference incorreta
      // outro appointment
      //
      // o pagamento permanece em /payments para auditoria,
      // mas não substitui appointment.payment.
      // ========================================================

      if (
        attachToAppointment ===
        true
      ) {
        transaction.set(
          appointmentReference,
          {
            payment: {
              recordId:
                paymentDocumentId,

              provider:
                normalizedProvider,

              method:
                normalizedMethod,

              orderId:
                normalizedOrderId,

              paymentId:
                normalizedPaymentId,

              status:
                normalizeString(
                  status,
                ),

              statusDetail:
                normalizeString(
                  statusDetail,
                ),

              amount:
                normalizeString(
                  amount,
                ),

              amountCents:
                normalizedAmountCents,

              realAppointmentAmount:
                normalizeString(
                  realAppointmentAmount,
                ),

              realAppointmentAmountCents:
                normalizedRealAmountCents,

              paymentMethodId:
                normalizeNullableString(
                  paymentMethodId,
                ),

              paymentMethodType:
                normalizeNullableString(
                  paymentMethodType,
                ),

              installments:
                normalizePositiveInteger(
                  installments,
                ),

              testMode:
                testMode === true,

              integrityStatus:
                normalizedIntegrityStatus,

              integrityIssues:
                normalizedIntegrityIssues,

              confirmationEligible:
                confirmationEligible ===
                true,

              confirmationBlockedReason:
                normalizedBlockedReason,

              requiresManualReview:
                requiresManualReview ===
                true,
            },

            paymentUpdatedAt:
              FieldValue
                .serverTimestamp(),
          },
          {
            merge:
              true,
          },
        );
      }
    },
  );

  return {
    paymentDocumentId,
  };
}

// ============================================================
// EXPORT
// ============================================================

module.exports = {
  registerPayment,
  findPaymentsForAppointment,
};