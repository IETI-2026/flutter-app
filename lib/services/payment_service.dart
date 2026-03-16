import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/tenant_service.dart';
import '../utils/constants.dart';

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

  const PaymentModel({
    required this.id,
    required this.serviceRequestId,
    required this.paymentMethod,
    required this.status,
    required this.grossAmount,
    required this.netAmount,
    required this.commissionAmount,
    required this.commissionRate,
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
    );
  }
}

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is List) {
          return message.join(' | ');
        }
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(StorageKeys.accessToken);

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa');
    }

    final normalizedToken = token.toLowerCase().startsWith('bearer ')
        ? token
        : 'Bearer $token';

    final tenantId = sl<TenantService>().tenantId;

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': normalizedToken,
      'X-Tenant-ID': tenantId,
    };
  }

  Future<List<String>> getAvailableMethods() async {
    final headers = await _authHeaders();
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.paymentsEndpoint}/methods/available',
    );

    final response = await http.get(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(
          response,
          'No se pudieron obtener métodos disponibles',
        ),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return [];
    }

    return decoded.map((item) => item.toString()).toList();
  }

  Future<List<PaymentMethodModel>> getMyMethods() async {
    final headers = await _authHeaders();
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.paymentsEndpoint}/methods/mine',
    );

    final response = await http.get(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(
          response,
          'No se pudieron obtener tus métodos de pago',
        ),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PaymentMethodModel.fromJson)
        .toList();
  }

  Future<PaymentMethodModel> createMethod({
    required String methodType,
    String? alias,
    String? accountHolder,
    String? accountIdentifier,
    bool isDefault = false,
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.paymentsEndpoint}/methods',
    );

    final payload = {
      'methodType': methodType,
      if (alias != null && alias.trim().isNotEmpty) 'alias': alias.trim(),
      if (accountHolder != null && accountHolder.trim().isNotEmpty)
        'accountHolder': accountHolder.trim(),
      if (accountIdentifier != null && accountIdentifier.trim().isNotEmpty)
        'accountIdentifier': accountIdentifier.trim(),
      'isDefault': isDefault,
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception(
        _extractErrorMessage(
          response,
          'No se pudo registrar el método de pago',
        ),
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return PaymentMethodModel.fromJson(decoded);
  }

  Future<PaymentMethodModel> setDefaultMethod(String paymentMethodId) async {
    final headers = await _authHeaders();
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.paymentsEndpoint}/methods/$paymentMethodId/default',
    );

    final response = await http.patch(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(
          response,
          'No se pudo establecer método predeterminado',
        ),
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return PaymentMethodModel.fromJson(decoded);
  }

  Future<void> removeMethod(String paymentMethodId) async {
    final headers = await _authHeaders();
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.paymentsEndpoint}/methods/$paymentMethodId',
    );

    final response = await http.delete(url, headers: headers);

    if (response.statusCode != 204) {
      throw Exception(
        _extractErrorMessage(response, 'No se pudo eliminar el método de pago'),
      );
    }
  }

  Future<List<PaymentModel>> getMyPayments() async {
    final headers = await _authHeaders();
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.paymentsEndpoint}/mine',
    );

    final response = await http.get(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(response, 'No se pudieron obtener los pagos'),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PaymentModel.fromJson)
        .toList();
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
    final headers = await _authHeaders();
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.paymentsEndpoint}',
    );

    final payload = {
      'serviceRequestId': serviceRequestId,
      'grossAmount': grossAmount,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
      if (commissionRate != null) 'commissionRate': commissionRate,
      if (externalTransactionId != null)
        'externalTransactionId': externalTransactionId,
      if (gatewayReference != null) 'gatewayReference': gatewayReference,
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception(
        _extractErrorMessage(response, 'No se pudo crear el pago'),
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return PaymentModel.fromJson(decoded);
  }

  Future<PaymentModel> updatePaymentStatus({
    required String paymentId,
    required String status,
    String? reason,
    String? receiptUrl,
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.paymentsEndpoint}/$paymentId/status',
    );

    final payload = {
      'status': status,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (receiptUrl != null && receiptUrl.trim().isNotEmpty)
        'receiptUrl': receiptUrl.trim(),
    };

    final response = await http.patch(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(
          response,
          'No se pudo actualizar el estado del pago',
        ),
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return PaymentModel.fromJson(decoded);
  }
}
