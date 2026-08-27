package com.example.j2i_app_barbearia

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.ProgressBar
import android.widget.Spinner
import android.widget.TextView
import androidx.activity.ComponentActivity
import com.mercadopago.sdk.android.coremethods.domain.interactor.coreMethods
import com.mercadopago.sdk.android.coremethods.domain.model.BuyerIdentification
import com.mercadopago.sdk.android.coremethods.domain.model.Installment
import com.mercadopago.sdk.android.coremethods.domain.model.PaymentMethod
import com.mercadopago.sdk.android.coremethods.domain.model.ResultError
import com.mercadopago.sdk.android.coremethods.domain.utils.Result
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.cardnumber.CardNumberTextFieldEvent
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.cardnumber.xml.CardNumberTextField
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.expirationdate.xml.ExpirationDateTextField
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.securitycode.xml.SecurityCodeTextField
import com.mercadopago.sdk.android.initializer.MercadoPagoSDK
import java.math.BigDecimal
import java.text.NumberFormat
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class CardTokenizationActivity : ComponentActivity() {

    companion object {
        const val EXTRA_AMOUNT =
            "com.example.j2i_app_barbearia.AMOUNT"

        const val EXTRA_CARD_TOKEN =
            "com.example.j2i_app_barbearia.CARD_TOKEN"

        const val EXTRA_PAYMENT_METHOD_ID =
            "com.example.j2i_app_barbearia.PAYMENT_METHOD_ID"

        const val EXTRA_PAYMENT_METHOD_TYPE =
            "com.example.j2i_app_barbearia.PAYMENT_METHOD_TYPE"

        const val EXTRA_INSTALLMENTS =
            "com.example.j2i_app_barbearia.INSTALLMENTS"
    }

    private data class CardMethodOption(
        val id: String,
        val type: String,
        val label: String,
        val securityCodeLength: Int,
    )

    private data class InstallmentOption(
        val installments: Int,
        val label: String,
    )

    private val activityJob =
        SupervisorJob()

    private val activityScope =
        CoroutineScope(
            activityJob + Dispatchers.Main.immediate,
        )

    private lateinit var amount: BigDecimal

    private lateinit var amountTextView: TextView

    private lateinit var cardHolderNameEditText: EditText

    private lateinit var cpfEditText: EditText

    private lateinit var cardNumberTextField: CardNumberTextField

    private lateinit var expirationDateTextField: ExpirationDateTextField

    private lateinit var securityCodeTextField: SecurityCodeTextField

    private lateinit var paymentMethodLabelTextView: TextView

    private lateinit var paymentMethodSpinner: Spinner

    private lateinit var installmentLabelTextView: TextView

    private lateinit var installmentSpinner: Spinner

    private lateinit var errorTextView: TextView

    private lateinit var progressBar: ProgressBar

    private lateinit var tokenizeButton: Button

    private lateinit var cancelButton: Button

    private var cardMethodOptions:
        List<CardMethodOption> =
        emptyList()

    private var installmentResults:
        List<Installment> =
        emptyList()

    private var installmentOptions:
        List<InstallmentOption> =
        emptyList()

    private var selectedCardMethod:
        CardMethodOption? =
        null

    private var selectedInstallments:
        Int =
        0

    private var currentBin:
        String? =
        null

    private var lookupVersion:
        Int =
        0

    private var busy:
        Boolean =
        false

    override fun onCreate(
        savedInstanceState: Bundle?,
    ) {
        super.onCreate(savedInstanceState)

        // Impede captura/gravação de tela com dados PCI.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )

        setContentView(
            R.layout.activity_card_tokenization,
        )

        bindViews()

        val receivedAmount =
            intent
                .getStringExtra(EXTRA_AMOUNT)
                ?.trim()
                ?.toBigDecimalOrNull()

        if (
            receivedAmount == null ||
            receivedAmount <= BigDecimal.ZERO
        ) {
            showError(
                "Valor do pagamento inválido.",
            )

            tokenizeButton.isEnabled =
                false

            return
        }

        amount =
            receivedAmount

        amountTextView.text =
            formatCurrency(amount)

        tokenizeButton.text =
            "PAGAR ${formatCurrency(amount)}"

        setupSpinners()

        setupCardNumberEvents()

        setupActions()

        clearPaymentConfiguration()
    }

    private fun bindViews() {
        amountTextView =
            findViewById(
                R.id.amountTextView,
            )

        cardHolderNameEditText =
            findViewById(
                R.id.cardHolderNameEditText,
            )

        cpfEditText =
            findViewById(
                R.id.cpfEditText,
            )

        cardNumberTextField =
            findViewById(
                R.id.cardNumberTextField,
            )

        expirationDateTextField =
            findViewById(
                R.id.expirationDateTextField,
            )

        securityCodeTextField =
            findViewById(
                R.id.securityCodeTextField,
            )

        paymentMethodLabelTextView =
            findViewById(
                R.id.paymentMethodLabelTextView,
            )

        paymentMethodSpinner =
            findViewById(
                R.id.paymentMethodSpinner,
            )

        installmentLabelTextView =
            findViewById(
                R.id.installmentLabelTextView,
            )

        installmentSpinner =
            findViewById(
                R.id.installmentSpinner,
            )

        errorTextView =
            findViewById(
                R.id.errorTextView,
            )

        progressBar =
            findViewById(
                R.id.progressBar,
            )

        tokenizeButton =
            findViewById(
                R.id.tokenizeButton,
            )

        cancelButton =
            findViewById(
                R.id.cancelButton,
            )
    }

    private fun setupCardNumberEvents() {
        cardNumberTextField.onEvent = { event ->

            when (event) {
                is CardNumberTextFieldEvent.OnBinChanged -> {
                    val bin =
                        event.cardBin
                            .orEmpty()
                            .filter {
                                it.isDigit()
                            }

                    // A API atual usa os primeiros 8 dígitos.
                    if (bin.length >= 8) {
                        resolveCardConfiguration(
                            bin.take(8),
                        )
                    } else {
                        resetCardConfiguration()
                    }
                }

                else -> Unit
            }
        }
    }

    private fun setupSpinners() {
        paymentMethodSpinner.onItemSelectedListener =
            object : AdapterView.OnItemSelectedListener {

                override fun onItemSelected(
                    parent: AdapterView<*>?,
                    view: View?,
                    position: Int,
                    id: Long,
                ) {
                    if (
                        position !in
                        cardMethodOptions.indices
                    ) {
                        return
                    }

                    selectedCardMethod =
                        cardMethodOptions[position]

                    configureSelectedCardMethod()
                }

                override fun onNothingSelected(
                    parent: AdapterView<*>?,
                ) {
                    selectedCardMethod =
                        null

                    selectedInstallments =
                        0

                    updatePayButton()
                }
            }

        installmentSpinner.onItemSelectedListener =
            object : AdapterView.OnItemSelectedListener {

                override fun onItemSelected(
                    parent: AdapterView<*>?,
                    view: View?,
                    position: Int,
                    id: Long,
                ) {
                    if (
                        position !in
                        installmentOptions.indices
                    ) {
                        selectedInstallments =
                            0

                        updatePayButton()

                        return
                    }

                    selectedInstallments =
                        installmentOptions[position]
                            .installments

                    updatePayButton()
                }

                override fun onNothingSelected(
                    parent: AdapterView<*>?,
                ) {
                    selectedInstallments =
                        0

                    updatePayButton()
                }
            }
    }

    private fun resolveCardConfiguration(
        bin: String,
    ) {
        if (
            currentBin == bin &&
            cardMethodOptions.isNotEmpty()
        ) {
            return
        }

        currentBin =
            bin

        val version =
            ++lookupVersion

        hideError()

        clearPaymentConfiguration()

        setBusy(true)

        activityScope.launch {
            try {
                val coreMethods =
                    MercadoPagoSDK
                        .getInstance()
                        .coreMethods

                val paymentMethodsResult =
                    coreMethods.getPaymentMethods(
                        bin = bin,
                    )

                if (version != lookupVersion) {
                    return@launch
                }

                val paymentMethods =
                    when (paymentMethodsResult) {
                        is Result.Success ->
                            paymentMethodsResult.data

                        is Result.Error -> {
                            showError(
                                resultErrorMessage(
                                    paymentMethodsResult.error,
                                ),
                            )

                            return@launch
                        }
                    }

                cardMethodOptions =
                    paymentMethods
                        .mapNotNull { method ->
                            method.toCardMethodOption()
                        }
                        .distinctBy {
                            "${it.id}:${it.type}"
                        }

                if (cardMethodOptions.isEmpty()) {
                    showError(
                        "Este cartão ou modalidade não está disponível.",
                    )

                    return@launch
                }

                val installmentsResult =
                    coreMethods.getInstallments(
                        bin = bin,
                        amount = amount,
                    )

                if (version != lookupVersion) {
                    return@launch
                }

                installmentResults =
                    when (installmentsResult) {
                        is Result.Success ->
                            installmentsResult.data

                        is Result.Error ->
                            emptyList()
                    }

                renderPaymentMethods()

                setBusy(false)
            } catch (_: Exception) {
                if (version == lookupVersion) {
                    showError(
                        "Não foi possível identificar o cartão.",
                    )
                }
            }
        }
    }

    private fun PaymentMethod.toCardMethodOption():
        CardMethodOption? {

        val methodId =
            id
                ?.trim()
                ?.lowercase()
                .orEmpty()

        val typeId =
            paymentTypeId
                ?.trim()
                ?.lowercase()
                .orEmpty()

        if (methodId.isBlank()) {
            return null
        }

        if (
            typeId != "credit_card" &&
            typeId != "debit_card" &&
            typeId != "prepaid_card"
        ) {
            return null
        }

        val securityLength =
            card
                ?.securityCode
                ?.length
                ?: 3

        return CardMethodOption(
            id = methodId,
            type = typeId,
            label =
                "${friendlyType(typeId)} • ${friendlyBrand(methodId)}",
            securityCodeLength =
                securityLength,
        )
    }

    private fun renderPaymentMethods() {
        val labels =
            cardMethodOptions.map {
                it.label
            }

        val adapter =
            ArrayAdapter(
                this,
                android.R.layout.simple_spinner_item,
                labels,
            )

        adapter.setDropDownViewResource(
            android.R.layout.simple_spinner_dropdown_item,
        )

        paymentMethodSpinner.adapter =
            adapter

        paymentMethodLabelTextView.visibility =
            View.VISIBLE

        paymentMethodSpinner.visibility =
            View.VISIBLE

        if (cardMethodOptions.isNotEmpty()) {
            paymentMethodSpinner.setSelection(0)
        }
    }

    private fun configureSelectedCardMethod() {
        val selected =
            selectedCardMethod
                ?: return

        securityCodeTextField.securityCodeSize =
            selected.securityCodeLength
                .coerceIn(
                    3,
                    4,
                )

        renderInstallments(selected)
    }

    private fun renderInstallments(
        method: CardMethodOption,
    ) {
        selectedInstallments =
            0

        installmentOptions =
            if (method.type == "credit_card") {
                buildCreditInstallments(method)
            } else {
                listOf(
                    InstallmentOption(
                        installments = 1,
                        label =
                            "1x de ${formatCurrency(amount)}",
                    ),
                )
            }

        if (installmentOptions.isEmpty()) {
            installmentLabelTextView.visibility =
                View.GONE

            installmentSpinner.visibility =
                View.GONE

            showError(
                "Não foi possível consultar as parcelas deste cartão.",
            )

            updatePayButton()

            return
        }

        hideError()

        val labels =
            installmentOptions.map {
                it.label
            }

        val adapter =
            ArrayAdapter(
                this,
                android.R.layout.simple_spinner_item,
                labels,
            )

        adapter.setDropDownViewResource(
            android.R.layout.simple_spinner_dropdown_item,
        )

        installmentSpinner.adapter =
            adapter

        installmentLabelTextView.visibility =
            View.VISIBLE

        installmentSpinner.visibility =
            View.VISIBLE

        installmentSpinner.setSelection(0)

        selectedInstallments =
            installmentOptions.first()
                .installments

        updatePayButton()
    }

    private fun buildCreditInstallments(
        method: CardMethodOption,
    ): List<InstallmentOption> {

        val matchingInstallment =
            installmentResults.firstOrNull {
                it.paymentMethodId
                    ?.equals(
                        method.id,
                        ignoreCase = true,
                    ) == true &&
                    it.paymentTypeId
                        ?.equals(
                            method.type,
                            ignoreCase = true,
                        ) == true
            }
                ?: installmentResults.firstOrNull {
                    it.paymentMethodId
                        ?.equals(
                            method.id,
                            ignoreCase = true,
                        ) == true
                }

        val payerCosts =
            matchingInstallment
                ?.payerCost
                .orEmpty()

        return payerCosts
            .mapNotNull { cost ->

                val installments =
                    cost.instalments
                        ?: return@mapNotNull null

                if (installments < 1) {
                    return@mapNotNull null
                }

                val installmentAmount =
                    cost.installmentAmount
                        ?.toDouble()
                        ?: (
                            amount.toDouble() /
                                installments.toDouble()
                            )

                val totalAmount =
                    cost.totalAmount
                        ?.toDouble()
                        ?: amount.toDouble()

                val label =
                    if (installments == 1) {
                        "1x de ${formatCurrency(installmentAmount)}"
                    } else {
                        "$installments x de " +
                            "${formatCurrency(installmentAmount)} " +
                            "• total ${formatCurrency(totalAmount)}"
                    }

                InstallmentOption(
                    installments = installments,
                    label = label,
                )
            }
            .sortedBy {
                it.installments
            }
    }

    private fun setupActions() {
        tokenizeButton.setOnClickListener {
            generateCardToken()
        }

        cancelButton.setOnClickListener {
            cancelTokenization()
        }
    }

    private fun generateCardToken() {
        if (busy) {
            return
        }

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
                .filter {
                    it.isDigit()
                }

        val method =
            selectedCardMethod

        if (holderName.isBlank()) {
            showError(
                "Informe o nome do titular.",
            )

            return
        }

        if (cpf.length != 11) {
            showError(
                "Informe um CPF com 11 números.",
            )

            return
        }

        if (method == null) {
            showError(
                "Aguarde a identificação do cartão.",
            )

            return
        }

        if (selectedInstallments < 1) {
            showError(
                "Selecione a forma de pagamento.",
            )

            return
        }

        setBusy(true)

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
                            tokenResult
                                .data
                                .token

                        if (token.isBlank()) {
                            showError(
                                "Não foi possível validar o cartão.",
                            )

                            return@launch
                        }

                        finishWithToken(
                            token = token,
                            paymentMethodId = method.id,
                            paymentMethodType = method.type,
                            installments =
                                selectedInstallments,
                        )
                    }

                    is Result.Error -> {
                        showError(
                            resultErrorMessage(
                                tokenResult.error,
                            ),
                        )
                    }
                }
            } catch (_: Exception) {
                showError(
                    "Não foi possível validar o cartão.",
                )
            } finally {
                if (!isFinishing) {
                    setBusy(false)
                }
            }
        }
    }

    private fun finishWithToken(
        token: String,
        paymentMethodId: String,
        paymentMethodType: String,
        installments: Int,
    ) {
        val resultIntent =
            Intent().apply {
                putExtra(
                    EXTRA_CARD_TOKEN,
                    token,
                )

                putExtra(
                    EXTRA_PAYMENT_METHOD_ID,
                    paymentMethodId,
                )

                putExtra(
                    EXTRA_PAYMENT_METHOD_TYPE,
                    paymentMethodType,
                )

                putExtra(
                    EXTRA_INSTALLMENTS,
                    installments,
                )
            }

        setResult(
            RESULT_OK,
            resultIntent,
        )

        finish()
    }

    private fun cancelTokenization() {
        setResult(
            RESULT_CANCELED,
        )

        finish()
    }

    private fun resetCardConfiguration() {
        ++lookupVersion

        currentBin =
            null

        clearPaymentConfiguration()

        hideError()

        setBusy(false)
    }

    private fun clearPaymentConfiguration() {
        cardMethodOptions =
            emptyList()

        installmentResults =
            emptyList()

        installmentOptions =
            emptyList()

        selectedCardMethod =
            null

        selectedInstallments =
            0

        paymentMethodSpinner.adapter =
            null

        installmentSpinner.adapter =
            null

        paymentMethodLabelTextView.visibility =
            View.GONE

        paymentMethodSpinner.visibility =
            View.GONE

        installmentLabelTextView.visibility =
            View.GONE

        installmentSpinner.visibility =
            View.GONE

        updatePayButton()
    }

    private fun setBusy(
        value: Boolean,
    ) {
        busy =
            value

        progressBar.visibility =
            if (value) {
                View.VISIBLE
            } else {
                View.GONE
            }

        cancelButton.isEnabled =
            !value

        paymentMethodSpinner.isEnabled =
            !value

        installmentSpinner.isEnabled =
            !value

        updatePayButton()
    }

    private fun updatePayButton() {
        tokenizeButton.isEnabled =
            !busy &&
            selectedCardMethod != null &&
            selectedInstallments > 0
    }

    private fun showError(
        message: String,
    ) {
        errorTextView.text =
            message

        errorTextView.visibility =
            View.VISIBLE

        setBusy(false)
    }

    private fun hideError() {
        errorTextView.text =
            ""

        errorTextView.visibility =
            View.GONE
    }

    private fun resultErrorMessage(
        error: ResultError,
    ): String {
        return when (error) {
            is ResultError.Request -> {
                error.message.ifBlank {
                    "Não foi possível comunicar com o Mercado Pago."
                }
            }

            is ResultError.Validation -> {
                error.message.ifBlank {
                    "Os dados do cartão não são válidos."
                }
            }
        }
    }

    private fun friendlyType(
        value: String,
    ): String {
        return when (value) {
            "credit_card" ->
                "Crédito"

            "debit_card" ->
                "Débito"

            "prepaid_card" ->
                "Pré-pago"

            else ->
                "Cartão"
        }
    }

    private fun friendlyBrand(
        value: String,
    ): String {
        return when (
            value.lowercase()
        ) {
            "master",
            "mastercard" ->
                "Mastercard"

            "visa" ->
                "Visa"

            "amex" ->
                "American Express"

            "elo" ->
                "Elo"

            "hipercard" ->
                "Hipercard"

            else ->
                value.uppercase(
                    Locale.ROOT,
                )
        }
    }

    private fun formatCurrency(
        value: BigDecimal,
    ): String {
        return currencyFormatter()
            .format(value)
    }

    private fun formatCurrency(
        value: Double,
    ): String {
        return currencyFormatter()
            .format(value)
    }

    private fun currencyFormatter():
        NumberFormat {

        return NumberFormat
            .getCurrencyInstance(
                Locale(
                    "pt",
                    "BR",
                ),
            )
    }

    override fun onDestroy() {
        activityScope.cancel()

        super.onDestroy()
    }
}