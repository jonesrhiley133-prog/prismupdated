import 'package:flutter/widgets.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/relationships/hub/rel_editor.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';

/// Opens the relationship editor (kept for older call sites).
Future<void> showRelationshipEditor(BuildContext context, {TrackerRecord? editing, String? memberId}) async {
  await showRelEditor(context, editing: editing == null ? null : Rel(editing), memberId: memberId);
}
