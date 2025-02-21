import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_webservice/directions.dart' as gmaps;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:newproject/static/api_keys.dart';

class OwnerTrackingScreen extends StatefulWidget {
  final String driverID;

  const OwnerTrackingScreen({super.key, required this.driverID});

  @override
  _OwnerTrackingScreenState createState() => _OwnerTrackingScreenState();
}

class _OwnerTrackingScreenState extends State<OwnerTrackingScreen> {
  GoogleMapController? _mapController;
  Location _location = Location();
  LatLng? _driverLocation;
  LatLng? _startLocation;
  LatLng? _endLocation;
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    debugPrint(
        "OwnerTrackingScreen initialized with driverID: ${widget.driverID}");
    _fetchJourneyDetails();
    _trackDriverLocation();
  }

  Future<void> _fetchJourneyDetails() async {
    print("Current user: ${FirebaseAuth.instance.currentUser?.uid}");

    try {
      debugPrint("Fetching journey details for driverID: ${widget.driverID}");
      QuerySnapshot journeySnapshot = await FirebaseFirestore.instance
          .collection('journeys')
          .where('driverID', isEqualTo: widget.driverID)
          .limit(1)
          .get();

      if (journeySnapshot.docs.isNotEmpty) {
        debugPrint("Journey found for driverID: ${widget.driverID}");
        var journeyData =
            journeySnapshot.docs.first.data() as Map<String, dynamic>;
        GeoPoint startGeoPoint = journeyData['startLocation'];
        GeoPoint endGeoPoint = journeyData['endLocation'];

        setState(() {
          _startLocation =
              LatLng(startGeoPoint.latitude, startGeoPoint.longitude);
          _endLocation = LatLng(endGeoPoint.latitude, endGeoPoint.longitude);
        });
        debugPrint(
            "Start Location: $_startLocation, End Location: $_endLocation");
        _updateRoutes();
      } else {
        debugPrint("No journey found for driverID: ${widget.driverID}");
      }
    } catch (e) {
      print("Error fetching journey details: $e");
    }
  }

  void _trackDriverLocation() {
    debugPrint("Tracking location for driverID: ${widget.driverID}");

    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.driverID)
        .snapshots()
        .listen((driverSnapshot) {
      if (driverSnapshot.exists) {
        var driverData = driverSnapshot.data();
        if (driverData?['latitude'] != null &&
            driverData?['longitude'] != null) {
          setState(() {
            _driverLocation =
                LatLng(driverData!['latitude'], driverData['longitude']);
          });
          debugPrint("Driver location updated: $_driverLocation");
          _updateRoutes();
        }
      } else {
        debugPrint("Driver data not found for driverID: ${widget.driverID}");
      }
    });
  }

  Future<void> _updateRoutes() async {
    if (_startLocation == null ||
        _endLocation == null ||
        _driverLocation == null) return;
    final directions = gmaps.GoogleMapsDirections(apiKey: googleMapsApiKey);

    // Get route between driver and end location
    final driverToEndResult = await directions.directionsWithLocation(
      gmaps.Location(
          lat: _driverLocation!.latitude, lng: _driverLocation!.longitude),
      gmaps.Location(lat: _endLocation!.latitude, lng: _endLocation!.longitude),
      travelMode: gmaps.TravelMode.driving,
    );

    // Get route between start and end location
    final startToEndResult = await directions.directionsWithLocation(
      gmaps.Location(
          lat: _startLocation!.latitude, lng: _startLocation!.longitude),
      gmaps.Location(lat: _endLocation!.latitude, lng: _endLocation!.longitude),
      travelMode: gmaps.TravelMode.driving,
    );

    Set<Polyline> newPolylines = {};

    if (driverToEndResult.status == "OK" &&
        driverToEndResult.routes.isNotEmpty) {
      final route = driverToEndResult.routes.first;
      List<LatLng> routeCoords = [];
      for (var leg in route.legs) {
        for (var step in leg.steps) {
          routeCoords
              .add(LatLng(step.startLocation.lat, step.startLocation.lng));
          routeCoords.add(LatLng(step.endLocation.lat, step.endLocation.lng));
        }
      }
      newPolylines.add(Polyline(
        polylineId: const PolylineId("driver_to_end"),
        points: routeCoords,
        color: Colors.blue,
        width: 5,
      ));
    }

    if (startToEndResult.status == "OK" && startToEndResult.routes.isNotEmpty) {
      final route = startToEndResult.routes.first;
      List<LatLng> routeCoords = [];
      for (var leg in route.legs) {
        for (var step in leg.steps) {
          routeCoords
              .add(LatLng(step.startLocation.lat, step.startLocation.lng));
          routeCoords.add(LatLng(step.endLocation.lat, step.endLocation.lng));
        }
      }
      newPolylines.add(Polyline(
        polylineId: const PolylineId("start_to_end"),
        points: routeCoords,
        color: Colors.green,
        width: 5,
      ));
    }

    setState(() {
      _polylines = newPolylines;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Driver"),
      ),
      body: Stack(
        children: [
          _startLocation == null ||
                  _endLocation == null ||
                  _driverLocation == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _driverLocation!,
                    zoom: 12,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId("start"),
                      position: _startLocation!,
                      icon: BitmapDescriptor.defaultMarker,
                      infoWindow: const InfoWindow(title: "Start Location"),
                    ),
                    Marker(
                      markerId: const MarkerId("end"),
                      position: _endLocation!,
                      icon: BitmapDescriptor.defaultMarker,
                      infoWindow: const InfoWindow(title: "End Location"),
                    ),
                    Marker(
                      markerId: const MarkerId("driver"),
                      position: _driverLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue),
                      infoWindow: const InfoWindow(title: "Driver"),
                    ),
                  },
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                ),
        ],
      ),
    );
  }
}
