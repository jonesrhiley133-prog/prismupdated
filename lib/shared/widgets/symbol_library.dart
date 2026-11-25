import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Unicode symbols and kaomoji, grouped. Everything here is plain text, so
/// it works offline and anywhere text does.
const symbolLibrary = <String, List<String>>{
  'Stars': [
    '★',
    '☆',
    '✦',
    '✧',
    '✩',
    '✪',
    '✫',
    '✬',
    '✭',
    '✮',
    '✯',
    '✰',
    '⁂',
    '✶',
    '✷',
    '✸',
    '✹',
    '✺',
    '❂',
    '⋆',
    '✵',
    '❋',
    '✱',
    '✲',
    '✳',
    '✴',
    '❇',
    '❈',
    '❉',
    '❊',
    '⭑',
    '⭒',
    '🌟',
    '⭐',
    '💫',
    '✨',
  ],
  'Hearts': [
    '♥',
    '♡',
    '❤',
    '❥',
    '❣',
    '❦',
    '❧',
    '☙',
    '💕',
    '💖',
    '💗',
    '💓',
    '💞',
    '💘',
    '💝',
    '💜',
    '💙',
    '💚',
    '💛',
    '🧡',
    '🤍',
    '🖤',
    '🤎',
    '💔',
    '❤️‍🔥',
    '❤️‍🩹',
    '🫶',
  ],
  'Moon & sky': [
    '☀',
    '☼',
    '☾',
    '☽',
    '🌙',
    '🌛',
    '🌜',
    '🌕',
    '🌖',
    '🌗',
    '🌘',
    '🌑',
    '🌒',
    '🌓',
    '🌔',
    '☁',
    '⛅',
    '🌤',
    '⚡',
    '❄',
    '❅',
    '❆',
    '☃',
    '🌈',
    '☄',
    '🪐',
    '🌌',
    '🌠',
    '☂',
    '☔',
  ],
  'Flowers & nature': [
    '❀',
    '✿',
    '❁',
    '✾',
    '❃',
    '❋',
    '⚘',
    '🌸',
    '🌺',
    '🌻',
    '🌼',
    '🌷',
    '🌹',
    '🥀',
    '💐',
    '🌿',
    '🍀',
    '☘',
    '🍃',
    '🍂',
    '🍁',
    '🌱',
    '🌲',
    '🌳',
    '🌵',
    '🍄',
    '🌊',
    '🔥',
    '💧',
    '🦋',
    '🐚',
    '🪸',
    '🪷',
  ],
  'Shapes': [
    '●',
    '○',
    '◉',
    '◎',
    '◌',
    '◍',
    '■',
    '□',
    '▢',
    '▣',
    '▪',
    '▫',
    '▲',
    '△',
    '▼',
    '▽',
    '◆',
    '◇',
    '◈',
    '⬟',
    '⬢',
    '⬡',
    '⬠',
    '◐',
    '◑',
    '◒',
    '◓',
    '◢',
    '◣',
    '◤',
    '◥',
    '⧫',
    '⬤',
    '⯃',
    '⯂',
  ],
  'Lines & frames': [
    '─',
    '━',
    '│',
    '┃',
    '┄',
    '┅',
    '═',
    '║',
    '╔',
    '╗',
    '╚',
    '╝',
    '╭',
    '╮',
    '╯',
    '╰',
    '┌',
    '┐',
    '└',
    '┘',
    '〔',
    '〕',
    '【',
    '】',
    '〖',
    '〗',
    '《',
    '》',
    '「',
    '」',
    '『',
    '』',
    '⟨',
    '⟩',
    '⦅',
    '⦆',
    '꒰',
    '꒱',
    '⊹',
    '˚',
    '｡',
    '゜',
    '·',
    '•',
    '◦',
    '‣',
    '⁃',
  ],
  'Arrows': [
    '←',
    '→',
    '↑',
    '↓',
    '↔',
    '↕',
    '↖',
    '↗',
    '↘',
    '↙',
    '⇐',
    '⇒',
    '⇑',
    '⇓',
    '⇔',
    '⇄',
    '⇆',
    '↺',
    '↻',
    '⟲',
    '⟳',
    '➜',
    '➝',
    '➞',
    '➟',
    '➠',
    '➤',
    '➥',
    '➦',
    '➧',
    '➨',
    '⤴',
    '⤵',
    '↯',
    '⇝',
    '⇜',
  ],
  'Signs & symbols': [
    '∞',
    '♾',
    '☯',
    '☮',
    '☪',
    '✡',
    '☸',
    '⚛',
    '⚜',
    '♠',
    '♣',
    '♦',
    '♤',
    '♧',
    '♢',
    '☘',
    '⚕',
    '⚖',
    '⚓',
    '⚔',
    '⚘',
    '⚙',
    '⚗',
    '☤',
    '☥',
    '✝',
    '☦',
    '♁',
    '⚲',
    '⚥',
    '⚧',
    '⚢',
    '⚣',
    '⚤',
    '♀',
    '♂',
    '⚪',
    '⚫',
    '✓',
    '✔',
    '✗',
    '✘',
    '✚',
    '✛',
    '✜',
    '❖',
    '§',
    '¶',
    '†',
    '‡',
    '※',
    '⁑',
  ],
  'Zodiac & astro': [
    '♈',
    '♉',
    '♊',
    '♋',
    '♌',
    '♍',
    '♎',
    '♏',
    '♐',
    '♑',
    '♒',
    '♓',
    '⛎',
    '☉',
    '☿',
    '♀',
    '⊕',
    '♂',
    '♃',
    '♄',
    '♅',
    '♆',
    '♇',
    '☊',
    '☋',
    '☌',
    '☍',
    '⚳',
    '⚴',
    '⚵',
    '⚶',
  ],
  'Music & play': [
    '♩',
    '♪',
    '♫',
    '♬',
    '♭',
    '♮',
    '♯',
    '𝄞',
    '𝄢',
    '🎵',
    '🎶',
    '🎼',
    '🎹',
    '🎸',
    '🎻',
    '🥁',
    '🎤',
    '🎧',
    '🎮',
    '🕹',
    '🎲',
    '♟',
    '🃏',
    '🀄',
    '🎴',
    '🧩',
  ],
  'Weather & time': [
    '⌚',
    '⏰',
    '⏳',
    '⌛',
    '🕐',
    '🕛',
    '☀️',
    '🌡',
    '🌪',
    '🌫',
    '🌧',
    '⛈',
    '🌨',
    '🌩',
    '🌦',
    '🌥',
    '🌬',
  ],
  'Animals': [
    '🐱',
    '🐶',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
    '🐔',
    '🐧',
    '🐦',
    '🦉',
    '🦇',
    '🐺',
    '🦄',
    '🐝',
    '🐞',
    '🦋',
    '🐌',
    '🐢',
    '🐍',
    '🦎',
    '🐙',
    '🦑',
    '🐠',
    '🐳',
    '🐬',
    '🦈',
    '🐉',
    '🐾',
  ],
  'Kaomoji: happy': [
    '(◕‿◕)',
    '(｡◕‿◕｡)',
    '(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧',
    '٩(◕‿◕｡)۶',
    '(*^▽^*)',
    '(≧▽≦)',
    '(＾▽＾)',
    '☆*:.｡.o(≧▽≦)o.｡.:*☆',
    '(´｡• ᵕ •｡`)',
    '(✿◠‿◠)',
    'ヽ(・∀・)ﾉ',
    '(•‿•)',
    '( ˘ ³˘)♥',
    '(◠‿◠✿)',
    '(ᵔᴥᵔ)',
    '\\(^o^)/',
    '(っ˘ω˘ς )',
  ],
  'Kaomoji: love': [
    '(♡°▽°♡)',
    '(´∀`)♡',
    '(｡♥‿♥｡)',
    '♡( ◡‿◡ )',
    '(っ´▽`)っ♡',
    '(˘︶˘).｡.:*♡',
    '(≧◡≦) ♡',
    '( ˘⌣˘)♡(˘⌣˘ )',
    '(づ￣ ³￣)づ',
    '(◍•ᴗ•◍)❤',
    '♡(ӦｖӦ｡)',
  ],
  'Kaomoji: sad': [
    '(╥﹏╥)',
    '(｡•́︿•̀｡)',
    '(っ˘̩╭╮˘̩)っ',
    '(ಥ﹏ಥ)',
    '(；へ：)',
    '(´；ω；`)',
    '( ˘･з･)',
    '(._.)',
    '(T_T)',
    '(｡ŏ﹏ŏ)',
    '(◞‸◟；)',
  ],
  'Kaomoji: other': [
    '(¬‿¬)',
    '(￢_￢)',
    '¯\\_(ツ)_/¯',
    '(•_•)',
    '( •_•)>⌐■-■',
    '(⌐■_■)',
    '(ಠ_ಠ)',
    '(°ロ°)',
    '(⊙_⊙)',
    '(￣ω￣)',
    '(=^･ω･^=)',
    'ʕ•ᴥ•ʔ',
    '(ᵘﻌᵘ)',
    'ฅ^•ﻌ•^ฅ',
    '(ง •̀_•́)ง',
    '(｡•̀ᴗ-)✧',
    '(⁄ ⁄•⁄ω⁄•⁄ ⁄)',
    '( ´ ▽ ` )ﾉ',
    '(*￣▽￣)b',
    '(っ◔◡◔)っ',
    '(-_-) zzZ',
    '(｡-ω-)zzz',
    '⊂(◉‿◉)つ',
  ],
  'Decorative': [
    '⋆｡°✩',
    '✧･ﾟ: *✧･ﾟ:*',
    '˚₊‧꒰ა',
    '໒꒱',
    '･ﾟ✧*:･ﾟ✧',
    '✿ ❀ ✿',
    '₊˚⊹♡',
    '⊹₊˚‧',
    '꒰ঌ',
    '໒꒱·ﾟ',
    '˗ˏˋ ★ ˎˊ˗',
    '⋆⁺₊⋆ ☾ ⋆⁺₊⋆',
    '❀•°•═════ஓ๑♡๑ஓ═════•°•❀',
    '✦•┈๑⋅⋯ ⋯⋅๑┈•✦',
    '·͙*̩̩͙˚̩̥̩̥*̩̩̥͙·̩̩̥͙*̩̩̥͙˚̩̥̩̥*̩̩͙‧͙',
    '︶꒷꒦︶',
    '⊰',
    '⊱',
    '≪',
    '≫',
  ],
  'Letters & numbers': [
    '①',
    '②',
    '③',
    '④',
    '⑤',
    '⑥',
    '⑦',
    '⑧',
    '⑨',
    '⑩',
    'Ⅰ',
    'Ⅱ',
    'Ⅲ',
    'Ⅳ',
    'Ⅴ',
    'Ⅵ',
    'Ⅶ',
    'Ⅷ',
    'Ⅸ',
    'Ⅹ',
    'Ⓐ',
    'Ⓑ',
    'Ⓒ',
    'ⓐ',
    'ⓑ',
    'ⓒ',
    'α',
    'β',
    'γ',
    'δ',
    'Ω',
    'π',
    'Σ',
    'λ',
    'φ',
    'ψ',
    '№',
    '℗',
    '©',
    '®',
    '™',
    '℃',
    '℉',
  ],
};

int get symbolCount => symbolLibrary.values.fold(0, (a, l) => a + l.length);

/// Favourites, recents and named collections (stored on this device).
class SymbolPrefs {
  SymbolPrefs({
    this.favorites = const [],
    this.recent = const [],
    this.collections = const {},
  });
  final List<String> favorites;
  final List<String> recent;
  final Map<String, List<String>> collections;

  static const _key = 'symbol.library.v1';

  static Future<SymbolPrefs> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return SymbolPrefs();
      final j = jsonDecode(raw) as Map;
      List<String> l(Object? v) => [
        for (final x in (v as List? ?? const [])) '$x',
      ];
      return SymbolPrefs(
        favorites: l(j['fav']),
        recent: l(j['recent']),
        collections: {
          for (final e in ((j['col'] as Map?) ?? const {}).entries)
            '${e.key}': l(e.value),
        },
      );
    } catch (_) {
      return SymbolPrefs();
    }
  }

  Future<void> save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode({'fav': favorites, 'recent': recent, 'col': collections}),
      );
    } catch (_) {}
  }
}

/// What the picker returns: a symbol and how it should look.
class PickedSymbol {
  const PickedSymbol(this.text, {this.color, this.size = 1});
  final String text;
  final int? color;

  /// Relative size (0.5–3).
  final double size;
}

/// Opens the symbol library. [styled] shows colour and size controls.
Future<PickedSymbol?> showSymbolLibrary(
  BuildContext context, {
  bool styled = false,
  String title = 'Symbols',
}) => PrismSheet.show<PickedSymbol>(
  context: context,
  title: title,
  maxHeightFactor: 0.9,
  builder: (_) => _SymbolLibrarySheet(styled: styled),
);

class _SymbolLibrarySheet extends StatefulWidget {
  const _SymbolLibrarySheet({required this.styled});
  final bool styled;
  @override
  State<_SymbolLibrarySheet> createState() => _SymbolLibrarySheetState();
}

class _SymbolLibrarySheetState extends State<_SymbolLibrarySheet> {
  SymbolPrefs _p = SymbolPrefs();
  String _cat = 'Stars';
  String _q = '';
  int? _color;
  double _size = 1;

  @override
  void initState() {
    super.initState();
    SymbolPrefs.load().then((p) {
      if (mounted) setState(() => _p = p);
    });
  }

  Future<void> _pick(String s) async {
    final recent = [s, ..._p.recent.where((x) => x != s)].take(30).toList();
    _p = SymbolPrefs(
      favorites: _p.favorites,
      recent: recent,
      collections: _p.collections,
    );
    await _p.save();
    if (mounted)
      Navigator.of(context).pop(PickedSymbol(s, color: _color, size: _size));
  }

  void _toggleFav(String s) {
    final f = _p.favorites.contains(s)
        ? ([..._p.favorites]..remove(s))
        : [..._p.favorites, s];
    setState(
      () => _p = SymbolPrefs(
        favorites: f,
        recent: _p.recent,
        collections: _p.collections,
      ),
    );
    _p.save();
  }

  Future<void> _addToCollection(String s) async {
    final names = _p.collections.keys.toList();
    final c = TextEditingController();
    final name = await PrismDialog.show<String>(
      context: context,
      title: 'Add $s to a collection',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final n in names)
            PrismListRow(
              dense: true,
              title: Text(n),
              onTap: () => Navigator.of(ctx, rootNavigator: true).pop(n),
            ),
          TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'New collection name'),
          ),
        ],
      ),
      actions: [
        PrismButton(
          label: 'Add',
          tone: PrismButtonTone.filled,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(c.text.trim()),
        ),
      ],
    );
    if (name == null || name.isEmpty) return;
    final col = {
      ..._p.collections,
      name: [
        ...?_p.collections[name],
        if (!(_p.collections[name]?.contains(s) ?? false)) s,
      ],
    };
    setState(
      () => _p = SymbolPrefs(
        favorites: _p.favorites,
        recent: _p.recent,
        collections: col,
      ),
    );
    await _p.save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cats = <String, List<String>>{
      if (_p.recent.isNotEmpty) 'Recent': _p.recent,
      if (_p.favorites.isNotEmpty) '★ Favourites': _p.favorites,
      for (final e in _p.collections.entries) '📁 ${e.key}': e.value,
      ...symbolLibrary,
    };
    if (!cats.containsKey(_cat)) _cat = cats.keys.first;
    final list = _q.isEmpty
        ? cats[_cat]!
        : [
            for (final l in symbolLibrary.entries)
              if (l.key.toLowerCase().contains(_q.toLowerCase())) ...l.value,
            for (final l in symbolLibrary.values)
              ...l.where((s) => s.contains(_q)),
          ].toSet().toList();
    final kaomoji = list.any((s) => s.runes.length > 3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(
            hintText: 'Search categories or paste a symbol',
            prefixIcon: const Icon(Icons.search),
            onChanged: (v) => setState(() => _q = v.trim()),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in cats.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(
                      label: c,
                      selected: _cat == c && _q.isEmpty,
                      onTap: () => setState(() {
                        _cat = c;
                        _q = '';
                      }),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.styled) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final c = await showPrismColorPicker(
                      context: context,
                      initial: Color(_color ?? 0xFF333333),
                      title: 'Symbol colour',
                    );
                    if (c != null) setState(() => _color = c.toARGB32());
                  },
                  child: Semantics(
                    button: true,
                    label: 'Symbol colour',
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(_color ?? 0xFF333333),
                    ),
                  ),
                ),
                if (_color != null)
                  PrismButton(
                    label: 'Card colour',
                    density: PrismControlDensity.compact,
                    onPressed: () => setState(() => _color = null),
                  ),
                const SizedBox(width: 8),
                const Text('Size'),
                Expanded(
                  child: Slider(
                    value: _size,
                    min: 0.5,
                    max: 3,
                    onChanged: (v) => setState(() => _size = v),
                    semanticFormatterCallback: (v) =>
                        'Size ${v.toStringAsFixed(1)}×',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Tap to use · long-press to favourite or add to a collection',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final s in list)
                    Semantics(
                      button: true,
                      label:
                          'Symbol $s${_p.favorites.contains(s) ? ', favourite' : ''}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _pick(s),
                        onLongPress: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PrismListRow(
                                  leading: Icon(
                                    _p.favorites.contains(s)
                                        ? Icons.star
                                        : Icons.star_border,
                                  ),
                                  title: Text(
                                    _p.favorites.contains(s)
                                        ? 'Remove from favourites'
                                        : 'Add to favourites',
                                  ),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _toggleFav(s);
                                  },
                                ),
                                PrismListRow(
                                  leading: const Icon(Icons.folder_outlined),
                                  title: const Text('Add to a collection…'),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _addToCollection(s);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: kaomoji ? 64 : 44,
                            minHeight: 44,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: s.runes.length > 3 ? 14 : 22,
                              color: _color == null ? null : Color(_color!),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
