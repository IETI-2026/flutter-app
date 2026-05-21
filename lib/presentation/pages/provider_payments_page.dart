import 'package:flutter/material.dart';
import 'package:flutter_app/presentation/pages/payments_management_page.dart';

class ProviderPaymentsPage extends StatelessWidget {
  const ProviderPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PaymentsManagementPage(roleLabel: 'Profesional');
  }
}
