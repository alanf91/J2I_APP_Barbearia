package com.example.j2i_app_barbearia

import android.app.Activity
import android.content.Intent
import com.mercadopago.sdk.android.coremethods.domain.interactor.coreMethods
import com.mercadopago.sdk.android.initializer.MercadoPagoSDK
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val MERCADO_PAGO_CHANNEL =
            "com.j2i.barbearia/mercado_pago"

        private const val REQUEST_CARD_TOKEN =
            3004
    }

    private var pendingCardTokenResult:
        MethodChannel.Result? = null

    // ============================================================
    // FLUTTER ENGINE
    // ============================================================

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine,
    ) {
        super.configureFlutterEngine(
            flutterEngine
        )

        MethodChannel(
            flutterEngine
                .dartExecutor
                .binaryMessenger,

            MERCADO_PAGO_CHANNEL,
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // =================================================
                // TESTE SDK
                // ETAPA 30.3
                // =================================================

                "isMercadoPagoReady" -> {
                    try {
                        MercadoPagoSDK
                            .getInstance()
                            .coreMethods

                        result.success(
                            mapOf(
                                "ready" to true,
                                "country" to "BRA",
                            )
                        )
                    } catch (_: Exception) {
                        result.error(
                            "MERCADO_PAGO_NOT_READY",
                            "Mercado Pago SDK " +
                                "não está inicializado.",
                            null,
                        )
                    }
                }

                // =================================================
                // TOKENIZAÇÃO
                // ETAPA 30.4
                // =================================================

                "createCardToken" -> {
                    openCardTokenization(
                        result
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ============================================================
    // ABRIR TELA NATIVA
    // ============================================================

    private fun openCardTokenization(
        result: MethodChannel.Result,
    ) {
        if (pendingCardTokenResult != null) {
            result.error(
                "CARD_TOKENIZATION_IN_PROGRESS",
                "Já existe uma tokenização " +
                    "de cartão em andamento.",
                null,
            )

            return
        }

        pendingCardTokenResult =
            result

        try {
            val intent =
                Intent(
                    this,
                    CardTokenizationActivity::class.java,
                )

            startActivityForResult(
                intent,
                REQUEST_CARD_TOKEN,
            )
        } catch (_: Exception) {
            pendingCardTokenResult =
                null

            result.error(
                "CARD_SCREEN_ERROR",
                "Não foi possível abrir " +
                    "a tela de cartão.",
                null,
            )
        }
    }

    // ============================================================
    // RESULTADO DA TELA NATIVA
    // ============================================================

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(
            requestCode,
            resultCode,
            data,
        )

        if (
            requestCode !=
            REQUEST_CARD_TOKEN
        ) {
            return
        }

        val result =
            pendingCardTokenResult
                ?: return

        pendingCardTokenResult =
            null

        when (resultCode) {

            Activity.RESULT_OK -> {
                val token =
                    data?.getStringExtra(
                        CardTokenizationActivity
                            .EXTRA_CARD_TOKEN
                    )

                if (token.isNullOrBlank()) {
                    result.error(
                        "EMPTY_CARD_TOKEN",
                        "O Mercado Pago não " +
                            "retornou o token.",
                        null,
                    )

                    return
                }

                result.success(
                    mapOf(
                        "status" to "success",
                        "token" to token,
                    )
                )
            }

            Activity.RESULT_CANCELED -> {
                result.success(
                    mapOf(
                        "status" to "cancelled",
                    )
                )
            }

            else -> {
                result.error(
                    "CARD_TOKENIZATION_ERROR",
                    "A tokenização do cartão " +
                        "não foi concluída.",
                    null,
                )
            }
        }
    }

    // ============================================================
    // DESTROY
    // ============================================================

    override fun onDestroy() {
        if (
            isFinishing &&
            pendingCardTokenResult != null
        ) {
            pendingCardTokenResult?.error(
                "ACTIVITY_DESTROYED",
                "A atividade Android foi encerrada.",
                null,
            )

            pendingCardTokenResult =
                null
        }

        super.onDestroy()
    }
}