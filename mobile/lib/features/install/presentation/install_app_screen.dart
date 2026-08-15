import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/install_app_models.dart';
import '../../../shared/services/install_app_service.dart';

class InstallAppScreen extends StatefulWidget {
  const InstallAppScreen({
    super.key,
    this.controller = const InstallAppService(),
  });

  final InstallAppController controller;

  @override
  State<InstallAppScreen> createState() => _InstallAppScreenState();
}

class _InstallAppScreenState extends State<InstallAppScreen> {
  static final _appStoreUrl = Uri.parse(
    'https://apps.apple.com/app/id6801616483',
  );
  static final _playStoreUrl = Uri.parse(
    'https://play.google.com/store/apps/details?id=in.voltmap.voltmap',
  );

  InstallAppStatus? status;
  bool installing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final nextStatus = await widget.controller.getStatus();
    if (mounted) setState(() => status = nextStatus);
  }

  Future<void> _install() async {
    setState(() => installing = true);
    final result = await widget.controller.promptInstall();
    if (!mounted) return;
    setState(() => installing = false);
    switch (result) {
      case InstallActionResult.accepted:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('VoltMapEV installation started.')),
        );
        await _refresh();
      case InstallActionResult.dismissed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Installation cancelled. You can try again anytime.'),
          ),
        );
      case InstallActionResult.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Use the browser steps shown below to install.'),
          ),
        );
        await _refresh();
    }
  }

  Future<void> _openStore(Uri uri, String storeName) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $storeName. Try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = status;
    return Scaffold(
      appBar: AppBar(title: const Text('Install VoltMapEV')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.brandNavy, Color(0xFF0B3829)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: AppTheme.brandLime,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: AppTheme.brandNavy,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Keep VoltMapEV on your home screen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Open charger search and trip planning like an app—without visiting an app store or creating an account.',
                      style: TextStyle(
                        color: Color(0xFFC4D8CF),
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                    if (current == null) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(),
                    ] else if (current.installed) ...[
                      const SizedBox(height: 20),
                      const _InstalledBadge(),
                    ] else if (current.canPrompt &&
                        current.platform != InstallAppPlatform.ios) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('installVoltMapEVButton'),
                        onPressed: installing ? null : _install,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandLime,
                          foregroundColor: AppTheme.brandNavy,
                        ),
                        icon: installing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.install_mobile_rounded),
                        label: const Text('Install VoltMapEV'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (current != null && !current.installed)
                ..._instructionsFor(current.platform),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _installationDisclosure(current?.platform),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (current != null &&
                  !current.installed &&
                  !current.canPrompt) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('checkInstallAvailabilityButton'),
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Check install availability again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _instructionsFor(InstallAppPlatform platform) {
    return switch (platform) {
      InstallAppPlatform.ios => [
          const _InstructionHeader(
            icon: Icons.apple,
            title: 'Get VoltMapEV for iPhone or iPad',
            text:
                'Open the official VoltMapEV Apple App Store listing. This button is shown only for Apple devices.',
          ),
          _StoreButton(
            key: const Key('openAppleAppStoreButton'),
            icon: Icons.apple,
            label: 'Open Apple App Store',
            onPressed: () => _openStore(_appStoreUrl, 'Apple App Store'),
          ),
        ],
      InstallAppPlatform.android => [
          const _InstructionHeader(
            icon: Icons.android_rounded,
            title: 'Get VoltMapEV for Android',
            text:
                'Use Google Play, or keep the existing secure web-app installation when Chrome offers it.',
          ),
          _StoreButton(
            key: const Key('openGooglePlayButton'),
            icon: Icons.shop_rounded,
            label: 'Open Google Play',
            onPressed: () => _openStore(_playStoreUrl, 'Google Play'),
          ),
          const _InstallStep(
              number: '1', text: 'Open voltmapev.com in Chrome.'),
          const _InstallStep(
            number: '2',
            text: 'Tap Install above, or open the Chrome menu (⋮).',
          ),
          const _InstallStep(
            number: '3',
            text: 'Choose Install app or Add to Home screen and confirm.',
          ),
        ],
      InstallAppPlatform.desktop => const [
          _InstructionHeader(
            icon: Icons.desktop_windows_outlined,
            title: 'Install on this computer',
            text: 'Use Chrome or Edge to open VoltMapEV in its own window.',
          ),
          _InstallStep(
            number: '1',
            text: 'Select the install icon in the address bar, when shown.',
          ),
          _InstallStep(
            number: '2',
            text: 'Or open the browser menu and choose Install VoltMapEV.',
          ),
        ],
      _ => [
          const _InstructionHeader(
            icon: Icons.install_mobile_rounded,
            title: 'Choose the correct app store',
            text:
                'VoltMapEV will not claim that an iOS app can be installed on Android. Select the store for your device.',
          ),
          _StoreButton(
            key: const Key('unsupportedAppleAppStoreButton'),
            icon: Icons.apple,
            label: 'Apple App Store',
            onPressed: () => _openStore(_appStoreUrl, 'Apple App Store'),
          ),
          _StoreButton(
            key: const Key('unsupportedGooglePlayButton'),
            icon: Icons.shop_rounded,
            label: 'Google Play',
            onPressed: () => _openStore(_playStoreUrl, 'Google Play'),
          ),
        ],
    };
  }

  String _installationDisclosure(InstallAppPlatform? platform) {
    return switch (platform) {
      InstallAppPlatform.ios =>
        'The Apple button opens only the official VoltMapEV App Store listing. It never redirects to an Android installer.',
      InstallAppPlatform.android =>
        'The Google Play button opens only the VoltMapEV Android package. Chrome may also install the secure website from voltmapev.com.',
      _ =>
        'Choose the store that matches your device. Store installation never requests a payment or VoltMapEV signup from this page.',
    };
  }
}

class _StoreButton extends StatelessWidget {
  const _StoreButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
      );
}

class _InstalledBadge extends StatelessWidget {
  const _InstalledBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('voltmapevInstalledBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.brandGreen.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.brandGreen),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.brandLime),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'VoltMapEV is installed on this device',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionHeader extends StatelessWidget {
  const _InstructionHeader({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallStep extends StatelessWidget {
  const _InstallStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(number)),
        title: Text(text),
      ),
    );
  }
}
