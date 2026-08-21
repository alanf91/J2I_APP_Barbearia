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
  });

  factory PixPaymentResult.fromMap(Map<String, dynamic> map) {
    final pix = map['pix'] is Map
        ? Map<String, dynamic>.from(map['pix'] as Map)
        : <String, dynamic>{};

    return PixPaymentResult(
      appointmentId: map['appointmentId']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      paymentId: map['paymentId']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      statusDetail: map['statusDetail']?.toString() ?? '',
      amount: map['amount']?.toString() ?? '',
      realAppointmentAmount: map['realAppointmentAmount']?.toString() ?? '',
      testMode: map['testMode'] == true,
      qrCode: pix['qrCode']?.toString() ?? '',
      qrCodeBase64: pix['qrCodeBase64']?.toString() ?? '',
      ticketUrl: pix['ticketUrl']?.toString() ?? '',
    );
  }
}
