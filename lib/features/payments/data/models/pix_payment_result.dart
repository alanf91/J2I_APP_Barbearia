class PixPaymentResult {
  final String appointmentId;
  final String orderId;
  final String paymentId;
  final String status;
  final String statusDetail;
  final String amount;
  final String realAppointmentAmount;
  final bool testMode;

  final String qrCode;
  final String qrCodeBase64;
  final String ticketUrl;

  final bool reused;
  final bool approved;

  // Momento exato em que termina
  // a reserva J2I de 2 minutos.
  final int? reservationExpiresAtMs;

  const PixPaymentResult({
    required this.appointmentId,
    required this.orderId,
    required this.paymentId,
    required this.status,
    required this.statusDetail,
    required this.amount,
    required this.realAppointmentAmount,
    required this.testMode,
    required this.qrCode,
    required this.qrCodeBase64,
    required this.ticketUrl,
    required this.reused,
    required this.approved,
    required this.reservationExpiresAtMs,
  });

  factory PixPaymentResult.fromMap(
    Map<String, dynamic> map,
  ) {
    final pix =
        map['pix'] is Map
            ? Map<String, dynamic>.from(
                map['pix'] as Map,
              )
            : <String, dynamic>{};

    final rawExpiration =
        map['reservationExpiresAtMs'];

    final int? reservationExpiresAtMs =
        rawExpiration is num
            ? rawExpiration.toInt()
            : int.tryParse(
                rawExpiration
                        ?.toString() ??
                    '',
              );

    return PixPaymentResult(
      appointmentId:
          map['appointmentId']
                  ?.toString()
                  .trim() ??
              '',

      orderId:
          map['orderId']
                  ?.toString()
                  .trim() ??
              '',

      paymentId:
          map['paymentId']
                  ?.toString()
                  .trim() ??
              '',

      status:
          map['status']
                  ?.toString()
                  .trim() ??
              '',

      statusDetail:
          map['statusDetail']
                  ?.toString()
                  .trim() ??
              '',

      amount:
          map['amount']
                  ?.toString()
                  .trim() ??
              '',

      realAppointmentAmount:
          map['realAppointmentAmount']
                  ?.toString()
                  .trim() ??
              '',

      testMode:
          map['testMode'] == true,

      qrCode:
          pix['qrCode']
                  ?.toString()
                  .trim() ??
              '',

      qrCodeBase64:
          pix['qrCodeBase64']
                  ?.toString()
                  .trim() ??
              '',

      ticketUrl:
          pix['ticketUrl']
                  ?.toString()
                  .trim() ??
              '',

      reused:
          map['reused'] == true,

      approved:
          map['approved'] == true,

      reservationExpiresAtMs:
          reservationExpiresAtMs,
    );
  }
}