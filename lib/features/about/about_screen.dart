import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.phone_android,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.aboutToolName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.aboutTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l10n.aboutDescription,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.aboutCapabilities, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _CapabilityTile(
                icon: Icons.devices,
                title: l10n.aboutDevicesTitle,
                subtitle: l10n.aboutDevicesDescription,
              ),
              _CapabilityTile(
                icon: Icons.terminal,
                title: l10n.aboutTerminalTitle,
                subtitle: l10n.aboutTerminalDescription,
              ),
              _CapabilityTile(
                icon: Icons.folder_outlined,
                title: l10n.aboutFilesTitle,
                subtitle: l10n.aboutFilesDescription,
              ),
              _CapabilityTile(
                icon: Icons.apps_outlined,
                title: l10n.aboutAppsTitle,
                subtitle: l10n.aboutAppsDescription,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.aboutProjectDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.aboutVersion,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
  );
}
