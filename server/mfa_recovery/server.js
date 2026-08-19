const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const crypto = require('node:crypto');

const {
  initializeApp,
  applicationDefault,
} = require('firebase-admin/app');

const {
  getAuth,
} = require('firebase-admin/auth');

const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require('firebase-admin/firestore');

// ============================================================
// FIREBASE ADMIN
// ============================================================

initializeApp({
  credential: applicationDefault(),
});

const auth = getAuth();
const db = getFirestore();

// ============================================================
// EXPRESS
// ============================================================

const app = express();

const PORT = Number(
  process.env.PORT || 8080,
);

const RECOVERY_EXPIRATION_MINUTES = 15;

const RECOVERY_EXPIRATION_MS =
  RECOVERY_EXPIRATION_MINUTES *
  60 *
  1000;

// Quando futuramente usarmos ngrok/proxy,
// isso permite ao Express interpretar corretamente
// o endereço do cliente.
app.set(
  'trust proxy',
  1,
);

app.use(
  helmet(),
);

app.use(
  express.json({
    limit: '20kb',
  }),
);

// ============================================================
// RATE LIMIT
// ============================================================

const recoveryLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(
  '/v1/mfa-recovery',
  recoveryLimiter,
);

// ============================================================
// UTILITÁRIOS
// ============================================================

function normalizeEmail(value) {
  return String(value || '')
    .trim()
    .toLowerCase();
}

function isValidEmail(email) {
  return (
    email.length >= 5 &&
    email.length <= 254 &&
    email.includes('@') &&
    email.includes('.')
  );
}

function createRecoveryToken() {
  return crypto
    .randomBytes(32)
    .toString('base64url');
}

function hashToken(token) {
  return crypto
    .createHash('sha256')
    .update(token)
    .digest('hex');
}

function safeCompareHashes(
  first,
  second,
) {
  try {
    const a = Buffer.from(
      first,
      'hex',
    );

    const b = Buffer.from(
      second,
      'hex',
    );

    if (a.length !== b.length) {
      return false;
    }

    return crypto.timingSafeEqual(
      a,
      b,
    );
  } catch (_) {
    return false;
  }
}

function parseFirebaseTime(value) {
  if (!value) {
    return 0;
  }

  const milliseconds =
    Date.parse(value);

  if (!Number.isFinite(milliseconds)) {
    return 0;
  }

  return milliseconds;
}

// ============================================================
// HEALTH CHECK
// ============================================================

app.get(
  '/health',
  (request, response) => {
    response.json({
      ok: true,
      service: 'j2i-mfa-recovery',
    });
  },
);

// ============================================================
// INICIAR RECUPERAÇÃO
// ============================================================
//
// IMPORTANTE:
//
// A resposta externa é propositalmente parecida
// mesmo quando o e-mail não existe.
//
// Isso reduz enumeração de contas.
// ============================================================

app.post(
  '/v1/mfa-recovery/start',
  async (request, response) => {
    const email =
      normalizeEmail(
        request.body?.email,
      );

    if (!isValidEmail(email)) {
      return response
        .status(400)
        .json({
          ok: false,
          message:
            'Informe um e-mail válido.',
        });
    }

    const requestId =
      crypto.randomUUID();

    const recoveryToken =
      createRecoveryToken();

    const tokenHash =
      hashToken(
        recoveryToken,
      );

    const expiresAtMs =
      Date.now() +
      RECOVERY_EXPIRATION_MS;

    try {
      const user =
        await auth.getUserByEmail(
          email,
        );

      // Para recuperação pelo e-mail,
      // somente contas que já possuem
      // e-mail verificado são elegíveis.
      if (user.emailVerified) {
        const baselineTokensValidAfterMs =
          parseFirebaseTime(
            user.tokensValidAfterTime,
          );

        await db
          .collection(
            'mfa_recovery_requests',
          )
          .doc(requestId)
          .set({
            uid:
              user.uid,

            email:
              email,

            tokenHash:
              tokenHash,

            baselineTokensValidAfterMs:
              baselineTokensValidAfterMs,

            status:
              'waiting_password_reset',

            createdAt:
              FieldValue
                .serverTimestamp(),

            expiresAt:
              Timestamp.fromMillis(
                expiresAtMs,
              ),
          });
      }
    } catch (error) {
      // Não revelamos para o aplicativo
      // se determinado e-mail existe.

      if (
        error?.code !==
        'auth/user-not-found'
      ) {
        console.error(
          'START RECOVERY ERROR:',
          error,
        );
      }
    }

    return response.json({
      ok: true,

      requestId:
        requestId,

      recoveryToken:
        recoveryToken,

      expiresInMinutes:
        RECOVERY_EXPIRATION_MINUTES,

      message:
        'Se a conta for válida, siga as instruções enviadas ao e-mail.',
    });
  },
);

// ============================================================
// CONCLUIR RECUPERAÇÃO
// ============================================================
//
// O aplicativo chama esta rota SOMENTE depois
// que o usuário redefiniu a senha pelo e-mail.
//
// Verificaremos se houve revogação/alteração dos
// tokens DEPOIS da criação da solicitação.
//
// Depois:
//
// 1. removemos todos os MFA antigos;
// 2. removemos o telefone principal antigo;
// 3. marcamos que a conta precisa cadastrar
//    um novo telefone;
// 4. revogamos novamente todas as sessões.
// ============================================================

app.post(
  '/v1/mfa-recovery/complete',
  async (request, response) => {
    const requestId =
      String(
        request.body?.requestId ||
          '',
      ).trim();

    const recoveryToken =
      String(
        request.body
          ?.recoveryToken ||
          '',
      ).trim();

    if (
      requestId.length < 10 ||
      recoveryToken.length < 20
    ) {
      return response
        .status(400)
        .json({
          ok: false,
          code:
            'INVALID_RECOVERY',
          message:
            'Não foi possível validar a recuperação.',
        });
    }

    const reference = db
      .collection(
        'mfa_recovery_requests',
      )
      .doc(requestId);

    const snapshot =
      await reference.get();

    if (!snapshot.exists) {
      return response
        .status(400)
        .json({
          ok: false,
          code:
            'INVALID_RECOVERY',
          message:
            'Não foi possível validar a recuperação.',
        });
    }

    const data =
      snapshot.data();

    if (!data) {
      return response
        .status(400)
        .json({
          ok: false,
          code:
            'INVALID_RECOVERY',
          message:
            'Não foi possível validar a recuperação.',
        });
    }

    // ==========================================================
    // STATUS
    // ==========================================================

    if (
      data.status !==
      'waiting_password_reset'
    ) {
      return response
        .status(400)
        .json({
          ok: false,
          code:
            'RECOVERY_ALREADY_USED',
          message:
            'Esta recuperação já foi utilizada ou não está mais disponível.',
        });
    }

    // ==========================================================
    // EXPIRAÇÃO
    // ==========================================================

    const expiresAtMs =
      data.expiresAt
        ?.toMillis?.() || 0;

    if (
      expiresAtMs <=
      Date.now()
    ) {
      await reference.update({
        status:
          'expired',

        expiredAt:
          FieldValue
            .serverTimestamp(),
      });

      return response
        .status(400)
        .json({
          ok: false,
          code:
            'RECOVERY_EXPIRED',
          message:
            'A solicitação expirou. Inicie uma nova recuperação.',
        });
    }

    // ==========================================================
    // TOKEN
    // ==========================================================

    const receivedHash =
      hashToken(
        recoveryToken,
      );

    if (
      !safeCompareHashes(
        receivedHash,
        String(
          data.tokenHash || '',
        ),
      )
    ) {
      return response
        .status(400)
        .json({
          ok: false,
          code:
            'INVALID_RECOVERY',
          message:
            'Não foi possível validar a recuperação.',
        });
    }

    // ==========================================================
    // USUÁRIO
    // ==========================================================

    const uid =
      String(
        data.uid || '',
      );

    if (!uid) {
      return response
        .status(400)
        .json({
          ok: false,
          code:
            'INVALID_RECOVERY',
          message:
            'Não foi possível validar a recuperação.',
        });
    }

    const user =
      await auth.getUser(
        uid,
      );

    // ==========================================================
    // DETECTAR REDEFINIÇÃO DA SENHA
    // ==========================================================

    const currentTokensValidAfterMs =
      parseFirebaseTime(
        user.tokensValidAfterTime,
      );

    const baselineTokensValidAfterMs =
      Number(
        data
          .baselineTokensValidAfterMs ||
          0,
      );

    if (
      currentTokensValidAfterMs <=
      baselineTokensValidAfterMs
    ) {
      return response
        .status(409)
        .json({
          ok: false,
          code:
            'PASSWORD_RESET_NOT_DETECTED',
          message:
            'Ainda não detectamos a redefinição da senha. '
            + 'Abra o e-mail, defina uma nova senha e tente novamente.',
        });
    }

    // ==========================================================
    // REGISTRAR QUANTOS FATORES EXISTIAM
    // ==========================================================

    const oldFactors =
      user.multiFactor
        ?.enrolledFactors ||
      [];

    // ==========================================================
    // REMOVER MFA E TELEFONE ANTIGOS
    // ==========================================================

    await auth.updateUser(
      uid,
      {
        phoneNumber:
          null,

        multiFactor: {
          enrolledFactors:
            null,
        },
      },
    );

    // O Admin SDK permite atualizar a lista de fatores MFA.
    // Definir enrolledFactors como null remove os fatores.

    // ==========================================================
    // MARCAR CONTA PARA NOVO CADASTRO DE TELEFONE
    // ==========================================================

    await db
      .collection('users')
      .doc(uid)
      .set(
        {
          phone:
            '',

          mfaRecoveryRequired:
            true,

          mfaRecoveryAt:
            FieldValue
              .serverTimestamp(),
        },
        {
          merge: true,
        },
      );

    // ==========================================================
    // REVOGAR TODAS AS SESSÕES
    // ==========================================================

    await auth
      .revokeRefreshTokens(
        uid,
      );

    // ==========================================================
    // FINALIZAR SOLICITAÇÃO
    // ==========================================================

    await reference.update({
      status:
        'completed',

      completedAt:
        FieldValue
          .serverTimestamp(),

      factorsRemoved:
        oldFactors.length,
    });

    return response.json({
      ok: true,

      code:
        'RECOVERY_COMPLETED',

      message:
        'Recuperação confirmada. '
        + 'Entre novamente e cadastre um novo telefone de segurança.',
    });
  },
);

// ============================================================
// FINALIZAR CADASTRO DO NOVO TELEFONE APÓS RECUPERAÇÃO
// ============================================================
//
// Fluxo:
//
// 1. Flutter faz login novamente.
// 2. Usuário cadastra um NOVO fator MFA.
// 3. Flutter envia seu Firebase ID Token.
// 4. Backend valida o ID Token.
// 5. Backend confirma que o telefone informado
//    realmente existe entre os fatores MFA do usuário.
// 6. Atualiza Firestore.
// 7. Remove mfaRecoveryRequired.
// 8. Revoga sessões novamente.
// ============================================================

app.post(
  '/v1/mfa-recovery/finalize-phone',
  async (request, response) => {
    // ==========================================================
    // AUTORIZAÇÃO
    // ==========================================================

    const authorization =
      String(
        request.headers.authorization ||
          '',
      ).trim();

    if (
      !authorization.startsWith(
        'Bearer ',
      )
    ) {
      return response
        .status(401)
        .json({
          ok: false,
          code: 'UNAUTHORIZED',
          message:
            'Autenticação necessária.',
        });
    }

    const idToken =
      authorization
        .substring(7)
        .trim();

    if (!idToken) {
      return response
        .status(401)
        .json({
          ok: false,
          code: 'UNAUTHORIZED',
          message:
            'Autenticação necessária.',
        });
    }

    // ==========================================================
    // NORMALIZAR TELEFONE BRASILEIRO
    // ==========================================================

    function normalizeBrazilPhone(
      value,
    ) {
      let digits =
        String(value || '')
          .replace(/\D/g, '');

      if (
        digits.startsWith('55') &&
        (
          digits.length === 12 ||
          digits.length === 13
        )
      ) {
        digits =
          digits.substring(2);
      }

      if (
        digits.length !== 10 &&
        digits.length !== 11
      ) {
        return null;
      }

      return digits;
    }

    const requestedPhone =
      normalizeBrazilPhone(
        request.body?.phoneNumber,
      );

    if (!requestedPhone) {
      return response
        .status(400)
        .json({
          ok: false,
          code:
            'INVALID_PHONE',
          message:
            'O telefone informado é inválido.',
        });
    }

    try {
      // ========================================================
      // VALIDAR TOKEN FIREBASE
      // ========================================================

      const decodedToken =
        await auth.verifyIdToken(
          idToken,
          true,
        );

      const uid =
        decodedToken.uid;

      // ========================================================
      // USUÁRIO NO FIREBASE AUTH
      // ========================================================

      const user =
        await auth.getUser(
          uid,
        );

      const factors =
        user.multiFactor
          ?.enrolledFactors ||
        [];

      // ========================================================
      // CONFIRMAR QUE O TELEFONE ESTÁ REALMENTE NO MFA
      // ========================================================

      const matchingFactor =
        factors.find(
          (factor) => {
            if (
              factor.factorId !==
              'phone'
            ) {
              return false;
            }

            const factorPhone =
              normalizeBrazilPhone(
                factor.phoneNumber,
              );

            return (
              factorPhone ===
              requestedPhone
            );
          },
        );

      if (!matchingFactor) {
        return response
          .status(409)
          .json({
            ok: false,
            code:
              'MFA_PHONE_NOT_ENROLLED',
            message:
              'O novo telefone ainda não foi '
              + 'confirmado como fator de segurança.',
          });
      }

      // ========================================================
      // CONFIRMAR QUE ESTA CONTA ESTÁ EM RECUPERAÇÃO
      // ========================================================

      const userReference =
        db
          .collection('users')
          .doc(uid);

      const userSnapshot =
        await userReference.get();

      if (!userSnapshot.exists) {
        return response
          .status(404)
          .json({
            ok: false,
            code:
              'USER_PROFILE_NOT_FOUND',
            message:
              'Perfil do usuário não encontrado.',
          });
      }

      const userData =
        userSnapshot.data();

      if (
        userData
          ?.mfaRecoveryRequired !==
        true
      ) {
        return response
          .status(409)
          .json({
            ok: false,
            code:
              'RECOVERY_NOT_REQUIRED',
            message:
              'Esta conta não está aguardando '
              + 'recuperação de MFA.',
          });
      }

      // ========================================================
      // FIRESTORE
      // ========================================================

      await userReference.set(
        {
          phone:
            requestedPhone,

          mfaRecoveryRequired:
            false,

          mfaRecoveryCompletedAt:
            FieldValue
              .serverTimestamp(),

          updatedAt:
            FieldValue
              .serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      // ========================================================
      // REVOGAR SESSÕES
      //
      // O usuário será obrigado a entrar novamente e provar
      // o NOVO segundo fator.
      // ========================================================

      await auth.revokeRefreshTokens(
        uid,
      );

      return response.json({
        ok: true,

        code:
          'RECOVERY_PHONE_COMPLETED',

        message:
          'Novo telefone de segurança '
          + 'cadastrado com sucesso.',
      });
    } catch (error) {
      console.error(
        'FINALIZE RECOVERY PHONE ERROR:',
        error,
      );

      if (
        error?.code ===
        'auth/id-token-revoked'
      ) {
        return response
          .status(401)
          .json({
            ok: false,
            code:
              'TOKEN_REVOKED',
            message:
              'Sua sessão expirou. '
              + 'Entre novamente.',
          });
      }

      return response
        .status(500)
        .json({
          ok: false,
          code:
            'FINALIZE_PHONE_ERROR',
          message:
            'Não foi possível finalizar '
            + 'o novo telefone.',
        });
    }
  },
);

// ============================================================
// TRATAMENTO DE ERRO
// ============================================================

app.use(
  (
    error,
    request,
    response,
    next,
  ) => {
    console.error(
      'SERVER ERROR:',
      error,
    );

    if (
      response.headersSent
    ) {
      return next(
        error,
      );
    }

    return response
      .status(500)
      .json({
        ok: false,
        code:
          'INTERNAL_ERROR',
        message:
          'Erro interno do servidor.',
      });
  },
);

// ============================================================
// START
// ============================================================

app.listen(
  PORT,
  () => {
    console.log(
      '============================================',
    );

    console.log(
      'J2I MFA Recovery Backend',
    );

    console.log(
      `Servidor: http://localhost:${PORT}`,
    );

    console.log(
      `Health:   http://localhost:${PORT}/health`,
    );

    console.log(
      '============================================',
    );
  },
);