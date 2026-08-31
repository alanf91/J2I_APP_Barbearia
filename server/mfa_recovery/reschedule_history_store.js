// ============================================================
// ETAPA 39
// HISTÓRICO PERMANENTE DE REAGENDAMENTOS
// ============================================================

// ============================================================
// NORMALIZAÇÃO
// ============================================================

function normalizeString(value) {
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
// VALIDAR HORÁRIO
// ============================================================

function normalizeSchedule({
  dateKey,
  startMinutes,
  endMinutes,
}) {
  const normalizedDateKey =
    normalizeString(
      dateKey,
    );

  const normalizedStartMinutes =
    normalizeInteger(
      startMinutes,
    );

  const normalizedEndMinutes =
    normalizeInteger(
      endMinutes,
    );

  if (
    !normalizedDateKey ||
    normalizedStartMinutes == null ||
    normalizedEndMinutes == null ||
    normalizedStartMinutes < 0 ||
    normalizedStartMinutes >= 1440 ||
    normalizedEndMinutes <=
      normalizedStartMinutes ||
    normalizedEndMinutes > 1440
  ) {
    throw new Error(
      'INVALID_RESCHEDULE_HISTORY_SCHEDULE',
    );
  }

  return {
    dateKey:
      normalizedDateKey,

    startMinutes:
      normalizedStartMinutes,

    endMinutes:
      normalizedEndMinutes,
  };
}

// ============================================================
// CRIAR HISTÓRICO DENTRO DA TRANSAÇÃO
// ============================================================

function createRescheduleHistoryInTransaction({
  transaction,
  db,

  appointmentId,
  appointment,

  uid,

  from,
  to,

  paymentValidation,

  changedAt,
}) {
  // ==========================================================
  // DEPENDÊNCIAS
  // ==========================================================

  if (
    !transaction ||
    !db
  ) {
    throw new Error(
      'RESCHEDULE_HISTORY_FIRESTORE_REQUIRED',
    );
  }

  // ==========================================================
  // IDENTIFICAÇÃO
  // ==========================================================

  const normalizedAppointmentId =
    normalizeString(
      appointmentId,
    );

  const normalizedUid =
    normalizeString(
      uid,
    );

  if (
    !normalizedAppointmentId ||
    !normalizedUid
  ) {
    throw new Error(
      'RESCHEDULE_HISTORY_IDENTITY_REQUIRED',
    );
  }

  // ==========================================================
  // APPOINTMENT
  // ==========================================================

  if (
    !appointment ||
    typeof appointment !==
      'object'
  ) {
    throw new Error(
      'RESCHEDULE_HISTORY_APPOINTMENT_REQUIRED',
    );
  }

  // ==========================================================
  // HORÁRIOS
  // ==========================================================

  const normalizedFrom =
    normalizeSchedule(
      from,
    );

  const normalizedTo =
    normalizeSchedule(
      to,
    );

  // ==========================================================
  // PROFISSIONAL
  // ==========================================================

  const professionalId =
    normalizeString(
      appointment
        .professionalId,
    );

  if (
    !professionalId
  ) {
    throw new Error(
      'RESCHEDULE_HISTORY_PROFESSIONAL_REQUIRED',
    );
  }

  // ==========================================================
  // SERVIÇO
  // ==========================================================

  const serviceId =
    normalizeString(
      appointment
        .serviceId,
    );

  const serviceName =
    normalizeString(
      appointment
        .serviceName,
    );

  // ==========================================================
  // DURAÇÃO
  // ==========================================================

  const durationMinutes =
    normalizeInteger(
      appointment
        .durationMinutes,
    );

  if (
    durationMinutes == null ||
    durationMinutes <= 0
  ) {
    throw new Error(
      'RESCHEDULE_HISTORY_DURATION_INVALID',
    );
  }

  // ==========================================================
  // VALOR
  // ==========================================================

  const priceCents =
    normalizeInteger(
      appointment
        .priceCents,
    );

  if (
    priceCents == null ||
    priceCents <= 0
  ) {
    throw new Error(
      'RESCHEDULE_HISTORY_PRICE_INVALID',
    );
  }

  // ==========================================================
  // PAGAMENTO
  // ==========================================================

  const paymentRecordId =
    normalizeString(
      paymentValidation
        ?.paymentRecordId,
    );

  const paymentOrderId =
    normalizeString(
      paymentValidation
        ?.orderId,
    );

  const paymentId =
    normalizeString(
      paymentValidation
        ?.paymentId,
    );

  if (
    !paymentRecordId ||
    !paymentOrderId ||
    !paymentId
  ) {
    throw new Error(
      'RESCHEDULE_HISTORY_PAYMENT_REQUIRED',
    );
  }

  // ==========================================================
  // CONTADOR
  // ==========================================================

  const currentRescheduleCount =
    normalizeInteger(
      appointment
        .rescheduleCount,
    );

  const historyNumber =
    (
      currentRescheduleCount != null &&
      currentRescheduleCount >= 0
    )
      ? currentRescheduleCount + 1
      : 1;

  // ==========================================================
  // DOCUMENTO
  // ==========================================================

  const historyReference =
    db
      .collection(
        'appointments',
      )
      .doc(
        normalizedAppointmentId,
      )
      .collection(
        'reschedule_history',
      )
      .doc();

  // ==========================================================
  // DADOS DO HISTÓRICO
  // ==========================================================

  const historyData = {
    appointmentId:
      normalizedAppointmentId,

    userId:
      normalizedUid,

    professionalId,

    serviceId:
      serviceId ||
      null,

    serviceName:
      serviceName ||
      null,

    durationMinutes,

    priceCents,

    historyNumber,

    from: {
      dateKey:
        normalizedFrom.dateKey,

      startMinutes:
        normalizedFrom.startMinutes,

      endMinutes:
        normalizedFrom.endMinutes,
    },

    to: {
      dateKey:
        normalizedTo.dateKey,

      startMinutes:
        normalizedTo.startMinutes,

      endMinutes:
        normalizedTo.endMinutes,
    },

    payment: {
      recordId:
        paymentRecordId,

      orderId:
        paymentOrderId,

      paymentId,
    },

    source:
      'client_reschedule',

    status:
      'completed',

    changedAt,
  };

  // ==========================================================
  // GRAVAR NA MESMA TRANSAÇÃO DO REAGENDAMENTO
  // ==========================================================

  transaction.set(
    historyReference,
    historyData,
  );

  // ==========================================================
  // RESULTADO
  // ==========================================================

  return {
    historyId:
      historyReference.id,

    historyNumber,
  };
}

// ============================================================
// EXPORTS
// ============================================================

module.exports = {
  createRescheduleHistoryInTransaction,
};