import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home/home_screen.dart';
import 'theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final authStateProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope(
      child: GeneTrustApp(),
    ),
  );
}

class GeneTrustApp extends ConsumerWidget {
  const GeneTrustApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateProvider);
    return MaterialApp(
      title: 'GeneTrust AI Studio',
      debugShowCheckedModeBanner: false,
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      themeMode: themeMode,
      home: authState.when(
        data: (user) => user == null ? const SignInScreen() : const HomeScreen(),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
      routes: {
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
      },
    );
  }
} 