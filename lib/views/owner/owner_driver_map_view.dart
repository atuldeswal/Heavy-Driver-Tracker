import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'start_journey_screen.dart';

class OwnerDriverMapView extends StatefulWidget {
  final String driverID;
  const OwnerDriverMapView({super.key, required this.driverID});

  @override
  _OwnerDriverMapViewState createState() => _OwnerDriverMapViewState();
}

class _OwnerDriverMapViewState extends State<OwnerDriverMapView> {
  late GoogleMapController mapController;
  LatLng? driverLocation;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDriverLocation();
  }

  Future<void> fetchDriverLocation() async {
    DocumentSnapshot driverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.driverID)
        .get();

    if (driverDoc.exists) {
      setState(() {
        driverLocation = LatLng(
          driverDoc['lat'], // Ensure these fields exist in Firestore
          driverDoc['lng'],
        );
        isLoading = false;
      });
    }
  }

  Future<Map<String, String>> getOwnerDetails() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return {}; // Handle case where user is not logged in

    var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return {};

    return {
      'ownerId': doc.id,
      'companyName': doc['companyName'] ?? '',
    };
  }

  void navigateToStartJourney() async {
    var ownerDetails = await getOwnerDetails();
    if (ownerDetails.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StartJourneyScreen(
            driverID: widget.driverID,
            ownerId: ownerDetails['ownerId']!,
            companyName: ownerDetails['companyName']!,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch owner details")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Location')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: driverLocation!,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('driver'),
                  position: driverLocation!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue),
                ),
              },
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: navigateToStartJourney,
        label: const Text("Assign Journey"),
        icon: const Icon(Icons.directions),
      ),
    );
  }
}
