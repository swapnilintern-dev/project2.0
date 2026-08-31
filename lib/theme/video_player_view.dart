// =============================================================================
// MediCaPlus — Reusable promotional-video player
//
// A single, self-contained video player used everywhere a product's
// promotional video is shown (the marketing media editor preview + the customer
// product-details video). Plays either a network URL (uploaded video) or a
// local file (a freshly picked, not-yet-uploaded video).
//
// [VideoPlayerView] is an inline 16:9 player with a play/pause overlay and a
// scrub bar. [VideoPlayerScreen] wraps it in a full-screen page (tap the inline
// preview → open here). Controllers are always disposed — no leaks.
// =============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../vendor_registration_screen.dart' show AppColors;

/// Full-screen video page (black background) with a back button.
class VideoPlayerScreen extends StatelessWidget {
  const VideoPlayerScreen({super.key, this.networkUrl, this.filePath, this.title})
      : assert(networkUrl != null || filePath != null,
            'Provide a networkUrl or a filePath');

  final String? networkUrl;
  final String? filePath;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title ?? 'Video',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: Center(
        child: VideoPlayerView(
          networkUrl: networkUrl,
          filePath: filePath,
          autoPlay: true,
        ),
      ),
    );
  }
}

/// Inline 16:9 player. Lazily initializes and always disposes its controller.
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    super.key,
    this.networkUrl,
    this.filePath,
    this.autoPlay = false,
  }) : assert(networkUrl != null || filePath != null,
            'Provide a networkUrl or a filePath');

  final String? networkUrl;
  final String? filePath;
  final bool autoPlay;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = widget.networkUrl != null
          ? VideoPlayerController.networkUrl(Uri.parse(widget.networkUrl!))
          : VideoPlayerController.file(File(widget.filePath!));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      if (widget.autoPlay) await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white54, size: 36),
                SizedBox(height: 8),
                Text('Could not play this video',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
      child: GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(c),
            AnimatedOpacity(
              opacity: c.value.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 44),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primary,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
