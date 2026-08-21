import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/models/element_config.dart';
import 'package:musify/models/layout_slot.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/widgets/position_slider.dart';
import 'package:musify/widgets/playback_icon_button.dart';
import 'package:musify/widgets/queue_list_view.dart';

class DynamicLayoutPlayer extends StatelessWidget {
  const DynamicLayoutPlayer({required this.slot, required this.metadata, super.key});

  final LayoutSlot slot;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: slot.elements.map((element) {
            final x = element.x.clamp(0.0, constraints.maxWidth).toDouble();
            final y = element.y.clamp(0.0, constraints.maxHeight).toDouble();
            final width = element.width
              .clamp(1.0, constraints.maxWidth)
              .toDouble();
            final height = element.height
              .clamp(1.0, constraints.maxHeight)
              .toDouble();
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
}

class _DynamicElement extends StatelessWidget {
  const _DynamicElement({required this.element, required this.metadata});

  final ElementConfig element;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(element.colorHex);
    final action = _actionWidget(context);
    if (element.customImagePath == null || element.customImagePath!.isEmpty) {
      return action;
    }

    final path = element.customImagePath!;
    final image = path.startsWith('http://') || path.startsWith('https://')
        ? Image.network(path, fit: BoxFit.cover)
        : Image.file(File(path), fit: BoxFit.cover);
    return Stack(
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
    );
  }

  Widget _actionWidget(BuildContext context) {
    switch (element.actionId ?? element.id) {
      case 'PLAY_PAUSE':
        return PlaybackIconButton(
          iconColor: Theme.of(context).colorScheme.onPrimary,
          backgroundColor: Theme.of(context).colorScheme.primary,
        );
      case 'NEXT_TRACK':
        return _controlButton(
          context,
          FluentIcons.next_24_regular,
          audioHandler.skipToNext,
        );
      case 'PREVIOUS_TRACK':
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
        return const QueueWidget(isBottomSheet: true);
      case 'PROGRESS_BAR':
        return const PositionSlider();
      case 'SONG_TITLE':
        return Center(child: Text(metadata.title, textAlign: TextAlign.center));
      case 'ARTIST_NAME':
        return Center(child: Text(metadata.artist ?? '', textAlign: TextAlign.center));
      case 'ALBUM_ART':
        return _albumArt();
      case 'CURRENT_TIME':
        return StreamBuilder<PositionData>(
          stream: audioHandler.positionDataStream,
          builder: (_, snapshot) => Text(_formatDuration(snapshot.data?.position)),
        );
      case 'TOTAL_TIME':
        return StreamBuilder<PositionData>(
          stream: audioHandler.positionDataStream,
          builder: (_, snapshot) => Text(_formatDuration(snapshot.data?.duration)),
        );
      default:
        return const SizedBox.shrink();
    }
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
      color: active ? colors.primary : colors.onSurfaceVariant,
      onPressed: onPressed,
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