import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_webservice/directions.dart' as gmaps;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:newproject/static/api_keys.dart';
import 'package:newproject/views/driver/driver_home_page.dart';

class JourneyMapScreen extends StatefulWidget {
  const JourneyMapScreen({super.key});

  @override
  _JourneyMapScreenState createState() => _JourneyMapScreenState();
}

class _JourneyMapScreenState extends State<JourneyMapScreen> {
  GoogleMapController? _mapController;
  Location _location = Location();
  LatLng? _currentLocation;
  LatLng? _destination;
  Set<Polyline> _polylines = {};
  List<String> _instructions = [];
  String _latestInstruction = "Fetching route...";

  @override
  void initState() {
    super.initState();
    _fetchJourneyDetails();
    _getCurrentLocation();
  }

  Future<void> _fetchJourneyDetails() async {
    try {
      QuerySnapshot journeySnapshot = await FirebaseFirestore.instance
          .collection('journeys')
          .limit(1)
          .get();

      if (journeySnapshot.docs.isNotEmpty) {
        var journeyData =
            journeySnapshot.docs.first.data() as Map<String, dynamic>;
        GeoPoint endGeoPoint = journeyData['endLocation'];

        setState(() {
          _destination = LatLng(endGeoPoint.latitude, endGeoPoint.longitude);
        });
      }
    } catch (e) {
      print("Error fetching journey details: $e");
    }
  }

  void _getCurrentLocation() async {
    var locationData = await _location.getLocation();
    String driverID =
        "aZyfMm3M6jbFp9x1hAM6Lw6QZUU2"; // Replace with actual driver ID from auth

    setState(() {
      _currentLocation =
          LatLng(locationData.latitude!, locationData.longitude!);
    });

    // Update Firestore with the first location fetch
    FirebaseFirestore.instance.collection('users').doc(driverID).update({
      'latitude': locationData.latitude,
      'longitude': locationData.longitude,
    });

    // Start listening for location updates
    _location.onLocationChanged.listen((newLoc) {
      setState(() {
        _currentLocation = LatLng(newLoc.latitude!, newLoc.longitude!);
      });

      // Update Firestore with the new location
      FirebaseFirestore.instance.collection('users').doc(driverID).update({
        'latitude': newLoc.latitude,
        'longitude': newLoc.longitude,
      });

      _updateRoute(); // Keep updating the route
    });
  }

  Future<void> _updateRoute() async {
    if (_currentLocation == null || _destination == null) return;
    final directions = gmaps.GoogleMapsDirections(apiKey: googleMapsApiKey);
    final result = await directions.directionsWithLocation(
      gmaps.Location(
          lat: _currentLocation!.latitude, lng: _currentLocation!.longitude),
      gmaps.Location(lat: _destination!.latitude, lng: _destination!.longitude),
      travelMode: gmaps.TravelMode.driving,
    );

    if (result.status == "OK" && result.routes.isNotEmpty) {
      final route = result.routes.first;
      final List<LatLng> routeCoords = [];
      final List<String> instructions = [];

      for (var leg in route.legs) {
        for (var step in leg.steps) {
          routeCoords
              .add(LatLng(step.startLocation.lat, step.startLocation.lng));
          routeCoords.add(LatLng(step.endLocation.lat, step.endLocation.lng));

          instructions.add(step.htmlInstructions
              .replaceAll(RegExp(r'<[^>]*>'), '')); // Remove HTML tags
        }
      }

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            points: routeCoords,
            color: Colors.blue,
            width: 5,
          ),
        );
        _instructions = instructions;
        if (_instructions.isNotEmpty) {
          _latestInstruction =
              _instructions.first; // Show the first upcoming instruction
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Makes app bar overlay the map
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 38),
          onPressed: () {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (builder) =>
                        DriverHomePage())); // Navigate back to driver homepage
          },
        ),
      ),
      body: Stack(
        children: [
          _currentLocation == null || _destination == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation!,
                    zoom: 12,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId("destination"),
                      position: _destination!,
                      infoWindow: const InfoWindow(title: "Destination"),
                    ),
                    if (_currentLocation != null)
                      Marker(
                        markerId: const MarkerId("current"),
                        position: _currentLocation!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueBlue),
                        infoWindow: const InfoWindow(title: "Your Location"),
                      ),
                  },
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                ),

          // Styled Google Maps-like Navigation Instruction at Bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 100,
              width: double.infinity,
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.navigation,
                    size: 30,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _latestInstruction,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
