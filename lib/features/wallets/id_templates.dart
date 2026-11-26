import 'package:flutter/material.dart';

import 'package:prism_plurality/features/wallets/wallet_data.dart';

/// 60+ structurally different card designs. Each one places its own shapes,
/// text, photo and decoration — they are not recolours of one layout. Cards
/// made from these are personal, decorative profile cards, never official
/// identification (every back says so).
class IdTemplate {
  const IdTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.bg1,
    required this.bg2,
    required this.front,
    this.aspect = idLandscape,
    this.pattern = 'none',
    this.backBg1,
    this.backBg2,
    this.ink = 0xFF222222,
    this.accent = 0xFF5B5BD6,
    this.font = 'standard',
  });

  /// `tpl.<slug>`
  final String id;
  final String name, category;
  final int bg1, bg2;
  final String pattern;
  final double aspect;
  final int? backBg1, backBg2;
  final int ink, accent;
  final String font;
  final void Function(IdLayout b) front;
}

const idLandscape = 1.585;
const idPortrait = 0.64;
const idSquare = 1.0;

/// Builds layers; skips fields the card doesn't show.
class IdLayout {
  IdLayout(this.fields, this.title, this.t);
  final Set<String> fields;
  final String title;
  final IdTemplate t;
  final layers = <CardLayer>[];

  int get ink => t.ink;
  int get accent => t.accent;

  CardLayer _l(CardLayer l) {
    layers.add(l);
    return l;
  }

  void text(
    String s,
    double x,
    double y, {
    double size = 0.05,
    bool bold = false,
    String align = 'left',
    int? color,
    double w = 0.5,
    String? font,
    double rot = 0,
    double op = 1,
  }) => _l(
    CardLayer(
      id: templateLayerId(),
      kind: 'text',
      text: s,
      x: x,
      y: y,
      w: w,
      size: size,
      bold: bold,
      align: align,
      color: color ?? ink,
      font: font ?? t.font,
      rotation: rot,
      opacity: op,
    ),
  );

  void field(
    String f,
    double x,
    double y, {
    double size = 0.048,
    bool bold = false,
    String align = 'left',
    int? color,
    double w = 0.5,
    String? font,
    double rot = 0,
    double op = 1,
  }) {
    if (!fields.contains(f)) return;
    _l(
      CardLayer(
        id: templateLayerId(),
        kind: 'field',
        field: f,
        x: x,
        y: y,
        w: w,
        size: size,
        bold: bold,
        align: align,
        color: color ?? ink,
        font: font ?? t.font,
        rotation: rot,
        opacity: op,
      ),
    );
  }

  void shape(
    String kind,
    double x,
    double y,
    double w,
    double h, {
    int? color,
    int? c2,
    double stroke = 0,
    double rot = 0,
    double op = 1,
  }) => _l(
    CardLayer(
      id: templateLayerId(),
      kind: 'shape',
      text: kind,
      x: x,
      y: y,
      w: w,
      h: h,
      color: color ?? accent,
      color2: c2,
      stroke: stroke,
      rotation: rot,
      opacity: op,
    ),
  );

  void circle(double x, double y, double d, {int? color, double op = 1}) => _l(
    CardLayer(
      id: templateLayerId(),
      kind: 'circle',
      x: x,
      y: y,
      w: d,
      h: d * t.aspect,
      color: color ?? accent,
      opacity: op,
    ),
  );

  void line(double x, double y, double w, {int? color, double op = 1}) => _l(
    CardLayer(
      id: templateLayerId(),
      kind: 'line',
      x: x,
      y: y,
      w: w,
      h: 0.04,
      color: color ?? ink,
      opacity: op,
    ),
  );

  void emoji(
    String e,
    double x,
    double y,
    double w, {
    double rot = 0,
    double op = 1,
  }) => _l(
    CardLayer(
      id: templateLayerId(),
      kind: 'emoji',
      text: e,
      x: x,
      y: y,
      w: w,
      h: w * t.aspect,
      rotation: rot,
      opacity: op,
    ),
  );

  void photo(
    double x,
    double y,
    double w,
    double h, {
    int? color,
    double rot = 0,
  }) {
    if (!fields.contains('photo')) return;
    _l(
      CardLayer(
        id: templateLayerId(),
        kind: 'photo',
        x: x,
        y: y,
        w: w,
        h: h,
        color: color ?? accent,
        rotation: rot,
      ),
    );
  }

  void barcode(
    double x,
    double y,
    double w,
    double h, {
    int? color,
    double op = 1,
  }) {
    if (!fields.contains('barcode') && !fields.contains('number')) return;
    _l(
      CardLayer(
        id: templateLayerId(),
        kind: 'barcode',
        x: x,
        y: y,
        w: w,
        h: h,
        color: color ?? ink,
        opacity: op,
      ),
    );
  }

  /// Card title in the template's voice.
  void heading(
    double x,
    double y, {
    double size = 0.05,
    String align = 'left',
    int? color,
    double w = 0.6,
    bool upper = true,
    String? font,
  }) => text(
    upper ? title.toUpperCase() : title,
    x,
    y,
    size: size,
    bold: true,
    align: align,
    color: color ?? accent,
    w: w,
    font: font,
  );
}

const _w = 0xFFFFFFFF;
const _k = 0xFF111111;

/// The library. Order = display order inside each category.
final idTemplates = <IdTemplate>[
  // ── Modern identification ─────────────────────────────────────────
  IdTemplate(
    id: 'tpl.modern-stripe',
    name: 'Modern stripe',
    category: 'Modern',
    bg1: 0xFFFFFFFF,
    bg2: 0xFFEFF2F7,
    ink: 0xFF1B2433,
    accent: 0xFF2F6BFF,
    front: (b) {
      b.shape('rect', 0.5, 0.09, 1, 0.18, color: b.accent, c2: 0xFF7A5CFF);
      b.heading(0.05, 0.09, color: _w, size: 0.048);
      b.photo(0.2, 0.55, 0.28, 0.58);
      b.field('name', 0.4, 0.4, size: 0.075, bold: true, w: 0.55);
      b.field('pronouns', 0.4, 0.52, w: 0.5);
      b.field('role', 0.4, 0.62, w: 0.5);
      b.field('number', 0.4, 0.82, size: 0.04, w: 0.5);
      b.barcode(0.78, 0.86, 0.34, 0.1);
    },
  ),
  IdTemplate(
    id: 'tpl.modern-split',
    name: 'Split panel',
    category: 'Modern',
    bg1: 0xFF14161F,
    bg2: 0xFF14161F,
    ink: _w,
    accent: 0xFFFF5A8A,
    front: (b) {
      b.shape('rect', 0.19, 0.5, 0.38, 1, color: 0xFFFF5A8A, c2: 0xFFFFA24A);
      b.photo(0.19, 0.42, 0.28, 0.5, color: _w);
      b.field('name', 0.43, 0.3, size: 0.07, bold: true, w: 0.55);
      b.field('pronouns', 0.43, 0.43, color: 0xFFFFC3D4);
      b.field('role', 0.43, 0.55);
      b.line(0.7, 0.68, 0.5, color: 0x66FFFFFF);
      b.field('number', 0.43, 0.8, size: 0.04, op: 0.8);
      b.text(
        b.title,
        0.19,
        0.85,
        size: 0.036,
        bold: true,
        align: 'center',
        color: _w,
        w: 0.34,
      );
    },
  ),
  // ── Student ───────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.student-campus',
    name: 'Campus card',
    category: 'Student',
    bg1: 0xFFFFFBEF,
    bg2: 0xFFFFF1C7,
    ink: 0xFF3B2A12,
    accent: 0xFFB3282D,
    font: 'serif',
    front: (b) {
      b.shape('rect', 0.5, 0.12, 1, 0.24, color: b.accent);
      b.emoji('🎓', 0.1, 0.12, 0.1);
      b.text(
        'UNIVERSITY OF YOU',
        0.2,
        0.12,
        size: 0.05,
        bold: true,
        color: _w,
        w: 0.7,
      );
      b.photo(0.82, 0.55, 0.26, 0.5);
      b.field('name', 0.06, 0.4, size: 0.07, bold: true, w: 0.62);
      b.field('role', 0.06, 0.52, w: 0.6);
      b.field('birthday', 0.06, 0.62, w: 0.6);
      b.field('number', 0.06, 0.88, size: 0.042, bold: true, w: 0.6);
      b.shape('ribbon', 0.82, 0.9, 0.28, 0.08, color: b.accent);
    },
  ),
  IdTemplate(
    id: 'tpl.student-notebook',
    name: 'Notebook student',
    category: 'Student',
    bg1: 0xFFFDFCF5,
    bg2: 0xFFFDFCF5,
    pattern: 'notes',
    ink: 0xFF1D3557,
    accent: 0xFFE63946,
    font: 'hand',
    front: (b) {
      b.shape('rect', 0.1, 0.5, 0.012, 1, color: 0xFFE63946, op: 0.7);
      for (var i = 0; i < 4; i++) {
        b.circle(0.04, 0.2 + i * 0.2, 0.035, color: 0xFFB8C0CC);
      }
      b.text(
        'STUDENT',
        0.16,
        0.12,
        size: 0.07,
        bold: true,
        color: b.accent,
        w: 0.5,
        rot: -2,
      );
      b.photo(0.78, 0.45, 0.26, 0.5, rot: 4);
      b.field('name', 0.16, 0.38, size: 0.075, bold: true, w: 0.55);
      b.field('pronouns', 0.16, 0.5, w: 0.5);
      b.field('role', 0.16, 0.62, w: 0.5);
      b.field('number', 0.16, 0.85, size: 0.04, w: 0.5);
      b.emoji('✏️', 0.88, 0.88, 0.1, rot: 20);
    },
  ),
  // ── Vintage ───────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.vintage-cardstock',
    name: 'Vintage cardstock',
    category: 'Vintage',
    bg1: 0xFFEBDDBA,
    bg2: 0xFFD9C494,
    pattern: 'paper',
    ink: 0xFF3A2A14,
    accent: 0xFF7A1F1F,
    font: 'serif',
    front: (b) {
      b.shape('rect', 0.5, 0.5, 0.94, 0.88, color: b.ink, stroke: 0.008);
      b.shape('rect', 0.5, 0.5, 0.9, 0.82, color: b.ink, stroke: 0.003);
      b.heading(
        0.5,
        0.15,
        align: 'center',
        size: 0.046,
        w: 0.8,
        color: 0xFF7A1F1F,
      );
      b.line(0.5, 0.23, 0.7);
      b.photo(0.2, 0.55, 0.22, 0.4);
      b.field('name', 0.36, 0.42, size: 0.062, bold: true, w: 0.58);
      b.field('birthday', 0.36, 0.54, w: 0.55);
      b.field('role', 0.36, 0.64, w: 0.55);
      b.field('signature', 0.36, 0.8, size: 0.06, w: 0.55, font: 'script');
      b.shape('burst', 0.86, 0.78, 0.14, 0.2, color: 0xFF7A1F1F, op: 0.8);
    },
  ),
  IdTemplate(
    id: 'tpl.vintage-typewriter',
    name: 'Typewriter pass',
    category: 'Vintage',
    bg1: 0xFFF4EFE1,
    bg2: 0xFFE8E0C8,
    pattern: 'grunge',
    ink: 0xFF222222,
    accent: 0xFFB22222,
    font: 'mono',
    front: (b) {
      b.text(
        '*** ${b.title.toUpperCase()} ***',
        0.5,
        0.1,
        size: 0.042,
        bold: true,
        align: 'center',
        w: 0.9,
      );
      b.line(0.5, 0.18, 0.9);
      b.field('name', 0.06, 0.3, size: 0.05, w: 0.88);
      b.field('role', 0.06, 0.41, size: 0.045, w: 0.88);
      b.field('birthday', 0.06, 0.52, size: 0.045, w: 0.88);
      b.field('number', 0.06, 0.63, size: 0.045, w: 0.88);
      b.line(0.5, 0.74, 0.9);
      b.text(
        'APPROVED',
        0.74,
        0.86,
        size: 0.07,
        bold: true,
        color: b.accent,
        rot: -12,
        w: 0.4,
        op: 0.75,
      );
      b.photo(0.84, 0.4, 0.22, 0.42);
    },
  ),
  IdTemplate(
    id: 'tpl.vintage-library',
    name: 'Library slip',
    category: 'Vintage',
    bg1: 0xFFF3E7C9,
    bg2: 0xFFEAD9AE,
    pattern: 'notes',
    ink: 0xFF33281A,
    accent: 0xFF2F5D50,
    font: 'mono',
    front: (b) {
      b.shape('rect', 0.5, 0.1, 1, 0.2, color: b.accent);
      b.text(
        'LIBRARY CARD',
        0.5,
        0.1,
        size: 0.06,
        bold: true,
        align: 'center',
        color: _w,
        w: 0.8,
      );
      b.text('Borrower', 0.06, 0.3, size: 0.034, w: 0.3, op: 0.6);
      b.field('name', 0.06, 0.4, size: 0.06, bold: true, w: 0.6);
      b.line(0.34, 0.47, 0.56);
      b.field('number', 0.06, 0.58, size: 0.045, w: 0.5);
      b.text('Date due', 0.06, 0.72, size: 0.034, w: 0.3, op: 0.6);
      for (var i = 0; i < 3; i++) {
        b.line(0.3, 0.8 + i * 0.07, 0.5, op: 0.5);
      }
      b.emoji('📚', 0.86, 0.7, 0.16);
    },
  ),
  // ── Passport-inspired ─────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.passport-page',
    name: 'Passport page',
    category: 'Passport',
    bg1: 0xFFF2EFE6,
    bg2: 0xFFE3DFD0,
    pattern: 'guilloche',
    ink: 0xFF1D2A44,
    accent: 0xFF1D2A44,
    aspect: 1.42,
    font: 'mono',
    front: (b) {
      b.text(
        'PERSONAL PASSPORT',
        0.5,
        0.08,
        size: 0.042,
        bold: true,
        align: 'center',
        w: 0.9,
      );
      b.photo(0.2, 0.46, 0.3, 0.6, color: b.ink);
      b.field('name', 0.4, 0.3, size: 0.05, bold: true, w: 0.56);
      b.field('birthday', 0.4, 0.4, size: 0.04, w: 0.56);
      b.field('role', 0.4, 0.5, size: 0.04, w: 0.56);
      b.field('issued', 0.4, 0.6, size: 0.036, w: 0.56);
      b.field('expires', 0.4, 0.68, size: 0.036, w: 0.56);
      b.text(
        'P<PRM${'<' * 4}${'<' * 6}<<<<<<<<<<<<<<',
        0.04,
        0.86,
        size: 0.04,
        w: 0.94,
        font: 'mono',
      );
      b.text(
        '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<',
        0.04,
        0.93,
        size: 0.04,
        w: 0.94,
        font: 'mono',
        op: 0.6,
      );
    },
  ),
  IdTemplate(
    id: 'tpl.passport-cover',
    name: 'Passport cover',
    category: 'Passport',
    bg1: 0xFF14305C,
    bg2: 0xFF0B1E3D,
    ink: 0xFFE9C46A,
    accent: 0xFFE9C46A,
    aspect: 0.7,
    font: 'serif',
    front: (b) {
      b.shape('rrect', 0.5, 0.5, 0.88, 0.9, color: 0xFFE9C46A, stroke: 0.006);
      b.text(
        'PASSPORT',
        0.5,
        0.14,
        size: 0.09,
        bold: true,
        align: 'center',
        w: 0.8,
      );
      b.emoji(b.fields.contains('emoji') ? '🌐' : '🌐', 0.5, 0.42, 0.4);
      b.field(
        'name',
        0.5,
        0.72,
        size: 0.07,
        bold: true,
        align: 'center',
        w: 0.8,
      );
      b.field('system', 0.5, 0.8, size: 0.045, align: 'center', w: 0.8);
      b.shape('rect', 0.5, 0.9, 0.3, 0.025, color: 0xFFE9C46A);
    },
  ),
  IdTemplate(
    id: 'tpl.passport-visa',
    name: 'Visa booklet',
    category: 'Passport',
    bg1: 0xFFFBF6E8,
    bg2: 0xFFF0E6C8,
    pattern: 'waves',
    ink: 0xFF3B2A62,
    accent: 0xFFB5651D,
    aspect: 0.8,
    front: (b) {
      b.shape(
        'stamp',
        0.3,
        0.2,
        0.42,
        0.26,
        color: b.accent,
        op: 0.8,
        stroke: 0.02,
      );
      b.text(
        'ARRIVED',
        0.3,
        0.2,
        size: 0.07,
        bold: true,
        align: 'center',
        color: b.accent,
        w: 0.4,
        rot: -8,
      );
      b.shape(
        'ellipse',
        0.72,
        0.28,
        0.34,
        0.26,
        color: 0xFF3B6EA8,
        stroke: 0.015,
        op: 0.75,
        rot: 10,
      );
      b.field('name', 0.08, 0.55, size: 0.07, bold: true, w: 0.84);
      b.field('role', 0.08, 0.65, w: 0.84);
      b.photo(0.78, 0.82, 0.26, 0.24);
      b.field('issued', 0.08, 0.8, size: 0.04, w: 0.5);
      b.field('number', 0.08, 0.9, size: 0.04, w: 0.5);
    },
  ),
  IdTemplate(
    id: 'tpl.travel-boarding',
    name: 'Boarding pass',
    category: 'Passport',
    bg1: 0xFFFFFFFF,
    bg2: 0xFFEAF2FF,
    ink: 0xFF0B2545,
    accent: 0xFF13A8FF,
    aspect: 2.1,
    front: (b) {
      b.shape('ticket', 0.5, 0.5, 1, 1, color: 0xFFEAF2FF);
      b.shape('rect', 0.5, 0.12, 1, 0.24, color: b.accent);
      b.text(
        '✈  BOARDING PASS',
        0.05,
        0.12,
        size: 0.04,
        bold: true,
        color: _w,
        w: 0.6,
      );
      b.field('name', 0.05, 0.4, size: 0.06, bold: true, w: 0.6);
      b.field('role', 0.05, 0.56, size: 0.04, w: 0.6);
      b.field('number', 0.05, 0.8, size: 0.04, w: 0.6);
      b.line(0.72, 0.55, 0.01, color: b.ink, op: 0.25);
      b.photo(0.86, 0.42, 0.16, 0.5);
      b.barcode(0.82, 0.84, 0.28, 0.14);
    },
  ),
  // ── Social profile ────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.social-profile',
    name: 'Profile card',
    category: 'Social',
    bg1: 0xFFFFFFFF,
    bg2: 0xFFF5F5FA,
    ink: 0xFF1A1A2E,
    accent: 0xFF7C4DFF,
    aspect: 1.25,
    front: (b) {
      b.shape('rect', 0.5, 0.17, 1, 0.34, color: b.accent, c2: 0xFFFF6FB5);
      b.photo(0.5, 0.36, 0.26, 0.4, color: _w);
      b.field(
        'name',
        0.5,
        0.64,
        size: 0.075,
        bold: true,
        align: 'center',
        w: 0.9,
      );
      b.field('pronouns', 0.5, 0.74, align: 'center', w: 0.9, color: b.accent);
      b.field('status', 0.5, 0.84, size: 0.042, align: 'center', w: 0.9);
      b.field(
        'interests',
        0.5,
        0.93,
        size: 0.038,
        align: 'center',
        w: 0.9,
        op: 0.7,
      );
    },
  ),
  IdTemplate(
    id: 'tpl.social-story',
    name: 'Story card',
    category: 'Social',
    bg1: 0xFF3A1C71,
    bg2: 0xFFFFAF7B,
    ink: _w,
    accent: _w,
    aspect: idPortrait,
    front: (b) {
      b.shape('rrect', 0.5, 0.03, 0.84, 0.012, color: _w, op: 0.7);
      b.photo(0.17, 0.1, 0.16, 0.1, color: _w);
      b.field('name', 0.34, 0.095, size: 0.06, bold: true, w: 0.6);
      b.field('pronouns', 0.34, 0.14, size: 0.04, w: 0.6, op: 0.85);
      b.emoji('✨', 0.5, 0.5, 0.5, op: 0.9);
      b.field(
        'status',
        0.5,
        0.78,
        size: 0.07,
        bold: true,
        align: 'center',
        w: 0.86,
      );
      b.field('interests', 0.5, 0.86, size: 0.045, align: 'center', w: 0.86);
      b.shape('rrect', 0.5, 0.94, 0.7, 0.05, color: _w, op: 0.25);
    },
  ),
  // ── Minimalist ────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.minimal-mono',
    name: 'Minimal mono',
    category: 'Minimalist',
    bg1: 0xFFFAFAFA,
    bg2: 0xFFFAFAFA,
    ink: _k,
    accent: _k,
    front: (b) {
      b.field('name', 0.08, 0.2, size: 0.09, bold: true, w: 0.84);
      b.field('pronouns', 0.08, 0.34, size: 0.045, w: 0.6, op: 0.6);
      b.photo(0.84, 0.76, 0.18, 0.3, color: _k);
      b.field('number', 0.08, 0.9, size: 0.036, w: 0.5, op: 0.55);
      b.line(0.5, 0.8, 0.84, op: 0.25);
    },
  ),
  IdTemplate(
    id: 'tpl.minimal-dot',
    name: 'Minimal dot',
    category: 'Minimalist',
    bg1: 0xFFF3F1EC,
    bg2: 0xFFF3F1EC,
    ink: 0xFF2B2B2B,
    accent: 0xFFE4572E,
    front: (b) {
      b.circle(0.5, 0.5, 0.34, color: 0xFFE4572E);
      b.photo(0.5, 0.5, 0.2, 0.4, color: _w);
      b.field('name', 0.08, 0.12, size: 0.05, bold: true, w: 0.4);
      b.field('role', 0.92, 0.12, size: 0.04, align: 'right', w: 0.4, op: 0.6);
      b.field('number', 0.08, 0.9, size: 0.036, w: 0.4, op: 0.6);
      b.field(
        'pronouns',
        0.92,
        0.9,
        size: 0.036,
        align: 'right',
        w: 0.4,
        op: 0.6,
      );
    },
  ),
  // ── Glassmorphism ─────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.glass-frost',
    name: 'Frosted glass',
    category: 'Glass',
    bg1: 0xFF6A82FB,
    bg2: 0xFFFC5C7D,
    pattern: 'bokeh',
    ink: _w,
    accent: _w,
    front: (b) {
      b.circle(0.2, 0.8, 0.3, color: 0xFFFFD166, op: 0.7);
      b.circle(0.85, 0.2, 0.24, color: 0xFF06D6A0, op: 0.6);
      b.shape('rrect', 0.5, 0.5, 0.86, 0.78, color: _w, op: 0.22);
      b.shape('rrect', 0.5, 0.5, 0.86, 0.78, color: _w, stroke: 0.004, op: 0.6);
      b.photo(0.25, 0.46, 0.25, 0.5, color: _w);
      b.field('name', 0.43, 0.38, size: 0.065, bold: true, w: 0.5);
      b.field('pronouns', 0.43, 0.5, w: 0.5, op: 0.9);
      b.field('role', 0.43, 0.6, w: 0.5, op: 0.9);
      b.heading(0.43, 0.2, size: 0.036, color: _w, w: 0.5);
    },
  ),
  IdTemplate(
    id: 'tpl.glass-aurora',
    name: 'Aurora glass',
    category: 'Glass',
    bg1: 0xFF0F2027,
    bg2: 0xFF2C5364,
    pattern: 'bokeh',
    ink: _w,
    accent: 0xFF7DF9C8,
    front: (b) {
      b.shape('blob', 0.3, 0.3, 0.6, 0.7, color: 0xFF7DF9C8, op: 0.35);
      b.shape('blob', 0.78, 0.75, 0.5, 0.6, color: 0xFFB388FF, op: 0.35);
      b.shape('rrect', 0.5, 0.5, 0.9, 0.82, color: _w, op: 0.14);
      b.field('name', 0.08, 0.3, size: 0.08, bold: true, w: 0.7);
      b.field('role', 0.08, 0.44, op: 0.85);
      b.field('interests', 0.08, 0.56, size: 0.04, op: 0.8, w: 0.7);
      b.photo(0.8, 0.28, 0.2, 0.34, color: _w);
      b.field('number', 0.08, 0.86, size: 0.038, op: 0.7);
    },
  ),
  // ── Holographic ───────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.holo-foil',
    name: 'Holo foil',
    category: 'Holographic',
    bg1: 0xFFE3F2FF,
    bg2: 0xFFF8E3FF,
    pattern: 'holo',
    ink: 0xFF2A2440,
    accent: 0xFF8E6CF0,
    front: (b) {
      b.shape(
        'diamond',
        0.82,
        0.3,
        0.3,
        0.55,
        color: 0xFFB39AFF,
        c2: 0xFF9AE6FF,
        op: 0.65,
      );
      b.shape(
        'diamond',
        0.9,
        0.78,
        0.18,
        0.3,
        color: 0xFFFF9AE6,
        c2: 0xFFFFF59A,
        op: 0.6,
      );
      b.photo(0.2, 0.5, 0.26, 0.56);
      b.field('name', 0.38, 0.38, size: 0.07, bold: true, w: 0.45);
      b.field('pronouns', 0.38, 0.5, w: 0.45);
      b.field('number', 0.38, 0.84, size: 0.04, w: 0.45);
      b.emoji('✨', 0.12, 0.1, 0.08);
    },
  ),
  IdTemplate(
    id: 'tpl.holo-prism',
    name: 'Prism burst',
    category: 'Holographic',
    bg1: 0xFF1B1B3A,
    bg2: 0xFF2E1A47,
    pattern: 'rays',
    ink: _w,
    accent: 0xFFFFD6F6,
    front: (b) {
      b.shape(
        'burst',
        0.5,
        0.5,
        0.7,
        1.1,
        color: 0xFFFFD6F6,
        c2: 0xFF9AE6FF,
        op: 0.3,
      );
      b.shape(
        'hex',
        0.5,
        0.5,
        0.36,
        0.7,
        color: 0xFFB39AFF,
        c2: 0xFFFFF59A,
        op: 0.9,
      );
      b.photo(0.5, 0.5, 0.22, 0.45, color: _w);
      b.field('name', 0.06, 0.15, size: 0.06, bold: true, w: 0.34);
      b.field('role', 0.94, 0.85, size: 0.042, align: 'right', w: 0.34);
      b.field('number', 0.06, 0.88, size: 0.036, w: 0.34, op: 0.7);
    },
  ),
  // ── Anime-inspired ────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.anime-hero',
    name: 'Hero card',
    category: 'Anime',
    bg1: 0xFFFFF176,
    bg2: 0xFFFF8A65,
    pattern: 'rays',
    ink: 0xFF1A1A2E,
    accent: 0xFFE53935,
    font: 'rounded',
    front: (b) {
      b.shape('para', 0.3, 0.5, 0.52, 1.1, color: 0xFF1A1A2E, op: 0.9);
      b.photo(0.26, 0.5, 0.26, 0.56, color: _w);
      b.shape('burst', 0.82, 0.24, 0.3, 0.5, color: _w, op: 0.9);
      b.text('LV', 0.82, 0.2, size: 0.045, bold: true, align: 'center', w: 0.2);
      b.text(
        '99',
        0.82,
        0.32,
        size: 0.075,
        bold: true,
        align: 'center',
        color: b.accent,
        w: 0.2,
      );
      b.field('name', 0.54, 0.55, size: 0.07, bold: true, w: 0.42);
      b.field('role', 0.54, 0.67, w: 0.42);
      b.field('pronouns', 0.54, 0.78, size: 0.04, w: 0.42);
      b.text(
        '!!',
        0.9,
        0.9,
        size: 0.1,
        bold: true,
        color: b.accent,
        w: 0.2,
        rot: 8,
      );
    },
  ),
  IdTemplate(
    id: 'tpl.anime-manga',
    name: 'Manga panel',
    category: 'Anime',
    bg1: 0xFFFFFFFF,
    bg2: 0xFFF2F2F2,
    pattern: 'crosshatch',
    ink: _k,
    accent: _k,
    front: (b) {
      b.shape('rect', 0.5, 0.5, 0.94, 0.9, color: _k, stroke: 0.014);
      b.shape('para', 0.28, 0.5, 0.44, 0.88, color: _k, op: 0.08);
      b.photo(0.27, 0.5, 0.3, 0.7, color: _k);
      b.text(
        'ドン!',
        0.78,
        0.2,
        size: 0.08,
        bold: true,
        align: 'center',
        w: 0.3,
        rot: -6,
      );
      b.field('name', 0.5, 0.5, size: 0.07, bold: true, w: 0.45);
      b.field('role', 0.5, 0.62, w: 0.45);
      b.field('pronouns', 0.5, 0.72, size: 0.04, w: 0.45);
      b.shape('cloud', 0.78, 0.86, 0.3, 0.2, color: _k, op: 0.1);
    },
  ),
  // ── RPG character ─────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.rpg-sheet',
    name: 'Character sheet',
    category: 'RPG',
    bg1: 0xFFF1E4C6,
    bg2: 0xFFE2CE9C,
    pattern: 'paper',
    ink: 0xFF3B2412,
    accent: 0xFF8B1E1E,
    aspect: idPortrait,
    font: 'serif',
    front: (b) {
      b.shape('rect', 0.5, 0.5, 0.92, 0.94, color: b.ink, stroke: 0.008);
      b.text(
        'CHARACTER',
        0.5,
        0.06,
        size: 0.07,
        bold: true,
        align: 'center',
        w: 0.8,
        color: b.accent,
      );
      b.photo(0.5, 0.26, 0.36, 0.26, color: b.ink);
      b.field(
        'name',
        0.5,
        0.46,
        size: 0.075,
        bold: true,
        align: 'center',
        w: 0.8,
      );
      b.field('role', 0.5, 0.52, size: 0.05, align: 'center', w: 0.8);
      for (var i = 0; i < 6; i++) {
        final x = 0.18 + (i % 3) * 0.32, y = 0.64 + (i ~/ 3) * 0.15;
        b.shape('shield', x, y, 0.2, 0.1, color: b.accent, op: 0.85);
        b.text(
          const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'][i],
          x,
          y,
          size: 0.034,
          bold: true,
          align: 'center',
          color: _w,
          w: 0.2,
        );
      }
      b.field(
        'number',
        0.5,
        0.92,
        size: 0.036,
        align: 'center',
        w: 0.8,
        op: 0.7,
      );
    },
  ),
  IdTemplate(
    id: 'tpl.rpg-guild',
    name: 'Guild badge',
    category: 'RPG',
    bg1: 0xFF2B2118,
    bg2: 0xFF4A3724,
    pattern: 'scales',
    ink: 0xFFF3E3B8,
    accent: 0xFFD4A537,
    font: 'serif',
    front: (b) {
      b.shape(
        'shield',
        0.18,
        0.5,
        0.3,
        0.86,
        color: 0xFFD4A537,
        c2: 0xFF8C6A1C,
      );
      b.photo(0.18, 0.4, 0.2, 0.36, color: 0xFFF3E3B8);
      b.emoji('⚔️', 0.18, 0.78, 0.1);
      b.heading(0.4, 0.14, size: 0.05, w: 0.55);
      b.field('name', 0.4, 0.34, size: 0.07, bold: true, w: 0.55);
      b.field('role', 0.4, 0.46, w: 0.55);
      b.line(0.67, 0.58, 0.5, color: 0xFFD4A537);
      b.field('notes', 0.4, 0.68, size: 0.04, w: 0.55);
      b.field('number', 0.4, 0.88, size: 0.038, w: 0.55);
    },
  ),
  // ── Trading card ──────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.trading-classic',
    name: 'Trading card',
    category: 'Trading card',
    bg1: 0xFFFFD54F,
    bg2: 0xFFFFB300,
    ink: 0xFF2B1B00,
    accent: 0xFFB71C1C,
    aspect: 0.716,
    font: 'rounded',
    front: (b) {
      b.shape('rrect', 0.5, 0.5, 0.92, 0.94, color: 0xFF2B1B00, stroke: 0.014);
      b.field('name', 0.08, 0.07, size: 0.075, bold: true, w: 0.6);
      b.text(
        'HP 100',
        0.92,
        0.07,
        size: 0.05,
        bold: true,
        align: 'right',
        color: b.accent,
        w: 0.3,
      );
      b.photo(0.5, 0.35, 0.8, 0.4, color: 0xFF2B1B00);
      b.field('role', 0.08, 0.62, size: 0.045, bold: true, w: 0.84);
      b.shape('rect', 0.5, 0.78, 0.84, 0.2, color: _w, op: 0.55);
      b.field('notes', 0.1, 0.78, size: 0.04, w: 0.8);
      b.field('number', 0.08, 0.93, size: 0.032, w: 0.5, op: 0.7);
      b.emoji('⭐', 0.88, 0.93, 0.07);
    },
  ),
  IdTemplate(
    id: 'tpl.trading-foil',
    name: 'Foil rare',
    category: 'Trading card',
    bg1: 0xFF1C1C3A,
    bg2: 0xFF4A1F6B,
    pattern: 'holo',
    ink: _w,
    accent: 0xFFFFE066,
    aspect: 0.716,
    front: (b) {
      b.shape(
        'rrect',
        0.5,
        0.5,
        0.94,
        0.95,
        color: 0xFFFFE066,
        c2: 0xFFFF9AE6,
        stroke: 0.02,
      );
      b.photo(0.5, 0.4, 0.78, 0.58, color: 0xFFFFE066);
      b.shape('ribbon', 0.5, 0.74, 0.78, 0.08, color: 0xFFFFE066);
      b.field(
        'name',
        0.5,
        0.74,
        size: 0.06,
        bold: true,
        align: 'center',
        w: 0.7,
        color: 0xFF1C1C3A,
      );
      b.field('role', 0.5, 0.83, size: 0.045, align: 'center', w: 0.8);
      b.text(
        '★ ★ ★',
        0.5,
        0.92,
        size: 0.05,
        align: 'center',
        color: 0xFFFFE066,
        w: 0.5,
      );
    },
  ),
  // ── Magazine ──────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.magazine-cover',
    name: 'Magazine cover',
    category: 'Magazine',
    bg1: 0xFFFF3D71,
    bg2: 0xFFFF3D71,
    ink: _w,
    accent: _w,
    aspect: 0.78,
    font: 'serif',
    front: (b) {
      b.text(
        b.title.toUpperCase().split(' ').first,
        0.5,
        0.1,
        size: 0.17,
        bold: true,
        align: 'center',
        w: 0.95,
        color: _w,
      );
      b.photo(0.5, 0.5, 0.84, 0.6, color: _w);
      b.field('name', 0.08, 0.84, size: 0.075, bold: true, w: 0.84);
      b.field('role', 0.08, 0.91, size: 0.04, w: 0.6);
      b.shape('burst', 0.84, 0.2, 0.2, 0.2, color: 0xFFFFE600, c2: null);
      b.text(
        'NEW!',
        0.84,
        0.2,
        size: 0.04,
        bold: true,
        align: 'center',
        color: _k,
        w: 0.18,
        rot: 10,
      );
    },
  ),
  IdTemplate(
    id: 'tpl.magazine-editorial',
    name: 'Editorial spread',
    category: 'Magazine',
    bg1: 0xFFF7F2EA,
    bg2: 0xFFF7F2EA,
    ink: 0xFF1F1F1F,
    accent: 0xFFB8242C,
    font: 'serif',
    front: (b) {
      b.photo(0.25, 0.5, 0.5, 1.0, color: _k);
      b.text(
        'PROFILE',
        0.56,
        0.1,
        size: 0.034,
        bold: true,
        color: b.accent,
        w: 0.4,
      );
      b.field('name', 0.56, 0.25, size: 0.085, bold: true, w: 0.4);
      b.line(0.76, 0.36, 0.38);
      b.field('role', 0.56, 0.46, size: 0.04, w: 0.4);
      b.field('interests', 0.56, 0.58, size: 0.036, w: 0.4);
      b.field('notes', 0.56, 0.7, size: 0.034, w: 0.4);
      b.field('number', 0.56, 0.92, size: 0.03, w: 0.4, op: 0.5);
    },
  ),
  // ── Gothic ────────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.gothic-manor',
    name: 'Gothic manor',
    category: 'Gothic',
    bg1: 0xFF18101F,
    bg2: 0xFF2B1633,
    pattern: 'diamonds',
    ink: 0xFFE8D9F2,
    accent: 0xFFB0305C,
    font: 'serif',
    front: (b) {
      b.shape('rect', 0.5, 0.5, 0.94, 0.9, color: 0xFFB0305C, stroke: 0.008);
      b.shape('brackets', 0.5, 0.5, 0.88, 0.84, color: 0xFFE8D9F2, op: 0.6);
      b.shape('moon', 0.84, 0.2, 0.16, 0.26, color: 0xFFE8D9F2);
      b.photo(0.22, 0.5, 0.26, 0.5, color: 0xFFB0305C);
      b.field('name', 0.4, 0.36, size: 0.068, bold: true, w: 0.45);
      b.field('role', 0.4, 0.48, w: 0.45, color: 0xFFD7A6C0);
      b.field('birthday', 0.4, 0.6, size: 0.04, w: 0.45);
      b.text(
        '✠',
        0.5,
        0.88,
        size: 0.07,
        align: 'center',
        color: 0xFFB0305C,
        w: 0.2,
      );
    },
  ),
  IdTemplate(
    id: 'tpl.gothic-crest',
    name: 'Blackletter crest',
    category: 'Gothic',
    bg1: 0xFF0D0D0D,
    bg2: 0xFF1E1E1E,
    pattern: 'scales',
    ink: 0xFFD9D9D9,
    accent: 0xFFC0C0C0,
    font: 'script',
    front: (b) {
      b.shape('shield', 0.5, 0.5, 0.34, 0.9, color: 0xFFC0C0C0, stroke: 0.012);
      b.photo(0.5, 0.38, 0.2, 0.36, color: 0xFFC0C0C0);
      b.emoji('🦇', 0.5, 0.74, 0.1);
      b.field('name', 0.06, 0.3, size: 0.07, bold: true, w: 0.34);
      b.field('role', 0.94, 0.3, size: 0.05, align: 'right', w: 0.34);
      b.field('pronouns', 0.06, 0.7, size: 0.04, w: 0.34);
      b.field('number', 0.94, 0.7, size: 0.036, align: 'right', w: 0.34);
    },
  ),
  // ── Cottagecore ───────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.cottage-garden',
    name: 'Cottage garden',
    category: 'Cottagecore',
    bg1: 0xFFF7F1DF,
    bg2: 0xFFE9EFD2,
    pattern: 'floral',
    ink: 0xFF4A3B2A,
    accent: 0xFF6B8F4E,
    font: 'serif',
    front: (b) {
      b.shape('scallop', 0.5, 0.06, 1, 0.12, color: 0xFFFFC2D1);
      b.shape(
        'leaf',
        0.08,
        0.92,
        0.16,
        0.18,
        color: 0xFF6B8F4E,
        rot: -30,
        op: 0.9,
      );
      b.shape(
        'leaf',
        0.16,
        0.95,
        0.14,
        0.14,
        color: 0xFF8DB36B,
        rot: 10,
        op: 0.9,
      );
      b.emoji('🌷', 0.9, 0.9, 0.12);
      b.photo(0.22, 0.5, 0.24, 0.5, color: 0xFF6B8F4E);
      b.field('name', 0.42, 0.34, size: 0.066, bold: true, w: 0.5);
      b.field('pronouns', 0.42, 0.46, w: 0.5);
      b.field('interests', 0.42, 0.58, size: 0.04, w: 0.5);
      b.field('number', 0.42, 0.8, size: 0.036, w: 0.5, op: 0.7);
    },
  ),
  IdTemplate(
    id: 'tpl.cottage-gingham',
    name: 'Gingham picnic',
    category: 'Cottagecore',
    bg1: 0xFFFFFFFF,
    bg2: 0xFFFFE3E3,
    pattern: 'gingham',
    ink: 0xFF5A2A2A,
    accent: 0xFFD6455D,
    font: 'rounded',
    front: (b) {
      b.shape('rrect', 0.5, 0.5, 0.82, 0.7, color: 0xFFFFFFFF, op: 0.9);
      b.shape('rrect', 0.5, 0.5, 0.82, 0.7, color: 0xFFD6455D, stroke: 0.006);
      b.emoji('🍓', 0.12, 0.14, 0.12, rot: -15);
      b.emoji('🧺', 0.88, 0.86, 0.14, rot: 10);
      b.photo(0.3, 0.5, 0.22, 0.4, color: 0xFFD6455D);
      b.field('name', 0.5, 0.4, size: 0.062, bold: true, w: 0.4);
      b.field('role', 0.5, 0.52, w: 0.4);
      b.field('interests', 0.5, 0.63, size: 0.038, w: 0.4);
    },
  ),
  // ── Cyberpunk ─────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.cyber-neon',
    name: 'Neon runner',
    category: 'Cyberpunk',
    bg1: 0xFF0D0F1A,
    bg2: 0xFF1F1240,
    pattern: 'scanlines',
    ink: 0xFF7DF9FF,
    accent: 0xFFFF2E93,
    font: 'mono',
    front: (b) {
      b.shape('notch', 0.5, 0.5, 0.94, 0.88, color: 0xFFFF2E93, stroke: 0.008);
      b.shape(
        'notch',
        0.5,
        0.5,
        0.88,
        0.8,
        color: 0xFF7DF9FF,
        stroke: 0.003,
        op: 0.8,
      );
      b.photo(0.2, 0.46, 0.24, 0.46, color: 0xFF7DF9FF);
      b.text(
        '>> ${b.title.toUpperCase()}',
        0.36,
        0.16,
        size: 0.04,
        bold: true,
        color: 0xFFFF2E93,
        w: 0.58,
      );
      b.field('name', 0.36, 0.34, size: 0.062, bold: true, w: 0.58);
      b.field('role', 0.36, 0.46, size: 0.042, w: 0.58);
      b.field('number', 0.36, 0.58, size: 0.04, w: 0.58);
      b.barcode(0.62, 0.78, 0.5, 0.12, color: 0xFF7DF9FF);
    },
  ),
  IdTemplate(
    id: 'tpl.cyber-glitch',
    name: 'Glitch terminal',
    category: 'Cyberpunk',
    bg1: 0xFF020B05,
    bg2: 0xFF04140A,
    pattern: 'circuit',
    ink: 0xFF39FF14,
    accent: 0xFF39FF14,
    font: 'mono',
    front: (b) {
      b.shape('rect', 0.5, 0.1, 1, 0.14, color: 0xFF39FF14, op: 0.9);
      b.text(
        'root@prism:~\$ whoami',
        0.04,
        0.1,
        size: 0.04,
        bold: true,
        color: _k,
        w: 0.8,
      );
      b.field('name', 0.06, 0.32, size: 0.06, w: 0.88);
      b.field('role', 0.06, 0.44, size: 0.045, w: 0.88);
      b.field('pronouns', 0.06, 0.55, size: 0.045, w: 0.88);
      b.field('status', 0.06, 0.66, size: 0.045, w: 0.88);
      b.text('█', 0.06, 0.8, size: 0.06, w: 0.1);
      b.photo(0.84, 0.62, 0.2, 0.42, color: 0xFF39FF14);
    },
  ),
  // ── Celestial ─────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.celestial-chart',
    name: 'Star chart',
    category: 'Celestial',
    bg1: 0xFF141A3D,
    bg2: 0xFF3B2C6E,
    pattern: 'stars',
    ink: 0xFFF4F1FF,
    accent: 0xFFFFD66B,
    font: 'serif',
    front: (b) {
      b.shape('ring', 0.78, 0.5, 0.5, 0.9, color: 0xFFFFD66B, op: 0.35);
      b.shape('ring', 0.78, 0.5, 0.34, 0.6, color: 0xFFFFD66B, op: 0.35);
      b.photo(0.78, 0.5, 0.2, 0.38, color: 0xFFFFD66B);
      b.field('name', 0.06, 0.32, size: 0.066, bold: true, w: 0.5);
      b.field('birthday', 0.06, 0.45, w: 0.5);
      b.field('pronouns', 0.06, 0.56, w: 0.5);
      b.emoji('☾', 0.1, 0.84, 0.1);
      b.field('number', 0.24, 0.86, size: 0.036, w: 0.4, op: 0.7);
    },
  ),
  IdTemplate(
    id: 'tpl.celestial-moon',
    name: 'Moon phase',
    category: 'Celestial',
    bg1: 0xFF0B1026,
    bg2: 0xFF1A2347,
    pattern: 'snow',
    ink: 0xFFE9EEFF,
    accent: 0xFFC8D1FF,
    aspect: idPortrait,
    front: (b) {
      for (var i = 0; i < 5; i++) {
        b.circle(
          0.15 + i * 0.175,
          0.07,
          0.07,
          color: 0xFFE9EEFF,
          op: i == 2 ? 1 : 0.3 + i * 0.12,
        );
      }
      b.shape('moon', 0.5, 0.34, 0.5, 0.34, color: 0xFFE9EEFF, c2: 0xFFC8D1FF);
      b.photo(0.5, 0.34, 0.24, 0.17, color: 0xFFE9EEFF);
      b.field(
        'name',
        0.5,
        0.62,
        size: 0.085,
        bold: true,
        align: 'center',
        w: 0.9,
      );
      b.field('pronouns', 0.5, 0.7, size: 0.05, align: 'center', w: 0.9);
      b.field('birthday', 0.5, 0.78, size: 0.045, align: 'center', w: 0.9);
      b.field(
        'number',
        0.5,
        0.94,
        size: 0.036,
        align: 'center',
        w: 0.9,
        op: 0.6,
      );
    },
  ),
  IdTemplate(
    id: 'tpl.celestial-tarot',
    name: 'Tarot card',
    category: 'Celestial',
    bg1: 0xFF2A1740,
    bg2: 0xFF4E2A6B,
    pattern: 'rays',
    ink: 0xFFFBE9B7,
    accent: 0xFFE8B84A,
    aspect: 0.58,
    font: 'serif',
    front: (b) {
      b.shape('rect', 0.5, 0.5, 0.9, 0.94, color: 0xFFE8B84A, stroke: 0.012);
      b.shape(
        'rect',
        0.5,
        0.5,
        0.82,
        0.88,
        color: 0xFFE8B84A,
        stroke: 0.004,
        op: 0.7,
      );
      b.text(
        '✦ ${b.title.toUpperCase()} ✦',
        0.5,
        0.09,
        size: 0.05,
        bold: true,
        align: 'center',
        w: 0.8,
      );
      b.photo(0.5, 0.42, 0.62, 0.44, color: 0xFFE8B84A);
      b.field(
        'name',
        0.5,
        0.74,
        size: 0.075,
        bold: true,
        align: 'center',
        w: 0.8,
      );
      b.field('role', 0.5, 0.82, size: 0.05, align: 'center', w: 0.8);
      b.emoji('☼', 0.5, 0.92, 0.1);
    },
  ),
  // ── Kawaii ────────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.kawaii-cloud',
    name: 'Kawaii cloud',
    category: 'Kawaii',
    bg1: 0xFFFFE3F0,
    bg2: 0xFFD9F1FF,
    pattern: 'bubbles',
    ink: 0xFF5A3D5C,
    accent: 0xFFFF7AB6,
    font: 'rounded',
    front: (b) {
      b.shape('cloud', 0.2, 0.14, 0.3, 0.2, color: _w);
      b.shape('cloud', 0.84, 0.82, 0.26, 0.18, color: _w);
      b.shape('rrect', 0.5, 0.52, 0.86, 0.66, color: _w, op: 0.85);
      b.photo(0.26, 0.52, 0.26, 0.5, color: 0xFFFF7AB6);
      b.field('name', 0.46, 0.38, size: 0.07, bold: true, w: 0.45);
      b.field('pronouns', 0.46, 0.5, w: 0.45, color: 0xFFFF7AB6);
      b.field('interests', 0.46, 0.62, size: 0.04, w: 0.45);
      b.emoji('🌸', 0.9, 0.14, 0.1, rot: 15);
      b.emoji('💖', 0.1, 0.88, 0.09);
    },
  ),
  IdTemplate(
    id: 'tpl.kawaii-sticker',
    name: 'Sticker sheet',
    category: 'Kawaii',
    bg1: 0xFFFFF4C9,
    bg2: 0xFFFFE0F0,
    pattern: 'dots',
    ink: 0xFF5A3D5C,
    accent: 0xFFFF7AB6,
    font: 'rounded',
    aspect: idSquare,
    front: (b) {
      b.shape('blob', 0.5, 0.42, 0.62, 0.62, color: _w);
      b.shape('blob', 0.5, 0.42, 0.62, 0.62, color: 0xFFFF7AB6, stroke: 0.01);
      b.photo(0.5, 0.42, 0.34, 0.34, color: 0xFFFF7AB6);
      b.emoji('⭐', 0.12, 0.12, 0.14, rot: -12);
      b.emoji('🎀', 0.88, 0.14, 0.14, rot: 12);
      b.emoji('🍓', 0.1, 0.62, 0.12);
      b.emoji('🐰', 0.9, 0.66, 0.14);
      b.field(
        'name',
        0.5,
        0.82,
        size: 0.075,
        bold: true,
        align: 'center',
        w: 0.9,
      );
      b.field('pronouns', 0.5, 0.92, size: 0.045, align: 'center', w: 0.9);
    },
  ),
  // ── Grunge ────────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.grunge-xerox',
    name: 'Xerox grunge',
    category: 'Grunge',
    bg1: 0xFFE6E2DA,
    bg2: 0xFFCFCABE,
    pattern: 'grunge',
    ink: 0xFF151515,
    accent: 0xFF151515,
    font: 'mono',
    front: (b) {
      b.shape('torn', 0.5, 0.2, 1, 0.34, color: 0xFF151515);
      b.text(
        b.title.toUpperCase(),
        0.5,
        0.2,
        size: 0.07,
        bold: true,
        align: 'center',
        color: 0xFFE6E2DA,
        w: 0.9,
        rot: -2,
      );
      b.photo(0.22, 0.62, 0.26, 0.5, color: 0xFF151515, rot: -3);
      b.field('name', 0.4, 0.52, size: 0.066, bold: true, w: 0.55, rot: 1);
      b.field('role', 0.4, 0.64, w: 0.55);
      b.field('interests', 0.4, 0.75, size: 0.04, w: 0.55);
      b.shape('rect', 0.7, 0.9, 0.5, 0.05, color: 0xFFE8D400, rot: -2);
    },
  ),
  IdTemplate(
    id: 'tpl.grunge-zine',
    name: 'Punk zine',
    category: 'Grunge',
    bg1: 0xFFF2F2F2,
    bg2: 0xFFF2F2F2,
    pattern: 'crosshatch',
    ink: _k,
    accent: 0xFFE4002B,
    font: 'mono',
    front: (b) {
      b.text(
        'ZINE',
        0.5,
        0.16,
        size: 0.2,
        bold: true,
        align: 'center',
        w: 0.95,
        color: _k,
      );
      b.shape('rect', 0.5, 0.34, 0.9, 0.05, color: 0xFFE4002B);
      b.photo(0.78, 0.66, 0.3, 0.5, color: _k, rot: 3);
      b.field('name', 0.06, 0.52, size: 0.07, bold: true, w: 0.56, rot: -2);
      b.field('role', 0.06, 0.64, w: 0.56);
      b.field('pronouns', 0.06, 0.74, size: 0.04, w: 0.56);
      b.text(
        '★ DIY ★',
        0.06,
        0.9,
        size: 0.05,
        bold: true,
        color: 0xFFE4002B,
        w: 0.4,
      );
    },
  ),
  // ── Scrapbook ─────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.scrap-page',
    name: 'Scrapbook page',
    category: 'Scrapbook',
    bg1: 0xFFFFF8EC,
    bg2: 0xFFF3E6CF,
    pattern: 'paper',
    ink: 0xFF4A3B2A,
    accent: 0xFFC0392B,
    font: 'script',
    front: (b) {
      b.shape('rect', 0.24, 0.52, 0.34, 0.66, color: _w, rot: -4);
      b.photo(0.24, 0.5, 0.29, 0.5, color: 0xFFC0392B, rot: -4);
      b.shape(
        'para',
        0.24,
        0.12,
        0.2,
        0.08,
        color: 0xFFF7C6D9,
        rot: -10,
        op: 0.85,
      );
      b.shape('rect', 0.7, 0.55, 0.5, 0.3, color: 0xFFFFF3A3, rot: 3);
      b.field('name', 0.48, 0.5, size: 0.062, bold: true, w: 0.44, rot: 3);
      b.field('pronouns', 0.48, 0.61, w: 0.44, rot: 3);
      b.emoji('🌼', 0.9, 0.18, 0.12, rot: 20);
      b.emoji('📌', 0.7, 0.36, 0.07);
    },
  ),
  IdTemplate(
    id: 'tpl.scrap-washi',
    name: 'Washi collage',
    category: 'Scrapbook',
    bg1: 0xFFE9F4EC,
    bg2: 0xFFF7EFE0,
    pattern: 'dots',
    ink: 0xFF2F4F4F,
    accent: 0xFFE76F51,
    font: 'hand',
    front: (b) {
      b.shape(
        'para',
        0.15,
        0.1,
        0.34,
        0.1,
        color: 0xFFE76F51,
        rot: -8,
        op: 0.85,
      );
      b.shape(
        'para',
        0.86,
        0.9,
        0.34,
        0.1,
        color: 0xFF2A9D8F,
        rot: -8,
        op: 0.85,
      );
      b.shape('rect', 0.5, 0.5, 0.78, 0.62, color: _w);
      b.photo(0.3, 0.5, 0.25, 0.46, color: 0xFFE76F51, rot: 2);
      b.field('name', 0.48, 0.38, size: 0.066, bold: true, w: 0.42);
      b.field('role', 0.48, 0.5, w: 0.42);
      b.field('interests', 0.48, 0.62, size: 0.04, w: 0.42);
      b.emoji('✂️', 0.86, 0.2, 0.1, rot: 30);
    },
  ),
  // ── Botanical ─────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.botanical-plate',
    name: 'Botanical plate',
    category: 'Botanical',
    bg1: 0xFFF6F1E1,
    bg2: 0xFFEAE3C8,
    pattern: 'paper',
    ink: 0xFF2E4A32,
    accent: 0xFF4F7A52,
    font: 'serif',
    aspect: idPortrait,
    front: (b) {
      b.text(
        'PLATE I',
        0.5,
        0.05,
        size: 0.04,
        bold: true,
        align: 'center',
        w: 0.6,
      );
      b.photo(0.5, 0.34, 0.6, 0.4, color: 0xFF4F7A52);
      b.shape('leaf', 0.14, 0.7, 0.16, 0.14, color: 0xFF4F7A52, rot: -20);
      b.shape('leaf', 0.86, 0.7, 0.16, 0.14, color: 0xFF6FA06B, rot: 200);
      b.field(
        'name',
        0.5,
        0.64,
        size: 0.08,
        bold: true,
        align: 'center',
        w: 0.8,
      );
      b.line(0.5, 0.71, 0.5);
      b.field('role', 0.5, 0.77, size: 0.048, align: 'center', w: 0.8);
      b.field('birthday', 0.5, 0.84, size: 0.04, align: 'center', w: 0.8);
      b.field(
        'number',
        0.5,
        0.94,
        size: 0.034,
        align: 'center',
        w: 0.8,
        op: 0.6,
      );
    },
  ),
  IdTemplate(
    id: 'tpl.botanical-fern',
    name: 'Fern frame',
    category: 'Botanical',
    bg1: 0xFFDCEBD3,
    bg2: 0xFFC4DDB8,
    pattern: 'topo',
    ink: 0xFF1F3D2B,
    accent: 0xFF2F6B45,
    font: 'rounded',
    front: (b) {
      for (var i = 0; i < 4; i++) {
        b.shape(
          'leaf',
          0.08 + i * 0.07,
          0.1 + i * 0.1,
          0.12,
          0.1,
          color: 0xFF2F6B45,
          rot: -40 + i * 12,
          op: 0.7,
        );
        b.shape(
          'leaf',
          0.92 - i * 0.07,
          0.9 - i * 0.1,
          0.12,
          0.1,
          color: 0xFF2F6B45,
          rot: 140 + i * 12,
          op: 0.7,
        );
      }
      b.shape('rrect', 0.5, 0.5, 0.7, 0.64, color: _w, op: 0.8);
      b.photo(0.34, 0.5, 0.22, 0.42, color: 0xFF2F6B45);
      b.field('name', 0.5, 0.4, size: 0.06, bold: true, w: 0.34);
      b.field('role', 0.5, 0.52, w: 0.34);
      b.field('pronouns', 0.5, 0.63, size: 0.04, w: 0.34);
    },
  ),
  // ── Retro technology ──────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.retro-terminal',
    name: 'Retro terminal',
    category: 'Retro tech',
    bg1: 0xFF1D2B20,
    bg2: 0xFF0F1A12,
    pattern: 'scanlines',
    ink: 0xFFB6F5A5,
    accent: 0xFFB6F5A5,
    font: 'mono',
    front: (b) {
      b.shape('rrect', 0.5, 0.5, 0.92, 0.86, color: 0xFFB6F5A5, stroke: 0.01);
      b.text('PRISM OS v1.0', 0.08, 0.14, size: 0.04, bold: true, w: 0.6);
      b.field('name', 0.08, 0.32, size: 0.06, w: 0.84);
      b.field('role', 0.08, 0.44, size: 0.045, w: 0.84);
      b.field('number', 0.08, 0.56, size: 0.045, w: 0.84);
      b.text('READY.', 0.08, 0.76, size: 0.05, bold: true, w: 0.4);
      b.photo(0.82, 0.62, 0.2, 0.4, color: 0xFFB6F5A5);
    },
  ),
  IdTemplate(
    id: 'tpl.retro-cassette',
    name: 'Cassette',
    category: 'Retro tech',
    bg1: 0xFFF4E3C1,
    bg2: 0xFFE4C98F,
    pattern: 'stripes',
    ink: 0xFF2B2B2B,
    accent: 0xFFD1495B,
    font: 'rounded',
    front: (b) {
      b.shape('rrect', 0.5, 0.5, 0.92, 0.88, color: 0xFF2B2B2B, op: 0.9);
      b.shape('rrect', 0.5, 0.36, 0.78, 0.42, color: 0xFFF4E3C1);
      b.field(
        'name',
        0.14,
        0.3,
        size: 0.06,
        bold: true,
        w: 0.7,
        color: 0xFF2B2B2B,
      );
      b.field('role', 0.14, 0.42, size: 0.04, w: 0.7, color: b.accent);
      b.shape('ring', 0.3, 0.74, 0.16, 0.26, color: _w);
      b.shape('ring', 0.7, 0.74, 0.16, 0.26, color: _w);
      b.photo(0.5, 0.74, 0.14, 0.2, color: _w);
      b.field(
        'number',
        0.5,
        0.92,
        size: 0.034,
        align: 'center',
        w: 0.5,
        color: _w,
        op: 0.7,
      );
    },
  ),
  IdTemplate(
    id: 'tpl.retro-pixel',
    name: 'Pixel arcade',
    category: 'Retro tech',
    bg1: 0xFF1A1033,
    bg2: 0xFF2D1B69,
    pattern: 'checker',
    ink: 0xFFFFEB3B,
    accent: 0xFF00E5FF,
    font: 'mono',
    front: (b) {
      b.shape('rect', 0.5, 0.5, 0.94, 0.9, color: 0xFF00E5FF, stroke: 0.014);
      b.text(
        'PLAYER 1',
        0.08,
        0.13,
        size: 0.05,
        bold: true,
        color: 0xFF00E5FF,
        w: 0.5,
      );
      b.photo(0.22, 0.54, 0.26, 0.5, color: 0xFFFFEB3B);
      b.field('name', 0.42, 0.38, size: 0.06, bold: true, w: 0.5);
      b.field('role', 0.42, 0.5, size: 0.045, w: 0.5);
      for (var i = 0; i < 5; i++) {
        b.shape(
          'heart',
          0.46 + i * 0.07,
          0.72,
          0.05,
          0.08,
          color: i < 4 ? 0xFFFF1744 : 0xFF555555,
        );
      }
      b.text(
        'HI-SCORE ${99999}',
        0.42,
        0.88,
        size: 0.036,
        color: 0xFF00E5FF,
        w: 0.5,
      );
    },
  ),
  // ── Music ─────────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.music-vinyl',
    name: 'Vinyl pass',
    category: 'Music',
    bg1: 0xFF161616,
    bg2: 0xFF2A2A2A,
    ink: _w,
    accent: 0xFFFF4D6D,
    front: (b) {
      b.circle(0.74, 0.5, 0.78, color: 0xFF050505);
      b.shape('ring', 0.74, 0.5, 0.6, 0.95, color: 0xFF333333, op: 0.8);
      b.circle(0.74, 0.5, 0.26, color: 0xFFFF4D6D);
      b.photo(0.74, 0.5, 0.18, 0.3, color: _w);
      b.heading(0.06, 0.14, size: 0.045, w: 0.4);
      b.field('name', 0.06, 0.4, size: 0.068, bold: true, w: 0.34);
      b.field('role', 0.06, 0.52, size: 0.042, w: 0.34);
      b.field('number', 0.06, 0.86, size: 0.036, w: 0.34, op: 0.6);
    },
  ),
  IdTemplate(
    id: 'tpl.music-concert',
    name: 'Concert ticket',
    category: 'Music',
    bg1: 0xFFFF7A59,
    bg2: 0xFFFFC857,
    pattern: 'rays',
    ink: 0xFF2B0F2E,
    accent: 0xFF2B0F2E,
    aspect: 2.0,
    front: (b) {
      b.shape('ticket', 0.5, 0.5, 0.96, 0.9, color: 0xFFFFF3D6);
      b.line(0.76, 0.5, 0.01, color: 0xFF2B0F2E, op: 0.35);
      b.text(
        'LIVE',
        0.06,
        0.2,
        size: 0.1,
        bold: true,
        w: 0.4,
        color: 0xFFFF7A59,
      );
      b.field('name', 0.06, 0.48, size: 0.06, bold: true, w: 0.6);
      b.field('role', 0.06, 0.64, size: 0.04, w: 0.6);
      b.field('number', 0.06, 0.82, size: 0.036, w: 0.6);
      b.emoji('🎤', 0.88, 0.32, 0.12);
      b.barcode(0.88, 0.7, 0.18, 0.28);
    },
  ),
  // ── Professional ──────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.pro-badge',
    name: 'Professional badge',
    category: 'Professional',
    bg1: 0xFFFFFFFF,
    bg2: 0xFFF1F3F6,
    ink: 0xFF1E2A3A,
    accent: 0xFF0A66C2,
    front: (b) {
      b.shape('rect', 0.5, 0.5, 0.012, 1, color: b.accent);
      b.shape('rect', 0.5, 0.08, 1, 0.16, color: 0xFFF1F3F6);
      b.heading(0.06, 0.08, size: 0.044);
      b.photo(0.24, 0.56, 0.28, 0.6, color: b.accent);
      b.field('name', 0.44, 0.42, size: 0.07, bold: true, w: 0.52);
      b.field('role', 0.44, 0.54, size: 0.048, w: 0.52, color: b.accent);
      b.field('pronouns', 0.44, 0.64, size: 0.04, w: 0.52);
      b.barcode(0.7, 0.86, 0.5, 0.1);
    },
  ),
  IdTemplate(
    id: 'tpl.pro-lanyard',
    name: 'Lanyard badge',
    category: 'Professional',
    bg1: 0xFFFFFFFF,
    bg2: 0xFFE8EEF7,
    ink: 0xFF14213D,
    accent: 0xFFFCA311,
    aspect: idPortrait,
    front: (b) {
      b.shape('rrect', 0.5, 0.045, 0.16, 0.05, color: 0xFF14213D);
      b.shape('rect', 0.5, 0.2, 1, 0.26, color: 0xFF14213D);
      b.heading(0.5, 0.2, align: 'center', color: _w, size: 0.06, w: 0.9);
      b.photo(0.5, 0.42, 0.5, 0.26, color: 0xFFFCA311);
      b.field(
        'name',
        0.5,
        0.64,
        size: 0.085,
        bold: true,
        align: 'center',
        w: 0.9,
      );
      b.field(
        'role',
        0.5,
        0.72,
        size: 0.05,
        align: 'center',
        w: 0.9,
        color: 0xFFB77400,
      );
      b.field('pronouns', 0.5, 0.78, size: 0.042, align: 'center', w: 0.9);
      b.shape('rect', 0.5, 0.96, 1, 0.08, color: 0xFFFCA311);
      b.barcode(0.5, 0.88, 0.6, 0.06);
    },
  ),
  // ── Digital business ──────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.business-card',
    name: 'Business card',
    category: 'Digital business',
    bg1: 0xFFFAFAF7,
    bg2: 0xFFFAFAF7,
    ink: 0xFF222222,
    accent: 0xFF0F766E,
    font: 'serif',
    aspect: 1.75,
    front: (b) {
      b.shape('rect', 0.03, 0.5, 0.012, 0.8, color: b.accent);
      b.field('name', 0.1, 0.32, size: 0.075, bold: true, w: 0.7);
      b.field('role', 0.1, 0.46, size: 0.045, w: 0.7, color: b.accent);
      b.line(0.35, 0.56, 0.5, op: 0.3);
      b.field('interests', 0.1, 0.68, size: 0.036, w: 0.6);
      b.field('number', 0.1, 0.8, size: 0.034, w: 0.6, op: 0.6);
      b.photo(0.86, 0.3, 0.18, 0.34, color: b.accent);
      b.barcode(0.82, 0.76, 0.2, 0.22);
    },
  ),
  IdTemplate(
    id: 'tpl.business-link',
    name: 'QR link card',
    category: 'Digital business',
    bg1: 0xFF111827,
    bg2: 0xFF1F2937,
    ink: _w,
    accent: 0xFF34D399,
    aspect: 1.4,
    front: (b) {
      b.shape('rrect', 0.27, 0.5, 0.4, 0.62, color: _w);
      b.barcode(0.27, 0.5, 0.34, 0.5, color: 0xFF111827);
      b.photo(0.78, 0.28, 0.16, 0.26, color: 0xFF34D399);
      b.field('name', 0.55, 0.52, size: 0.06, bold: true, w: 0.42);
      b.field('role', 0.55, 0.62, size: 0.04, w: 0.42, color: 0xFF34D399);
      b.field('custom1', 0.55, 0.72, size: 0.036, w: 0.42);
      b.field('custom2', 0.55, 0.8, size: 0.036, w: 0.42);
      b.text(
        'Scan to connect',
        0.27,
        0.88,
        size: 0.034,
        align: 'center',
        w: 0.4,
        op: 0.7,
      );
    },
  ),
  // ── Polaroid ──────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.polaroid-snap',
    name: 'Polaroid snap',
    category: 'Polaroid',
    bg1: 0xFFE9E3D6,
    bg2: 0xFFD8D0BE,
    pattern: 'paper',
    ink: 0xFF333333,
    accent: 0xFF333333,
    font: 'script',
    aspect: 0.84,
    front: (b) {
      b.shape('rect', 0.5, 0.5, 0.86, 0.9, color: _w, rot: -2);
      b.photo(0.5, 0.42, 0.74, 0.58, color: 0xFF333333, rot: -2);
      b.field(
        'name',
        0.5,
        0.82,
        size: 0.085,
        bold: true,
        align: 'center',
        w: 0.74,
        rot: -2,
      );
      b.field(
        'pronouns',
        0.5,
        0.91,
        size: 0.048,
        align: 'center',
        w: 0.74,
        rot: -2,
        op: 0.7,
      );
    },
  ),
  IdTemplate(
    id: 'tpl.polaroid-instant',
    name: 'Instant film',
    category: 'Polaroid',
    bg1: 0xFFF7F3EA,
    bg2: 0xFFEFE8D8,
    ink: 0xFF2B2B2B,
    accent: 0xFFFF6B6B,
    font: 'hand',
    front: (b) {
      b.shape('rect', 0.27, 0.5, 0.46, 0.8, color: _w, rot: 4);
      b.photo(0.27, 0.46, 0.4, 0.5, color: 0xFF2B2B2B, rot: 4);
      b.shape('rect', 0.76, 0.5, 0.42, 0.66, color: _w, rot: -3, op: 0.95);
      b.photo(0.76, 0.46, 0.36, 0.42, color: 0xFFFF6B6B, rot: -3);
      b.field(
        'name',
        0.5,
        0.9,
        size: 0.07,
        bold: true,
        align: 'center',
        w: 0.9,
      );
    },
  ),
  // ── Seasonal ──────────────────────────────────────────────────────
  IdTemplate(
    id: 'tpl.season-winter',
    name: 'Winter frost',
    category: 'Seasonal',
    bg1: 0xFFD7ECFA,
    bg2: 0xFFA9CCE8,
    pattern: 'snow',
    ink: 0xFF13344F,
    accent: 0xFF3D8BC9,
    front: (b) {
      b.shape('scallop', 0.5, 0.94, 1, 0.14, color: _w);
      b.emoji('❄️', 0.1, 0.14, 0.1);
      b.emoji('❄️', 0.9, 0.3, 0.07, op: 0.7);
      b.photo(0.22, 0.5, 0.24, 0.5, color: _w);
      b.field('name', 0.42, 0.36, size: 0.068, bold: true, w: 0.5);
      b.field('role', 0.42, 0.48, w: 0.5);
      b.field('interests', 0.42, 0.6, size: 0.04, w: 0.5);
    },
  ),
  IdTemplate(
    id: 'tpl.season-spring',
    name: 'Spring bloom',
    category: 'Seasonal',
    bg1: 0xFFFFF0F5,
    bg2: 0xFFE4F5DC,
    pattern: 'floral',
    ink: 0xFF4B3A4F,
    accent: 0xFFE56B9A,
    font: 'rounded',
    front: (b) {
      b.shape('flower', 0.88, 0.16, 0.2, 0.3, color: 0xFFFFB3CE);
      b.shape('flower', 0.08, 0.84, 0.16, 0.24, color: 0xFFFFD68A);
      b.shape('leaf', 0.18, 0.9, 0.12, 0.1, color: 0xFF8DB36B);
      b.photo(0.26, 0.48, 0.26, 0.5, color: 0xFFE56B9A);
      b.field('name', 0.46, 0.36, size: 0.07, bold: true, w: 0.46);
      b.field('pronouns', 0.46, 0.48, w: 0.46);
      b.field('interests', 0.46, 0.6, size: 0.04, w: 0.46);
    },
  ),
  IdTemplate(
    id: 'tpl.season-summer',
    name: 'Summer sun',
    category: 'Seasonal',
    bg1: 0xFFFFE066,
    bg2: 0xFFFF9F43,
    pattern: 'rays',
    ink: 0xFF4A2A00,
    accent: 0xFFE8590C,
    font: 'rounded',
    front: (b) {
      b.circle(0.86, 0.2, 0.3, color: 0xFFFFF3B0);
      b.shape('wave', 0.5, 0.92, 1, 0.22, color: 0xFF29B6F6);
      b.shape('wave', 0.5, 0.98, 1, 0.16, color: 0xFF0288D1);
      b.photo(0.24, 0.46, 0.25, 0.5, color: 0xFFE8590C);
      b.field('name', 0.44, 0.34, size: 0.07, bold: true, w: 0.48);
      b.field('role', 0.44, 0.46, w: 0.48);
      b.field('interests', 0.44, 0.58, size: 0.04, w: 0.48);
    },
  ),
  IdTemplate(
    id: 'tpl.season-autumn',
    name: 'Autumn leaves',
    category: 'Seasonal',
    bg1: 0xFFF6E0B5,
    bg2: 0xFFE9A15B,
    pattern: 'paper',
    ink: 0xFF4A2511,
    accent: 0xFFB5451B,
    font: 'serif',
    front: (b) {
      for (var i = 0; i < 5; i++) {
        b.shape(
          'leaf',
          0.06 + i * 0.21,
          0.08 + (i % 2) * 0.05,
          0.12,
          0.12,
          color: const [
            0xFFB5451B,
            0xFFD97A1E,
            0xFF8B3A0F,
            0xFFE0A526,
            0xFFA83232,
          ][i],
          rot: 30.0 * i,
        );
      }
      b.photo(0.24, 0.56, 0.25, 0.5, color: 0xFFB5451B);
      b.field('name', 0.44, 0.44, size: 0.068, bold: true, w: 0.5);
      b.field('role', 0.44, 0.56, w: 0.5);
      b.field('birthday', 0.44, 0.67, size: 0.04, w: 0.5);
      b.emoji('🍂', 0.9, 0.86, 0.12);
    },
  ),
  IdTemplate(
    id: 'tpl.season-spooky',
    name: 'Spooky night',
    category: 'Seasonal',
    bg1: 0xFF1B0F2E,
    bg2: 0xFF3B1458,
    pattern: 'bokeh',
    ink: 0xFFFFE9B3,
    accent: 0xFFFF8A00,
    font: 'serif',
    front: (b) {
      b.shape('moon', 0.84, 0.2, 0.18, 0.3, color: 0xFFFFE9B3);
      b.emoji('🦇', 0.62, 0.14, 0.08, rot: -10);
      b.emoji('🎃', 0.9, 0.84, 0.14, rot: 8);
      b.shape('torn', 0.5, 0.96, 1, 0.1, color: 0xFF000000, op: 0.6);
      b.photo(0.22, 0.52, 0.24, 0.5, color: 0xFFFF8A00);
      b.field('name', 0.4, 0.4, size: 0.066, bold: true, w: 0.45);
      b.field('role', 0.4, 0.52, w: 0.45, color: 0xFFFF8A00);
      b.field('pronouns', 0.4, 0.63, size: 0.04, w: 0.45);
    },
  ),
  IdTemplate(
    id: 'tpl.season-sakura',
    name: 'Sakura season',
    category: 'Seasonal',
    bg1: 0xFFFFE9F0,
    bg2: 0xFFFFC9DA,
    pattern: 'snow',
    ink: 0xFF5C2A3D,
    accent: 0xFFE0568A,
    font: 'serif',
    front: (b) {
      b.shape('arc', 0.9, 0.08, 0.5, 0.2, color: 0xFF6B4A3A, rot: 180);
      for (var i = 0; i < 6; i++) {
        b.shape(
          'flower',
          0.55 + i * 0.07,
          0.1 + (i % 3) * 0.06,
          0.06,
          0.09,
          color: 0xFFFF9EBB,
        );
      }
      b.photo(0.22, 0.54, 0.25, 0.5, color: 0xFFE0568A);
      b.field('name', 0.42, 0.42, size: 0.07, bold: true, w: 0.5);
      b.field('role', 0.42, 0.54, w: 0.5);
      b.field('interests', 0.42, 0.66, size: 0.04, w: 0.5);
    },
  ),
  IdTemplate(
    id: 'tpl.season-holiday',
    name: 'Holiday lights',
    category: 'Seasonal',
    bg1: 0xFF0F3B2E,
    bg2: 0xFF165C45,
    pattern: 'snow',
    ink: 0xFFFFF6E0,
    accent: 0xFFE63946,
    font: 'serif',
    front: (b) {
      b.shape('wave', 0.5, 0.06, 1, 0.12, color: 0xFF3A2A1A);
      for (var i = 0; i < 9; i++) {
        b.circle(
          0.06 + i * 0.11,
          0.12 + (i.isEven ? 0.01 : 0.04),
          0.035,
          color: const [
            0xFFE63946,
            0xFFFFD166,
            0xFF4CC9F0,
            0xFFF72585,
            0xFF80ED99,
          ][i % 5],
        );
      }
      b.photo(0.22, 0.56, 0.24, 0.5, color: 0xFFFFD166);
      b.field('name', 0.4, 0.44, size: 0.068, bold: true, w: 0.5);
      b.field('role', 0.4, 0.56, w: 0.5);
      b.field('pronouns', 0.4, 0.67, size: 0.04, w: 0.5);
      b.emoji('🎄', 0.9, 0.84, 0.14);
    },
  ),
  IdTemplate(
    id: 'tpl.season-pride',
    name: 'Pride prism',
    category: 'Seasonal',
    bg1: 0xFFFFFFFF,
    bg2: 0xFFF6F0FF,
    ink: 0xFF2A1F3D,
    accent: 0xFF7C4DFF,
    font: 'rounded',
    front: (b) {
      const bands = [
        0xFFE40303,
        0xFFFF8C00,
        0xFFFFED00,
        0xFF008026,
        0xFF004DFF,
        0xFF750787,
      ];
      for (var i = 0; i < 6; i++) {
        b.shape('rect', 0.5, 0.025 + i * 0.05, 1, 0.05, color: bands[i]);
      }
      b.photo(0.22, 0.6, 0.24, 0.5, color: 0xFF7C4DFF);
      b.field('name', 0.4, 0.46, size: 0.07, bold: true, w: 0.55);
      b.field('pronouns', 0.4, 0.58, w: 0.55, color: 0xFF7C4DFF);
      b.field('flags', 0.4, 0.7, size: 0.05, w: 0.55);
      b.field('interests', 0.4, 0.82, size: 0.038, w: 0.55);
    },
  ),
  IdTemplate(
    id: 'tpl.season-ocean',
    name: 'Ocean tide',
    category: 'Seasonal',
    bg1: 0xFFCDEFFB,
    bg2: 0xFF5FB7DB,
    pattern: 'waves',
    ink: 0xFF06304A,
    accent: 0xFF0B7FAB,
    font: 'rounded',
    front: (b) {
      b.shape('wave', 0.5, 0.9, 1, 0.3, color: 0xFF0B7FAB, op: 0.85);
      b.shape('wave', 0.5, 0.98, 1, 0.2, color: 0xFF06304A, op: 0.8);
      b.emoji('🐚', 0.86, 0.2, 0.1, rot: 12);
      b.photo(0.24, 0.46, 0.25, 0.5, color: 0xFF0B7FAB);
      b.field('name', 0.44, 0.34, size: 0.07, bold: true, w: 0.5);
      b.field('role', 0.44, 0.46, w: 0.5);
      b.field('interests', 0.44, 0.58, size: 0.04, w: 0.5);
    },
  ),
];

final _byId = {for (final t in idTemplates) t.id: t};

IdTemplate? idTemplateById(String id) => _byId[id];

/// Category names in display order.
List<String> get idTemplateCategories => [
  for (final c in idTemplates.map((t) => t.category).toSet()) c,
];

/// Builds a card face from a template. The back is its own design, not a
/// copy: it keeps the front's palette and says plainly the card is personal.
(CardFace, CardFace) buildIdTemplate(
  IdTemplate t, {
  required String type,
  Set<String> fields = const {
    'name',
    'pronouns',
    'number',
    'photo',
    'issued',
    'emoji',
  },
}) {
  final title = idCardTypes[type]?.$1 ?? 'ID card';
  final f = IdLayout(fields, title, t);
  t.front(f);
  final back = IdLayout({...fields, 'barcode'}, title, t);
  final i = idTemplates.indexOf(t);
  final dark =
      ThemeData.estimateBrightnessForColor(Color(t.bg1)) == Brightness.dark;
  final fg = dark ? 0xFFFFFFFF : t.ink;
  switch (i % 4) {
    case 0:
      back.shape('rect', 0.5, 0.14, 1, 0.1, color: t.accent, op: 0.9);
      back.text(
        'If found, please return to its owner.',
        0.5,
        0.45,
        size: 0.042,
        align: 'center',
        w: 0.9,
        color: fg,
      );
      back.field('notes', 0.08, 0.6, size: 0.04, w: 0.84, color: fg);
      back.barcode(0.5, 0.82, 0.7, 0.13, color: fg);
    case 1:
      back.shape('rect', 0.1, 0.5, 0.2, 1, color: t.accent, op: 0.9);
      back.text(
        title,
        0.6,
        0.18,
        size: 0.05,
        bold: true,
        align: 'center',
        w: 0.6,
        color: fg,
      );
      back.field('notes', 0.24, 0.42, size: 0.04, w: 0.7, color: fg);
      back.field('issuer', 0.24, 0.6, size: 0.038, w: 0.7, color: fg);
      back.barcode(0.6, 0.82, 0.6, 0.12, color: fg);
    case 2:
      back.shape('burst', 0.5, 0.4, 0.3, 0.4, color: t.accent, op: 0.35);
      back.emoji('💛', 0.5, 0.4, 0.14);
      back.text(
        'Made by a system, for a system.',
        0.5,
        0.64,
        size: 0.042,
        align: 'center',
        w: 0.9,
        color: fg,
      );
      back.field(
        'issuer',
        0.5,
        0.74,
        size: 0.038,
        align: 'center',
        w: 0.9,
        color: fg,
      );
      back.barcode(0.5, 0.88, 0.5, 0.08, color: fg);
    default:
      back.line(0.5, 0.2, 0.84, color: t.accent);
      back.field('notes', 0.08, 0.34, size: 0.042, w: 0.84, color: fg);
      back.field('boundaries', 0.08, 0.5, size: 0.04, w: 0.84, color: fg);
      back.field('issuer', 0.08, 0.66, size: 0.038, w: 0.84, color: fg);
      back.barcode(0.5, 0.84, 0.74, 0.12, color: fg);
  }
  back.text(
    'Personal / fictional — not an official document',
    0.5,
    0.96,
    size: 0.03,
    align: 'center',
    w: 0.94,
    color: fg,
    op: 0.7,
  );
  return (
    CardFace(
      bg1: t.bg1,
      bg2: t.bg2,
      pattern: t.pattern,
      layers: f.layers,
      tpl: t.id,
      aspect: t.aspect,
    ),
    CardFace(
      bg1: t.backBg1 ?? t.bg2,
      bg2: t.backBg2 ?? t.bg1,
      pattern: t.pattern,
      layers: back.layers,
      tpl: t.id,
      aspect: t.aspect,
    ),
  );
}

/// Builds any template id: a new `tpl.*` design or a legacy
/// `<collection>.<layout>` one.
(CardFace, CardFace) buildAnyTemplate(
  String collection,
  String layout, {
  required String type,
  Set<String> fields = const {
    'name',
    'pronouns',
    'number',
    'photo',
    'issued',
    'emoji',
  },
}) {
  final t = collection == 'tpl' ? idTemplateById('tpl.$layout') : null;
  if (t != null) return buildIdTemplate(t, type: type, fields: fields);
  return buildTemplate(collection, layout, type: type, fields: fields);
}

/// The native shape of a template (width ÷ height).
double idTemplateAspect(String collection, String layout) =>
    (collection == 'tpl' ? idTemplateById('tpl.$layout')?.aspect : null) ??
    idLandscape;
