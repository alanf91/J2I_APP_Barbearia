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

  if (!Number.isInteger(number) || number < 1) {
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
// ID DO DOCUMENTO
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
      .limit(safeLimit)
      .get();

  return snapshot.docs.map(
    (document) => ({
      id: document.id,
      data: document.data(),
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

  provider = 'mercado_pago',
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

  paymentMethodId = null,
  paymentMethodType = null,
  installments = null,

  // ==========================================================
  // DADOS DO PIX
  // ==========================================================
  //
  // Esses dados são salvos na PRIMEIRA criação do Pix.
  //
  // Depois, caso o cliente saia da tela, o sistema poderá
  // reapresentar o MESMO QR sem criar outra cobrança.
  // ==========================================================

  pixQrCode = null,
  pixQrCodeBase64 = null,
  pixTicketUrl = null,

  // ==========================================================
  // SEGURANÇA / INTEGRIDADE
  // ==========================================================

  source = 'payment_api',

  integrityStatus = 'valid',

  integrityIssues = [],

  confirmationEligible = false,

  confirmationBlockedReason = null,

  requiresManualReview = false,

  attachToAppointment = true,
}) {
  // ==========================================================
  // NORMALIZAÇÃO
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

  // ==========================================================
  // VALORES
  // ==========================================================

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

  // ==========================================================
  // INTEGRIDADE
  // ==========================================================

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
  // PIX RECEBIDO
  // ==========================================================

  const requestedPixData = {
    qrCode:
      normalizeNullableString(
        pixQrCode,
      ),

    qrCodeBase64:
      normalizeNullableString(
        pixQrCodeBase64,
      ),

    ticketUrl:
      normalizeNullableString(
        pixTicketUrl,
      ),
  };

  // ==========================================================
  // DOCUMENTOS
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
  // PAYMENT
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
      FieldValue.serverTimestamp(),
  };

  // ==========================================================
  // TRANSAÇÃO
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

      if (!appointmentData) {
        throw new Error(
          'APPOINTMENT_DATA_NOT_FOUND',
        );
      }

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

      const existingData =
        existingPayment.exists
          ? existingPayment.data() || {}
          : {};

      // ========================================================
      // IMUTABILIDADE
      // ========================================================

      if (
        existingPayment.exists
      ) {
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
          ] of immutableChecks
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
          FieldValue.serverTimestamp();
      }

      // ========================================================
      // PRESERVAR PIX
      // ========================================================
      //
      // Muito importante:
      //
      // O Webhook pode atualizar o pagamento posteriormente sem
      // trazer novamente qrCode.
      //
      // Portanto:
      //
      // NOVO QR recebido
      //     ↓
      // usa novo
      //
      // Webhook sem QR
      //     ↓
      // mantém QR que já estava salvo
      //
      // ========================================================

      const existingPix =
        existingData.pix &&
        typeof existingData.pix ===
          'object'
          ? existingData.pix
          : {};

      const effectivePix = {
        qrCode:
          requestedPixData.qrCode ||
          normalizeNullableString(
            existingPix.qrCode,
          ),

        qrCodeBase64:
          requestedPixData.qrCodeBase64 ||
          normalizeNullableString(
            existingPix.qrCodeBase64,
          ),

        ticketUrl:
          requestedPixData.ticketUrl ||
          normalizeNullableString(
            existingPix.ticketUrl,
          ),
      };

      const hasEffectivePixData =
        Boolean(
          effectivePix.qrCode ||
          effectivePix.qrCodeBase64 ||
          effectivePix.ticketUrl,
        );

      if (
        normalizedMethod ===
          'pix' &&
        hasEffectivePixData
      ) {
        paymentData.pix =
          effectivePix;
      }

      // ========================================================
      // GRAVAR PAYMENT
      // ========================================================

      transaction.set(
        paymentReference,
        paymentData,
        {
          merge: true,
        },
      );

      // ========================================================
      // APPOINTMENT.PAYMENT
      // ========================================================

      if (
        attachToAppointment ===
        true
      ) {
        const appointmentPaymentData = {
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
            confirmationEligible === true,

          confirmationBlockedReason:
            normalizedBlockedReason,

          requiresManualReview:
            requiresManualReview === true,
        };

        // ======================================================
        // PIX TAMBÉM NO APPOINTMENT
        // ======================================================

        if (
          normalizedMethod ===
            'pix' &&
          hasEffectivePixData
        ) {
          appointmentPaymentData.pix =
            effectivePix;
        }

        transaction.set(
          appointmentReference,
          {
            payment:
              appointmentPaymentData,

            paymentUpdatedAt:
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

  return {
    paymentDocumentId,
  };
}

// ============================================================
// EXPORTS
// ============================================================

module.exports = {
  registerPayment,
  findPaymentsForAppointment,
};