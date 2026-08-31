// ============================================================
// ETAPA 38
// VALIDAÇÃO DE PAGAMENTO PARA REAGENDAMENTO
// ============================================================

function normalizeString(value) {
  return String(
    value || '',
  )
    .trim()
    .toLowerCase();
}

function normalizeOriginalString(value) {
  return String(
    value || '',
  ).trim();
}

function normalizeInteger(value) {
  const number =
    Number(
      value,
    );

  if (
    !Number.isInteger(
      number,
    )
  ) {
    return null;
  }

  return number;
}

// ============================================================
// RESULTADO DE ERRO
// ============================================================

function paymentError({
  code,
  message,
}) {
  return {
    ok:
      false,

    statusCode:
      409,

    code,

    message,
  };
}

// ============================================================
// VALIDAR PAGAMENTO APROVADO
// ============================================================

async function validateApprovedPaymentForReschedule({
  transaction,
  db,
  appointment,
  appointmentId,
  uid,
}) {
  // ==========================================================
  // DEPENDÊNCIAS
  // ==========================================================

  if (
    !transaction ||
    !db
  ) {
    throw new Error(
      'RESCHEDULE_PAYMENT_FIRESTORE_REQUIRED',
    );
  }

  const normalizedAppointmentId =
    normalizeOriginalString(
      appointmentId,
    );

  const normalizedUid =
    normalizeOriginalString(
      uid,
    );

  if (
    !normalizedAppointmentId ||
    !normalizedUid
  ) {
    throw new Error(
      'RESCHEDULE_PAYMENT_IDENTITY_REQUIRED',
    );
  }

  // ==========================================================
  // PAYMENT VINCULADO AO APPOINTMENT
  // ==========================================================

  const appointmentPayment =
    appointment?.payment;

  if (
    !appointmentPayment ||
    typeof appointmentPayment !==
      'object'
  ) {
    return paymentError({
      code:
        'PAYMENT_NOT_ATTACHED',

      message:
        'Não foi encontrado um pagamento vinculado a este agendamento.',
    });
  }

  // ==========================================================
  // RECORD ID
  // ==========================================================

  const paymentRecordId =
    normalizeOriginalString(
      appointmentPayment
        .recordId,
    );

  if (
    !paymentRecordId
  ) {
    return paymentError({
      code:
        'PAYMENT_RECORD_NOT_FOUND',

      message:
        'O registro do pagamento deste agendamento não foi encontrado.',
    });
  }

  // ==========================================================
  // DOCUMENTO DE PAGAMENTO
  // ==========================================================

  const paymentReference =
    db
      .collection(
        'payments',
      )
      .doc(
        paymentRecordId,
      );

  const paymentSnapshot =
    await transaction.get(
      paymentReference,
    );

  if (
    !paymentSnapshot.exists
  ) {
    return paymentError({
      code:
        'PAYMENT_RECORD_NOT_FOUND',

      message:
        'O registro do pagamento deste agendamento não existe.',
    });
  }

  const payment =
    paymentSnapshot.data() ||
    {};

  // ==========================================================
  // APPOINTMENT
  // ==========================================================

  const paymentAppointmentId =
    normalizeOriginalString(
      payment.appointmentId,
    );

  if (
    paymentAppointmentId !==
    normalizedAppointmentId
  ) {
    return paymentError({
      code:
        'PAYMENT_APPOINTMENT_MISMATCH',

      message:
        'O pagamento não pertence a este agendamento.',
    });
  }

  // ==========================================================
  // USUÁRIO
  // ==========================================================

  const paymentUserId =
    normalizeOriginalString(
      payment.userId,
    );

  if (
    paymentUserId !==
    normalizedUid
  ) {
    return paymentError({
      code:
        'PAYMENT_USER_MISMATCH',

      message:
        'O pagamento não pertence ao usuário deste agendamento.',
    });
  }

  // ==========================================================
  // PROVIDER
  // ==========================================================

  const provider =
    normalizeString(
      payment.provider,
    );

  if (
    provider !==
    'mercado_pago'
  ) {
    return paymentError({
      code:
        'INVALID_PAYMENT_PROVIDER',

      message:
        'O pagamento deste agendamento não possui uma origem válida.',
    });
  }

  // ==========================================================
  // ORDER ID / PAYMENT ID
  // ==========================================================

  const orderId =
    normalizeOriginalString(
      payment.orderId,
    );

  const paymentId =
    normalizeOriginalString(
      payment.paymentId,
    );

  if (
    !orderId ||
    !paymentId
  ) {
    return paymentError({
      code:
        'PAYMENT_REFERENCE_INCOMPLETE',

      message:
        'O pagamento deste agendamento está com identificação incompleta.',
    });
  }

  // ==========================================================
  // CONFERIR COM O PAYMENT DO APPOINTMENT
  // ==========================================================

  const appointmentOrderId =
    normalizeOriginalString(
      appointmentPayment
        .orderId,
    );

  const appointmentPaymentId =
    normalizeOriginalString(
      appointmentPayment
        .paymentId,
    );

  if (
    appointmentOrderId &&
    appointmentOrderId !==
      orderId
  ) {
    return paymentError({
      code:
        'PAYMENT_ORDER_MISMATCH',

      message:
        'A cobrança vinculada ao agendamento não corresponde ao pagamento registrado.',
    });
  }

  if (
    appointmentPaymentId &&
    appointmentPaymentId !==
      paymentId
  ) {
    return paymentError({
      code:
        'PAYMENT_ID_MISMATCH',

      message:
        'O pagamento vinculado ao agendamento não corresponde ao registro financeiro.',
    });
  }

  // ==========================================================
  // STATUS
  // ==========================================================

  const status =
    normalizeString(
      payment.status,
    );

  const statusDetail =
    normalizeString(
      payment.statusDetail,
    );

  if (
    status !==
      'processed' ||
    statusDetail !==
      'accredited'
  ) {
    return paymentError({
      code:
        'PAYMENT_NOT_APPROVED',

      message:
        'Somente agendamentos com pagamento aprovado podem ser reagendados.',
    });
  }

  // ==========================================================
  // INTEGRIDADE
  // ==========================================================

  const integrityStatus =
    normalizeString(
      payment.integrityStatus,
    );

  if (
    integrityStatus !==
    'valid'
  ) {
    return paymentError({
      code:
        'PAYMENT_INTEGRITY_INVALID',

      message:
        'O pagamento deste agendamento não passou pela validação de integridade.',
    });
  }

  // ==========================================================
  // PROBLEMAS DE INTEGRIDADE
  // ==========================================================

  const integrityIssues =
    Array.isArray(
      payment.integrityIssues,
    )
      ? payment
          .integrityIssues
          .filter(
            (
              issue,
            ) =>
              normalizeOriginalString(
                issue,
              ) !== '',
          )
      : [];

  if (
    integrityIssues.length >
    0
  ) {
    return paymentError({
      code:
        'PAYMENT_INTEGRITY_ISSUES',

      message:
        'O pagamento deste agendamento possui uma inconsistência de integridade.',
    });
  }

  // ==========================================================
  // REVISÃO MANUAL
  // ==========================================================

  if (
    payment.requiresManualReview ===
    true
  ) {
    return paymentError({
      code:
        'PAYMENT_REQUIRES_MANUAL_REVIEW',

      message:
        'Este pagamento precisa de revisão antes que o agendamento possa ser reagendado.',
    });
  }

  // ==========================================================
  // ELEGÍVEL PARA CONFIRMAÇÃO
  // ==========================================================

  if (
    payment.confirmationEligible !==
    true
  ) {
    return paymentError({
      code:
        'PAYMENT_NOT_CONFIRMATION_ELIGIBLE',

      message:
        'O pagamento ainda não está liberado para reagendamento.',
    });
  }

  // ==========================================================
  // VALOR DO AGENDAMENTO
  // ==========================================================

  const appointmentPriceCents =
    normalizeInteger(
      appointment
        ?.priceCents,
    );

  if (
    appointmentPriceCents ==
      null ||
    appointmentPriceCents <=
      0
  ) {
    return paymentError({
      code:
        'INVALID_APPOINTMENT_PRICE',

      message:
        'O valor do agendamento é inválido.',
    });
  }

  // ==========================================================
  // VALOR REAL REGISTRADO
  // ==========================================================

  const realAppointmentAmountCents =
    normalizeInteger(
      payment
        .realAppointmentAmountCents,
    );

  if (
    realAppointmentAmountCents ==
    null
  ) {
    return paymentError({
      code:
        'PAYMENT_AMOUNT_MISSING',

      message:
        'O pagamento não possui o valor real do agendamento registrado.',
    });
  }

  if (
    realAppointmentAmountCents !==
    appointmentPriceCents
  ) {
    return paymentError({
      code:
        'PAYMENT_AMOUNT_MISMATCH',

      message:
        'O valor do pagamento não corresponde ao valor do agendamento.',
    });
  }

  // ==========================================================
  // VALOR PROCESSADO
  // ==========================================================

  const amountCents =
    normalizeInteger(
      payment.amountCents,
    );

  if (
    amountCents ==
    null ||
    amountCents <=
      0
  ) {
    return paymentError({
      code:
        'PAYMENT_AMOUNT_INVALID',

      message:
        'O valor processado do pagamento é inválido.',
    });
  }

  // ==========================================================
  // SUCESSO
  // ==========================================================

  return {
    ok:
      true,

    paymentRecordId,

    orderId,

    paymentId,

    method:
      normalizeString(
        payment.method,
      ),

    status,

    statusDetail,

    amountCents,

    realAppointmentAmountCents,
  };
}

// ============================================================
// EXPORTS
// ============================================================

module.exports = {
  validateApprovedPaymentForReschedule,
};