import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/models/element_config.dart';
import 'package:musify/models/layout_slot.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/layout_repository.dart';

class LayoutEditorScreen extends StatefulWidget {
  const LayoutEditorScreen({
    required this.slot,
    this.repository,
    super.key,
  });

  final LayoutSlot slot;
  final LayoutRepository? repository;

  @override
  State<LayoutEditorScreen> createState() => _LayoutEditorScreenState();
}

class _LayoutEditorScreenState extends State<LayoutEditorScreen> {
  static const double _snapDistance = 8;

  late List<ElementConfig> _elements;
  String? _selectedElementId;
  List<double> _verticalGuides = <double>[];
  List<double> _horizontalGuides = <double>[];

  @override
  void initState() {
    super.initState();
    _elements = List<ElementConfig>.from(widget.slot.elements);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.slot.slotName),
        actions: [
          FilledButton.icon(
            icon: const Icon(FluentIcons.save_24_filled),
            label: const Text('Kaydet'),
            onPressed: _saveLayout,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          return ColoredBox(
            color: colorScheme.surfaceContainerLowest,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LayoutGridPainter(
                      color: colorScheme.outlineVariant,
                      verticalGuides: _verticalGuides,
                      horizontalGuides: _horizontalGuides,
                    ),
                  ),
                ),
                ..._elements.map(
                  (element) => _buildElement(element, canvasSize),
                ),
                if (_elements.isEmpty)
                  const Center(
                    child: Text('Bu slotta düzenlenecek eleman yok.'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildElement(ElementConfig element, Size canvasSize) {
    final isSelected = element.id == _selectedElementId;
    final color = _parseColor(element.colorHex) ??
        Theme.of(context).colorScheme.primaryContainer;

    return Positioned(
      left: element.x,
      top: element.y,
      width: element.width,
      height: element.height,
      child: GestureDetector(
        onTap: () => _editElement(element),
        onPanStart: (_) => setState(() => _selectedElementId = element.id),
        onPanUpdate: (details) => _moveElement(element, details.delta, canvasSize),
        onPanEnd: (_) => setState(() {
          _verticalGuides = <double>[];
          _horizontalGuides = <double>[];
        }),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.82),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : color.withValues(alpha: 0.55),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: _buildElementContent(element, color),
        ),
      ),
    );
  }

  Widget _buildElementContent(ElementConfig element, Color color) {
    final imagePath = element.customImagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      final image = imagePath.startsWith('http://') ||
              imagePath.startsWith('https://')
          ? Image.network(imagePath, fit: BoxFit.cover)
          : Image.file(File(imagePath), fit: BoxFit.cover);
      return ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
        child: image,
      );
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            _elementLabel(element.id),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _moveElement(ElementConfig element, Offset delta, Size canvasSize) {
    final proposedX = (element.x + delta.dx)
        .clamp(0.0, (canvasSize.width - element.width).clamp(0.0, double.infinity));
    final proposedY = (element.y + delta.dy)
        .clamp(0.0, (canvasSize.height - element.height).clamp(0.0, double.infinity));
    final snapped = _snapElement(
      element,
      proposedX.toDouble(),
      proposedY.toDouble(),
      canvasSize,
    );

    setState(() {
      _replaceElement(
        element,
        element.copyWith(x: snapped.x, y: snapped.y),
      );
      _verticalGuides = snapped.verticalGuides;
      _horizontalGuides = snapped.horizontalGuides;
      _selectedElementId = element.id;
    });
  }

  _SnapResult _snapElement(
    ElementConfig element,
    double x,
    double y,
    Size canvasSize,
  ) {
    final verticalTargets = <double>[canvasSize.width / 2];
    final horizontalTargets = <double>[canvasSize.height / 2];
    for (final other in _elements) {
      if (other.id == element.id) continue;
      verticalTargets.addAll(<double>[other.x, other.x + other.width / 2, other.x + other.width]);
      horizontalTargets.addAll(<double>[other.y, other.y + other.height / 2, other.y + other.height]);
    }

    final xCandidates = <double>[x, x + element.width / 2, x + element.width];
    final yCandidates = <double>[y, y + element.height / 2, y + element.height];
    final xSnap = _findSnap(xCandidates, verticalTargets);
    final ySnap = _findSnap(yCandidates, horizontalTargets);
    return _SnapResult(
      x: (x + (xSnap?.offset ?? 0)).clamp(0.0, canvasSize.width - element.width),
      y: (y + (ySnap?.offset ?? 0)).clamp(0.0, canvasSize.height - element.height),
      verticalGuides: xSnap == null ? <double>[] : <double>[xSnap.target],
      horizontalGuides: ySnap == null ? <double>[] : <double>[ySnap.target],
    );
  }

  _GuideMatch? _findSnap(List<double> candidates, List<double> targets) {
    _GuideMatch? closest;
    for (final candidate in candidates) {
      for (final target in targets) {
        final distance = target - candidate;
        if (distance.abs() <= _snapDistance &&
            (closest == null || distance.abs() < closest.distance)) {
          closest = _GuideMatch(target, distance);
        }
      }
    }
    return closest;
  }

  Future<void> _editElement(ElementConfig element) async {
    setState(() => _selectedElementId = element.id);
    final editedElement = await showModalBottomSheet<ElementConfig>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ElementEditorPanel(element: element),
    );
    if (!mounted || editedElement == null) return;
    setState(() => _replaceElement(element, editedElement));
  }

  Future<void> _saveLayout() async {
    final repository = widget.repository ?? LayoutRepository();
    await repository.saveSlot(
      LayoutSlot(
        slotId: widget.slot.slotId,
        slotName: widget.slot.slotName,
        elements: _elements,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Düzen kaydedildi.')),
    );
  }

  void _replaceElement(ElementConfig oldElement, ElementConfig newElement) {
    final index = _elements.indexOf(oldElement);
    if (index != -1) _elements[index] = newElement;
  }

  String _elementLabel(String id) => id.replaceAll('_', ' ');

  Color? _parseColor(String? value) {
    if (value == null) return null;
    final hex = value.replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final color = int.tryParse(normalized, radix: 16);
    return color == null ? null : Color(color);
  }
}

class _SnapResult {
  const _SnapResult({
    required this.x,
    required this.y,
    required this.verticalGuides,
    required this.horizontalGuides,
  });

  final double x;
  final double y;
  final List<double> verticalGuides;
  final List<double> horizontalGuides;
}

class _GuideMatch {
  const _GuideMatch(this.target, this.offset) : distance = offset.abs();

  final double target;
  final double offset;
  final double distance;
}

class _LayoutGridPainter extends CustomPainter {
  const _LayoutGridPainter({
    required this.color,
    required this.verticalGuides,
    required this.horizontalGuides,
  });

  final Color color;
  final List<double> verticalGuides;
  final List<double> horizontalGuides;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final guidePaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..strokeWidth = 1.5;
    for (final x in verticalGuides) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guidePaint);
    }
    for (final y in horizontalGuides) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }
  }

  @override
  bool shouldRepaint(_LayoutGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.verticalGuides != verticalGuides ||
        oldDelegate.horizontalGuides != horizontalGuides;
  }
}

class _ElementEditorPanel extends StatefulWidget {
  const _ElementEditorPanel({required this.element});

  final ElementConfig element;

  @override
  State<_ElementEditorPanel> createState() => _ElementEditorPanelState();
}

class _ElementEditorPanelState extends State<_ElementEditorPanel> {
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _colorController;
  late final TextEditingController _imageUrlController;
  String? _customImagePath;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    final element = widget.element;
    _xController = TextEditingController(text: element.x.toString());
    _yController = TextEditingController(text: element.y.toString());
    _widthController = TextEditingController(text: element.width.toString());
    _heightController = TextEditingController(text: element.height.toString());
    _colorController = TextEditingController(text: element.colorHex ?? '');
    _imageUrlController = TextEditingController(
      text: element.customImagePath?.startsWith('http') == true
          ? element.customImagePath
          : '',
    );
    _customImagePath = element.customImagePath;
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _colorController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      _numberField('X', _xController),
      _numberField('Y', _yController),
      _numberField('Genişlik', _widthController),
      _numberField('Yükseklik', _heightController),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.element.id,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: fields,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(
                labelText: 'Renk (HEX)',
                hintText: '#009688',
                prefixIcon: Icon(FluentIcons.color_24_filled),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isPickingImage ? null : _pickImage,
              icon: const Icon(FluentIcons.image_add_24_filled),
              label: Text(
                _customImagePath != null &&
                        !_customImagePath!.startsWith('http')
                    ? 'Özel Görseli Değiştir'
                    : 'Özel Görsel Ekle',
              ),
            ),
            if (_customImagePath != null &&
                !_customImagePath!.startsWith('http'))
              Text(
                _customImagePath!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Görsel URL (isteğe bağlı)',
                hintText: 'https://ornek.com/gorsel.png',
                prefixIcon: Icon(FluentIcons.globe_24_filled),
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                final url = value.trim();
                setState(() => _customImagePath = url.isEmpty ? null : url);
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _apply,
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      final pickedPath = result?.files.single.path;
      if (pickedPath == null) return;

      final imageDirectory = Directory('$applicationDirPath/layout_images');
      await imageDirectory.create(recursive: true);
      final source = File(pickedPath);
      final fileName = pickedPath.split(Platform.pathSeparator).last;
      final destination = File(
        '${imageDirectory.path}/${DateTime.now().microsecondsSinceEpoch}_$fileName',
      );
      final copiedFile = await source.copy(destination.path);
      if (!mounted) return;
      setState(() {
        _customImagePath = copiedFile.path;
        _imageUrlController.clear();
      });
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Widget _numberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }

  void _apply() {
    final values = <double?>[
      double.tryParse(_xController.text),
      double.tryParse(_yController.text),
      double.tryParse(_widthController.text),
      double.tryParse(_heightController.text),
    ];
    if (values.any((value) => value == null || value < 0)) return;

    Navigator.pop(
      context,
      ElementConfig(
        id: widget.element.id,
        x: values[0]!,
        y: values[1]!,
        width: values[2]!,
        height: values[3]!,
        colorHex: _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
        customImagePath: _customImagePath,
        actionId: widget.element.actionId,
      ),
    );
  }
}