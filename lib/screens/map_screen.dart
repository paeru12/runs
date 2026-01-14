import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/running_session.dart';

class MapScreen extends StatefulWidget {
  final RunningSession session;

  const MapScreen({super.key, required this.session});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  void _initializeMap() {
    if (widget.session.routePoints.isEmpty) return;

    final points = widget.session.routePoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Colors.blue,
        width: 5,
      ),
    };

    if (points.isNotEmpty) {
      _markers = {
        Marker(
          markerId: const MarkerId('start'),
          position: points.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: points.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'End'),
        ),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.routePoints.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Route Map'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('No route data available'),
        ),
      );
    }

    final initialPosition = LatLng(
      widget.session.routePoints.first.latitude,
      widget.session.routePoints.first.longitude,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map'),
        centerTitle: true,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialPosition,
          zoom: 15,
        ),
        polylines: _polylines,
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
          _fitMapToRoute();
        },
        myLocationButtonEnabled: true,
        myLocationEnabled: false,
        mapType: MapType.normal,
      ),
    );
  }

  void _fitMapToRoute() {
    if (widget.session.routePoints.isEmpty || _mapController == null) return;

    double minLat = widget.session.routePoints.first.latitude;
    double maxLat = widget.session.routePoints.first.latitude;
    double minLng = widget.session.routePoints.first.longitude;
    double maxLng = widget.session.routePoints.first.longitude;

    for (var point in widget.session.routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
