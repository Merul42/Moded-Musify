import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:musify/models/element_config.dart';
import 'package:musify/models/layout_slot.dart';
import 'package:musify/services/layout_repository.dart';

class LayoutPageOverlay extends StatelessWidget {
  const LayoutPageOverlay({required this.page, required this.child, super.key});

  final LayoutPage page;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LayoutSlot?>(
      future: LayoutRepository().getPageLayout(page),
      builder: (context, snapshot) {
        final slot = snapshot.data;
        if (slot == null || slot.elements.isEmpty) return child;

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                child,
                IgnorePointer(
                  child: Stack(
                    children: slot.elements.map((element) {
                      final width = element.width.clamp(
                        1.0,
                        constraints.maxWidth,
                      );
                      final height = element.height.clamp(
                        1.0,
                        constraints.maxHeight,
                      );
                      return Positioned(
                        left: element.x.clamp(
                          0.0,
                          constraints.maxWidth - width,
                        ),
                        top: element.y.clamp(
                          0.0,
                          constraints.maxHeight - height,
                        ),
                        width: width,
                        height: height,
                        child: _LayoutPageElement(element: element),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LayoutPageElement extends StatelessWidget {
  const _LayoutPageElement({required this.element});

  final ElementConfig element;

  @override
  Widget build(BuildContext context) {
    final mediaSource = element.resolvedMediaSource;
    final content = mediaSource == null || mediaSource.isEmpty
        ? _label(context)
        : _media(mediaSource);
    final color = _parseColor(element.colorHex);

    return Opacity(
      opacity: element.opacity.clamp(0.0, 1.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(element.borderRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color?.withValues(alpha: 0.12),
            border: element.actionId == 'NEON_FRAME'
                ? Border.all(
                    color: color ?? Theme.of(context).colorScheme.primary,
                    width: 3,
                  )
                : null,
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _label(BuildContext context) {
    final label = (element.actionId ?? element.id).replaceAll('_', ' ');
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          textAlign: _textAlign,
          style: TextStyle(
            color:
                _parseColor(element.colorHex) ??
                Theme.of(context).colorScheme.onSurface,
            fontSize: element.textSize,
          ),
        ),
      ),
    );
  }

  Widget _media(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(source, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return Image.file(File(source), fit: BoxFit.cover);
  }

  TextAlign get _textAlign {
    switch (element.textAlignment) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }

  Color? _parseColor(String? value) {
    if (value == null) return null;
    final hex = value.replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final number = int.tryParse(normalized, radix: 16);
    return number == null ? null : Color(number);
  }
}
