const admin = require('firebase-admin');

const db = admin.firestore();

function getMercadoPagoAccessToken() {
  const token = process.env.MERCADO_PAGO_ACCESS_TOKEN;

  if (!token) {
    throw new Error('MERCADO_PAGO_ACCESS_TOKEN não configurado no .env');
  }

  return token;
}

async function getMercadoPagoOrder(orderId) {
  const token = getMercadoPagoAccessToken();

  const response = await fetch(`https://api.mercadopago.com/v1/orders/${orderId}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });

  const text = await response.text();

  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch (error) {
    json = {
      raw: text,
    };
  }

  if (!response.ok) {
    console.error('[MP ORDER SYNC] Erro ao consultar order:', {
      status: response.status,
      body: json,
    });

    throw new Error(`Erro ao consultar Order no Mercado Pago: ${response.status}`);
  }

  return json;
}

function getFirstPayment(order) {
  const payments = order?.transactions?.payments;

  if (Array.isArray(payments) && payments.length > 0) {
    return payments[0];
  }

  return null;
}

function normalizeOrderStatus(order) {
  const payment = getFirstPayment(order);

  const orderStatus = order?.status || null;
  const orderStatusDetail = order?.status_detail || null;

  const paymentStatus = payment?.status || null;
  const paymentStatusDetail = payment?.status_detail || null;

  const isPaid =
    orderStatus === 'processed' ||
    orderStatusDetail === 'accredited' ||
    paymentStatus === 'processed' ||
    paymentStatusDetail === 'accredited';

  const isWaitingPix =
    orderStatusDetail === 'waiting_transfer' ||
    paymentStatusDetail === 'waiting_transfer';

  const isProcessing =
    orderStatus === 'processing' ||
    paymentStatus === 'processing' ||
    orderStatusDetail === 'in_process' ||
    paymentStatusDetail === 'in_process';

  const isRejected =
    orderStatus === 'failed' ||
    orderStatus === 'cancelled' ||
    orderStatus === 'canceled' ||
    paymentStatus === 'failed' ||
    paymentStatus === 'cancelled' ||
    paymentStatus === 'canceled' ||
    paymentStatus === 'rejected';

  return {
    isPaid,
    isWaitingPix,
    isProcessing,
    isRejected,
    orderStatus,
    orderStatusDetail,
    paymentStatus,
    paymentStatusDetail,
    paymentId: payment?.id || null,
  };
}

async function findPaymentDocumentByOrderId(orderId) {
  const possibleFields = [
    'mercadoPagoOrderId',
    'mpOrderId',
    'orderId',
    'mercadoPago.orderId',
  ];

  for (const field of possibleFields) {
    const snapshot = await db
      .collection('payments')
      .where(field, '==', orderId)
      .limit(1)
      .get();

    if (!snapshot.empty) {
      return snapshot.docs[0];
    }
  }

  return null;
}

async function confirmAppointmentIfPossible(paymentData, order, normalized) {
  const appointmentId =
    paymentData.appointmentId ||
    paymentData.scheduleId ||
    paymentData.agendamentoId ||
    order?.external_reference ||
    null;

  if (!appointmentId) {
    console.warn('[MP ORDER SYNC] Pagamento aprovado, mas appointmentId não foi encontrado.');
    return null;
  }

  const appointmentRef = db.collection('appointments').doc(appointmentId);
  const appointmentSnapshot = await appointmentRef.get();

  if (!appointmentSnapshot.exists) {
    console.warn('[MP ORDER SYNC] Appointment não encontrado:', appointmentId);
    return null;
  }

  await appointmentRef.set(
    {
      status: 'confirmed',
      paymentStatus: 'approved',
      paymentProvider: 'mercado_pago',
      mercadoPagoOrderId: order.id,
      mercadoPagoPaymentId: normalized.paymentId,
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    }
  );

  return appointmentId;
}

async function syncMercadoPagoOrder(orderId) {
  if (!orderId) {
    throw new Error('orderId obrigatório');
  }

  console.log('[MP ORDER SYNC] Sincronizando order:', orderId);

  const order = await getMercadoPagoOrder(orderId);
  const normalized = normalizeOrderStatus(order);

  const paymentDoc = await findPaymentDocumentByOrderId(orderId);

  if (!paymentDoc) {
    console.warn('[MP ORDER SYNC] Documento de pagamento não encontrado para order:', orderId);

    return {
      foundLocalPayment: false,
      orderId,
      paid: normalized.isPaid,
      status: normalized.orderStatus,
      statusDetail: normalized.orderStatusDetail,
      paymentStatus: normalized.paymentStatus,
      paymentStatusDetail: normalized.paymentStatusDetail,
      mercadoPagoOrder: order,
    };
  }

  const paymentRef = paymentDoc.ref;
  const paymentData = paymentDoc.data();

  const updateData = {
    mercadoPagoOrderId: order.id,
    mercadoPagoPaymentId: normalized.paymentId,
    mercadoPagoStatus: normalized.orderStatus,
    mercadoPagoStatusDetail: normalized.orderStatusDetail,
    mercadoPagoPaymentStatus: normalized.paymentStatus,
    mercadoPagoPaymentStatusDetail: normalized.paymentStatusDetail,
    mercadoPagoLastSyncAt: admin.firestore.FieldValue.serverTimestamp(),
    mercadoPagoRawOrder: order,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  let appointmentId = null;
  let internalPaymentStatus = 'pending';

  if (normalized.isPaid) {
    internalPaymentStatus = 'approved';

    updateData.status = 'approved';
    updateData.approvedAt = admin.firestore.FieldValue.serverTimestamp();

    appointmentId = await confirmAppointmentIfPossible(paymentData, order, normalized);
  } else if (normalized.isRejected) {
    internalPaymentStatus = 'rejected';
    updateData.status = 'rejected';
  } else if (normalized.isWaitingPix) {
    internalPaymentStatus = 'waiting_transfer';
    updateData.status = 'waiting_transfer';
  } else if (normalized.isProcessing) {
    internalPaymentStatus = 'processing';
    updateData.status = 'processing';
  } else {
    updateData.status = 'pending';
  }

  await paymentRef.set(updateData, {
    merge: true,
  });

  return {
    foundLocalPayment: true,
    orderId,
    appointmentId,
    paid: normalized.isPaid,
    paymentStatus: internalPaymentStatus,
    mercadoPago: {
      orderStatus: normalized.orderStatus,
      orderStatusDetail: normalized.orderStatusDetail,
      paymentStatus: normalized.paymentStatus,
      paymentStatusDetail: normalized.paymentStatusDetail,
      paymentId: normalized.paymentId,
    },
  };
}

module.exports = {
  syncMercadoPagoOrder,
};