const crypto = require('node:crypto');

require('dotenv').config();

// ============================================================
// DADOS REAIS CAPTURADOS PELO NGROK
// ============================================================

const dataId =
  'ORDTST01M0XKAWS1F4GJMV6X7Q3MR3AY';

const requestId =
  '80266c1c-64cd-4384-9739-680086ad924b';

const ts =
  '1787699755';

const receivedV1 =
  'a7016d655dca7e3776248ce323f194db099c66a6d2db2181819f4534effd697d';

// ============================================================
// SECRET DO .ENV
// ============================================================

const secret =
  String(
    process.env.MERCADO_PAGO_WEBHOOK_SECRET || '',
  ).trim();

if (!secret) {
  console.error(
    'ERRO: MERCADO_PAGO_WEBHOOK_SECRET não encontrada no .env',
  );

  process.exit(1);
}

// ============================================================
// FUNÇÕES
// ============================================================

function hmac(manifest) {
  return crypto
    .createHmac(
      'sha256',
      secret,
    )
    .update(
      manifest,
      'utf8',
    )
    .digest(
      'hex',
    );
}

function fingerprint(value) {
  return crypto
    .createHash('sha256')
    .update(value)
    .digest('hex')
    .substring(0, 12);
}

function test(
  name,
  manifest,
) {
  const computed =
    hmac(manifest);

  const match =
    computed ===
    receivedV1;

  console.log(
    `\n${name}`,
  );

  console.log(
    'MATCH:',
    match,
  );

  console.log(
    'manifest:',
    JSON.stringify(manifest),
  );

  console.log(
    'calculado:',
    computed,
  );

  return match;
}

// ============================================================
// INFORMAÇÕES
// ============================================================

console.log(
  '============================================================',
);

console.log(
  'DIAGNÓSTICO MERCADO PAGO - WEBHOOK ORDER',
);

console.log(
  '============================================================',
);

console.log(
  '\nSecret carregada:',
);

console.log({
  configured:
    true,

  length:
    secret.length,

  fingerprint:
    fingerprint(secret),
});

console.log(
  '\nDados recebidos:',
);

console.log({
  dataId,
  requestId,
  ts,
  receivedV1,
});

// ============================================================
// TESTE 1
//
// FORMATO OFICIAL DO SDK ATUAL
// ============================================================

const officialManifest =
  `id:${dataId};`
  +
  `request-id:${requestId};`
  +
  `ts:${ts};`;

const officialMatch =
  test(
    '1 - SDK OFICIAL / CASE ORIGINAL / ;',
    officialManifest,
  );

// ============================================================
// TESTE 2
//
// LOWERCASE + ;
// ============================================================

const lowercaseSemicolon =
  `id:${dataId.toLowerCase()};`
  +
  `request-id:${requestId};`
  +
  `ts:${ts};`;

const lowercaseSemicolonMatch =
  test(
    '2 - LOWERCASE / ;',
    lowercaseSemicolon,
  );

// ============================================================
// TESTE 3
//
// FORMATO INFORMADO PELO SUPORTE
// LOWERCASE + ESPAÇOS
// ============================================================

const lowercaseSpaces =
  `id:${dataId.toLowerCase()} `
  +
  `request-id:${requestId} `
  +
  `ts:${ts}`;

const lowercaseSpacesMatch =
  test(
    '3 - LOWERCASE / ESPAÇOS',
    lowercaseSpaces,
  );

// ============================================================
// TESTE 4
//
// CASE ORIGINAL + ESPAÇOS
// ============================================================

const originalSpaces =
  `id:${dataId} `
  +
  `request-id:${requestId} `
  +
  `ts:${ts}`;

const originalSpacesMatch =
  test(
    '4 - CASE ORIGINAL / ESPAÇOS',
    originalSpaces,
  );

// ============================================================
// TESTE 5
//
// SEM ; FINAL
// ============================================================

const noFinalSemicolon =
  `id:${dataId};`
  +
  `request-id:${requestId};`
  +
  `ts:${ts}`;

const noFinalSemicolonMatch =
  test(
    '5 - CASE ORIGINAL / SEM ; FINAL',
    noFinalSemicolon,
  );

// ============================================================
// TESTE 6
//
// SEM REQUEST-ID
//
// O SDK omite campos que não existem.
// Vamos testar para eliminar essa hipótese.
// ============================================================

const withoutRequestId =
  `id:${dataId};`
  +
  `ts:${ts};`;

const withoutRequestIdMatch =
  test(
    '6 - SEM REQUEST-ID',
    withoutRequestId,
  );

// ============================================================
// TESTE 7
//
// SOMENTE REQUEST-ID + TS
// ============================================================

const withoutDataId =
  `request-id:${requestId};`
  +
  `ts:${ts};`;

const withoutDataIdMatch =
  test(
    '7 - SEM DATA.ID',
    withoutDataId,
  );

// ============================================================
// TESTE 8
//
// TESTAR POSSÍVEL DIVERGÊNCIA SEGUNDOS x MILISSEGUNDOS
//
// O header recebido possui:
// ts=1787699755
//
// São 10 dígitos.
//
// Exemplos atuais da documentação do MP mostram timestamps
// de 13 dígitos.
//
// Vamos verificar todas as combinações de milissegundos
// dentro do segundo recebido e +/- 5 segundos.
//
// Isso são poucas milhares de tentativas e termina
// praticamente instantaneamente.
// ============================================================

console.log(
  '\n============================================================',
);

console.log(
  '8 - BUSCA POR POSSÍVEL TIMESTAMP EM MILISSEGUNDOS',
);

console.log(
  '============================================================',
);

let millisecondsMatch =
  null;

const receivedSeconds =
  Number(ts);

for (
  let secondsOffset = -5;
  secondsOffset <= 5;
  secondsOffset += 1
) {
  const second =
    receivedSeconds +
    secondsOffset;

  for (
    let milliseconds = 0;
    milliseconds <= 999;
    milliseconds += 1
  ) {
    const possibleTimestamp =
      String(
        second * 1000 +
        milliseconds,
      );

    const manifest =
      `id:${dataId};`
      +
      `request-id:${requestId};`
      +
      `ts:${possibleTimestamp};`;

    const computed =
      hmac(manifest);

    if (
      computed ===
      receivedV1
    ) {
      millisecondsMatch = {
        timestamp:
          possibleTimestamp,

        secondsOffset:
          secondsOffset,

        milliseconds:
          milliseconds,

        manifest:
          manifest,

        computed:
          computed,
      };

      break;
    }
  }

  if (
    millisecondsMatch
  ) {
    break;
  }
}

if (
  millisecondsMatch
) {
  console.log(
    '\n🚨 ENCONTRADO MATCH COM TIMESTAMP EM MILISSEGUNDOS!',
  );

  console.log(
    millisecondsMatch,
  );
} else {
  console.log(
    '\nNenhum timestamp de 13 dígitos em +/- 5 segundos produziu o v1 recebido.',
  );
}

// ============================================================
// TESTE 9
//
// ALGUNS IDs DE TRACE OBSERVADOS NA REQUISIÇÃO BRUTA
//
// Apenas diagnóstico. Eles NÃO deveriam substituir
// x-request-id segundo a documentação.
// ============================================================

console.log(
  '\n============================================================',
);

console.log(
  '9 - TESTANDO POSSÍVEIS IDS DE TRACE',
);

console.log(
  '============================================================',
);

const alternativeRequestIds = [
  'f31cdd4046daa591',
];

let alternativeRequestMatch =
  null;

for (
  const candidateRequestId of
  alternativeRequestIds
) {
  const manifest =
    `id:${dataId};`
    +
    `request-id:${candidateRequestId};`
    +
    `ts:${ts};`;

  const computed =
    hmac(manifest);

  console.log(
    '\nRequest ID candidato:',
    candidateRequestId,
  );

  console.log(
    'MATCH:',
    computed === receivedV1,
  );

  if (
    computed ===
    receivedV1
  ) {
    alternativeRequestMatch = {
      candidateRequestId,
      manifest,
      computed,
    };
  }
}

// ============================================================
// RESULTADO FINAL
// ============================================================

console.log(
  '\n============================================================',
);

console.log(
  'RESULTADO FINAL',
);

console.log(
  '============================================================',
);

console.log({
  officialMatch,
  lowercaseSemicolonMatch,
  lowercaseSpacesMatch,
  originalSpacesMatch,
  noFinalSemicolonMatch,
  withoutRequestIdMatch,
  withoutDataIdMatch,

  millisecondsMatch:
    millisecondsMatch !==
    null,

  alternativeRequestMatch:
    alternativeRequestMatch !==
    null,
});

if (
  officialMatch
) {
  console.log(
    '\n✅ A ASSINATURA BATE COM O ALGORITMO OFICIAL.',
  );

  console.log(
    'Se o SDK ainda rejeita, o problema está entre ngrok e Express/SDK.',
  );
} else if (
  millisecondsMatch
) {
  console.log(
    '\n🚨 POSSÍVEL ERRO NO TIMESTAMP GERADO PELO MERCADO PAGO.',
  );
} else if (
  alternativeRequestMatch
) {
  console.log(
    '\n🚨 A ASSINATURA FOI GERADA COM OUTRO REQUEST-ID.',
  );
} else if (
  lowercaseSpacesMatch
) {
  console.log(
    '\n✅ O formato informado pelo suporte produziu MATCH.',
  );
} else if (
  lowercaseSemicolonMatch
) {
  console.log(
    '\n✅ MATCH encontrado usando data.id lowercase.',
  );
} else {
  console.log(
    '\n❌ NENHUMA VARIANTE TESTADA PRODUZIU O v1 RECEBIDO.',
  );

  console.log(
    '\nSe o fingerprint da Secret continuar sendo 4cf3dcadd848,',
  );

  console.log(
    'isso indica fortemente que o Mercado Pago assinou esta',
  );

  console.log(
    'requisição usando outra Secret ou outros dados internos.',
  );
}

console.log(
  '\n============================================================',
);