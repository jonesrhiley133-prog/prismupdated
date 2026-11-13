import 'package:flutter/material.dart';

import 'package:prism_plurality/core/diagnostics/freeze_report_card.dart';
import 'package:prism_plurality/features/app_update/app_update_widgets.dart';
import 'package:prism_plurality/features/settings/views/about_section.dart';
import 'package:prism_plurality/features/whats_new/whats_new.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: context.l10n.settingsAbout,
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: NavBarInset.of(context)),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FreezeReportCard(),
            AppUpdateCard(),
            WhatsNewTile(),
            AboutSection(),
          ],
        ),
      ),
    );
  }
}
