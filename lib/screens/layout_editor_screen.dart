import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/models/element_config.dart';
import 'package:musify/models/layout_slot.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/layout_repository.dart';
import 'package:musify/widgets/now_playing/dynamic_layout_player.dart';

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
  bool _gridEnabled = true;
  bool _snapEnabled = true;
  bool _previewEnabled = false;

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
          IconButton(
            tooltip: 'Izgara',
            isSelected: _gridEnabled,
            selectedIcon: const Icon(FluentIcons.grid_24_filled),
            icon: const Icon(FluentIcons.grid_24_regular),
            onPressed: () => setState(() => _gridEnabled = !_gridEnabled),
          ),
          IconButton(
            tooltip: 'Mıknatıs',
            isSelected: _snapEnabled,
            selectedIcon: const Icon(FluentIcons.target_24_filled),
            icon: const Icon(FluentIcons.target_24_regular),
            onPressed: () => setState(() => _snapEnabled = !_snapEnabled),
          ),
          IconButton(
            tooltip: 'Önizleme',
            isSelected: _previewEnabled,
            selectedIcon: const Icon(FluentIcons.eye_24_filled),
            icon: const Icon(FluentIcons.eye_24_regular),
            onPressed: () => setState(() => _previewEnabled = !_previewEnabled),
          ),
          IconButton(
            tooltip: 'Katmanlar',
            icon: const Icon(FluentIcons.layer_24_filled),
            onPressed: _showLayersSheet,
          ),
          IconButton(
            tooltip: 'Şablonlar',
            icon: const Icon(FluentIcons.book_24_filled),
            onPressed: _showTemplatesSheet,
          ),
          IconButton(
            tooltip: 'Tasarımı Paylaş / Aktar',
            icon: const Icon(FluentIcons.share_24_filled),
            onPressed: _showTransferSheet,
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(FluentIcons.add_24_filled),
        label: const Text('Bileşen Ekle'),
        onPressed: _showAddElementSheet,
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
                if (!_previewEnabled)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LayoutGridPainter(
                        color: colorScheme.outlineVariant,
                        showGrid: _gridEnabled,
                        showGuides: _snapEnabled,
                        verticalGuides: _verticalGuides,
                        horizontalGuides: _horizontalGuides,
                      ),
                    ),
                  ),
                if (_previewEnabled)
                  StreamBuilder<MediaItem?>(
                    stream: audioHandler.mediaItem,
                    builder: (context, snapshot) {
                      final metadata = snapshot.data;
                      if (metadata == null) return _buildPreviewFallback();
                      return DynamicLayoutPlayer(
                        slot: LayoutSlot(
                          slotId: widget.slot.slotId,
                          slotName: widget.slot.slotName,
                          elements: _elements,
                        ),
                        metadata: metadata,
                      );
                    },
                  )
                else
                  ..._elements.map(
                    (element) => _buildElement(element, canvasSize),
                  ),
                if (_elements.isEmpty)
                  Center(
                    child: FilledButton.icon(
                      icon: const Icon(FluentIcons.layout_cell_four_24_filled),
                      label: const Text('Varsayılan Düzeni Yükle'),
                      onPressed: _loadDefaultLayout,
                    ),
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
        child: Opacity(
          opacity: element.opacity.clamp(0.0, 1.0),
          child: _EditorInteractiveFeedback(
            element: element,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(element.borderRadius),
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
        ),
      ),
    );
  }

  Widget _buildPreviewFallback() {
    return Center(
      child: Text(
        'Önizleme için bir şarkı çalın',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Widget _buildElementContent(ElementConfig element, Color color) {
    final componentId = element.actionId ?? element.id;
    if (componentId == 'BLUR_BACKGROUND') {
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: ColoredBox(color: color.withValues(alpha: 0.18)),
      );
    }
    if (componentId == 'NEON_FRAME' || componentId == 'EKRAN_CERCEVESI') {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.9), blurRadius: 12),
            BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 28),
          ],
        ),
      );
    }
    final imagePath = element.customImagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      final image = imagePath.startsWith('http://') ||
              imagePath.startsWith('https://')
          ? Image.network(imagePath, fit: BoxFit.cover)
          : Image.file(File(imagePath), fit: BoxFit.cover);
      return ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(element.borderRadius),
          child: image,
        ),
      );
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            _elementLabel(element.id),
            textAlign: _textAlign(element.textAlignment),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: element.textSize,
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
    final snapped = _snapEnabled
        ? _snapElement(element, proposedX, proposedY, canvasSize)
        : _SnapResult(
            x: proposedX,
            y: proposedY,
            verticalGuides: <double>[],
            horizontalGuides: <double>[],
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
    await repository.setActiveSlotId(widget.slot.slotId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Düzen kaydedildi.')),
    );
  }

  Future<void> _loadDefaultLayout() async {
    setState(() {
      _elements = <ElementConfig>[
        const ElementConfig(
          id: 'ALBUM_ART',
          x: 40,
          y: 40,
          width: 280,
          height: 280,
        ),
        const ElementConfig(
          id: 'SONG_TITLE',
          x: 40,
          y: 340,
          width: 280,
          height: 48,
        ),
        const ElementConfig(
          id: 'PROGRESS_BAR',
          x: 40,
          y: 400,
          width: 280,
          height: 24,
        ),
        const ElementConfig(
          id: 'PREVIOUS_TRACK',
          x: 72,
          y: 456,
          width: 56,
          height: 56,
          actionId: 'PREVIOUS_TRACK',
        ),
        const ElementConfig(
          id: 'PLAY_PAUSE',
          x: 152,
          y: 448,
          width: 72,
          height: 72,
          actionId: 'PLAY_PAUSE',
        ),
        const ElementConfig(
          id: 'NEXT_TRACK',
          x: 248,
          y: 456,
          width: 56,
          height: 56,
          actionId: 'NEXT_TRACK',
        ),
      ];
      _selectedElementId = null;
    });
    await _saveLayout();
  }

  Future<void> _showAddElementSheet() async {
    final option = await showModalBottomSheet<_ComponentOption>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _ComponentPickerSheet(),
    );
    if (!mounted || option == null) return;

    final screenSize = MediaQuery.sizeOf(context);
    final width = option.defaultWidth;
    final height = option.defaultHeight;
    final x = ((screenSize.width - width) / 2).clamp(16.0, double.infinity);
    final y = ((screenSize.height - height) / 2).clamp(16.0, double.infinity);
    final element = ElementConfig(
      id: '${option.id}_${DateTime.now().microsecondsSinceEpoch}',
      x: x.toDouble(),
      y: y.toDouble(),
      width: width,
      height: height,
      actionId: option.id,
    );

    setState(() {
      _elements.add(element);
      _selectedElementId = element.id;
    });
    await _saveLayout();
  }

  Future<void> _showLayersSheet() async {
    if (_elements.isEmpty) return;
    final reordered = await showModalBottomSheet<List<ElementConfig>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _LayersSheet(
        elements: _elements,
        onChanged: (elements) async {
          if (!mounted) return;
          setState(() => _elements = elements);
          await _saveLayout();
        },
      ),
    );
    if (!mounted || reordered == null) return;
    setState(() => _elements = reordered);
    await _saveLayout();
  }

  Future<void> _showTemplatesSheet() async {
    final template = await showModalBottomSheet<_LayoutTemplate>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _TemplatesSheet(),
    );
    if (!mounted || template == null) return;
    setState(() {
      _elements = _templateElements(template);
      _selectedElementId = null;
    });
    await _saveLayout();
  }

  Future<void> _showTransferSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(FluentIcons.copy_24_filled),
              title: const Text('JSON Dışa Aktar'),
              onTap: () => Navigator.pop(context, 'export'),
            ),
            ListTile(
              leading: const Icon(FluentIcons.clipboard_paste_24_filled),
              title: const Text('JSON İçe Aktar'),
              onTap: () => Navigator.pop(context, 'import'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'export') {
      await _exportLayout();
    } else if (action == 'import') {
      await _importLayout();
    }
  }

  Future<void> _exportLayout() async {
    final json = const JsonEncoder.withIndent('  ').convert(
      LayoutSlot(
        slotId: widget.slot.slotId,
        slotName: widget.slot.slotName,
        elements: _elements,
      ).toJson(),
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tasarım JSON olarak panoya kopyalandı.')),
    );
  }

  Future<void> _importLayout() async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JSON İçe Aktar'),
        content: TextField(
          controller: controller,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: '{"elements": [...]}',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('İçe Aktar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || json == null || json.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(json);
      final rawElements = decoded is Map ? decoded['elements'] : decoded;
      if (rawElements is! List) throw const FormatException('elements bulunamadı');
      final elements = rawElements
          .map((element) => ElementConfig.fromJson(
                Map<String, dynamic>.from(element as Map),
              ))
          .toList();
      setState(() {
        _elements = elements;
        _selectedElementId = null;
      });
      await _saveLayout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tasarım içe aktarıldı.')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçersiz layout JSON verisi.')),
      );
    }
  }

  List<ElementConfig> _templateElements(_LayoutTemplate template) {
    switch (template) {
      case _LayoutTemplate.classic:
        return const [
          ElementConfig(id: 'classic_blur', actionId: 'BLUR_BACKGROUND', x: 0, y: 0, width: 360, height: 640),
          ElementConfig(id: 'classic_art', actionId: 'ALBUM_ART', x: 40, y: 44, width: 280, height: 280, borderRadius: 24),
          ElementConfig(id: 'classic_title', actionId: 'SONG_TITLE', x: 40, y: 350, width: 280, height: 44, textSize: 20),
          ElementConfig(id: 'classic_artist', actionId: 'ARTIST_NAME', x: 40, y: 394, width: 280, height: 32, opacity: 0.7),
          ElementConfig(id: 'classic_progress', actionId: 'PROGRESS_BAR', x: 32, y: 450, width: 296, height: 48),
          ElementConfig(id: 'classic_previous', actionId: 'PREVIOUS_TRACK', x: 72, y: 530, width: 56, height: 56),
          ElementConfig(id: 'classic_play', actionId: 'PLAY_PAUSE', x: 148, y: 520, width: 72, height: 72),
          ElementConfig(id: 'classic_next', actionId: 'NEXT_TRACK', x: 248, y: 530, width: 56, height: 56),
        ];
      case _LayoutTemplate.minimalist:
        return const [
          ElementConfig(id: 'minimal_art', actionId: 'ALBUM_ART', x: 24, y: 260, width: 112, height: 112, borderRadius: 16),
          ElementConfig(id: 'minimal_title', actionId: 'SONG_TITLE', x: 152, y: 274, width: 184, height: 36, textAlignment: 'left', textSize: 18),
          ElementConfig(id: 'minimal_artist', actionId: 'ARTIST_NAME', x: 152, y: 310, width: 184, height: 28, textAlignment: 'left', opacity: 0.7),
          ElementConfig(id: 'minimal_progress', actionId: 'PROGRESS_BAR', x: 24, y: 400, width: 312, height: 44),
          ElementConfig(id: 'minimal_play', actionId: 'PLAY_PAUSE', x: 152, y: 470, width: 56, height: 56),
          ElementConfig(id: 'minimal_previous', actionId: 'PREVIOUS_TRACK', x: 88, y: 476, width: 44, height: 44),
          ElementConfig(id: 'minimal_next', actionId: 'NEXT_TRACK', x: 228, y: 476, width: 44, height: 44),
        ];
      case _LayoutTemplate.retroCyber:
        return const [
          ElementConfig(id: 'retro_blur', actionId: 'BLUR_BACKGROUND', x: 0, y: 0, width: 360, height: 640, opacity: 0.85),
          ElementConfig(id: 'retro_frame', actionId: 'NEON_FRAME', x: 8, y: 8, width: 344, height: 624, borderRadius: 12, colorHex: '#00E5FF'),
          ElementConfig(id: 'retro_art', actionId: 'ALBUM_ART', x: 56, y: 72, width: 248, height: 248, borderRadius: 8),
          ElementConfig(id: 'retro_title', actionId: 'SONG_TITLE', x: 32, y: 350, width: 296, height: 48, textSize: 24, colorHex: '#00E5FF'),
          ElementConfig(id: 'retro_progress', actionId: 'PROGRESS_BAR', x: 24, y: 430, width: 312, height: 52),
          ElementConfig(id: 'retro_previous', actionId: 'PREVIOUS_TRACK', x: 52, y: 520, width: 72, height: 72, colorHex: '#FF2BD6'),
          ElementConfig(id: 'retro_play', actionId: 'PLAY_PAUSE', x: 144, y: 510, width: 88, height: 88, colorHex: '#00E5FF'),
          ElementConfig(id: 'retro_next', actionId: 'NEXT_TRACK', x: 236, y: 520, width: 72, height: 72, colorHex: '#FF2BD6'),
        ];
    }
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

  TextAlign _textAlign(String value) {
    switch (value) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
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
  _GuideMatch(this.target, this.offset) : distance = offset.abs();

  final double target;
  final double offset;
  final double distance;
}

class _LayoutGridPainter extends CustomPainter {
  const _LayoutGridPainter({
    required this.color,
    required this.showGrid,
    required this.showGuides,
    required this.verticalGuides,
    required this.horizontalGuides,
  });

  final Color color;
  final bool showGrid;
  final bool showGuides;
  final List<double> verticalGuides;
  final List<double> horizontalGuides;

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 16) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = 0; y < size.height; y += 16) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    if (!showGuides) return;
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
      oldDelegate.showGrid != showGrid ||
      oldDelegate.showGuides != showGuides ||
        oldDelegate.verticalGuides != verticalGuides ||
        oldDelegate.horizontalGuides != horizontalGuides;
  }
}

enum _LayoutTemplate { classic, minimalist, retroCyber }

class _TemplatesSheet extends StatelessWidget {
  const _TemplatesSheet();

  @override
  Widget build(BuildContext context) {
    final templates = [
      (
        template: _LayoutTemplate.classic,
        title: 'Klasik / Classic',
        description: 'Büyük kapak, ortalanmış bilgiler ve alt kontroller.',
        icon: FluentIcons.music_note_2_24_filled,
      ),
      (
        template: _LayoutTemplate.minimalist,
        title: 'Minimalist',
        description: 'Küçük kapak, yan yana bilgiler ve sade kontroller.',
        icon: FluentIcons.apps_list_24_filled,
      ),
      (
        template: _LayoutTemplate.retroCyber,
        title: 'Retro / Cyber',
        description: 'Neon çerçeve, bulanık arka plan ve geniş kontroller.',
        icon: FluentIcons.flash_24_filled,
      ),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Şablonlar', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            for (final item in templates)
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.title),
                subtitle: Text(item.description),
                onTap: () => Navigator.pop(context, item.template),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComponentPickerSheet extends StatelessWidget {
  const _ComponentPickerSheet();

  static const _sections = <({String title, List<_ComponentOption> options})>[
    (
      title: 'Görseller',
      options: [
        _ComponentOption(
          id: 'ALBUM_ART',
          label: 'Albüm Kapağı',
          icon: FluentIcons.image_24_filled,
          defaultWidth: 180,
          defaultHeight: 180,
        ),
        _ComponentOption(
          id: 'BLUR_BACKGROUND',
          label: 'Bulanık Arka Plan',
          icon: FluentIcons.image_24_regular,
          defaultWidth: 320,
          defaultHeight: 180,
        ),
        _ComponentOption(
          id: 'NEON_FRAME',
          label: 'Neon Çerçeve / Ekran Çerçevesi',
          icon: FluentIcons.border_all_24_filled,
          defaultWidth: 320,
          defaultHeight: 560,
        ),
      ],
    ),
    (
      title: 'Metinler',
      options: [
        _ComponentOption(
          id: 'SONG_TITLE',
          label: 'Şarkı Adı',
          icon: FluentIcons.text_bullet_list_24_filled,
          defaultWidth: 240,
          defaultHeight: 48,
        ),
        _ComponentOption(
          id: 'ARTIST_NAME',
          label: 'Sanatçı Adı',
          icon: FluentIcons.person_24_filled,
          defaultWidth: 240,
          defaultHeight: 40,
        ),
        _ComponentOption(
          id: 'CURRENT_TIME',
          label: 'Geçen Süre',
          icon: FluentIcons.timer_24_filled,
          defaultWidth: 80,
          defaultHeight: 40,
        ),
        _ComponentOption(
          id: 'TOTAL_TIME',
          label: 'Toplam Süre',
          icon: FluentIcons.timer_24_regular,
          defaultWidth: 80,
          defaultHeight: 40,
        ),
      ],
    ),
    (
      title: 'Kontroller',
      options: [
        _ComponentOption(
          id: 'PLAY_PAUSE',
          label: 'Oynat / Duraklat',
          icon: FluentIcons.play_circle_24_filled,
          defaultWidth: 64,
          defaultHeight: 64,
        ),
        _ComponentOption(
          id: 'NEXT_TRACK',
          label: 'Sonraki Şarkı',
          icon: FluentIcons.next_24_filled,
          defaultWidth: 56,
          defaultHeight: 56,
        ),
        _ComponentOption(
          id: 'PREVIOUS_TRACK',
          label: 'Önceki Şarkı',
          icon: FluentIcons.previous_24_filled,
          defaultWidth: 56,
          defaultHeight: 56,
        ),
        _ComponentOption(
          id: 'LIKE',
          label: 'Beğen',
          icon: FluentIcons.heart_24_filled,
          defaultWidth: 56,
          defaultHeight: 56,
        ),
        _ComponentOption(
          id: 'SHUFFLE',
          label: 'Karıştır',
          icon: FluentIcons.arrow_shuffle_24_filled,
          defaultWidth: 56,
          defaultHeight: 56,
        ),
        _ComponentOption(
          id: 'REPEAT',
          label: 'Tekrarla',
          icon: FluentIcons.arrow_repeat_all_24_filled,
          defaultWidth: 56,
          defaultHeight: 56,
        ),
        _ComponentOption(
          id: 'QUEUE',
          label: 'Sıra',
          icon: FluentIcons.list_24_filled,
          defaultWidth: 56,
          defaultHeight: 56,
        ),
        _ComponentOption(
          id: 'VOLUME_SLIDER',
          label: 'Ses Seviyesi',
          icon: FluentIcons.speaker_2_24_filled,
          defaultWidth: 180,
          defaultHeight: 48,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bileşen Ekle',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            for (final section in _sections) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...section.options.map(
                (option) => ListTile(
                  leading: Icon(option.icon),
                  title: Text(option.label),
                  trailing: const Icon(FluentIcons.chevron_right_24_regular),
                  onTap: () => Navigator.pop(context, option),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComponentOption {
  const _ComponentOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.defaultWidth,
    required this.defaultHeight,
  });

  final String id;
  final String label;
  final IconData icon;
  final double defaultWidth;
  final double defaultHeight;
}

class _EditorInteractiveFeedback extends StatefulWidget {
  const _EditorInteractiveFeedback({required this.element, required this.child});

  final ElementConfig element;
  final Widget child;

  @override
  State<_EditorInteractiveFeedback> createState() =>
      _EditorInteractiveFeedbackState();
}

class _EditorInteractiveFeedbackState
    extends State<_EditorInteractiveFeedback> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (widget.element.tapEffect == 'scale_down') {
      child = AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        child: child,
      );
    } else if (widget.element.tapEffect == 'glow_flash') {
      child = AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary,
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: child,
      );
    }
    return GestureDetector(
      onTapDown: (_) {
        if (widget.element.hapticEnabled) HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: widget.element.tapEffect == 'ripple'
          ? Material(
              color: Colors.transparent,
              child: InkWell(onTap: () {}, child: child),
            )
          : child,
    );
  }
}

class _LayersSheet extends StatefulWidget {
  const _LayersSheet({required this.elements, required this.onChanged});

  final List<ElementConfig> elements;
  final Future<void> Function(List<ElementConfig> elements) onChanged;

  @override
  State<_LayersSheet> createState() => _LayersSheetState();
}

class _LayersSheetState extends State<_LayersSheet> {
  late List<ElementConfig> _topToBottom;

  @override
  void initState() {
    super.initState();
    _topToBottom = widget.elements.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Katmanlar', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Üstteki öğeler alttaki öğelerin üzerinde görünür.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _topToBottom.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final element = _topToBottom.removeAt(oldIndex);
                    _topToBottom.insert(newIndex, element);
                  });
                  widget.onChanged(_topToBottom.reversed.toList());
                },
                itemBuilder: (context, index) {
                  final element = _topToBottom[index];
                  return ListTile(
                    key: ValueKey(element.id),
                    leading: const Icon(FluentIcons.layer_24_regular),
                    title: Text(_layerLabel(element)),
                    subtitle: Text(element.id),
                    trailing: const Icon(FluentIcons.re_order_dots_vertical_24_regular),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, _topToBottom.reversed.toList()),
              child: const Text('Sıralamayı Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  String _layerLabel(ElementConfig element) {
    final action = element.actionId ?? element.id;
    return action.replaceAll('_', ' ');
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
  late double _borderRadius;
  late double _opacity;
  late String _textAlignment;
  late double _textSize;
  late bool _hapticEnabled;
  late String _tapEffect;
  late String? _actionId;

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
    _borderRadius = element.borderRadius;
    _opacity = element.opacity;
    _textAlignment = element.textAlignment;
    _textSize = element.textSize;
    _hapticEnabled = element.hapticEnabled;
    _tapEffect = element.tapEffect;
    _actionId = element.actionId;
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
        child: SingleChildScrollView(
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
            _sliderField(
              label: 'Köşe Yuvarlama',
              value: _borderRadius,
              min: 0,
              max: 50,
              divisions: 50,
              suffix: _borderRadius.toStringAsFixed(0),
              onChanged: (value) => setState(() => _borderRadius = value),
            ),
            _sliderField(
              label: 'Saydamlık',
              value: _opacity,
              min: 0,
              max: 1,
              divisions: 20,
              suffix: _opacity.toStringAsFixed(2),
              onChanged: (value) => setState(() => _opacity = value),
            ),
            if (_isTextElement) ...[
              DropdownButtonFormField<String>(
                value: _textAlignment,
                decoration: const InputDecoration(labelText: 'Metin Hizalama'),
                items: const [
                  DropdownMenuItem(value: 'left', child: Text('Sol')),
                  DropdownMenuItem(value: 'center', child: Text('Orta')),
                  DropdownMenuItem(value: 'right', child: Text('Sağ')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _textAlignment = value);
                },
              ),
              _sliderField(
                label: 'Punto Boyutu',
                value: _textSize,
                min: 8,
                max: 48,
                divisions: 40,
                suffix: _textSize.toStringAsFixed(0),
                onChanged: (value) => setState(() => _textSize = value),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _actionId,
              decoration: const InputDecoration(
                labelText: 'Buton Aksiyonu / İşlevi',
              ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('Yok')),
                DropdownMenuItem(value: 'PLAY_PAUSE', child: Text('Oynat / Duraklat')),
                DropdownMenuItem(value: 'NEXT', child: Text('Sonraki')),
                DropdownMenuItem(value: 'PREVIOUS', child: Text('Önceki')),
                DropdownMenuItem(value: 'LIKE', child: Text('Beğen')),
                DropdownMenuItem(value: 'SHUFFLE', child: Text('Karıştır')),
                DropdownMenuItem(value: 'REPEAT', child: Text('Tekrarla')),
                DropdownMenuItem(value: 'OPEN_QUEUE', child: Text('Sırayı Aç')),
                DropdownMenuItem(value: 'OPEN_LYRICS', child: Text('Şarkı Sözlerini Aç')),
                DropdownMenuItem(value: 'TOGGLE_EQUALIZER', child: Text('Ekolayzeri Aç / Kapat')),
                DropdownMenuItem(value: 'MUTE_UNMUTE', child: Text('Sessize Al / Sesi Aç')),
              ],
              onChanged: (value) => setState(() => _actionId = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dokunma Titreşimi'),
              value: _hapticEnabled,
              onChanged: (value) => setState(() => _hapticEnabled = value),
            ),
            DropdownButtonFormField<String>(
              value: _tapEffect,
              decoration: const InputDecoration(labelText: 'Tıklama Efekti'),
              items: const [
                DropdownMenuItem(value: 'scale_down', child: Text('Ölçek Küçülme')),
                DropdownMenuItem(value: 'ripple', child: Text('Ripple / Su Dalgası')),
                DropdownMenuItem(value: 'glow_flash', child: Text('Parlama / Glow Flash')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _tapEffect = value);
              },
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
                    ? 'Özel Görseli Değiştir (PNG/JPG/GIF)'
                    : 'Özel Görsel / PNG / GIF Yükle',
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
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'gif'],
      );
      final pickedPath = result?.path;
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
        actionId: _actionId,
        borderRadius: _borderRadius,
        opacity: _opacity,
        textAlignment: _textAlignment,
        textSize: _textSize,
        hapticEnabled: _hapticEnabled,
        tapEffect: _tapEffect,
      ),
    );
  }

  bool get _isTextElement {
    const textIds = {'SONG_TITLE', 'ARTIST_NAME', 'CURRENT_TIME', 'TOTAL_TIME'};
    return textIds.contains(widget.element.actionId ?? widget.element.id);
  }

  Widget _sliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(suffix)],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}