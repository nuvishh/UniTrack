import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/provider_descriptor.dart';
import '../providers/registry_provider.dart';
import '../theme/app_theme.dart';

/// Bold section heading used across screens ("Fleet", "Saved vehicles"…),
/// with an optional trailing widget (e.g. a count or an action).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small pill identifying a provider, in secondaryContainer (Material
/// You, v1.3.0 — the same pill the prototype uses in the detail header
/// and map sheet). Resolves the display name through the provider
/// descriptors, so registry-added providers show their name too (and
/// an unknown key falls back to the key itself instead of throwing).
class ProviderBadge extends ConsumerWidget {
  const ProviderBadge({super.key, required this.providerKey});

  final String providerKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final descriptors = ref.watch(providerDescriptorsProvider);
    final match = descriptors.where((d) => d.key == providerKey);
    final displayName = match.isEmpty ? providerKey : match.first.displayName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        displayName,
        style: TextStyle(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// A verified / needs-setup pill for a provider.
class ProviderStatusPill extends StatelessWidget {
  const ProviderStatusPill({super.key, required this.descriptor});

  final ProviderDescriptor descriptor;

  @override
  Widget build(BuildContext context) {
    final verified = descriptor.verified;
    final color = verified ? AppColors.live : AppColors.idle;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_outlined : Icons.construction_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            verified ? l10n.providerVerified : l10n.providerSetupNeeded,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly empty state: big icon in a coloured circle, bold title,
/// helpful message and an optional action button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              // Full-width button: the label ("Add your first vehicle")
              // is too wide for the narrow map empty-state card at
              // 360 dp otherwise. FilledButton.icon already wraps the
              // label in a Flexible, so it wraps instead of overflowing.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel!, textAlign: TextAlign.center),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Plain-language error card with a Retry button.
class ErrorStateCard extends StatelessWidget {
  const ErrorStateCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      color: AppColors.error.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.refreshErrorTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer-free loading skeleton for the fleet list: grey rounded
/// blocks that gently pulse while the first refresh is in flight.
class FleetListSkeleton extends StatefulWidget {
  const FleetListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  State<FleetListSkeleton> createState() => _FleetListSkeletonState();
}

class _FleetListSkeletonState extends State<FleetListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurfaceVariant;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = base.withValues(alpha: 0.08 + 0.08 * _controller.value);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: widget.itemCount,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, _) => Container(
            height: 108,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
          ),
        );
      },
    );
  }
}

/// A 3-step progress indicator for the add-vehicle flow: numbered
/// circles joined by lines, with the current step highlighted and
/// completed steps ticked.
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.labels,
  });

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i <= currentStep
                      ? primary
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: i < currentStep
                      ? AppColors.live
                      : i == currentStep
                      ? primary
                      : muted.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == currentStep ? primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: i < currentStep
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: i == currentStep ? Colors.white : muted,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: i == currentStep ? primary : muted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
