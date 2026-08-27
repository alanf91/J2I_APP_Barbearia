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

        private const val REQUEST_CARD_TOKEN = 3004
    }

    private var pendingCardTokenResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine,
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MERCADO_PAGO_CHANNEL,
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "isMercadoPagoReady" -> {
                    try {
                        MercadoPagoSDK
                            .getInstance()
                            .coreMethods

                        result.success(
                            mapOf(
                                "ready" to true,
                                "country" to "BRA",
                            ),
                        )
                    } catch (_: Exception) {
                        result.error(
                            "MERCADO_PAGO_NOT_READY",
                            "Mercado Pago SDK não está inicializado.",
                            null,
                        )
                    }
                }

                "createCardToken" -> {
                    val amount =
                        call.argument<String>("amount")
                            ?.trim()
                            .orEmpty()

                    if (amount.isBlank()) {
                        result.error(
                            "INVALID_AMOUNT",
                            "Valor do pagamento inválido.",
                            null,
                        )

                        return@setMethodCallHandler
                    }

                    openCardTokenization(
                        amount = amount,
                        result = result,
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openCardTokenization(
        amount: String,
        result: MethodChannel.Result,
    ) {
        if (pendingCardTokenResult != null) {
            result.error(
                "CARD_TOKENIZATION_IN_PROGRESS",
                "Já existe um pagamento com cartão em andamento.",
                null,
            )

            return
        }

        pendingCardTokenResult = result

        try {
            val intent =
                Intent(
                    this,
                    CardTokenizationActivity::class.java,
                ).apply {
                    putExtra(
                        CardTokenizationActivity.EXTRA_AMOUNT,
                        amount,
                    )
                }

            startActivityForResult(
                intent,
                REQUEST_CARD_TOKEN,
            )
        } catch (_: Exception) {
            pendingCardTokenResult = null

            result.error(
                "CARD_SCREEN_ERROR",
                "Não foi possível abrir a tela de cartão.",
                null,
            )
        }
    }

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

        if (requestCode != REQUEST_CARD_TOKEN) {
            return
        }

        val result =
            pendingCardTokenResult
                ?: return

        pendingCardTokenResult = null

        when (resultCode) {

            Activity.RESULT_OK -> {
                val token =
                    data
                        ?.getStringExtra(
                            CardTokenizationActivity.EXTRA_CARD_TOKEN,
                        )
                        .orEmpty()

                val paymentMethodId =
                    data
                        ?.getStringExtra(
                            CardTokenizationActivity.EXTRA_PAYMENT_METHOD_ID,
                        )
                        .orEmpty()

                val paymentMethodType =
                    data
                        ?.getStringExtra(
                            CardTokenizationActivity.EXTRA_PAYMENT_METHOD_TYPE,
                        )
                        .orEmpty()

                val installments =
                    data?.getIntExtra(
                        CardTokenizationActivity.EXTRA_INSTALLMENTS,
                        0,
                    ) ?: 0

                if (
                    token.isBlank() ||
                    paymentMethodId.isBlank() ||
                    paymentMethodType.isBlank() ||
                    installments < 1
                ) {
                    result.error(
                        "INVALID_CARD_RESULT",
                        "O Mercado Pago não retornou os dados completos do cartão.",
                        null,
                    )

                    return
                }

                result.success(
                    mapOf(
                        "status" to "success",
                        "token" to token,
                        "paymentMethodId" to paymentMethodId,
                        "paymentMethodType" to paymentMethodType,
                        "installments" to installments,
                    ),
                )
            }

            Activity.RESULT_CANCELED -> {
                result.success(
                    mapOf(
                        "status" to "cancelled",
                    ),
                )
            }

            else -> {
                result.error(
                    "CARD_TOKENIZATION_ERROR",
                    "O pagamento com cartão não foi concluído.",
                    null,
                )
            }
        }
    }

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

            pendingCardTokenResult = null
        }

        super.onDestroy()
    }
}