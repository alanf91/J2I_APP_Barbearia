const express = require('express');
const { syncMercadoPagoOrder } = require('../services/mercadoPagoOrderSync.service');

const router = express.Router();

router.post('/mercado-pago', async (req, res) => {
  try {
    console.log('[MP WEBHOOK] Chegou webhook Mercado Pago');
    console.log('[MP WEBHOOK] Query:', req.query);
    console.log('[MP WEBHOOK] Body:', req.body);
    console.log('[MP WEBHOOK] Headers importantes:', {
      xSignature: req.headers['x-signature'],
      xRequestId: req.headers['x-request-id'],
    });

    const orderId =
      req.query['data.id'] ||
      req.body?.data?.id ||
      req.body?.resource ||
      null;

    if (!orderId) {
      console.warn('[MP WEBHOOK] Webhook recebido sem orderId');

      return res.status(200).json({
        ok: true,
        ignored: true,
        reason: 'Webhook sem orderId',
      });
    }

    const result = await syncMercadoPagoOrder(orderId);

    return res.status(200).json({
      ok: true,
      source: 'webhook',
      ...result,
    });
  } catch (error) {
    console.error('[MP WEBHOOK] Erro ao processar webhook:', error);

    return res.status(200).json({
      ok: false,
      error: error.message || 'Erro ao processar webhook',
    });
  }
});

module.exports = router;