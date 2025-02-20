// import 'package:conductor/authentication/login_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newproject/authentication/login_page.dart';
import 'journey_map_screen.dart';
import 'package:geolocator/geolocator.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  _DriverHomePageState createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool journeyAccepted = false;
  String? journeyId;
  bool isLoading = true;
  bool hasJourney = false;
  bool canAcceptJourney = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _checkJourneyStatus();
  }

  Future<void> _checkJourneyStatus() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        var userData = userDoc.data() as Map<String, dynamic>;
        var currentJourney = userData['currentJourneyId'];
        var acceptedJourney = userData['acceptedJourney'] ?? false;

        if (currentJourney != null) {
          setState(() {
            journeyId = currentJourney;
            journeyAccepted = acceptedJourney;
            canAcceptJourney = !acceptedJourney;
          });
        }
      }
    }
  }

  Future<void> _acceptJourney() async {
    User? user = _auth.currentUser;
    if (user != null && journeyId != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'acceptedJourney': true,
        'isOnJourney': true,
      });
      await _firestore.collection('journeys').doc(journeyId).update({
        'status': 'active',
      });
      setState(() {
        journeyAccepted = true;
      });
      _navigateToJourneyMap();
    }
  }

  void _navigateToJourneyMap() {
    if (journeyId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => JourneyMapScreen(),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _checkLocationAndNavigation(BuildContext context) async {
    bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();

    if (!isLocationEnabled) {
      _showLocationDialog(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (builder) => JourneyMapScreen()),
      );
    }
  }

  void _showLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Required'),
          content: Text('Please turn on location service to continue.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openLocationSettings();
              },
              child: Text('Turn On'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      drawer: NavigationDrawer(
        backgroundColor: const Color(0xFFF5F7FA),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF6C63FF),
                  child: Text(
                    currentUser?.email?[0].toUpperCase() ?? '0',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  currentUser?.email ?? 'driver',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Driver',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          NavigationDrawerDestination(
            icon: const Icon(Icons.dashboard),
            label: Text(
              'Dashboard',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.work),
            label: Text(
              'Employeer Info',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'App Management',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.settings),
            label: Text(
              'Settings',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.help),
            label: Text(
              'Help & Support',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              _logout(context);
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF6c63ff),
            expandedHeight: 120,
            floating: true,
            pinned: true,
            leading: IconButton(
              icon: const Icon(
                Icons.menu,
                color: Colors.white,
              ),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Driver Dashboard',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications,
                  color: Colors.white,
                ),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        'Available',
                        '0',
                        Icons.pending_actions,
                        const Color(0xFFFFA726),
                      ),
                      _buildStatCard(
                        'Completed',
                        '12',
                        Icons.local_shipping,
                        const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!journeyAccepted && journeyId != null && canAcceptJourney)
                    Container(
                      width: double.infinity,
                      height: 56,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: ElevatedButton.icon(
                        onPressed: _acceptJourney,
                        icon: const Icon(
                          Icons.map,
                          color: Colors.green,
                        ),
                        label: Text(
                          'Accept Journey',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (journeyAccepted)
                    Container(
                      width: double.infinity,
                      height: 56,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: ElevatedButton.icon(
                        onPressed: () => _checkLocationAndNavigation(context),
                        icon: const Icon(
                          Icons.map,
                          color: Colors.green,
                        ),
                        label: Text(
                          'Go To Map',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (journeyId == null)
                    Center(
                      child: Text(
                        'No Journies Available',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(height: 20),
                  if (journeyId == null)
                    Container(
                      width: double.infinity,
                      height: 56,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (builder) => JourneyMapScreen()));
                        },
                        icon: const Icon(Icons.local_shipping,
                            color: Colors.white, size: 30),
                        label: Text(
                          'Request Journey',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(55, 158, 158, 158),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
