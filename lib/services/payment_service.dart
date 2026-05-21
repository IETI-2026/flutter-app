import 'package:dio/dio.dart';
import 'package:flutter_app/core/constants/app_constants.dart';
import 'package:flutter_app/utils/constants.dart';

class PaymentMethodModel {
  final String id;
  final String methodType;
  final String? alias;
  final String? accountHolder;
  final String? accountIdentifier;
  final bool isDefault;
  final bool isActive;

  const PaymentMethodModel({
    required this.id,
    required this.methodType,
    this.alias,
    this.accountHolder,
    this.accountIdentifier,
    required this.isDefault,
    required this.isActive,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id']?.toString() ?? '',
      methodType: json['methodType']?.toString() ?? '',
      alias: json['alias']?.toString(),
      accountHolder: json['accountHolder']?.toString(),
      accountIdentifier: json['accountIdentifier']?.toString(),
      isDefault: json['isDefault'] == true,
      isActive: json['isActive'] == true,
    );
  }
}

class PaymentModel {
  final String id;
  final String serviceRequestId;
  final String paymentMethod;
  final String status;
  final String grossAmount;
  final String netAmount;
  final String commissionAmount;
  final double commissionRate;
  final String? gatewayReference;
  final String? receiptUrl;
  final DateTime? paidAt;

  const PaymentModel({
    required this.id,
    required this.serviceRequestId,
    required this.paymentMethod,
    required this.status,
    required this.grossAmount,
    required this.netAmount,
    required this.commissionAmount,
    required this.commissionRate,
    this.gatewayReference,
    this.receiptUrl,
    this.paidAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id']?.toString() ?? '',
      serviceRequestId: json['serviceRequestId']?.toString() ?? '',
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      grossAmount: json['grossAmount']?.toString() ?? '0',
      netAmount: json['netAmount']?.toString() ?? '0',
      commissionAmount: json['commissionAmount']?.toString() ?? '0',
      commissionRate: (json['commissionRate'] as num?)?.toDouble() ?? 0,
      gatewayReference: json['gatewayReference']?.toString(),
      receiptUrl: json['receiptUrl']?.toString(),
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'].toString())
          : null,
    );
  }

  bool get isEpayco => paymentMethod.toUpperCase() == 'EPAYCO';
  bool get isPending => status == 'PENDING';
  bool get isProcessing => status == 'PROCESSING';
  bool get isCompleted => status == 'COMPLETED';
}

class PaymentService {
  final Dio _dio;

  PaymentService({required Dio dio}) : _dio = dio;

  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is List) return msg.join(' | ');
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString();
      }
      final err = data['error'];
      if (err is Map && err['message'] != null) {
        return err['message'].toString();
      }
    }
    return '$fallback (${e.response?.statusCode ?? 'sin respuesta'})';
  }

  Future<List<String>> getAvailableMethods() async {
    try {
      final resp = await _dio.get(
        '${ApiConstants.paymentsEndpoint}/methods/available',
      );
      final data = resp.data;
      if (data is List) return data.map((e) => e.toString()).toList();
      return [];
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'No se pudieron obtener métodos disponibles'));
    }
  }

  Future<List<PaymentMethodModel>> getMyMethods() async {
    try {
      final resp = await _dio.get(
        '${ApiConstants.paymentsEndpoint}/methods/mine',
      );
      final data = resp.data;
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(PaymentMethodModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'No se pudieron obtener tus métodos de pago'));
    }
  }

  Future<PaymentMethodModel> createMethod({
    required String methodType,
    String? alias,
    String? accountHolder,
    String? accountIdentifier,
    bool isDefault = false,
  }) async {
    try {
      final resp = await _dio.post(
        '${ApiConstants.paymentsEndpoint}/methods',
        data: {
          'methodType': methodType,
          if (alias != null && alias.trim().isNotEmpty) 'alias': alias.trim(),
          if (accountHolder != null && accountHolder.trim().isNotEmpty)
            'accountHolder': accountHolder.trim(),
          if (accountIdentifier != null && accountIdentifier.trim().isNotEmpty)
            'accountIdentifier': accountIdentifier.trim(),
          'isDefault': isDefault,
        },
      );
      return PaymentMethodModel.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'No se pudo registrar el método de pago'));
    }
  }

  Future<PaymentMethodModel> setDefaultMethod(String paymentMethodId) async {
    try {
      final resp = await _dio.patch(
        '${ApiConstants.paymentsEndpoint}/methods/$paymentMethodId/default',
      );
      return PaymentMethodModel.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'No se pudo establecer método predeterminado'));
    }
  }

  Future<void> removeMethod(String paymentMethodId) async {
    try {
      await _dio.delete(
        '${ApiConstants.paymentsEndpoint}/methods/$paymentMethodId',
      );
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'No se pudo eliminar el método de pago'));
    }
  }

  Future<List<PaymentModel>> getMyPayments() async {
    try {
      final resp = await _dio.get('${ApiConstants.paymentsEndpoint}/mine');
      final data = resp.data;
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(PaymentModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'No se pudieron obtener los pagos'));
    }
  }

  Future<PaymentModel?> getPaymentByServiceRequest(
    String serviceRequestId,
  ) async {
    try {
      final resp = await _dio.get(
        '${ApiConstants.paymentsEndpoint}/service-request/$serviceRequestId',
      );
      return PaymentModel.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(_extractError(e, 'No se pudo obtener el pago de la solicitud'));
    }
  }

  Future<PaymentModel> createPayment({
    required String serviceRequestId,
    required double grossAmount,
    String? paymentMethod,
    String? paymentMethodId,
    double? commissionRate,
    String? externalTransactionId,
    String? gatewayReference,
  }) async {
    try {
      final resp = await _dio.post(
        ApiConstants.paymentsEndpoint,
        data: {
          'serviceRequestId': serviceRequestId,
          'grossAmount': grossAmount,
          if (paymentMethod != null) 'paymentMethod': paymentMethod,
          if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
          if (commissionRate != null) 'commissionRate': commissionRate,
          if (externalTransactionId != null)
            'externalTransactionId': externalTransactionId,
          if (gatewayReference != null) 'gatewayReference': gatewayReference,
        },
      );
      return PaymentModel.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'No se pudo crear el pago'));
    }
  }

  Future<PaymentModel> updatePaymentStatus({
    required String paymentId,
    required String status,
    String? reason,
    String? receiptUrl,
  }) async {
    try {
      final resp = await _dio.patch(
        '${ApiConstants.paymentsEndpoint}/$paymentId/status',
        data: {
          'status': status,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
          if (receiptUrl != null && receiptUrl.trim().isNotEmpty)
            'receiptUrl': receiptUrl.trim(),
        },
      );
      return PaymentModel.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'No se pudo actualizar el estado del pago'));
    }
  }

  /// Devuelve la URL del checkout de ePayco para abrir en el navegador.
  String getEpaycoCheckoutUrl(String paymentId) {
    return '${AppConstants.baseUrl}/payments/$paymentId/epayco-checkout';
  }
}
