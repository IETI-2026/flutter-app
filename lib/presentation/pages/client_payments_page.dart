import 'package:flutter/material.dart';
import 'package:flutter_app/presentation/pages/payments_management_page.dart';

class ClientPaymentsPage extends StatelessWidget {
  const ClientPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PaymentsManagementPage(roleLabel: 'Cliente');
  }
}
