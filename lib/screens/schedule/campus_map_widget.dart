import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  String? _currentHighlightId;
  String? _currentHighlightLabel;

  static const LatLng _campusCenter = LatLng(-1.264627, 36.727029);

  @override
  void initState() {
    super.initState();
    _rebuildMarkers();
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
    _currentHighlightId = widget.highlightId;
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

  void _zoomToLocation(String locationId) {
    final loc = campusLocations.where((l) => l.id == locationId).firstOrNull;
    if (loc == null) return;

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(loc.lat, loc.lng),
        18.0,
      ),
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
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            if (widget.highlightId != null) {
              _zoomToLocation(widget.highlightId!);
            }
          },
          markers: {..._markers, ..._highlightMarkers},
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapType: MapType.satellite,
          mapToolbarEnabled: false,
        ),
        if (_currentHighlightLabel != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white.withValues(alpha: 0.9),
              child: Padding(
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
                      onPressed: () {
                        setState(() {
                          _currentHighlightLabel = null;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              'Tap a marker for details',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                backgroundColor: Colors.black54,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
