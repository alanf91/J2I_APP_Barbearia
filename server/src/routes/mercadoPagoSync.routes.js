const express = require('express');
const { syncMercadoPagoOrder } = require('../services/mercadoPagoOrderSync.service');

const router = express.Router();

router.get('/orders/:orderId/sync', async (req, res) => {
  try {
    const { orderId } = req.params;

    const result = await syncMercadoPagoOrder(orderId);

    return res.status(200).json({
      ok: true,
      ...result,
    });
  } catch (error) {
    console.error('[MP ORDER SYNC ROUTE] Erro:', error);

    return res.status(500).json({
      ok: false,
      error: error.message || 'Erro ao sincronizar order',
    });
  }
});

router.post('/orders/:orderId/sync', async (req, res) => {
  try {
    const { orderId } = req.params;

    const result = await syncMercadoPagoOrder(orderId);

    return res.status(200).json({
      ok: true,
      ...result,
    });
  } catch (error) {
    console.error('[MP ORDER SYNC ROUTE] Erro:', error);

    return res.status(500).json({
      ok: false,
      error: error.message || 'Erro ao sincronizar order',
    });
  }
});

module.exports = router;