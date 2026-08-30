const {
  FieldValue,
} = require('firebase-admin/firestore');

// ============================================================
// UTILITÁRIOS
// ============================================================

function normalizeString(value) {
  return String(value || '').trim();
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
// CRIAR NOTIFICAÇÃO DE CONFIRMAÇÃO
// ============================================================
//
// ETAPA 34.1
//
// Ainda NÃO envia SMS.
//
// Apenas registra uma notificação pendente no Firestore.
//
// O ID é determinístico:
// appointment_confirmation_<appointmentId>
//
// Isso impede duplicidade caso o Mercado Pago envie
// o mesmo webhook mais de uma vez.
// ============================================================

async function queueAppointmentConfirmationNotification({
  db,

  appointmentId,
  userId,

  serviceName,
  professionalName,

  startAt,
  endAt,

  dateKey,
  startMinutes,
  endMinutes,

  orderId,
  paymentId,
}) {
  if (!db) {
    throw new Error(
      'NOTIFICATION_FIRESTORE_REQUIRED',
    );
  }

  const normalizedAppointmentId =
    normalizeString(
      appointmentId,
    );

  const normalizedUserId =
    normalizeString(
      userId,
    );

  if (!normalizedAppointmentId) {
    throw new Error(
      'NOTIFICATION_APPOINTMENT_ID_REQUIRED',
    );
  }

  if (!normalizedUserId) {
    throw new Error(
      'NOTIFICATION_USER_ID_REQUIRED',
    );
  }

  const notificationId =
    `appointment_confirmation_${safeDocumentId(
      normalizedAppointmentId,
    )}`;

  const reference =
    db
      .collection(
        'notification_outbox',
      )
      .doc(
        notificationId,
      );

  const result =
    await db.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(
            reference,
          );

        // ======================================================
        // IDEMPOTÊNCIA
        // ======================================================
        //
        // Se já existe, não cria novamente.
        // ======================================================

        if (snapshot.exists) {
          return {
            queued: true,
            alreadyQueued: true,
            notificationId,
          };
        }

        transaction.set(
          reference,
          {
            type:
              'appointment_confirmation',

            channel:
              'sms',

            status:
              'pending',

            appointmentId:
              normalizedAppointmentId,

            userId:
              normalizedUserId,

            serviceName:
              normalizeString(
                serviceName,
              ),

            professionalName:
              normalizeString(
                professionalName,
              ),

            startAt:
              startAt || null,

            endAt:
              endAt || null,

            dateKey:
              normalizeString(
                dateKey,
              ),

            startMinutes:
              Number.isInteger(
                Number(startMinutes),
              )
                ? Number(startMinutes)
                : null,

            endMinutes:
              Number.isInteger(
                Number(endMinutes),
              )
                ? Number(endMinutes)
                : null,

            payment: {
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
            },

            deliveryAttempts:
              0,

            lastAttemptAt:
              null,

            sentAt:
              null,

            providerMessageId:
              null,

            errorCode:
              null,

            errorMessage:
              null,

            createdAt:
              FieldValue
                .serverTimestamp(),

            updatedAt:
              FieldValue
                .serverTimestamp(),
          },
        );

        return {
          queued: true,
          alreadyQueued: false,
          notificationId,
        };
      },
    );

  return result;
}

// ============================================================
// EXPORT
// ============================================================

module.exports = {
  queueAppointmentConfirmationNotification,
};