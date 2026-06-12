import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/campus_map_data.dart';

class CampusMapWidget extends StatefulWidget {
  final String? highlightId;
  final String? highlightLabel;

  const CampusMapWidget({
    super.key,
    this.highlightId,
    this.highlightLabel,
  });

  @override
  State<CampusMapWidget> createState() => _CampusMapWidgetState();
}

class _CampusMapWidgetState extends State<CampusMapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Marker> _highlightMarkers = {};
  String? _currentHighlightLabel;
  bool _locationGranted = false;
  bool _mapReady = false;
  bool _legendOpen = false;

  static const LatLng _campusCenter = LatLng(-1.264627, 36.727029);

  @override
  void initState() {
    super.initState();
    _rebuildMarkers();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;
    if (status.isGranted) {
      if (mounted) setState(() => _locationGranted = true);
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (mounted) {
      setState(() => _locationGranted = status.isGranted);
      if (!status.isGranted && status.isPermanentlyDenied) {
        openAppSettings();
      }
    }
  }

  @override
  void didUpdateWidget(CampusMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightId != oldWidget.highlightId ||
        widget.highlightLabel != oldWidget.highlightLabel) {
      _rebuildMarkers();
      if (widget.highlightId != null) {
        Future.microtask(() => _zoomToLocation(widget.highlightId!));
      }
    }
  }

  void _rebuildMarkers() {
    final markers = <Marker>{};
    final highlightMarkers = <Marker>{};

    for (final loc in campusLocations) {
      final isHighlighted = loc.id == widget.highlightId;
      final marker = Marker(
        markerId: MarkerId(loc.id),
        position: LatLng(loc.lat, loc.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isHighlighted ? BitmapDescriptor.hueYellow : _hueForType(loc.type),
        ),
        infoWindow: InfoWindow(
          title: loc.name,
          snippet: isHighlighted && widget.highlightLabel != null
              ? '📍 ${widget.highlightLabel}'
              : loc.description,
        ),
        onTap: () => _showLocationInfo(loc),
      );

      if (isHighlighted) {
        highlightMarkers.add(marker);
      } else {
        markers.add(marker);
      }
    }

    _markers = markers;
    _highlightMarkers = highlightMarkers;
    _currentHighlightLabel = widget.highlightLabel;
    if (mounted) setState(() {});
  }

  double _hueForType(LocationType type) {
    switch (type) {
      case LocationType.adminOffice:
        return BitmapDescriptor.hueBlue;
      case LocationType.academicBlock:
        return BitmapDescriptor.hueOrange;
      case LocationType.lab:
        return BitmapDescriptor.hueGreen;
      case LocationType.workshop:
        return BitmapDescriptor.hueViolet;
      case LocationType.departmentOffice:
        return BitmapDescriptor.hueCyan;
      case LocationType.staffRoom:
        return BitmapDescriptor.hueRose;
      case LocationType.library:
        return BitmapDescriptor.hueCyan;
      case LocationType.hall:
        return BitmapDescriptor.hueMagenta;
      case LocationType.hostel:
        return BitmapDescriptor.hueRed;
      case LocationType.medBay:
        return BitmapDescriptor.hueRed;
      case LocationType.busPark:
        return BitmapDescriptor.hueAzure;
      case LocationType.sportsField:
        return BitmapDescriptor.hueGreen;
      case LocationType.cafeteria:
        return BitmapDescriptor.hueYellow;
      case LocationType.other:
        return BitmapDescriptor.hueBlue;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() => _mapReady = true);
    if (widget.highlightId != null) {
      _zoomToLocation(widget.highlightId!);
    }
  }

  void _zoomToLocation(String locationId) {
    final loc = campusLocations.where((l) => l.id == locationId).firstOrNull;
    if (loc == null) return;

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(loc.lat, loc.lng), 18.0),
    );
  }

  void _showLocationInfo(CampusLocation loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(iconForType(loc.type), color: loc.color),
            const SizedBox(width: 12),
            Expanded(child: Text(loc.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.description),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorForType(loc.type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                labelForType(loc.type),
                style: TextStyle(color: colorForType(loc.type), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _campusCenter,
            zoom: 16.0,
            tilt: 0.0,
            bearing: 0.0,
          ),
          onMapCreated: _onMapCreated,
          markers: {..._markers, ..._highlightMarkers},
          myLocationEnabled: _locationGranted,
          myLocationButtonEnabled: _locationGranted,
          compassEnabled: true,
          mapToolbarEnabled: false,
          mapType: MapType.satellite,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          minMaxZoomPreference: const MinMaxZoomPreference(15.0, 21.0),
          onTap: (_) {
            setState(() => _currentHighlightLabel = null);
          },
        ),
        if (!_mapReady)
          const Center(child: CircularProgressIndicator()),
        if (_mapReady && !_locationGranted)
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'location_permission',
                  backgroundColor: Colors.white,
                  onPressed: _requestLocationPermission,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
              ],
            ),
          ),
        Positioned(
          right: 16,
          bottom: 200,
          child: FloatingActionButton.small(
            heroTag: 'legend_toggle',
            backgroundColor: Colors.white,
            onPressed: () => setState(() => _legendOpen = !_legendOpen),
            child: Icon(_legendOpen ? Icons.map : Icons.layers, color: Colors.blueGrey),
          ),
        ),
        if (_legendOpen)
          Positioned(
            top: 16,
            right: 16,
            left: 16,
            bottom: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.map, size: 20),
                          const SizedBox(width: 8),
                          const Text('Campus Map Legend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => setState(() => _legendOpen = false),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: _buildLegendGroups(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_currentHighlightLabel != null)
          Positioned(
            top: 16,
            left: 16,
            right: 72,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentHighlightLabel!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _currentHighlightLabel = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildLegendGroups() {
    final grouped = <LocationType, List<CampusLocation>>{};
    for (final loc in campusLocations) {
      grouped.putIfAbsent(loc.type, () => []).add(loc);
    }
    final sortedTypes = grouped.keys.toList()
      ..sort((a, b) => grouped[b]!.length.compareTo(grouped[a]!.length));

    return [
      for (final type in sortedTypes) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(iconForType(type), size: 18, color: colorForType(type)),
              const SizedBox(width: 8),
              Text(
                labelForType(type),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: colorForType(type),
                ),
              ),
              const Spacer(),
              Text(
                '${grouped[type]!.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        ...grouped[type]!.map((loc) => InkWell(
          onTap: () {
            setState(() {
              _currentHighlightLabel = loc.name;
              _legendOpen = false;
            });
            _zoomToLocation(loc.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: colorForType(type).withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(loc.name, style: const TextStyle(fontSize: 13)),
                ),
                Icon(Icons.zoom_in, size: 14, color: Colors.grey[400]),
              ],
            ),
          ),
        )),
        const SizedBox(height: 4),
      ],
    ];
  }
}
