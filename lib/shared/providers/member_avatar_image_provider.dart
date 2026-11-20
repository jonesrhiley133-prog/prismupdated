import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_plurality/core/database/database_providers.dart';

final memberAvatarImageDataProvider = StreamProvider.autoDispose
    .family<Uint8List?, String>((ref, memberId) {
      return ref.watch(membersDaoProvider).watchAvatarImageData(memberId);
    });

/// Banner bytes for a member card (loaded only for visible cards).
///
/// Kept for a short while after its card scrolls away, so scrolling back up
/// and down a long list does not re-query every banner.
final memberBannerImageDataProvider = StreamProvider.autoDispose
    .family<Uint8List?, String>((ref, memberId) {
      final link = ref.keepAlive();
      Timer? release;
      ref.onCancel(() => release = Timer(const Duration(seconds: 30), link.close));
      ref.onResume(() => release?.cancel());
      ref.onDispose(() => release?.cancel());
      return ref.watch(membersDaoProvider).watchBannerImageData(memberId);
    });
