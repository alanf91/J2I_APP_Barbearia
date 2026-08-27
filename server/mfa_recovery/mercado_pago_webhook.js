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

  return normalized ||
    null;
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
    value
      ?.toMillis?.();

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
        .map(
          normalizeString,
        )
        .filter(
          Boolean,
        ),
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

  return safe ||
    'unknown';
}

// ============================================================
// BODY.DATA
// ============================================================

function parseNotificationData(body) {
  const rawData =
    body?.data;

  if (
    !rawData
  ) {
    return {};
  }

  if (
    typeof rawData ===
      'object' &&
    !Array.isArray(
      rawData,
    )
  ) {
    return rawData;
  }

  if (
    typeof rawData ===
    'string'
  ) {
    try {
      const parsed =
        JSON.parse(
          rawData,
        );

      if (
        parsed &&
        typeof parsed ===
          'object' &&
        !Array.isArray(
          parsed,
        )
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
    !value.startsWith(
      prefix,
    )
  ) {
    return null;
  }

  const appointmentId =
    value
      .substring(
        prefix.length,
      )
      .trim();

  return appointmentId ||
    null;
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
    paymentMethodId ===
      'pix' ||
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
    normalizeString(
      status,
    ) ===
      'processed' &&
    normalizeString(
      statusDetail,
    ) ===
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
        method:
          'GET',

        headers: {
          Accept:
            'application/json',

          Authorization:
            `Bearer ${accessToken}`,
        },
      },
    );

  const raw =
    await mercadoPagoResponse
      .text();

  let data =
    {};

  try {
    data =
      raw
        ? JSON.parse(
            raw,
          )
        : {};
  } catch (_) {
    data =
      {};
  }

  if (
    !mercadoPagoResponse.ok
  ) {
    const error =
      new Error(
        'MERCADO_PAGO_ORDER_QUERY_FAILED',
      );

    error.status =
      mercadoPagoResponse
        .status;

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
// Salva somente dados necessários para auditoria.
//
// NÃO salvamos:
//
// token do cartão
// access token
// secret
// x-signature
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
  confirmationBlockedReason,

  requiresManualReview,
}) {
  const auditId = [
    'mercado_pago_webhook',

    safeDocumentId(
      orderId,
    ),

    safeDocumentId(
      paymentId,
    ),
  ].join(
    '_',
  );

  const reference =
    db
      .collection(
        'audit_logs',
      )
      .doc(
        auditId,
      );

  const snapshot =
    await reference.get();

  const data = {
    type:
      'mercado_pago_webhook',

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
      normalizeString(
        status,
      ),

    statusDetail:
      normalizeString(
        statusDetail,
      ),

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
        integrityIssues ||
        [],
      ),

    confirmationEligible:
      confirmationEligible ===
      true,

    confirmationBlockedReason:
      normalizeNullableString(
        confirmationBlockedReason,
      ),

    requiresManualReview:
      requiresManualReview ===
      true,

    lastSeenAt:
      FieldValue
        .serverTimestamp(),

    deliveryCount:
      FieldValue
        .increment(1),
  };

  if (
    !snapshot.exists
  ) {
    data.firstSeenAt =
      FieldValue
        .serverTimestamp();
  }

  await reference.set(
    data,
    {
      merge:
        true,
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
    async (
      transaction,
    ) => {
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
        snapshot.data() ||
        {};

      const status =
        normalizeString(
          appointment.status,
        );

      const expirationMs =
        timestampToMillis(
          appointment
            .paymentExpiresAt,
        );

      if (
        status ===
          'pending_payment' &&
        expirationMs != null &&
        expirationMs <=
          Date.now()
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
// PROCESSAR ORDER
// ============================================================

async function processOrder({
  db,
  order,
  configuredTestMode,
  notificationMeta =
    {},
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
      order
        ?.external_reference,
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
    detectMethod(
      payment,
    );

  const testMode =
    order.live_mode ===
      false ||
    configuredTestMode ===
      true;

  const approved =
    isApprovedPayment(
      status,
      statusDetail,
    );

  // ==========================================================
  // REGISTROS JÁ EXISTENTES PARA ESTA ORDER
  // ==========================================================

  const existingPayments =
    await findExistingPaymentsByOrderId({
      db:
        db,

      orderId:
        orderId,
    });

  const existingPayment =
    existingPayments[0] ||
    null;

  const existingAppointmentId =
    normalizeString(
      existingPayment
        ?.data
        ?.appointmentId,
    );

  // ==========================================================
  // VERIFICAR INTEGRIDADE DA ASSOCIAÇÃO
  // ==========================================================

  const integrityIssues =
    [];

  // ----------------------------------------------------------
  // EXTERNAL REFERENCE
  // ----------------------------------------------------------

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

  // ----------------------------------------------------------
  // APPOINTMENT DA ORDER X REGISTRO EXISTENTE
  // ----------------------------------------------------------

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

  // ----------------------------------------------------------
  // MAIS DE UM PAYMENT PARA A MESMA ORDER
  // ----------------------------------------------------------

  if (
    existingPayments.length >
    1
  ) {
    integrityIssues.push(
      'multiple_payment_records_for_same_order',
    );
  }

  // ==========================================================
  // DETERMINAR APPOINTMENT
  // ==========================================================
  //
  // A external_reference retornada diretamente pela API do MP
  // é a fonte principal.
  //
  // Existing payment é apenas fallback para registros antigos.
  // ==========================================================

  const appointmentId =
    externalAppointmentId ||
    existingAppointmentId ||
    null;

  // ==========================================================
  // NÃO CONSEGUIU RESOLVER O APPOINTMENT
  // ==========================================================

  if (
    !appointmentId
  ) {
    integrityIssues.push(
      'appointment_id_not_found',
    );

    await registerWebhookAudit({
      db:
        db,

      orderId:
        orderId,

      paymentId:
        paymentId,

      appointmentId:
        null,

      externalReference:
        externalReference,

      applicationId:
        notificationMeta
          .applicationId,

      liveMode:
        notificationMeta
          .liveMode,

      status:
        status,

      statusDetail:
        statusDetail,

      paymentAmountCents:
        paymentAmountCents,

      appointmentAmountCents:
        null,

      integrityStatus:
        'invalid',

      integrityIssues:
        integrityIssues,

      confirmationEligible:
        false,

      confirmationBlockedReason:
        'appointment_id_not_found',

      requiresManualReview:
        approved,
    });

    return {
      processed:
        false,

      appointmentId:
        null,

      orderId:
        orderId,

      paymentId:
        paymentId,

      method:
        method,

      status:
        status,

      statusDetail:
        statusDetail,

      integrityStatus:
        'invalid',

      integrityIssues:
        uniqueStrings(
          integrityIssues,
        ),

      confirmationEligible:
        false,

      confirmationBlockedReason:
        'appointment_id_not_found',

      requiresManualReview:
        approved,
    };
  }

  // ==========================================================
  // BUSCAR AGENDAMENTO
  // ==========================================================

  const appointmentReference =
    db
      .collection(
        'appointments',
      )
      .doc(
        appointmentId,
      );

  let appointmentSnapshot =
    await appointmentReference
      .get();

  if (
    !appointmentSnapshot.exists
  ) {
    integrityIssues.push(
      'appointment_not_found',
    );

    await registerWebhookAudit({
      db:
        db,

      orderId:
        orderId,

      paymentId:
        paymentId,

      appointmentId:
        appointmentId,

      externalReference:
        externalReference,

      applicationId:
        notificationMeta
          .applicationId,

      liveMode:
        notificationMeta
          .liveMode,

      status:
        status,

      statusDetail:
        statusDetail,

      paymentAmountCents:
        paymentAmountCents,

      appointmentAmountCents:
        null,

      integrityStatus:
        'invalid',

      integrityIssues:
        integrityIssues,

      confirmationEligible:
        false,

      confirmationBlockedReason:
        'appointment_not_found',

      requiresManualReview:
        approved,
    });

    return {
      processed:
        false,

      appointmentId:
        appointmentId,

      orderId:
        orderId,

      paymentId:
        paymentId,

      method:
        method,

      status:
        status,

      statusDetail:
        statusDetail,

      integrityStatus:
        'invalid',

      integrityIssues:
        uniqueStrings(
          integrityIssues,
        ),

      confirmationEligible:
        false,

      confirmationBlockedReason:
        'appointment_not_found',

      requiresManualReview:
        approved,
    };
  }

  let appointment =
    appointmentSnapshot
      .data();

  if (
    !appointment
  ) {
    throw new Error(
      'APPOINTMENT_DATA_NOT_FOUND',
    );
  }

  // ==========================================================
  // USER ID
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
      existingPayment
        .data
        .userId,
    ) !==
      userId
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
      appointment
        .priceCents,
    );

  const validAppointmentPrice =
    Number.isInteger(
      appointmentPriceCents,
    ) &&
    appointmentPriceCents >
      0;

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
    paymentAmountCents ==
    null
  ) {
    integrityIssues.push(
      'payment_amount_invalid',
    );
  }

  // ==========================================================
  // COMPARAR VALORES
  // ==========================================================

  if (
    validAppointmentPrice &&
    paymentAmountCents !=
      null &&
    paymentAmountCents !==
      appointmentPriceCents
  ) {
    integrityIssues.push(
      'payment_amount_mismatch',
    );
  }

  // ==========================================================
  // VALOR REAL DO APPOINTMENT
  // ==========================================================

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
    realAppointmentAmountCents >
      0
      ? (
          realAppointmentAmountCents /
          100
        ).toFixed(2)
      : '';

  // ==========================================================
  // STATUS DO APPOINTMENT
  // ==========================================================

  let appointmentStatus =
    normalizeString(
      appointment.status,
    );

  let confirmationEligible =
    false;

  let confirmationBlockedReason =
    null;

  let requiresManualReview =
    false;

  const expirationMs =
    timestampToMillis(
      appointment
        .paymentExpiresAt,
    );

  const startAtMs =
    timestampToMillis(
      appointment
        .startAt,
    );

  // ==========================================================
  // RESERVA VENCEU, MAS AINDA ESTÁ pending_payment
  // ==========================================================

  if (
    appointmentStatus ===
      'pending_payment' &&
    expirationMs !=
      null &&
    expirationMs <=
      Date.now()
  ) {
    await markAppointmentExpiredIfNeeded({
      db:
        db,

      appointmentReference:
        appointmentReference,
    });

    appointmentSnapshot =
      await appointmentReference
        .get();

    appointment =
      appointmentSnapshot
        .data() ||
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
    criticalIntegrityIssues
      .length === 0
      ? 'valid'
      : 'invalid';

  // ==========================================================
  // ELEGIBILIDADE PARA FUTURA ETAPA 33
  // ==========================================================

  if (
    integrityStatus !==
    'valid'
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
    confirmationBlockedReason =
      'appointment_already_confirmed';
  } else if (
    appointmentStatus !==
    'pending_payment'
  ) {
    confirmationBlockedReason =
      'appointment_status_not_payable';

    requiresManualReview =
      true;
  } else if (
    expirationMs ==
    null
  ) {
    confirmationBlockedReason =
      'appointment_expiration_invalid';

    requiresManualReview =
      true;
  } else if (
    expirationMs <=
    Date.now()
  ) {
    confirmationBlockedReason =
      'appointment_expired';

    requiresManualReview =
      true;
  } else if (
    startAtMs != null &&
    startAtMs <=
      Date.now()
  ) {
    confirmationBlockedReason =
      'appointment_already_started';

    requiresManualReview =
      true;
  } else {
    // ========================================================
    // ESTE É O CENÁRIO IDEAL
    // ========================================================
    //
    // assinatura válida
    // Order confirmada pela API
    // external_reference válida
    // valor correto
    // appointment pending_payment
    // reserva ainda válida
    // pagamento processado/acreditado
    //
    // Ainda NÃO confirmamos o appointment.
    //
    // Apenas registramos:
    //
    // confirmationEligible = true
    //
    // A mudança:
    //
    // pending_payment → confirmed
    //
    // será implementada na etapa 33.
    // ========================================================

    confirmationEligible =
      true;
  }

  // ==========================================================
  // PODEMOS SALVAR PAYMENT?
  // ==========================================================

  const canPersistPayment =
    userId &&
    paymentAmountCents !=
      null &&
    Number.isInteger(
      realAppointmentAmountCents,
    ) &&
    realAppointmentAmountCents >
      0;

  let registration =
    null;

  // ==========================================================
  // SALVAR PAYMENT
  // ==========================================================

  if (
    canPersistPayment
  ) {
    registration =
      await registerPayment({
        db:
          db,

        appointmentId:
          appointmentId,

        userId:
          userId,

        provider:
          'mercado_pago',

        method:
          method,

        orderId:
          orderId,

        paymentId:
          paymentId,

        status:
          status,

        statusDetail:
          statusDetail,

        amount:
          paymentAmount,

        amountCents:
          paymentAmountCents,

        realAppointmentAmount:
          realAppointmentAmount,

        realAppointmentAmountCents:
          realAppointmentAmountCents,

        testMode:
          testMode,

        paymentMethodId:
          paymentMethodId,

        paymentMethodType:
          paymentMethodType,

        installments:
          installments,

        source:
          'mercado_pago_webhook',

        integrityStatus:
          integrityStatus,

        integrityIssues:
          criticalIntegrityIssues,

        confirmationEligible:
          confirmationEligible,

        confirmationBlockedReason:
          confirmationBlockedReason,

        requiresManualReview:
          requiresManualReview,

        // ====================================================
        // NÃO ASSOCIAR DADOS INCONSISTENTES AO APPOINTMENT
        // ====================================================

        attachToAppointment:
          integrityStatus ===
          'valid',
      });
  }

  // ==========================================================
  // REGISTRAR WEBHOOK NO APPOINTMENT
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

        orderId:
          orderId,

        paymentId:
          paymentId,

        externalReference:
          normalizeNullableString(
            externalReference,
          ),

        status:
          status,

        statusDetail:
          statusDetail,

        amountCents:
          paymentAmountCents,

        expectedAmountCents:
          validAppointmentPrice
            ? appointmentPriceCents
            : null,

        integrityStatus:
          integrityStatus,

        integrityIssues:
          criticalIntegrityIssues,

        confirmationEligible:
          confirmationEligible,

        confirmationBlockedReason:
          normalizeNullableString(
            confirmationBlockedReason,
          ),

        requiresManualReview:
          requiresManualReview,

        receivedAt:
          FieldValue
            .serverTimestamp(),
      },
    },
    {
      merge:
        true,
    },
  );

  // ==========================================================
  // AUDITORIA
  // ==========================================================

  await registerWebhookAudit({
    db:
      db,

    orderId:
      orderId,

    paymentId:
      paymentId,

    appointmentId:
      appointmentId,

    externalReference:
      externalReference,

    applicationId:
      notificationMeta
        .applicationId,

    liveMode:
      notificationMeta
        .liveMode,

    status:
      status,

    statusDetail:
      statusDetail,

    paymentAmountCents:
      paymentAmountCents,

    appointmentAmountCents:
      validAppointmentPrice
        ? appointmentPriceCents
        : null,

    integrityStatus:
      integrityStatus,

    integrityIssues:
      criticalIntegrityIssues,

    confirmationEligible:
      confirmationEligible,

    confirmationBlockedReason:
      confirmationBlockedReason,

    requiresManualReview:
      requiresManualReview,
  });

  // ==========================================================
  // RESULTADO
  // ==========================================================

  return {
    processed:
      true,

    appointmentId:
      appointmentId,

    orderId:
      orderId,

    paymentId:
      paymentId,

    paymentRecordId:
      registration
        ?.paymentDocumentId ||
      null,

    method:
      method,

    status:
      status,

    statusDetail:
      statusDetail,

    integrityStatus:
      integrityStatus,

    integrityIssues:
      criticalIntegrityIssues,

    confirmationEligible:
      confirmationEligible,

    confirmationBlockedReason:
      confirmationBlockedReason,

    requiresManualReview:
      requiresManualReview,
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
          request
            .query
            ?.type ||
          request
            .body
            ?.type,
        ).toLowerCase();

      if (
        type &&
        type !==
          'order'
      ) {
        return response
          .status(200)
          .json({
            ok:
              true,

            ignored:
              true,

            type:
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
            ok:
              false,

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
            ok:
              false,

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
            ok:
              false,

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
          request
            .body
            ?.application_id,
        );

      const liveMode =
        request
          .body
          ?.live_mode;

      console.log(
        'WEBHOOK ORIGEM:',
        {
          applicationId:
            applicationId ||
            null,

          liveMode:
            liveMode ??
            null,

          type:
            request
              .body
              ?.type ??
            request
              .query
              ?.type ??
            null,

          queryDataId:
            dataId,

          bodyDataId:
            bodyOrderId ||
            null,
        },
      );

      // ========================================================
      // VALIDAR ASSINATURA OFICIAL
      // ========================================================

      try {
        WebhookSignatureValidator
          .validate({
            xSignature:
              xSignature,

            xRequestId:
              xRequestId,

            dataId:
              dataId,

            secret:
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

            dataId:
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
              ok:
                false,

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
          dataId:
            dataId,

          applicationId:
            applicationId ||
            null,

          liveMode:
            liveMode ??
            null,
        },
      );

      // ========================================================
      // SIMULADOR
      // ========================================================

      const notificationId =
        normalizeString(
          request
            .body
            ?.id,
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
            ok:
              true,

            simulated:
              true,
          });
      }

      // ========================================================
      // ORDER ID CANÔNICO
      // ========================================================
      //
      // IMPORTANTE:
      //
      // Sempre usamos o data.id que participou da validação
      // criptográfica.
      //
      // Não usamos body.data.id como fonte principal.
      // ========================================================

      const orderId =
        dataId;

      // ========================================================
      // BODY DIFERENTE DO ID ASSINADO
      // ========================================================

      if (
        bodyOrderId &&
        bodyOrderId !==
          orderId
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
      // CONSULTAR ORDER NA API MERCADO PAGO
      // ========================================================

      try {
        const order =
          await getMercadoPagoOrder({
            orderId:
              orderId,

            accessToken:
              accessToken,
          });

        // ======================================================
        // VERIFICAR ORDER ID RETORNADO PELA API
        // ======================================================

        const verifiedOrderId =
          normalizeString(
            order?.id,
          );

        if (
          verifiedOrderId !==
          orderId
        ) {
          throw new Error(
            'ORDER_ID_MISMATCH',
          );
        }

        // ======================================================
        // PROCESSAR ORDER
        // ======================================================

        const result =
          await processOrder({
            db:
              db,

            order:
              order,

            configuredTestMode:
              testMode,

            notificationMeta: {
              applicationId:
                applicationId,

              liveMode:
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
              result
                .processed,

            appointmentId:
              result
                .appointmentId,

            orderId:
              result
                .orderId,

            paymentId:
              result
                .paymentId,

            method:
              result
                .method,

            status:
              result
                .status,

            statusDetail:
              result
                .statusDetail,

            integrityStatus:
              result
                .integrityStatus,

            integrityIssues:
              result
                .integrityIssues,

            confirmationEligible:
              result
                .confirmationEligible,

            confirmationBlockedReason:
              result
                .confirmationBlockedReason,

            requiresManualReview:
              result
                .requiresManualReview,
          },
        );

        // ======================================================
        // RESPOSTA 200 PARA ERROS DE REGRA DE NEGÓCIO
        // ======================================================
        //
        // Exemplos:
        //
        // appointment cancelado
        // reserva expirada
        // valor incorreto
        // external_reference incorreta
        //
        // Essas situações já foram auditadas.
        //
        // Repetir o mesmo Webhook não corrigiria o problema.
        // ======================================================

        return response
          .status(200)
          .json({
            ok:
              true,

            processed:
              result
                .processed,

            integrityStatus:
              result
                .integrityStatus,

            confirmationEligible:
              result
                .confirmationEligible,
          });
      } catch (
        error
      ) {
        // ======================================================
        // ERRO TÉCNICO REAL
        // ======================================================
        //
        // Aqui retornamos 500.
        //
        // Assim uma falha temporária pode ser tentada novamente.
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

            orderId:
              orderId,

            status:
              error?.status ||
              null,
          },
        );

        return response
          .status(500)
          .json({
            ok:
              false,

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