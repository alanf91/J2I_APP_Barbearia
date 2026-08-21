package com.example.j2i_app_barbearia

import android.app.Application
import com.mercadopago.sdk.android.domain.model.CountryCode
import com.mercadopago.sdk.android.initializer.MercadoPagoSDK

class J2IApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        val publicKey = BuildConfig.MERCADO_PAGO_PUBLIC_KEY

        check(publicKey.isNotBlank()) {
            "Mercado Pago Public Key não configurada."
        }

        MercadoPagoSDK.initialize(
            context = this,
            publicKey = publicKey,
            countryCode = CountryCode.BRA,
        )
    }
}