require('dotenv').config();

const crypto = require('node:crypto');

// ============================================================
// CONFIGURAÇÕES
// ============================================================

const ACCESS_TOKEN =
  process.env.MERCADO_PAGO_ACCESS_TOKEN;

const MERCADO_PAGO_URL =
  'https://api.mercadopago.com/v1/orders';

// ============================================================
// VALIDAR CREDENCIAL
// ============================================================

if (!ACCESS_TOKEN) {
  console.error(
    'ERRO: MERCADO_PAGO_ACCESS_TOKEN não encontrado no .env.',
  );

  process.exit(1);
}

// ============================================================
// CRIAR PIX DE TESTE
// ============================================================

async function createTestPix() {
  const idempotencyKey =
    crypto.randomUUID();

  const body = {
    type: 'online',

    external_reference:
      `j2i_test_${Date.now()}`,

    processing_mode:
      'automatic',

    total_amount:
      '50.00',

    payer: {
      email:
        'test_user_br@testuser.com',

      // APRO é um valor de teste oficial
      // utilizado pelo Mercado Pago.
      first_name:
        'APRO',
    },

    transactions: {
      payments: [
        {
          amount:
            '50.00',

          payment_method: {
            id:
              'pix',

            type:
              'bank_transfer',
          },
        },
      ],
    },
  };

  console.log(
    '==========================================',
  );

  console.log(
    'J2I - TESTE PIX MERCADO PAGO',
  );

  console.log(
    '==========================================',
  );

  console.log(
    'Criando order Pix de teste...',
  );

  console.log(
    `Idempotency Key: ${idempotencyKey}`,
  );

  try {
    const response =
      await fetch(
        MERCADO_PAGO_URL,
        {
          method:
            'POST',

          headers: {
            'Content-Type':
              'application/json',

            Accept:
              'application/json',

            Authorization:
              `Bearer ${ACCESS_TOKEN}`,

            'X-Idempotency-Key':
              idempotencyKey,
          },

          body:
            JSON.stringify(
              body,
            ),
        },
      );

    const raw =
      await response.text();

    let data;

    try {
      data =
        JSON.parse(raw);
    } catch (_) {
      data = raw;
    }

    console.log();
    console.log(
      `HTTP STATUS: ${response.status}`,
    );

    // ==========================================================
    // ERRO
    // ==========================================================

    if (!response.ok) {
      console.error();
      console.error(
        'ERRO AO CRIAR PIX:',
      );

      console.dir(
        data,
        {
          depth: null,
        },
      );

      process.exitCode =
        1;

      return;
    }

    // ==========================================================
    // ORDER
    // ==========================================================

    console.log();
    console.log(
      'ORDER CRIADA COM SUCESSO!',
    );

    console.log();

    console.log(
      'Order ID:',
      data.id,
    );

    console.log(
      'Status:',
      data.status,
    );

    console.log(
      'Status detail:',
      data.status_detail,
    );

    console.log(
      'External reference:',
      data.external_reference,
    );

    // ==========================================================
    // PAGAMENTO
    // ==========================================================

    const payment =
      data.transactions
        ?.payments?.[0];

    if (!payment) {
      console.log();
      console.log(
        'Pagamento não encontrado na resposta.',
      );

      return;
    }

    console.log();
    console.log(
      'Payment ID:',
      payment.id,
    );

    console.log(
      'Payment status:',
      payment.status,
    );

    console.log(
      'Payment status detail:',
      payment.status_detail,
    );

    // ==========================================================
    // PIX
    // ==========================================================

    const paymentMethod =
      payment.payment_method;

    if (!paymentMethod) {
      console.log(
        'Dados Pix não encontrados.',
      );

      return;
    }

    console.log();
    console.log(
      'QR Code recebido:',
      Boolean(
        paymentMethod.qr_code,
      ),
    );

    console.log(
      'QR Code Base64 recebido:',
      Boolean(
        paymentMethod.qr_code_base64,
      ),
    );

    console.log(
      'Ticket URL recebido:',
      Boolean(
        paymentMethod.ticket_url,
      ),
    );

    console.log();
    console.log(
      '==========================================',
    );

    console.log(
      'TESTE FINALIZADO',
    );

    console.log(
      '==========================================',
    );
  } catch (error) {
    console.error();
    console.error(
      'ERRO DE CONEXÃO:',
      error,
    );

    process.exitCode =
      1;
  }
}

createTestPix();