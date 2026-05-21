import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/theme_service.dart';
import 'package:flutter_app/core/services/websocket_service.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/services/payment_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentsManagementPage extends StatefulWidget {
  final String roleLabel;

  const PaymentsManagementPage({super.key, required this.roleLabel});

  @override
  State<PaymentsManagementPage> createState() => _PaymentsManagementPageState();
}

class _PaymentsManagementPageState extends State<PaymentsManagementPage> {
  late final PaymentService _paymentService;

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<String> _availableMethods = <String>[];
  List<PaymentMethodModel> _methods = <PaymentMethodModel>[];
  List<PaymentModel> _payments = <PaymentModel>[];

  bool _isDark = false;

  void _onThemeChanged() {
    if (mounted) setState(() => _isDark = sl<ThemeService>().isDark);
  }

  Color get _bg =>
      _isDark ? const Color(0xFF0F0F0F) : AppColors.backgroundLight;
  Color get _card => _isDark ? const Color(0xFF1C1C1C) : AppColors.white;
  Color get _cardAlt =>
      _isDark ? const Color(0xFF252525) : AppColors.surfaceSoft;
  Color get _txtPri => _isDark ? Colors.white : AppColors.textPrimary;
  Color get _txtSec =>
      _isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    _paymentService = sl<PaymentService>();
    _isDark = sl<ThemeService>().isDark;
    sl<ThemeService>().addListener(_onThemeChanged);
    _subscribePaymentCompleted();
    _loadData();
  }

  void _subscribePaymentCompleted() {
    sl<WebSocketService>().onPaymentCompleted((data) {
      AppLogger.info('WebSocket payment_completed: $data');
      if (mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['status'] == 'COMPLETED'
                  ? '¡Pago completado! Recibo disponible en tu historial.'
                  : 'Pago actualizado: ${data['status']}',
            ),
            backgroundColor: data['status'] == 'COMPLETED'
                ? Colors.green
                : AppColors.primary,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    sl<ThemeService>().removeListener(_onThemeChanged);
    sl<WebSocketService>().offPaymentCompleted();
    super.dispose();
  }

  String _labelForMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CREDIT_CARD':
        return 'Crédito o Débito';
      case 'DEBIT_CARD':
        return 'Débito';
      case 'BANK_TRANSFER':
        return 'Transferencia bancaria';
      case 'CASH':
        return 'Efectivo';
      case 'EPAYCO':
        return 'ePayco';
      case 'NEQUI':
        return 'Nequi';
      case 'DAVIPLATA':
        return 'Daviplata';
      default:
        return method;
    }
  }

  IconData _iconForMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CREDIT_CARD':
      case 'DEBIT_CARD':
        return Icons.credit_card;
      case 'BANK_TRANSFER':
        return Icons.account_balance;
      case 'CASH':
        return Icons.attach_money;
      case 'EPAYCO':
        return Icons.language;
      case 'NEQUI':
      case 'DAVIPLATA':
        return Icons.account_balance_wallet;
      default:
        return Icons.payments_outlined;
    }
  }

  List<Color> _colorsForMethod(String method) {
    switch (method.toUpperCase()) {
      case 'NEQUI':
        return const [Color(0xFF6A11CB), Color(0xFF8A2BE2)];
      case 'DAVIPLATA':
        return const [Color(0xFFD4145A), Color(0xFFFBB03B)];
      case 'EPAYCO':
        return const [Color(0xFF0077C2), Color(0xFF00A8E8)];
      case 'CASH':
        return const [Color(0xFF11998E), Color(0xFF38EF7D)];
      case 'CREDIT_CARD':
      case 'DEBIT_CARD':
        return const [Color(0xFF232526), Color(0xFF414345)];
      default:
        return [AppColors.primary, AppColors.secondary];
    }
  }

  String _formatMoney(String value) {
    final parsed = double.tryParse(value) ?? 0;
    return parsed.toStringAsFixed(0);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    String? errorMessage;

    try {
      final availableMethods = await _paymentService.getAvailableMethods();
      if (mounted) {
        setState(() {
          _availableMethods = availableMethods;
        });
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    try {
      final methods = await _paymentService.getMyMethods();
      if (mounted) {
        setState(() {
          _methods = methods;
        });
      }
    } catch (e) {
      errorMessage ??= e.toString();
    }

    try {
      final payments = await _paymentService.getMyPayments();
      if (mounted) {
        setState(() {
          _payments = payments;
        });
      }
    } catch (e) {
      errorMessage ??= e.toString();
    }

    if (errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando pagos: $errorMessage')),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMethod() async {
    if (_availableMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay métodos habilitados para tu cuenta'),
        ),
      );
      return;
    }

    final selectedMethod = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agregar método de pago',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: _txtPri,
                  ),
                ),
                const SizedBox(height: 12),
                ..._availableMethods.map(
                  (method) => Card(
                    color: _cardAlt,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: _isDark
                            ? const Color(0xFF3A3A3A)
                            : AppColors.greyLight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: _isDark
                            ? const Color(0xFF333333)
                            : AppColors.backgroundLight,
                        child: Icon(
                          _iconForMethod(method),
                          color: _txtPri,
                        ),
                      ),
                      title: Text(
                        _labelForMethod(method),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _txtPri,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: _txtSec),
                      onTap: () => Navigator.pop(context, method),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedMethod == null || !mounted) {
      return;
    }

    final aliasController = TextEditingController();
    final holderController = TextEditingController();
    final identifierController = TextEditingController();
    bool isDefault = _methods.isEmpty;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final borderColor =
                _isDark ? const Color(0xFF3A3A3A) : AppColors.greyLight;
            final inputBorder = OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            );

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _isDark
                              ? const Color(0xFF333333)
                              : AppColors.backgroundLight,
                          child: Icon(
                            _iconForMethod(selectedMethod),
                            color: _txtPri,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _labelForMethod(selectedMethod),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _txtPri,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completa estos datos para guardar el método en tu cuenta.',
                      style: TextStyle(color: _txtSec),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: aliasController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Alias (opcional)',
                        prefixIcon: const Icon(Icons.bookmark_outline),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder.copyWith(
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: holderController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Titular (opcional)',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder.copyWith(
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: identifierController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: 'Cuenta / teléfono / referencia',
                        hintText: 'Ej: 3001234567',
                        prefixIcon: const Icon(Icons.numbers_outlined),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder.copyWith(
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: _cardAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        value: isDefault,
                        onChanged: (value) {
                          setModalState(() => isDefault = value);
                        },
                        title: const Text(
                          'Usar como predeterminado',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Se selecciona primero al pagar.'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.greyLight,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Guardar método'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      setState(() => _isSubmitting = true);
      await _paymentService.createMethod(
        methodType: selectedMethod,
        alias: aliasController.text.trim().isEmpty
            ? null
            : aliasController.text.trim(),
        accountHolder: holderController.text.trim().isEmpty
            ? null
            : holderController.text.trim(),
        accountIdentifier: identifierController.text.trim().isEmpty
            ? null
            : identifierController.text.trim(),
        isDefault: isDefault,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo agregar el método: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openEpaycoCheckout(PaymentModel payment) async {
    final rawUrl = _paymentService.getEpaycoCheckoutUrl(payment.id);
    final uri = Uri.parse(rawUrl);
    try {
      final canOpen = await canLaunchUrl(uri);
      if (!canOpen) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el navegador para el pago.'),
          ),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.error('Error abriendo checkout ePayco', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir checkout: $e')),
      );
    }
  }

  Future<void> _showCreatePaymentDialog() async {
    final requestIdController = TextEditingController();
    final amountController = TextEditingController();

    final activeMethods = _methods.where((method) => method.isActive).toList();
    String? selectedMethodId = activeMethods.isNotEmpty
        ? activeMethods.first.id
        : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Registrar pago'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: requestIdController,
                      decoration: const InputDecoration(
                        labelText: 'ID de solicitud de servicio',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monto bruto',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (activeMethods.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedMethodId,
                        items: activeMethods
                            .map(
                              (method) => DropdownMenuItem<String>(
                                value: method.id,
                                child: Text(
                                  '${_labelForMethod(method.methodType)}${method.alias != null ? ' · ${method.alias}' : ''}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedMethodId = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Método guardado',
                        ),
                      )
                    else
                      const Text(
                        'No tienes métodos guardados. Agrega uno antes de registrar pagos.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un monto válido')));
      return;
    }

    if (requestIdController.text.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el ID de la solicitud')),
      );
      return;
    }

    try {
      setState(() => _isSubmitting = true);
      await _paymentService.createPayment(
        serviceRequestId: requestIdController.text.trim(),
        grossAmount: amount,
        paymentMethodId: selectedMethodId,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el pago: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _setDefaultMethod(String id) async {
    try {
      setState(() => _isSubmitting = true);
      await _paymentService.setDefaultMethod(id);
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar predeterminado: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _removeMethod(String id) async {
    try {
      setState(() => _isSubmitting = true);
      await _paymentService.removeMethod(id);
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el método: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _updatePaymentStatus(PaymentModel payment, String status) async {
    try {
      setState(() => _isSubmitting = true);
      await _paymentService.updatePaymentStatus(
        paymentId: payment.id,
        status: status,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar estado: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showRefundMethodPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Selecciona método de reembolso',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ..._methods.map(
                (method) => ListTile(
                  leading: Icon(_iconForMethod(method.methodType)),
                  title: Text(_labelForMethod(method.methodType)),
                  subtitle: Text(
                    method.alias ?? method.accountIdentifier ?? '',
                  ),
                  trailing: method.isDefault
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : null,
                  onTap: () => Navigator.pop(context, method.id),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    await _setDefaultMethod(selected);
  }

  void _showPendingPayments() {
    final pending = _payments
        .where((payment) => payment.status.toUpperCase() != 'COMPLETED')
        .toList();

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: pending.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No tienes pagos pendientes.'),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    const ListTile(
                      title: Text(
                        'Pagos pendientes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ...pending.map(
                      (payment) => ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(
                          '${_labelForMethod(payment.paymentMethod)} · ${_formatMoney(payment.grossAmount)}',
                        ),
                        subtitle: Text('Estado: ${payment.status}'),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildWalletHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Tus métodos de pago',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: _txtPri,
            ),
          ),
        ),
        IconButton.filled(
          onPressed: _isSubmitting ? null : _addMethod,
          style: IconButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _buildSavedMethodsCards() {
    if (_methods.isEmpty) {
      return Card(
        color: _card,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aún no tienes métodos guardados',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _txtPri,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toca el botón + para agregar uno.',
                style: TextStyle(color: _txtSec),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _addMethod,
                icon: const Icon(Icons.add),
                label: const Text('Agregar método'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _methods.map((method) {
        final colors = _colorsForMethod(method.methodType);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Icon(
                _iconForMethod(method.methodType),
                color: Colors.white,
              ),
            ),
            title: Text(
              _labelForMethod(method.methodType),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            subtitle: Text(
              method.alias ?? method.accountIdentifier ?? 'Cuenta registrada',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: PopupMenuButton<String>(
              color: Colors.white,
              onSelected: (value) {
                if (value == 'default') {
                  _setDefaultMethod(method.id);
                }
                if (value == 'delete') {
                  _removeMethod(method.id);
                }
              },
              itemBuilder: (context) => [
                if (!method.isDefault)
                  const PopupMenuItem(
                    value: 'default',
                    child: Text('Marcar predeterminado'),
                  ),
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
              icon: const Icon(Icons.more_vert, color: Colors.white),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvailableMethodsCard() {
    return Card(
      color: _card,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métodos disponibles para tu cuenta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _txtPri,
              ),
            ),
            const SizedBox(height: 10),
            if (_availableMethods.isEmpty)
              Text(
                'No hay métodos habilitados en este momento.',
                style: TextStyle(color: _txtSec),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableMethods
                    .map(
                      (method) => Chip(
                        backgroundColor: _cardAlt,
                        side: BorderSide(
                          color: _isDark
                              ? const Color(0xFF3A3A3A)
                              : AppColors.greyLight,
                        ),
                        avatar: Icon(
                          _iconForMethod(method),
                          size: 16,
                          color: _txtPri,
                        ),
                        label: Text(
                          _labelForMethod(method),
                          style: TextStyle(color: _txtPri),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Card(
      color: _card,
      elevation: 0,
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: _txtPri,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: _txtSec),
        ),
        trailing: Icon(Icons.chevron_right, color: _txtSec),
        onTap: onTap,
      ),
    );
  }

  Widget _buildPaymentsCard() {
    return Card(
      color: _card,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Historial de pagos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _txtPri,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _showCreatePaymentDialog,
                    icon: const Icon(Icons.add_card),
                    label: const Text('Registrar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_payments.isEmpty)
              const Text('Aún no tienes pagos registrados.')
            else
              ..._payments.map(
                (payment) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                        '${_labelForMethod(payment.paymentMethod)} · COP ${_formatMoney(payment.grossAmount)}',
                      ),
                      subtitle: Text(
                        'Estado: ${payment.status}\nSolicitud: ${payment.serviceRequestId.substring(0, 8)}...',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (status) =>
                            _updatePaymentStatus(payment, status),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'PROCESSING',
                            child: Text('En proceso'),
                          ),
                          PopupMenuItem(
                            value: 'COMPLETED',
                            child: Text('Completado'),
                          ),
                          PopupMenuItem(
                            value: 'FAILED',
                            child: Text('Fallido'),
                          ),
                          PopupMenuItem(
                            value: 'REFUNDED',
                            child: Text('Reembolsado'),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert),
                      ),
                    ),
                    if (payment.isEpayco && payment.isProcessing)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => _openEpaycoCheckout(payment),
                          icon: const Icon(Icons.open_in_browser, size: 18),
                          label: const Text('Pagar con ePayco'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0077C2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultMethod = _methods.where((method) => method.isDefault).toList();
    final fallbackMethod = _methods.isNotEmpty ? _methods.first : null;
    final refundMethod = defaultMethod.isNotEmpty
        ? defaultMethod.first
        : fallbackMethod;

    final pendingCount = _payments
        .where((payment) => payment.status.toUpperCase() != 'COMPLETED')
        .length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('Pagos · ${widget.roleLabel}'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildWalletHeader(),
                  const SizedBox(height: 16),
                  _buildAvailableMethodsCard(),
                  const SizedBox(height: 16),
                  _buildSavedMethodsCards(),
                  const SizedBox(height: 16),
                  _buildActionTile(
                    title: 'Método de reembolso',
                    subtitle: refundMethod != null
                        ? _labelForMethod(refundMethod.methodType)
                        : 'Sin definir',
                    onTap: _methods.isEmpty ? null : _showRefundMethodPicker,
                  ),
                  const SizedBox(height: 16),
                  _buildActionTile(
                    title: 'Pagos pendientes',
                    subtitle: '$pendingCount pendientes',
                    onTap: _showPendingPayments,
                  ),
                  const SizedBox(height: 20),
                  _buildPaymentsCard(),
                ],
              ),
            ),
    );
  }
}
