import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'static/firebase_options.dart';
import 'views/driver/driver_home_page.dart';
import 'authentication/login_page.dart';
import 'views/owner/owner_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login/Signup Page',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            String uid = snapshot.data!.uid;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const LoginPage(); // Redirect to login if data is missing
                }

                // *** Change: Casting to Map<String, dynamic> ***
                var userData = userSnapshot.data!.data() as Map<String, dynamic>?;

                if (userData == null || !userData.containsKey('accountType')) {
                  return const LoginPage(); // Prevents crash if field is missing
                }

                String accountType = userData['accountType'];

                if (accountType == 'owner') {
                  return OwnerHomePage();
                } else if (accountType == 'driver') {
                  return DriverHomePage();
                }

                return const LoginPage(); // Fallback if accountType is unknown
              },
            );
          }

          return const LoginPage(); // Redirect to login if user is not authenticated
        },
      ),
    );
  }
}
