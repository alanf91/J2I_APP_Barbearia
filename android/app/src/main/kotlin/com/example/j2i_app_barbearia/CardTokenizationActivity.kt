package com.example.j2i_app_barbearia
import androidx.activity.ComponentActivity
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.ProgressBar
import android.widget.TextView
import com.mercadopago.sdk.android.coremethods.domain.interactor.coreMethods
import com.mercadopago.sdk.android.coremethods.domain.model.BuyerIdentification
import com.mercadopago.sdk.android.coremethods.domain.model.ResultError
import com.mercadopago.sdk.android.coremethods.domain.utils.Result
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.cardnumber.xml.CardNumberTextField
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.expirationdate.xml.ExpirationDateTextField
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.securitycode.xml.SecurityCodeTextField
import com.mercadopago.sdk.android.initializer.MercadoPagoSDK
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class CardTokenizationActivity : ComponentActivity() {

    companion object {
        const val EXTRA_CARD_TOKEN =
            "com.example.j2i_app_barbearia.CARD_TOKEN"
    }

    private val activityJob = SupervisorJob()

    private val activityScope =
        CoroutineScope(
            activityJob + Dispatchers.Main.immediate
        )

    private lateinit var cardHolderNameEditText: EditText
    private lateinit var cpfEditText: EditText

    private lateinit var cardNumberTextField: CardNumberTextField

    private lateinit var expirationDateTextField:
        ExpirationDateTextField

    private lateinit var securityCodeTextField:
        SecurityCodeTextField

    private lateinit var errorTextView: TextView

    private lateinit var progressBar: ProgressBar

    private lateinit var tokenizeButton: Button

    private lateinit var cancelButton: Button

    // ============================================================
    // CREATE
    // ============================================================

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Impede screenshots/gravação da tela contendo
        // informações do cartão.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )

        setContentView(
            R.layout.activity_card_tokenization
        )

        bindViews()

        setupActions()
    }

    // ============================================================
    // VIEWS
    // ============================================================

    private fun bindViews() {
        cardHolderNameEditText =
            findViewById(
                R.id.cardHolderNameEditText
            )

        cpfEditText =
            findViewById(
                R.id.cpfEditText
            )

        cardNumberTextField =
            findViewById(
                R.id.cardNumberTextField
            )

        expirationDateTextField =
            findViewById(
                R.id.expirationDateTextField
            )

        securityCodeTextField =
            findViewById(
                R.id.securityCodeTextField
            )

        errorTextView =
            findViewById(
                R.id.errorTextView
            )

        progressBar =
            findViewById(
                R.id.progressBar
            )

        tokenizeButton =
            findViewById(
                R.id.tokenizeButton
            )

        cancelButton =
            findViewById(
                R.id.cancelButton
            )
    }

    // ============================================================
    // AÇÕES
    // ============================================================

    private fun setupActions() {
        tokenizeButton.setOnClickListener {
            generateCardToken()
        }

        cancelButton.setOnClickListener {
            cancelTokenization()
        }
    }

    // ============================================================
    // GERAR TOKEN
    // ============================================================

    private fun generateCardToken() {
        hideError()

        val holderName =
            cardHolderNameEditText
                .text
                .toString()
                .trim()

        val cpf =
            cpfEditText
                .text
                .toString()
                .filter { it.isDigit() }

        if (holderName.isBlank()) {
            showError(
                "Informe o nome do titular."
            )

            return
        }

        if (cpf.length != 11) {
            showError(
                "Informe um CPF com 11 números."
            )

            return
        }

        setLoading(true)

        activityScope.launch {
            try {
                val coreMethods =
                    MercadoPagoSDK
                        .getInstance()
                        .coreMethods

                val tokenResult =
                    coreMethods.generateCardToken(
                        cardNumberState =
                            cardNumberTextField.state,

                        expirationDateState =
                            expirationDateTextField.state,

                        securityCodeState =
                            securityCodeTextField.state,

                        buyerIdentification =
                            BuyerIdentification(
                                name = holderName,
                                number = cpf,
                                type = "CPF",
                            ),
                    )

                when (tokenResult) {
                    is Result.Success -> {
                        val token =
                            tokenResult.data.token

                        if (token.isBlank()) {
                            showError(
                                "O Mercado Pago não retornou " +
                                    "um token válido."
                            )

                            return@launch
                        }

                        finishWithToken(
                            token = token
                        )
                    }

                    is Result.Error -> {
                        val message =
                            when (
                                val error =
                                    tokenResult.error
                            ) {
                                is ResultError.Request ->
                                    error.message

                                is ResultError.Validation ->
                                    error.message

                                else ->
                                    "Erro ao gerar token do cartão."
                            }

                        showError(
                            message.ifBlank {
                                "Não foi possível gerar " +
                                    "o token do cartão."
                            }
                        )
                    }
                }
            } catch (_: Exception) {
                showError(
                    "Falha ao comunicar com " +
                        "o Mercado Pago."
                )
            } finally {
                if (!isFinishing) {
                    setLoading(false)
                }
            }
        }
    }

    // ============================================================
    // DEVOLVER TOKEN
    // ============================================================

    private fun finishWithToken(
        token: String,
    ) {
        val resultIntent =
            Intent().apply {
                putExtra(
                    EXTRA_CARD_TOKEN,
                    token,
                )
            }

        setResult(
            RESULT_OK,
            resultIntent,
        )

        finish()
    }

    // ============================================================
    // CANCELAR
    // ============================================================

    private fun cancelTokenization() {
        setResult(
            RESULT_CANCELED
        )

        finish()
    }

    // ============================================================
    // LOADING
    // ============================================================

    private fun setLoading(
        loading: Boolean,
    ) {
        progressBar.visibility =
            if (loading) {
                View.VISIBLE
            } else {
                View.GONE
            }

        tokenizeButton.isEnabled =
            !loading

        cancelButton.isEnabled =
            !loading
    }

    // ============================================================
    // ERRO
    // ============================================================

    private fun showError(
        message: String,
    ) {
        errorTextView.text =
            message

        errorTextView.visibility =
            View.VISIBLE

        setLoading(false)
    }

    private fun hideError() {
        errorTextView.text = ""

        errorTextView.visibility =
            View.GONE
    }

    // ============================================================
    // DESTROY
    // ============================================================

    override fun onDestroy() {
        activityJob.cancel()

        super.onDestroy()
    }
}