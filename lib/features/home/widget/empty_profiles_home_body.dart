import 'package:flutter/material.dart';
import 'package:hiddify/features/strizh/strizh_onboarding.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class EmptyProfilesHomeBody extends HookConsumerWidget {
  const EmptyProfilesHomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: StrizhOnboarding(),
    );
  }
}
