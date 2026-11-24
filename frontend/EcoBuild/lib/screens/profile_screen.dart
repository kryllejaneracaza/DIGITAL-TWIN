import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color primaryGreen = Color(0xFF125838);
  static const Color backgroundColor = Color(0xFFF1F5F2);

  void _showInformationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Icon(icon, color: primaryGreen),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.black54, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CLOSE', style: TextStyle(color: primaryGreen)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Log Out'),
          content: const Text(
            'Are you sure you want to log out of your EcoBuild account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('LOG OUT'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !context.mounted) return;

    try {
      await context.read<AuthProvider>().logout();
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to log out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final email = user?['email']?.toString() ?? 'No User Logged In';

    final displayName =
        user?['name']?.toString() ??
        (user?['email']?.toString().split('@').first ?? 'EcoBuild User');

    final userId = user?['id']?.toString() ?? 'Not available';
    final role = user?['role']?.toString() ?? 'Not available';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 45,
                      backgroundColor: Color(0xFFD9EFE1),
                      child: Icon(
                        Icons.person_rounded,
                        size: 55,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9EFE1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ECOBUILD ACCOUNT',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'ACCOUNT',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 10),

              _settingsCard(
                children: [
                  _settingsTile(
                    icon: Icons.person_outline,
                    title: 'Account Details',
                    subtitle: 'View your account information',
                    onTap: () {
                      _showInformationDialog(
                        context,
                        title: 'Account Details',
                        icon: Icons.person_outline,
                        message:
                            'Name: $displayName\n\n'
                            'Email: $email\n\n'
                            'User ID: $userId\n\n'
                            'Account role: $role\n\n'
                            'Account status: '
                            '${user != null ? 'Signed in' : 'Not signed in'}',
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 22),

              const Text(
                'PREFERENCES',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 10),

              _settingsCard(
                children: [
                  _settingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Notification information',
                    onTap: () {
                      _showInformationDialog(
                        context,
                        title: 'Notifications',
                        icon: Icons.notifications_none_rounded,
                        message:
                            'EcoBuild notification preferences and alerts '
                            'will be available when the notification '
                            'service is configured.',
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 55),
                  _settingsTile(
                    icon: Icons.settings_outlined,
                    title: 'System',
                    subtitle: 'Application information',
                    onTap: () {
                      _showInformationDialog(
                        context,
                        title: 'System Information',
                        icon: Icons.settings_outlined,
                        message:
                            'EcoBuild Smart Building Management System\n\n'
                            'This application provides building, room, '
                            'sensor, and appliance management features.\n\n'
                            'Live monitoring and hardware controls depend '
                            'on the backend and device integration.',
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 55),
                  _settingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About EcoBuild',
                    subtitle: 'Learn about the application',
                    onTap: () {
                      _showInformationDialog(
                        context,
                        title: 'About EcoBuild',
                        icon: Icons.eco_outlined,
                        message:
                            'EcoBuild is a smart building monitoring '
                            'and management application designed to '
                            'support smarter and more sustainable spaces.\n\n'
                            'Smarter Spaces, Smarter Living.',
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: user == null
                      ? null
                      : () => _showLogoutDialog(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'LOG OUT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB83232),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Center(
                child: Text(
                  'EcoBuild • Smarter Spaces, Smarter Living',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFD9EFE1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: primaryGreen),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }
}
