import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail_flutter/video_thumbnail_flutter.dart';

const sampleVideoUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ThumbnailPage());
  }
}

class ThumbnailPage extends StatefulWidget {
  const ThumbnailPage({super.key});

  @override
  State<ThumbnailPage> createState() => _ThumbnailPageState();
}

class _ThumbnailPageState extends State<ThumbnailPage> {
  final _video = TextEditingController(text: sampleVideoUrl);
  ImageFormat _format = ImageFormat.JPEG;
  double _maxWidth = 256;
  double _timeMs = 0;
  double _quality = 75;
  bool _toFile = false;
  bool _busy = false;

  Uint8List? _bytes;
  String? _status;

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked != null) setState(() => _video.text = picked.path);
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      Uint8List? bytes;
      String? path;
      if (_toFile) {
        path = await VideoThumbnail.thumbnailFile(
          video: _video.text,
          thumbnailPath: (await getTemporaryDirectory()).path,
          imageFormat: _format,
          maxWidth: _maxWidth.round(),
          timeMs: _timeMs.round(),
          quality: _quality.round(),
        );
        if (path != null) bytes = await File(path).readAsBytes();
      } else {
        bytes = await VideoThumbnail.thumbnailData(
          video: _video.text,
          imageFormat: _format,
          maxWidth: _maxWidth.round(),
          timeMs: _timeMs.round(),
          quality: _quality.round(),
        );
      }
      setState(() {
        _bytes = bytes;
        _status = bytes == null
            ? 'No thumbnail was created.'
            : '${bytes.length} bytes in ${stopwatch.elapsedMilliseconds} ms'
                  '${path == null ? '' : '\n$path'}';
      });
    } catch (e) {
      setState(() {
        _bytes = null;
        _status = '$e';
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('video_thumbnail_flutter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _video,
            decoration: InputDecoration(
              labelText: 'Video path or URL',
              suffixIcon: IconButton(
                icon: const Icon(Icons.video_library),
                onPressed: _pickVideo,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ImageFormat>(
            segments: [
              for (final f in ImageFormat.values)
                ButtonSegment(value: f, label: Text(f.name)),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          _slider('Max width', _maxWidth, 0, 1024, (v) => _maxWidth = v),
          _slider('Time (ms)', _timeMs, 0, 10000, (v) => _timeMs = v),
          _slider('Quality', _quality, 0, 100, (v) => _quality = v),
          SwitchListTile(
            title: const Text('Save to file'),
            value: _toFile,
            onChanged: (v) => setState(() => _toFile = v),
          ),
          FilledButton(
            onPressed: _busy ? null : _generate,
            child: Text(_busy ? 'Generating…' : 'Generate thumbnail'),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_status!, key: const Key('status')),
            ),
          if (_bytes != null) Image.memory(_bytes!),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) update,
  ) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: (v) => setState(() => update(v)),
          ),
        ),
        SizedBox(width: 48, child: Text('${value.round()}')),
      ],
    );
  }
}
