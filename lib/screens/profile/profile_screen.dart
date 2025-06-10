import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart';

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  return doc.data();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: const Text('This feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, String currentUsername) {
    final controller = TextEditingController(text: currentUsername);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'username': controller.text.trim(),
                });
                ref.refresh(userProfileProvider);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final themeMode = ref.watch(themeModeProvider);
    if (user == null) {
      // Not signed in: show Sign In/Sign Up
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/signin');
                },
                child: const Text('Sign In'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/signup');
                },
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ),
      );
    } else {
      final userProfile = ref.watch(userProfileProvider);
      return Scaffold(
        body: userProfile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('No profile data found.'));
            }
            return CustomScrollView(
              slivers: [
                // Profile Header
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primaryContainer,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  profile['username'] ?? 'No username',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white),
                                  onPressed: () => _showEditProfileDialog(context, ref, profile['username'] ?? ''),
                                ),
                              ],
                            ),
                            Text(
                              profile['email'] ?? 'No email',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Profile Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Account Settings Section
                        _buildSectionTitle(context, 'Account Settings'),
                        _buildSettingsCard(
                          context,
                          [
                            _SettingsItem(
                              icon: Icons.person_outline,
                              title: 'Edit Profile',
                              subtitle: 'Update your personal information',
                              onTap: () => _showEditProfileDialog(context, ref, profile['username'] ?? ''),
                            ),
                            _SettingsItem(
                              icon: Icons.security_outlined,
                              title: 'Security',
                              subtitle: 'Password and authentication',
                              onTap: () => _showComingSoon(context, 'Security'),
                            ),
                            _SettingsItem(
                              icon: Icons.notifications_outlined,
                              title: 'Notifications',
                              subtitle: 'Manage your notification preferences',
                              onTap: () => _showComingSoon(context, 'Notifications'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Preferences Section
                        _buildSectionTitle(context, 'Preferences'),
                        _buildSettingsCard(
                          context,
                          [
                            _SettingsItem(
                              icon: Icons.language_outlined,
                              title: 'Language',
                              subtitle: 'English (US)',
                              onTap: () => _showComingSoon(context, 'Language'),
                            ),
                            _SettingsItem(
                              icon: themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                              title: 'Theme',
                              subtitle: themeMode == ThemeMode.dark ? 'Dark' : themeMode == ThemeMode.light ? 'Light' : 'System default',
                              onTap: () {
                                final next = themeMode == ThemeMode.light
                                    ? ThemeMode.dark
                                    : themeMode == ThemeMode.dark
                                        ? ThemeMode.system
                                        : ThemeMode.light;
                                ref.read(themeModeProvider.notifier).state = next;
                              },
                            ),
                            _SettingsItem(
                              icon: Icons.data_usage_outlined,
                              title: 'Data Usage',
                              subtitle: 'Manage your data preferences',
                              onTap: () => _showComingSoon(context, 'Data Usage'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Support Section
                        _buildSectionTitle(context, 'Support'),
                        _buildSettingsCard(
                          context,
                          [
                            _SettingsItem(
                              icon: Icons.help_outline,
                              title: 'Help Center',
                              subtitle: 'Get help and support',
                              onTap: () => _showComingSoon(context, 'Help Center'),
                            ),
                            _SettingsItem(
                              icon: Icons.info_outline,
                              title: 'About',
                              subtitle: 'Version 1.0.0',
                              onTap: () => _showComingSoon(context, 'About'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Logout Button
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.error,
                              foregroundColor: Theme.of(context).colorScheme.onError,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    List<_SettingsItem> items,
  ) {
    return Card(
      child: Column(
        children: items.map((item) {
          final isLast = items.last == item;
          return Column(
            children: [
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: item.onTap,
              ),
              if (!isLast)
                const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
} 