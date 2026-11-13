import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/provider_credentials.dart';
import '../models/provider_descriptor.dart';
import '../models/saved_vehicle.dart';
import '../models/vehicle_category.dart';
import '../providers/registry_provider.dart';
import '../providers/storage_provider.dart';
import '../services/providers/gps_provider_client.dart';
import '../services/providers/provider_client_factory.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Adds a vehicle in three clear steps: 1) pick a provider, 2) enter
/// that provider's credentials, 3) test the connection, then save.
/// The secret is stored only in secure storage. Save unlocks only
/// after a successful test — that rule is unchanged.
///
/// The wizard step, the test state and the form are local, ephemeral
/// screen state — plain setState. Only the save goes through a
/// provider (the storage provider).
///
/// When embedded as the Add tab ([onSaved]/[onBack] set), saving or
/// backing out returns to the Fleet tab instead of popping a route —
/// there is no route to pop inside the tab shell.
class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key, this.onSaved, this.onBack});

  /// Called after a successful save, instead of popping the route.
  final VoidCallback? onSaved;

  /// Called when the user backs out of step 1, instead of popping
  /// the route.
  final VoidCallback? onBack;

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

enum _TestState { idle, testing, success, error }

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _secretController = TextEditingController();
  final _regNoController = TextEditingController();
  final _displayNameController = TextEditingController();

  int _step = 0;

  /// Selected provider, by key. Resolved to a [ProviderDescriptor]
  /// via [_descriptor] — built-ins and registry-added providers alike.
  String _providerKey = 'aargee';
  bool _secretVisible = false;
  bool _testedOk = false;
  bool _saving = false;
  _TestState _testState = _TestState.idle;
  String? _testMessage;
  int _testCount = 0;

  /// Vehicle type for this vehicle. Defaults to [VehicleCategory.other]
  /// — the user picks it in the credentials step.
  VehicleCategory _category = VehicleCategory.other;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _secretController.dispose();
    _regNoController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  ProviderDescriptor get _descriptor {
    final descriptors = ref.read(providerDescriptorsProvider);
    return descriptors.firstWhere(
      (d) => d.key == _providerKey,
      orElse: () => descriptors.first,
    );
  }

  ProviderCredentials get _credentials => ProviderCredentials(
    deviceId: _deviceIdController.text.trim(),
    secret: _secretController.text.trim(),
    regNo: _regNoController.text.trim().isEmpty
        ? null
        : _regNoController.text.trim(),
    displayName: _displayNameController.text.trim().isEmpty
        ? null
        : _displayNameController.text.trim(),
  );

  void _resetTest() {
    setState(() {
      _testedOk = false;
      _testState = _TestState.idle;
      _testMessage = null;
      _testCount = 0;
    });
  }

  void _selectProvider(String key) {
    setState(() {
      _providerKey = key;
      _testedOk = false;
      _testState = _TestState.idle;
      _testMessage = null;
      _testCount = 0;
    });
  }

  void _goToStep(int step) => setState(() => _step = step);

  void _continueFromDetails() {
    final form = _formKey.currentState;
    if (form != null && !form.validate()) return;
    _goToStep(2);
  }

  Future<void> _testConnection() async {
    setState(() {
      _testState = _TestState.testing;
      _testedOk = false;
      _testMessage = null;
    });
    try {
      final client = clientForSavedVehicle(
        _providerKey,
        ref.read(registryProvider).registry,
      );
      final vehicles = await client.fetchLiveVehicles(_credentials);
      if (!mounted) return;
      if (vehicles.isEmpty) {
        setState(() {
          _testState = _TestState.error;
          _testMessage =
              'Connected, but the account returned no '
              'vehicles. Check the device ID — it must match a vehicle '
              'registered under this account.';
        });
        return;
      }
      setState(() {
        _testState = _TestState.success;
        _testCount = vehicles.length;
        _testedOk = true;
      });
    } on ProviderException catch (e) {
      if (!mounted) return;
      setState(() {
        _testState = _TestState.error;
        _testMessage = e.message;
      });
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      setState(() {
        _testState = _TestState.error;
        _testMessage = e.message ?? 'Not supported yet.';
      });
    } on TimeoutException {
      // The provider clients give up after 20s (30s for Aargee); on a
      // slow mobile connection that can fire even when the key is
      // right. This used to be uncaught, leaving the screen stuck on
      // the spinner forever with no error and no retry.
      if (!mounted) return;
      setState(() {
        _testState = _TestState.error;
        _testMessage =
            'The provider took too long to answer. Check your internet '
            'connection and tap Test again.';
      });
    } on IOException {
      // Covers SocketException and ClientException (no route to host,
      // DNS failure, connection refused, ...).
      if (!mounted) return;
      setState(() {
        _testState = _TestState.error;
        _testMessage =
            'Could not reach ${_descriptor.displayName} — check your '
            'internet connection and try again.';
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _testState = _TestState.error;
        _testMessage =
            'The provider returned an unexpected response. Try again, '
            'or check the API key.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testState = _TestState.error;
        _testMessage = 'Connection failed: $e';
      });
    }
  }

  Future<void> _save() async {
    if (!_testedOk) return;
    setState(() => _saving = true);
    try {
      final vehicle = SavedVehicle(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        providerKey: _providerKey,
        deviceId: _deviceIdController.text.trim(),
        regNo: _regNoController.text.trim().isEmpty
            ? null
            : _regNoController.text.trim(),
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
        category: _category,
      );
      await ref
          .read(secureStorageServiceProvider)
          .saveVehicle(vehicle, _secretController.text.trim());
      if (!mounted) return;
      final onSaved = widget.onSaved;
      if (onSaved != null) {
        // Embedded as a tab: reset the wizard for the next vehicle
        // and hand navigation back to the caller (Fleet tab).
        _resetWizard();
        onSaved();
      } else {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Clears the wizard back to a fresh step 1.
  void _resetWizard() {
    _deviceIdController.clear();
    _secretController.clear();
    _regNoController.clear();
    _displayNameController.clear();
    _resetTest();
    setState(() {
      _step = 0;
      _category = VehicleCategory.other;
    });
  }

  String _authDescription(String authKind) {
    switch (authKind) {
      case 'apiKey':
        return 'Signs in with one API key';
      case 'userIdAndKey':
        return 'Signs in with a user ID + key';
      case 'usernamePassword':
        return 'Signs in with username + password';
      default:
        return 'Signs in with its own credentials';
    }
  }

  void _handleBack() {
    if (_step > 0) {
      _goToStep(_step - 1);
      return;
    }
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Embedded as a tab there is no route to pop from step 1 —
      // the back button goes to Fleet instead (see [_handleBack]).
      canPop: _step == 0 && widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _goToStep(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: _step == 0 ? 'Back' : 'Previous step',
            onPressed: _handleBack,
          ),
          title: const Text('Add vehicle'),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    StepIndicator(
                      currentStep: _step,
                      labels: const ['Provider', 'Details', 'Test & save'],
                    ),
                    const SizedBox(height: 20),
                    if (_step == 0) _buildProviderStep(),
                    if (_step == 1) _buildDetailsStep(),
                    if (_step == 2) _buildTestStep(),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// Sticky action bar: the wizard's primary actions stay thumb-reachable
  /// at the bottom instead of scrolling away with the form.
  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: switch (_step) {
          0 => SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _goToStep(1),
              child: const Text('Continue'),
            ),
          ),
          1 => Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goToStep(0),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _continueFromDetails,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
          _ => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _testState == _TestState.testing
                      ? null
                      : _testConnection,
                  icon: const Icon(Icons.wifi_tethering_outlined),
                  label: Text(
                    _testState == _TestState.testing
                        ? 'Testing…'
                        : _testState == _TestState.error
                        ? 'Test again'
                        : 'Test connection',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _testedOk && !_saving ? _save : null,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save vehicle'),
                ),
              ),
              if (!_testedOk)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Test the connection first — Save unlocks after a '
                    'successful test.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        },
      ),
    );
  }

  Widget _buildProviderStep() {
    final theme = Theme.of(context);
    final descriptors = ref.watch(providerDescriptorsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Which GPS provider is this vehicle on?',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Each provider has its own API. Pick the one the vehicle\'s '
          'tracker is registered with.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ...descriptors.map((descriptor) {
          final selected = descriptor.key == _providerKey;
          final color = AppColors.providerColor(descriptor.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                side: BorderSide(
                  color: selected ? color : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: InkWell(
                onTap: () => _selectProvider(descriptor.key),
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.satellite_alt_outlined,
                          color: color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    descriptor.displayName,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                // Registry-added providers carry a
                                // "Remote" badge so they stand apart
                                // from the built-ins.
                                if (descriptor.isRemote)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .secondaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Remote',
                                      style: TextStyle(
                                        color: theme
                                            .colorScheme
                                            .onSecondaryContainer,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ProviderStatusPill(descriptor: descriptor),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _authDescription(descriptor.authKind),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (descriptor.supportsHistory)
                              Text(
                                'Live tracking + history',
                                style: theme.textTheme.bodySmall,
                              )
                            else
                              Text(
                                'Live tracking only (no history)',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? color
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailsStep() {
    final theme = Theme.of(context);
    final descriptor = _descriptor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter ${descriptor.displayName} credentials',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'These stay only on this device, in secure storage.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (!descriptor.verified)
          Card(
            color: AppColors.idle.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.construction_outlined,
                    color: AppColors.idle,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${descriptor.displayName} is not verified yet — '
                      'its endpoint paths are not confirmed. Test '
                      'connection will explain what is missing.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Text(descriptor.rateLimitNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deviceIdController,
          decoration: InputDecoration(
            labelText: descriptor.deviceIdLabel,
            hintText: descriptor.deviceIdHint,
            helperText: 'This identifies the vehicle at the provider.',
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null,
          onChanged: (_) {
            if (_testedOk) _resetTest();
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _secretController,
          obscureText: !_secretVisible,
          decoration: InputDecoration(
            labelText: descriptor.secretLabel,
            hintText: descriptor.secretHint,
            helperText: 'Never shared — stored only on this device.',
            suffixIcon: IconButton(
              icon: Icon(
                _secretVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              tooltip: _secretVisible ? 'Hide' : 'Show',
              onPressed: () => setState(() => _secretVisible = !_secretVisible),
            ),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null,
          onChanged: (_) {
            if (_testedOk) _resetTest();
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _regNoController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Registration number (optional)',
            hintText: 'Used for display and fallback matching',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _displayNameController,
          decoration: const InputDecoration(
            labelText: 'Display name (optional)',
            hintText: 'Friendly name for the fleet list',
          ),
        ),
        const SizedBox(height: 24),
        Text('Vehicle type', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Shown as an icon on fleet cards and the map.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: VehicleCategory.values.map((category) {
            final selected = category == _category;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category.icon, size: 18),
                  const SizedBox(width: 6),
                  Text(category.label),
                ],
              ),
              selected: selected,
              onSelected: (_) => setState(() => _category = category),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTestStep() {
    final theme = Theme.of(context);
    final descriptor = _descriptor;
    final deviceId = _deviceIdController.text.trim();
    final regNo = _regNoController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Test the connection', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'We\'ll contact ${descriptor.displayName} with these credentials '
          'before saving anything.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    ProviderBadge(providerKey: descriptor.key),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        descriptor.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.tag_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(deviceId, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
                if (regNo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.directions_car_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(regNo, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_testState == _TestState.idle)
          Card(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.wifi_tethering_outlined,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tap "Test connection" — if the provider answers '
                      'with your vehicle, Save unlocks.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_testState == _TestState.testing)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Contacting the provider…',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_testState == _TestState.success)
          Card(
            color: AppColors.live.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.live,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.live,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_testCount vehicle${_testCount == 1 ? '' : 's'} '
                          'found on ${descriptor.displayName}.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_testState == _TestState.error)
          Card(
            color: AppColors.error.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connection failed',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _testMessage ?? 'Unknown error.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('What to check:', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  const Text('• The API key / password is copied correctly'),
                  const Text('• The device ID matches the provider account'),
                  const Text('• The vehicle is registered under this account'),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Credentials are stored only on this device, in secure '
          'storage. They are never uploaded anywhere except the '
          'provider\'s own API.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
