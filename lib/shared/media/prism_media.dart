import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart'
    show SocialImage;
import 'package:prism_plurality/features/social/widgets/video_tile.dart';
import 'package:prism_plurality/shared/media/prism_originals.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';

/// Picking and showing photos, videos and audio for the newer modules.
/// Images sync (stored as media records); videos and audio stay on the
/// device they were added on, like Bulletin Board videos.
abstract final class PrismMedia {
  static const _uuid = Uuid();

  static Future<Directory?> _audioDir() async {
    if (kIsWeb) return null;
    final dir = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'prism_audio'),
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Picks, crops (with Prism's one shared cropper) and stores an image.
  /// Returns a media id, or null if cancelled / unreadable. The untouched
  /// original is kept so [recropImage] can crop it again later.
  static Future<String?> pickImage(
    WidgetRef ref, {
    bool camera = false,
    String? owner,
    PrismCropSpec spec = PrismCropSpec.free,
    bool crop = true,
  }) async {
    final picked = await PrismImageCrop.pick(
      ref.context,
      spec: spec,
      camera: camera,
      allowCrop: crop,
    );
    if (picked == null) return null;
    return ref
        .read(socialMediaStoreProvider)
        .addImage(picked.bytes, owner: owner, original: picked.originalId);
  }

  /// Re-crops an image you imported earlier, from its saved original.
  /// Returns the new media id (the old record is left alone), or null.
  static Future<String?> recropImage(
    WidgetRef ref,
    String mediaId, {
    String? owner,
    PrismCropSpec spec = PrismCropSpec.free,
  }) async {
    final orig = ref.read(socialMediaStoreProvider).originalOf(mediaId);
    PrismPickedImage? picked;
    if (orig != null && await PrismOriginals.exists(orig)) {
      picked = await PrismImageCrop.recrop(ref.context, orig, spec: spec);
    } else {
      // Imported before originals were kept: crop what we have.
      final current = ref.read(socialImageProvider(mediaId));
      if (current == null) {
        if (ref.context.mounted) {
          PrismToast.error(
            ref.context,
            message: tr(
              ref.context,
              'This image isn\'t available to crop.',
              'Esta imagen no está disponible para recortar.',
            ),
          );
        }
        return null;
      }
      picked = await PrismImageCrop.fromBytes(ref.context, current, spec: spec);
    }
    if (picked == null) return null;
    return ref
        .read(socialMediaStoreProvider)
        .addImage(picked.bytes, owner: owner, original: picked.originalId);
  }

  /// Picks several images; each one goes through the shared cropper in turn
  /// (cancel a crop to skip that image).
  static Future<List<String>> pickImages(
    WidgetRef ref, {
    String? owner,
    PrismCropSpec spec = PrismCropSpec.free,
  }) async {
    final xs = await ImagePicker().pickMultiImage();
    final out = <String>[];
    for (final x in xs) {
      if (!ref.context.mounted) break;
      final picked = await PrismImageCrop.fromBytes(
        ref.context,
        await x.readAsBytes(),
        spec: spec,
      );
      if (picked == null) continue;
      final id = await ref
          .read(socialMediaStoreProvider)
          .addImage(picked.bytes, owner: owner, original: picked.originalId);
      if (id != null) out.add(id);
    }
    return out;
  }

  static Future<String?> pickVideo(WidgetRef ref) async =>
      (await pickVideoResult(ref)).id;

  /// Like [pickVideo] but reports why a video was rejected, so callers can
  /// tell the user instead of silently doing nothing.
  static Future<({String? id, String? error})> pickVideoResult(
    WidgetRef ref,
  ) async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (x == null) return (id: null, error: null);
    return ref.read(socialMediaStoreProvider).addVideo(x.path);
  }

  /// Picks an audio file; returns `audio:<file>`.
  static Future<String?> pickAudio() async {
    final dir = await _audioDir();
    if (dir == null) return null;
    final res = await FilePicker.pickFiles(type: FileType.audio);
    final path = res?.files.single.path;
    if (path == null) return null;
    final name = '${_uuid.v4()}${p.extension(path)}';
    await File(path).copy(p.join(dir.path, name));
    return 'audio:$name';
  }

  static Future<String?> audioPath(String id) async {
    if (!id.startsWith('audio:')) return null;
    final dir = await _audioDir();
    if (dir == null) return null;
    final f = File(p.join(dir.path, id.substring(6)));
    return await f.exists() ? f.path : null;
  }

  /// Records a voice clip in a small sheet; returns `audio:<file>`.
  static Future<String?> recordAudio(BuildContext context) =>
      PrismSheet.show<String>(
        context: context,
        title: tr(context, 'Record audio', 'Grabar audio'),
        builder: (ctx) => const _Recorder(),
      );
}

class _Recorder extends StatefulWidget {
  const _Recorder();
  @override
  State<_Recorder> createState() => _RecorderState();
}

class _RecorderState extends State<_Recorder> {
  final _rec = AudioRecorder();
  String? _path;
  bool _recording = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      setState(
        () => _error = tr(
          context,
          'Microphone permission is needed.',
          'Se necesita permiso de micrófono.',
        ),
      );
      return;
    }
    final dir = await PrismMedia._audioDir();
    if (dir == null) return;
    _path = p.join(dir.path, '${PrismMedia._uuid.v4()}.m4a');
    await _rec.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _path!,
    );
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _elapsed += const Duration(seconds: 1)),
    );
    setState(() => _recording = true);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _rec.stop();
    if (!mounted) return;
    if (path == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop('audio:${p.basename(path)}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
            style: theme.textTheme.displaySmall,
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 16),
          PrismButton(
            label: _recording
                ? tr(context, 'Stop and save', 'Detener y guardar')
                : tr(context, 'Start recording', 'Empezar a grabar'),
            icon: _recording ? PhosphorIcons.stop() : AppIcons.microphone,
            tone: PrismButtonTone.filled,
            onPressed: _recording ? _stop : _start,
          ),
        ],
      ),
    );
  }
}

/// Shows a stored image or video by id.
class PrismMediaView extends StatelessWidget {
  const PrismMediaView({
    super.key,
    required this.id,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
  });
  final String id;
  final BoxFit fit;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    if (id.startsWith('video:')) return VideoTile(id: id, fill: true);
    if (id.startsWith('audio:')) return AudioClip(id: id);
    return SocialImage(id: id, fit: fit, height: height, width: width);
  }
}

/// Compact play/pause control for a recorded or attached audio clip.
class AudioClip extends StatefulWidget {
  const AudioClip({super.key, required this.id, this.label});
  final String id;
  final String? label;

  @override
  State<AudioClip> createState() => _AudioClipState();
}

class _AudioClipState extends State<AudioClip> {
  AudioPlayer? _player;
  bool _playing = false;
  bool _missing = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player == null) {
      final path = await PrismMedia.audioPath(widget.id);
      if (path == null) {
        setState(() => _missing = true);
        return;
      }
      _player = AudioPlayer();
      await _player!.setFilePath(path);
      _player!.playerStateStream.listen((s) {
        if (!mounted) return;
        final done = s.processingState == ProcessingState.completed;
        if (done) _player!.seek(Duration.zero);
        setState(() => _playing = s.playing && !done);
      });
    }
    _playing ? await _player!.pause() : await _player!.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: prismCorners(context, 24),
      child: InkWell(
        borderRadius: prismCorners(context, 24),
        onTap: _missing ? null : _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _missing
                    ? PhosphorIcons.speakerSlash()
                    : (_playing ? PhosphorIcons.pause() : PhosphorIcons.play()),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _missing
                    ? tr(
                        context,
                        'Audio on another device',
                        'Audio en otro dispositivo',
                      )
                    : (widget.label ?? tr(context, 'Audio', 'Audio')),
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row of buttons to attach media, plus thumbnails with remove buttons.
class MediaAttachRow extends ConsumerWidget {
  const MediaAttachRow({
    super.key,
    required this.ids,
    required this.onChanged,
    this.allowVideo = true,
    this.allowAudio = true,
    this.owner,
  });
  final List<String> ids;
  final ValueChanged<List<String>> onChanged;
  final bool allowVideo;
  final bool allowAudio;
  final String? owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismButton(
              label: tr(context, 'Photos', 'Fotos'),
              icon: AppIcons.imageOutlined,
              onPressed: () async => onChanged([
                ...ids,
                ...await PrismMedia.pickImages(ref, owner: owner),
              ]),
            ),
            if (!kIsWeb)
              PrismButton(
                label: tr(context, 'Camera', 'Cámara'),
                icon: AppIcons.cameraAlt,
                onPressed: () async {
                  final id = await PrismMedia.pickImage(
                    ref,
                    camera: true,
                    owner: owner,
                  );
                  if (id != null) onChanged([...ids, id]);
                },
              ),
            if (allowVideo && !kIsWeb)
              PrismButton(
                label: tr(context, 'Video', 'Vídeo'),
                icon: PhosphorIcons.videoCamera(),
                onPressed: () async {
                  final id = await PrismMedia.pickVideo(ref);
                  if (id != null) onChanged([...ids, id]);
                },
              ),
            if (allowAudio && !kIsWeb)
              PrismButton(
                label: tr(context, 'Record', 'Grabar'),
                icon: AppIcons.microphone,
                onPressed: () async {
                  final id = await PrismMedia.recordAudio(context);
                  if (id != null) onChanged([...ids, id]);
                },
              ),
          ],
        ),
        if (ids.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final id in ids)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: prismCorners(context, 10),
                          child: SizedBox(
                            width: id.startsWith('audio:') ? 140 : 88,
                            height: 88,
                            child: id.startsWith('audio:')
                                ? Center(child: AudioClip(id: id))
                                : PrismMediaView(id: id),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            tooltip: tr(context, 'Remove', 'Quitar'),
                            icon: Icon(AppIcons.close, size: 14),
                            onPressed: () => onChanged([...ids]..remove(id)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
