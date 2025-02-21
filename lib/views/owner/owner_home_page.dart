import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newproject/authentication/add_driver_page.dart';
import 'package:newproject/authentication/login_page.dart';
import 'package:newproject/views/owner/driver_details.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {

  int driverCount = 0;
  int onJourneyCount = 0;
  int pendingDriverCount = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
void initState() {
  super.initState();
  fetchDriverStats();
}

  Future<void> fetchDriverStats() async {
  var user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint("fetchDriverStats: No authenticated user.");
    return;
  }

  try {
    debugPrint("fetchDriverStats: Fetching user document for userId: ${user.uid}");

    // Fetch the user's document to get the companyId
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      debugPrint("fetchDriverStats: User document does not exist.");
      return;
    }

    String companyId = userDoc.data()?['companyId'] ?? '';
    debugPrint("fetchDriverStats: Retrieved companyId: $companyId");

    if (companyId.isEmpty) {
      debugPrint("fetchDriverStats: Company ID is empty.");
      return;
    }

    // Query to count the number of drivers
    debugPrint("fetchDriverStats: Fetching driver count for companyId: $companyId");

    QuerySnapshot driverQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('accountType', isEqualTo: 'driver')
        .where('companyId', isEqualTo: companyId)
        .get();

    debugPrint("fetchDriverStats: Driver count retrieved: ${driverQuery.docs.length}");

    // Query to count the number of drivers on journey
    debugPrint("fetchDriverStats: Fetching count of drivers on journey for companyId: $companyId");

    QuerySnapshot journeyQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('accountType', isEqualTo: 'driver')
        .where('companyId', isEqualTo: companyId)
        .where('acceptedJourney', isEqualTo: true)
        .get();

    debugPrint("fetchDriverStats: Drivers on journey count retrieved: ${journeyQuery.docs.length}");

    QuerySnapshot pendingQuery = await FirebaseFirestore.instance
    .collection('users')
    .where('acceptedJourney', isEqualTo: false)
    .get();

    setState(() {
      driverCount = driverQuery.docs.length;
      onJourneyCount = journeyQuery.docs.length;
      pendingDriverCount = pendingQuery.docs.length;
    });
  } catch (e) {
    debugPrint("fetchDriverStats: Error fetching driver stats: $e");
  }
}


  void navigateToAddDriver(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDriverPage()),
    );
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

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;
    // final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7FA),
      drawer: NavigationDrawer(
        backgroundColor: Colors.white,
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
                    currentUser?.email?[0].toUpperCase() ?? 'O',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  currentUser?.email ?? 'Owner',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Owner',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          NavigationDrawerDestination(
            icon: const Icon(Icons.dashboard),
            label: Text('Dashboard',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.directions_car),
            label: Text('Drivers',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.route),
            label: Text('Active Routes',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.analytics),
            label: Text('Analytics',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
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
            icon: const Icon(Icons.settings),
            label: Text('Settings',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.help_outline),
            label: Text('Help & Support',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
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
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: const Color(0xFF6C63FF),
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Owner Dashboard',
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
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
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
                  // Stats Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        'Active Drivers',
                        '$driverCount',
                        Icons.people,
                        const Color(0xFF6C63FF),
                      ),
                      _buildStatCard(
                        'On Journey',
                        onJourneyCount.toString(),
                        Icons.local_shipping,
                        const Color(0xFF4CAF50),
                      ),
                      _buildStatCard(
                        'Pending',
                        pendingDriverCount.toString(),
                        Icons.pending_actions,
                        const Color(0xFFFFA726),
                      ),
                      _buildStatCard(
                        'Completed',
                        '45',
                        Icons.check_circle,
                        const Color(0xFF26A69A),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Add Driver Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ElevatedButton.icon(
                      onPressed: () => navigateToAddDriver(context),
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: Text(
                        "Add New Driver",
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
                        elevation: 2,
                      ),
                    ),
                  ),

                  // Drivers List Section
                  Text(
                    'Your Drivers',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Drivers List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('accountType', isEqualTo: 'driver')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const SliverFillRemaining(
                  child: Center(child: Text("Error loading drivers")),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      "No drivers available",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }

              // Filter drivers based on companyID condition
              var allDrivers = snapshot.data!.docs;
              var filteredDrivers = allDrivers.where((doc) {
                String? companyId = doc['companyId']?.toString();
                if (companyId == null || companyId.length < 8) return false;

                String trimmedCompanyId = companyId.substring(8);
                return trimmedCompanyId == currentUser?.uid;
              }).toList();

              if (filteredDrivers.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      "No drivers found for your company",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      var doc = filteredDrivers[index];
                      Color statusColor;
                      String statusText;

                      if (doc['isOnJourney'] == true) {
                        statusColor = Colors.red;
                        statusText = "On Journey";
                      } else if (doc['currentJourneyId'] != null &&
                          doc['acceptedJourney'] == false) {
                        statusColor = Colors.orange;
                        statusText = "Pending";
                      } else {
                        statusColor = Colors.green;
                        statusText = "Available";
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: const Color(0xFF6C63FF),
                            child: Text(
                              doc['name'][0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            doc['name'],
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                doc['email'],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
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
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                              color: Color(0xFF6C63FF),
                            ),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (builder) =>
                                          DriverDetails(driverID: doc.id)));
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (builder) =>
                                        DriverDetails(driverID: doc.id)));
                          },
                        ),
                      );
                    },
                    childCount: filteredDrivers.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String count, IconData icon, Color color) {
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              count,
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
            ),
          ],
        ),
      ),
    );
  }
}
