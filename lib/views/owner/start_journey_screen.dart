import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_maps_webservice/places.dart' as gmws;
import 'package:google_maps_webservice/directions.dart' as gmd;
import 'package:newproject/static/api_keys.dart';
import 'package:newproject/views/owner/owner_home_page.dart';

class StartJourneyScreen extends StatefulWidget {
  final String driverID;
  final String ownerId;
  final String companyName;

  const StartJourneyScreen({
    super.key,
    required this.driverID,
    required this.ownerId,
    required this.companyName,
  });

  @override
  State<StartJourneyScreen> createState() => _StartJourneyScreenState();
}

class _StartJourneyScreenState extends State<StartJourneyScreen> {
  late GoogleMapController mapController;
  LatLng? startLocation;
  LatLng? endLocation;
  String? selectingType;
  final Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
  gmws.GoogleMapsPlaces? _places;

  @override
  void initState() {
    super.initState();
    _places = gmws.GoogleMapsPlaces(apiKey: googleMapsApiKey);

    // Add listeners to clear suggestions when input is empty
    startController.addListener(() {
      if (startController.text.isEmpty) {
        setState(() {}); // Forces rebuild to remove suggestions
      }
    });

    endController.addListener(() {
      if (endController.text.isEmpty) {
        setState(() {}); // Forces rebuild to remove suggestions
      }
    });
  }

  @override
  void dispose() {
    startController.dispose();
    endController.dispose();
    _places?.dispose();
    super.dispose();
  }

  void _selectLocation(String type) {
    setState(() {
      selectingType = type;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tap on the map to select the $type location'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _setLocation(String type, dynamic predictionData) async {
    String? placeId = predictionData.placeId;
    String? description = predictionData.description;

    if (placeId == null) return;

    final detail = await _places!.getDetailsByPlaceId(placeId);

    if (detail.result.geometry?.location == null) return;

    final location = LatLng(
      detail.result.geometry!.location.lat,
      detail.result.geometry!.location.lng,
    );

    setState(() {
      if (type == "start") {
        startLocation = location;
        startController.text = description ?? '';
        _updateMarker('start', location, BitmapDescriptor.hueGreen);
      } else {
        endLocation = location;
        endController.text = description ?? '';
        _updateMarker('end', location, BitmapDescriptor.hueRed);
      }
    });

    if (startLocation != null && endLocation != null) {
      _updateCameraToShowMarkers();
      _addIntermediateMarkersAndRoute();
    }
  }

  Future<void> _addIntermediateMarkersAndRoute() async {
    if (startLocation == null || endLocation == null) return;

    final directions = gmd.GoogleMapsDirections(apiKey: googleMapsApiKey);
    final result = await directions.directionsWithLocation(
      gmd.Location(lat: startLocation!.latitude, lng: startLocation!.longitude),
      gmd.Location(lat: endLocation!.latitude, lng: endLocation!.longitude),
      travelMode: gmd.TravelMode.driving,
    );

    if (result.isOkay && result.routes.isNotEmpty) {
      final route = result.routes.first;
      final List<LatLng> routePoints =
          _decodePolyline(route.overviewPolyline.points);

      setState(() {
        // Clear previous markers & polylines
        markers.clear();
        polylines.clear();

        // Add start and end markers
        markers.add(Marker(
          markerId: const MarkerId('start'),
          position: startLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ));
        markers.add(Marker(
          markerId: const MarkerId('end'),
          position: endLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));

        // Add polyline (highlighted path)
        polylines.add(Polyline(
          polylineId: const PolylineId("route"),
          points: routePoints,
          color: Colors.blue,
          width: 5,
        ));
      });
    }
  }

  /// Decodes polyline points from Google API response
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  void _updateMarker(String id, LatLng position, double hue) {
    markers.removeWhere((marker) => marker.markerId.value == id);
    markers.add(Marker(
      markerId: MarkerId(id),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
    ));
  }

  Future<void> _updateCameraToShowMarkers() async {
    if (startLocation == null || endLocation == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        startLocation!.latitude < endLocation!.latitude
            ? startLocation!.latitude
            : endLocation!.latitude,
        startLocation!.longitude < endLocation!.longitude
            ? startLocation!.longitude
            : endLocation!.longitude,
      ),
      northeast: LatLng(
        startLocation!.latitude > endLocation!.latitude
            ? startLocation!.latitude
            : endLocation!.latitude,
        startLocation!.longitude > endLocation!.longitude
            ? startLocation!.longitude
            : endLocation!.longitude,
      ),
    );

    await mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0),
    );
  }

  Future<void> _confirmJourney() async {
    if (startLocation == null || endLocation == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final journeyRef =
          FirebaseFirestore.instance.collection('journeys').doc();
      batch.set(journeyRef, {
        'companyName': widget.companyName,
        'driverID': widget.driverID,
        'ownerID': widget.ownerId,
        'startLocation':
            GeoPoint(startLocation!.latitude, startLocation!.longitude),
        'endLocation': GeoPoint(endLocation!.latitude, endLocation!.longitude),
        'status': 'assigned',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final driverRef =
          FirebaseFirestore.instance.collection('users').doc(widget.driverID);
      batch.update(driverRef, {
        'currentJourneyId': journeyRef.id,
        'isOnJourney': false,
        'acceptedJourney': false,
      });

      await batch.commit();

      // Ensure UI update happens in the main thread
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Journey sent to driver')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (builder) => OwnerHomePage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error confirming journey: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Journey')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                GooglePlaceAutoCompleteTextField(
                  textEditingController: startController,
                  googleAPIKey: googleMapsApiKey,
                  inputDecoration: const InputDecoration(
                    labelText: "Start Location",
                    border: OutlineInputBorder(),
                  ),
                  debounceTime: 800,
                  countries: const ["in"],
                  isLatLngRequired: true,
                  getPlaceDetailWithLatLng: (prediction) {
                    _setLocation("start", prediction);
                  },
                  itemClick: (prediction) {
                    startController.text = prediction.description ?? '';
                    _setLocation("start", prediction);
                  },
                ),
                const SizedBox(height: 10),
                GooglePlaceAutoCompleteTextField(
                  textEditingController: endController,
                  googleAPIKey: googleMapsApiKey,
                  inputDecoration: const InputDecoration(
                    labelText: "End Location",
                    border: OutlineInputBorder(),
                  ),
                  debounceTime: 800,
                  countries: const ["in"],
                  isLatLngRequired: true,
                  getPlaceDetailWithLatLng: (prediction) {
                    _setLocation("end", prediction);
                  },
                  itemClick: (prediction) {
                    endController.text = prediction.description ?? '';
                    _setLocation("end", prediction);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(20.5937, 78.9629), // Center of India
                zoom: 9,
              ),
              markers: markers,
              polylines: polylines,
              onTap: (LatLng tappedLocation) {
                if (selectingType != null) {
                  setState(() {
                    if (selectingType == "start") {
                      startLocation = tappedLocation;
                      startController.text =
                          "Lat: ${tappedLocation.latitude}, Lng: ${tappedLocation.longitude}";
                      _updateMarker(
                          'start', tappedLocation, BitmapDescriptor.hueGreen);
                    } else {
                      endLocation = tappedLocation;
                      endController.text =
                          "Lat: ${tappedLocation.latitude}, Lng: ${tappedLocation.longitude}";
                      _updateMarker(
                          'end', tappedLocation, BitmapDescriptor.hueRed);
                    }
                    selectingType = null;
                    _updateCameraToShowMarkers();
                    _addIntermediateMarkersAndRoute();
                  });
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmJourney,
                child: const Text('Assign Journey'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "startLocation",
            onPressed: () {
              _selectLocation("start");
            },
            backgroundColor: Colors.green,
            child: const Icon(Icons.location_on),
          ),
          const SizedBox(height: 10), // Space between buttons
          FloatingActionButton(
            heroTag: "endLocation",
            onPressed: () {
              _selectLocation("end");
            },
            backgroundColor: Colors.red,
            child: const Icon(Icons.location_on),
          ),
        ],
      ),
    );
  }
}
