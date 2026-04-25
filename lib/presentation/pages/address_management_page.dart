import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/theme_service.dart';
import 'package:flutter_app/data/datasources/geocoding_remote_datasource.dart';
import 'package:flutter_app/domain/entities/address.dart';
import 'package:flutter_app/domain/usecases/create_address_usecase.dart';
import 'package:flutter_app/presentation/bloc/address/address_bloc.dart';
import 'package:flutter_app/presentation/bloc/address/address_event.dart';
import 'package:flutter_app/presentation/bloc/address/address_state.dart';
import 'package:flutter_app/presentation/widgets/map_location_picker_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

class AddressManagementPage extends StatefulWidget {
  const AddressManagementPage({super.key});

  @override
  State<AddressManagementPage> createState() => _AddressManagementPageState();
}

class _AddressManagementPageState extends State<AddressManagementPage> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _isDark = sl<ThemeService>().isDark;
    sl<ThemeService>().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    sl<ThemeService>().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() => _isDark = sl<ThemeService>().isDark);
  }

  Color get _bg => _isDark ? const Color(0xFF0F0F0F) : AppColors.backgroundLight;
  Color get _card => _isDark ? const Color(0xFF1C1C1C) : AppColors.white;
  Color get _txtPri => _isDark ? Colors.white : AppColors.textPrimary;
  Color get _txtSec => _isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AddressBloc>()..add(const LoadAddressesEvent()),
      child: _AddressManagementView(
        isDark: _isDark,
        bg: _bg,
        card: _card,
        txtPri: _txtPri,
        txtSec: _txtSec,
      ),
    );
  }
}

class _AddressManagementView extends StatelessWidget {
  final bool isDark;
  final Color bg;
  final Color card;
  final Color txtPri;
  final Color txtSec;

  const _AddressManagementView({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.txtPri,
    required this.txtSec,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(
          'Mis direcciones',
          style: TextStyle(
            color: txtPri,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: txtPri),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<AddressBloc, AddressState>(
        listener: (context, state) {
          if (state is AddressOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          if (state is AddressError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AddressLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final addresses = state is AddressLoaded
              ? state.addresses
              : state is AddressOperationSuccess
                  ? state.addresses
                  : <Address>[];

          if (addresses.isEmpty && state is! AddressLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_outlined, size: 64, color: txtSec),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes direcciones guardadas',
                    style: TextStyle(color: txtSec, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega una para facilitar tus solicitudes',
                    style: TextStyle(color: txtSec, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final addr = addresses[index];
              return _AddressCard(
                address: addr,
                isDark: isDark,
                card: card,
                txtPri: txtPri,
                txtSec: txtSec,
                onSetDefault: () => context
                    .read<AddressBloc>()
                    .add(SetDefaultAddressEvent(addr.id)),
                onDelete: () => _confirmDelete(context, addr),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Agregar dirección'),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Address addr) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: card,
        title: Text('Eliminar dirección', style: TextStyle(color: txtPri)),
        content: Text(
          '¿Deseas eliminar "${addr.displayName}"?',
          style: TextStyle(color: txtSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context
                  .read<AddressBloc>()
                  .add(DeleteAddressEvent(addr.id));
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<AddressBloc>(),
        child: _AddAddressSheet(
          isDark: isDark,
          card: card,
          txtPri: txtPri,
          geocodingDataSource: sl<GeocodingRemoteDataSource>(),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Address address;
  final bool isDark;
  final Color card;
  final Color txtPri;
  final Color txtSec;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.isDark,
    required this.card,
    required this.txtPri,
    required this.txtSec,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: card,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  address.isDefault ? Icons.home : Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (address.label != null && address.label!.isNotEmpty)
                        Text(
                          address.label!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: txtPri,
                          ),
                        ),
                      Text(
                        address.displayName,
                        style: TextStyle(color: txtSec, fontSize: 13),
                      ),
                      if (address.department != null &&
                          address.department!.isNotEmpty)
                        Text(
                          address.department!,
                          style: TextStyle(color: txtSec, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Principal',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!address.isDefault)
                  TextButton(
                    onPressed: onSetDefault,
                    child: const Text('Marcar como principal'),
                  ),
                TextButton(
                  onPressed: onDelete,
                  child: const Text(
                    'Eliminar',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAddressSheet extends StatefulWidget {
  final bool isDark;
  final Color card;
  final Color txtPri;
  final GeocodingRemoteDataSource geocodingDataSource;

  const _AddAddressSheet({
    required this.isDark,
    required this.card,
    required this.txtPri,
    required this.geocodingDataSource,
  });

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();

  double? _lat;
  double? _lng;
  bool _showMap = false;
  bool _geocodingLoading = false;

  @override
  void dispose() {
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _departmentCtrl.dispose();
    _postalCodeCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _onMapLocationSelected(LatLng point) async {
    setState(() {
      _lat = point.latitude;
      _lng = point.longitude;
      _geocodingLoading = true;
    });

    try {
      final result = await widget.geocodingDataSource.reverseGeocodeComponents(
        lat: point.latitude,
        lng: point.longitude,
      );
      if (mounted) {
        setState(() {
          if (result['street'] != null) _streetCtrl.text = result['street']!;
          if (result['city'] != null) _cityCtrl.text = result['city']!;
          if (result['neighborhood'] != null) {
            _neighborhoodCtrl.text = result['neighborhood']!;
          }
          if (result['department'] != null) {
            _departmentCtrl.text = result['department']!;
          }
          _geocodingLoading = false;
          _showMap = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _geocodingLoading = false);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.read<AddressBloc>().add(
      CreateAddressEvent(
        CreateAddressParams(
          street: _streetCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          neighborhood: _neighborhoodCtrl.text.trim().isEmpty
              ? null
              : _neighborhoodCtrl.text.trim(),
          department: _departmentCtrl.text.trim().isEmpty
              ? null
              : _departmentCtrl.text.trim(),
          postalCode: _postalCodeCtrl.text.trim().isEmpty
              ? null
              : _postalCodeCtrl.text.trim(),
          label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
          latitude: _lat,
          longitude: _lng,
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: _showMap
          ? MediaQuery.of(context).size.height * 0.8
          : null,
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: _showMap
          ? Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selecciona en el mapa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.txtPri,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _showMap = false),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MapLocationPickerWidget(
                      initialCenter: LatLng(
                        _lat ?? 4.711,
                        _lng ?? -74.0721,
                      ),
                      onLocationSelected: _onMapLocationSelected,
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Nueva dirección',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.txtPri,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showMap = true),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        _lat != null
                            ? 'Ubicación seleccionada ✓'
                            : 'Seleccionar en el mapa',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (_geocodingLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _labelCtrl,
                      label: 'Etiqueta (opcional)',
                      hint: 'Ej: Casa, Oficina',
                      maxLength: 100,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _streetCtrl,
                      label: 'Calle *',
                      hint: 'Ej: Calle 123 #45-67',
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _cityCtrl,
                      label: 'Ciudad *',
                      hint: 'Ej: Bogotá',
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _neighborhoodCtrl,
                      label: 'Barrio (opcional)',
                      hint: 'Ej: Chapinero',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _departmentCtrl,
                      label: 'Departamento (opcional)',
                      hint: 'Ej: Cundinamarca',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _postalCodeCtrl,
                      label: 'Código postal (opcional)',
                      hint: 'Ej: 110111',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Guardar dirección',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: TextStyle(color: widget.txtPri),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null
          : null,
    );
  }
}
