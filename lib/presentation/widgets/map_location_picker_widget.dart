import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapLocationPickerWidget extends StatefulWidget {
  final LatLng initialCenter;
  final void Function(LatLng) onLocationSelected;

  const MapLocationPickerWidget({
    super.key,
    required this.initialCenter,
    required this.onLocationSelected,
  });

  @override
  State<MapLocationPickerWidget> createState() =>
      _MapLocationPickerWidgetState();
}

class _MapLocationPickerWidgetState extends State<MapLocationPickerWidget> {
  late LatLng _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: 15,
            onTap: (_, point) {
              setState(() => _selected = point);
              widget.onLocationSelected(point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.cameyo.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _selected,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Toca el mapa para seleccionar la ubicación',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
