import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/models/element_config.dart';
import 'package:musify/models/layout_slot.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/screens/equalizer_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/widgets/playback_icon_button.dart';
import 'package:musify/widgets/position_slider.dart';
import 'package:musify/widgets/queue_list_view.dart';

bool _layoutPlayerMuted = false;

class DynamicLayoutPlayer extends StatelessWidget {
  const DynamicLayoutPlayer({required this.slot, required this.metadata, super.key});

  final LayoutSlot slot;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: slot.elements.map((element) {
          final x = _limit(element.x, 0, constraints.maxWidth);
          final y = _limit(element.y, 0, constraints.maxHeight);
          final width = _limit(element.width, 1, constraints.maxWidth);
          final height = _limit(element.height, 1, constraints.maxHeight);
          return Positioned(
            left: x,
            top: y,
            width: width,
            height: height,
            child: _DynamicElement(element: element, metadata: metadata),
          );
        }).toList(),
      ),
    );
  }

  double _limit(double value, double minimum, double maximum) {
    if (maximum < minimum) return minimum;
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
  }
}

class _DynamicElement extends StatelessWidget {
  const _DynamicElement({required this.element, required this.metadata});

  final ElementConfig element;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(element.colorHex);
    final componentId = element.actionId ?? element.id;
    if (componentId == 'BLUR_BACKGROUND') {
      return _styled(
        context,
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: ColoredBox(
            color: (color ?? Theme.of(context).colorScheme.surface)
                .withValues(alpha: 0.18),
          ),
        ),
      );
    }
    if (componentId == 'NEON_FRAME' || componentId == 'EKRAN_CERCEVESI') {
      final frameColor = color ?? Theme.of(context).colorScheme.primary;
      return _styled(
        context,
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: frameColor, width: 3),
            boxShadow: [
              BoxShadow(color: frameColor.withValues(alpha: 0.9), blurRadius: 12),
              BoxShadow(color: frameColor.withValues(alpha: 0.55), blurRadius: 28),
            ],
          ),
        ),
      );
    }
    final action = _actionWidget(context);
    if (element.customImagePath == null || element.customImagePath!.isEmpty) {
      return _styled(context, _InteractiveFeedback(element: element, child: action));
    }

    final path = element.customImagePath!;
    final image = path.startsWith('http://') || path.startsWith('https://')
        ? Image.network(path, fit: BoxFit.cover)
        : Image.file(File(path), fit: BoxFit.cover);
    return _styled(
      context,
      _InteractiveFeedback(
        element: element,
        child: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: color == null
                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                : ColorFilter.mode(color, BlendMode.srcATop),
            child: image,
          ),
          _actionWidget(context),
        ],
        ),
      ),
    );
  }

  Widget _styled(BuildContext context, Widget child) {
    return Opacity(
      opacity: element.opacity.clamp(0.0, 1.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(element.borderRadius),
        child: child,
      ),
    );
  }

  Widget _actionWidget(BuildContext context) {
    switch (element.actionId ?? element.id) {
      case 'PLAY_PAUSE':
        return PlaybackIconButton(
          iconSize: 32,
          iconColor: Theme.of(context).colorScheme.onPrimary,
          backgroundColor: Theme.of(context).colorScheme.primary,
        );
      case 'NEXT_TRACK':
      case 'NEXT':
        return _controlButton(
          context,
          FluentIcons.next_24_regular,
          audioHandler.skipToNext,
        );
      case 'PREVIOUS_TRACK':
      case 'PREVIOUS':
        return _controlButton(
          context,
          FluentIcons.previous_24_regular,
          audioHandler.skipToPrevious,
        );
      case 'SHUFFLE':
        return ValueListenableBuilder<bool>(
          valueListenable: shuffleNotifier,
          builder: (context, enabled, _) => _controlButton(
            context,
            FluentIcons.arrow_shuffle_24_filled,
            () => audioHandler.setShuffleMode(
              enabled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
            ),
            active: enabled,
          ),
        );
      case 'REPEAT':
        return ValueListenableBuilder<AudioServiceRepeatMode>(
          valueListenable: repeatNotifier,
          builder: (context, mode, _) => _controlButton(
            context,
            FluentIcons.arrow_repeat_all_24_filled,
            () {
              final next = mode == AudioServiceRepeatMode.none
                  ? AudioServiceRepeatMode.all
                  : mode == AudioServiceRepeatMode.all
                  ? AudioServiceRepeatMode.one
                  : AudioServiceRepeatMode.none;
              repeatNotifier.value = next;
              audioHandler.setRepeatMode(next);
            },
            active: mode != AudioServiceRepeatMode.none,
          ),
        );
      case 'LIKE':
        final audioId = metadata.extras?['ytid'];
        return ValueListenableBuilder<List>(
          valueListenable: userLikedSongsList,
          builder: (context, likedSongs, _) {
            final liked = isSongAlreadyLiked(audioId);
            return _controlButton(
              context,
              liked ? FluentIcons.heart_24_filled : FluentIcons.heart_24_regular,
              () => updateSongLikeStatus(audioId, !liked, songData: metadata.extras),
              active: liked,
            );
          },
        );
      case 'QUEUE':
      case 'OPEN_QUEUE':
        return _controlButton(
          context,
          FluentIcons.list_24_filled,
          () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => const QueueWidget(isBottomSheet: true),
          ),
        );
      case 'OPEN_LYRICS':
        return _controlButton(
          context,
          FluentIcons.text_quote_24_filled,
          () => _showLyrics(context),
        );
      case 'TOGGLE_EQUALIZER':
        return _controlButton(
          context,
          FluentIcons.options_24_filled,
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const EqualizerPage()),
          ),
        );
      case 'MUTE_UNMUTE':
        return _controlButton(
          context,
          _layoutPlayerMuted
              ? FluentIcons.speaker_off_24_filled
              : FluentIcons.speaker_2_24_filled,
          () {
            _layoutPlayerMuted = !_layoutPlayerMuted;
            audioHandler.audioPlayer.setVolume(_layoutPlayerMuted ? 0 : 1);
          },
          active: _layoutPlayerMuted,
        );
      case 'PROGRESS_BAR':
        return const PositionSlider();
      case 'SONG_TITLE':
        return _textWidget(metadata.title);
      case 'ARTIST_NAME':
        return _textWidget(metadata.artist ?? '');
      case 'ALBUM_ART':
        return _albumArt();
      case 'CURRENT_TIME':
        return StreamBuilder<PositionData>(
          stream: audioHandler.positionDataStream,
          builder: (_, snapshot) => _textWidget(
            _formatDuration(snapshot.data?.position),
          ),
        );
      case 'TOTAL_TIME':
        return StreamBuilder<PositionData>(
          stream: audioHandler.positionDataStream,
          builder: (_, snapshot) => _textWidget(
            _formatDuration(snapshot.data?.duration),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _textWidget(String text) {
    final alignment = switch (element.textAlignment) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };
    return Center(
      child: Text(
        text,
        textAlign: alignment,
        style: TextStyle(fontSize: element.textSize),
      ),
    );
  }

  Widget _albumArt() {
    final uri = metadata.artUri;
    if (uri == null) return const SizedBox.shrink();
    return Image.network(uri.toString(), fit: BoxFit.cover);
  }

  Widget _controlButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed, {
    bool active = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon),
      iconSize: 24,
      color: active ? colors.primary : colors.onSurfaceVariant,
      onPressed: onPressed,
    );
  }

  Future<void> _showLyrics(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FutureBuilder<String?>(
          future: getSongLyrics(metadata.artist, metadata.title),
          builder: (context, snapshot) => Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Text(
                snapshot.data ?? 'Şarkı sözleri bulunamadı.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Color? _parseColor(String? value) {
    if (value == null) return null;
    final hex = value.replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final number = int.tryParse(normalized, radix: 16);
    return number == null ? null : Color(number);
  }
}

class _InteractiveFeedback extends StatefulWidget {
  const _InteractiveFeedback({required this.element, required this.child});

  final ElementConfig element;
  final Widget child;

  @override
  State<_InteractiveFeedback> createState() => _InteractiveFeedbackState();
}

class _InteractiveFeedbackState extends State<_InteractiveFeedback> {
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
              child: InkWell(
                onTap: () {},
                child: child,
              ),
            )
          : child,
    );
  }
}