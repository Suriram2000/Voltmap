import 'package:flutter/material.dart';

import '../state/app_state.dart';

Future<bool> requireRegisteredAccount(
  BuildContext context,
  AppState appState,
  String feature,
) async {
  if (!appState.isDemoAccount) return true;

  final createAccount = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('signupRequiredDialog'),
      icon: const Icon(Icons.person_add_alt_1_rounded),
      title: Text('Sign up to use $feature'),
      content: Text(
        '$feature saves personal data and is available to registered VoltMap accounts. Create an account to continue.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not now'),
        ),
        FilledButton.icon(
          key: const Key('goToSignupButton'),
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Create account'),
        ),
      ],
    ),
  );
  if (createAccount == true) {
    await appState.signOut();
  }
  return false;
}
