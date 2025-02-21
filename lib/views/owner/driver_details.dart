import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:newproject/views/driver/journey_map_screen.dart';
import 'package:newproject/views/owner/start_journey_screen.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverDetails extends StatefulWidget {
  final String driverID;

  DriverDetails({super.key, required this.driverID});

  @override
  State<DriverDetails> createState() => _DriverDetailsState();
}

class _DriverDetailsState extends State<DriverDetails> {
  Map<String, dynamic>? driverData;
  Color statusColor = Colors.green;
  String statusText = "Available";
  String centerText = " ";
  String buttonText = " ";
  Icon buttonIcon = Icon(Icons.map);

  @override
  void initState() {
    super.initState();
    fetchDriverDetails();
  }

  Future<void> fetchDriverDetails() async {
    try {
      DocumentSnapshot driverSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.driverID)
          .get();

      if (driverSnapshot.exists && driverSnapshot.data() != null) {
        setState(() {
          driverData = driverSnapshot.data() as Map<String, dynamic>;

          if (driverData!['isOnJourney'] == true) {
            statusColor = Colors.red;
            statusText = "On Journey";
            centerText = "Driver On Journey!";
            buttonText = "Driver Tracking Map";
            buttonIcon = Icon(Icons.map, color: Colors.white, size: 30);
          } else if (driverData!['currentJourneyId'] != null &&
              driverData!['acceptedJourney'] == false) {
            statusColor = Colors.orange;
            statusText = "Pending";
            centerText = "Journey Confirmation Pending!";
            buttonText = "Click to Cancel Journey";
            buttonIcon = Icon(Icons.cancel, color: Colors.red, size: 30);
          } else {
            statusColor = Colors.green;
            statusText = "Available";
            centerText = "Driver Available For Journey";
            buttonText = "Assign Journey";
            buttonIcon =
                Icon(Icons.local_shipping, color: Colors.green, size: 30);
          }
        });
      } else {
        debugPrint('Driver data not found');
      }
    } catch (e) {
      debugPrint('Error fetching driver details: $e');
    }
  }

  void _callDriver() async {
    if (driverData != null && driverData!['phoneNumber'] != null) {
      final String phoneNumber =
          driverData!['phoneNumber']; // Extract phone number
      final String phoneUri = 'tel:$phoneNumber';
      if (await canLaunchUrlString(phoneUri)) {
        await launchUrlString(phoneUri);
      } else {
        debugPrint('Could not launch dialer');
      }
    } else {
      debugPrint('Driver phone number not available');
    }
  }

  void _ownerToDriverActions() async {
    if (driverData?['isOnJourney'] == true) {
      Navigator.push(
          context, MaterialPageRoute(builder: (builder) => JourneyMapScreen()));
    } else if (driverData?['currentJourneyId'] != null &&
        driverData?['acceptedJourney'] == false) {
      await _deletePendingJourneys(widget.driverID);
      sendNotificationToDriver(widget.driverID, "A journey was cancelled by owner.");
      Navigator.pop(context);
    } else {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.driverID)
            .get();

        if (!userDoc.exists || userDoc.data() == null) {
          debugPrint("User document does not exist.");
          return;
        }

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        String companyId =
            userData.containsKey('companyId') ? userData['companyId'] : '';

        if (companyId.isEmpty) {
          debugPrint("Company ID is empty or missing.");
          return;
        }

        DocumentSnapshot companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();

        if (!companyDoc.exists || companyDoc.data() == null) {
          debugPrint("Company document does not exist.");
          return;
        }

        Map<String, dynamic> companyData =
            companyDoc.data() as Map<String, dynamic>;

        debugPrint("Company document data: $companyData");

        // Fix field name (ownerId instead of ownerID)
        String ownerId =
            companyData.containsKey('ownerId') ? companyData['ownerId'] : '';

        String companyName = companyData.containsKey('companyName')
            ? companyData['companyName']
            : '';

        if (ownerId.isEmpty) {
          debugPrint("Owner ID is missing from company document.");
          return;
        }

        debugPrint("Navigating to StartJourneyScreen...");

        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (builder) => StartJourneyScreen(
                  driverID: widget.driverID,
                  ownerId: ownerId,
                  companyName: companyName),
            ));
      } catch (e) {
        debugPrint("Error in _ownerToDriverActions: $e");
      }
    }
  }

  Future<void> _deletePendingJourneys(String driverID) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('journeys')
          .where('driverID', isEqualTo: driverID)
          .where('status', isEqualTo: 'assigned') // change to assigned
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      await firestore.collection('users').doc(driverID).update({
        'acceptedJourney': FieldValue.delete(),
        'currentJourneyId': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pending journeys deleted and user updated successfully!',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.pink.shade100,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.pink.shade100,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void sendNotificationToDriver(String driverID, String message) {
    FirebaseFirestore.instance.collection('notifications').add({
      'userId': driverID,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    }).then((value) {
      print('Notification Sent Successfully');
    }).catchError((error) {
      print('Failed to send Notification: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: const Color(0xFF6C63FF),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Driver Details',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.call, color: Colors.white, size: 28),
                onPressed: _callDriver,
              ),
            ],
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: driverData == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: driverData!['imageUrl'] != null
                                      ? Image.network(
                                          driverData!['imageUrl'],
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.person, size: 100),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driverData!['name'] ?? 'N/A',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(driverData!['email'] ?? 'N/A',
                                        style:
                                            GoogleFonts.poppins(fontSize: 14)),
                                    Text(
                                      'Joined: ${driverData!['createdAt'] != null ? DateFormat('dd MMM yyyy').format((driverData!['createdAt'] as Timestamp).toDate()) : 'N/A'}',
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                    Text(
                                      'Journeys Completed: ${driverData!['journeysCompleted'] ?? 0}',
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                centerText,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 24),
                          child: ElevatedButton.icon(
                            onPressed: _ownerToDriverActions,
                            icon: buttonIcon,
                            label: Text(
                              buttonText,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        Text(
                          'Driver History',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        driverData!['journeyHistory'] != null &&
                                (driverData!['journeyHistory'] as List)
                                    .isNotEmpty
                            ? Table(
                                border: TableBorder.all(color: Colors.grey),
                                columnWidths: const {
                                  0: FlexColumnWidth(2),
                                  1: FlexColumnWidth(3),
                                  2: FlexColumnWidth(2),
                                },
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade300),
                                    children: [
                                      tableCell('Date', isHeader: true),
                                      tableCell('Destination', isHeader: true),
                                      tableCell('Status', isHeader: true),
                                    ],
                                  ),
                                  ...driverData!['journeyHistory']
                                      .map<TableRow>((journey) {
                                    return tableRow(
                                      journey['date'] ?? 'N/A',
                                      journey['destination'] ?? 'N/A',
                                      journey['status'] ?? 'Pending',
                                    );
                                  }).toList(),
                                ],
                              )
                            : Center(
                                child: Text(
                                  'No history available',
                                  style: GoogleFonts.poppins(fontSize: 14),
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

  TableRow tableRow(String date, String destination, String status) {
    return TableRow(
      children: [
        tableCell(date),
        tableCell(destination),
        tableCell(status,
            color: status == 'Completed' ? Colors.green : Colors.orange),
      ],
    );
  }

  Widget tableCell(String text, {bool isHeader = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black,
        ),
      ),
    );
  }
}
