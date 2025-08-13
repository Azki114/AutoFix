// lib/screens/guide_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:video_player/video_player.dart'; // Import video_player

class GuideViewerScreen extends StatefulWidget {
  final String guideTitle;
  final String? guideAssetPath; // Not used in this version but kept for consistency
  final String? markdownContent;
  final String? videoAssetPath; // This parameter MUST be present

  const GuideViewerScreen({
    super.key,
    required this.guideTitle,
    this.guideAssetPath,
    this.markdownContent,
    this.videoAssetPath, // Make sure this line is here
  });

  @override
  State<GuideViewerScreen> createState() => _GuideViewerScreenState();
}

class _GuideViewerScreenState extends State<GuideViewerScreen> {
  late VideoPlayerController _videoPlayerController;
  Future<void>? _initializeVideoPlayerFuture;
  // Removed _isVideoPlaying as we'll use controller.value.isPlaying directly

  @override
  void initState() {
    super.initState();
    if (widget.videoAssetPath != null) {
      _videoPlayerController = VideoPlayerController.asset(widget.videoAssetPath!);
      _initializeVideoPlayerFuture = _videoPlayerController.initialize().then((_) {
        // Autoplay on load if desired, or just prepare the player
        // _videoPlayerController.play();
        // _videoPlayerController.setLooping(true);
        if (mounted) {
          setState(() {
            // Update state after initialization
          });
        }
      }).catchError((error) {
        // Handle video initialization errors
        print('Error initializing video: $error');
        if (mounted) {
          setState(() {
            // Set future to null to indicate an error, or show a fallback
            _initializeVideoPlayerFuture = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // Dispose the video controller if it was initialized
    if (widget.videoAssetPath != null) {
      _videoPlayerController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.guideTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      body: widget.videoAssetPath != null
          ? _buildVideoPlayerContent() // Show video if path is provided
          : _buildMarkdownContent(), // Otherwise, show markdown
    );
  }

  // Helper to build video player UI
  Widget _buildVideoPlayerContent() {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && _initializeVideoPlayerFuture != null) {
          // Check if there was an error during initialization
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Failed to load video. Please check the file and path.',
                style: TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _videoPlayerController.value.aspectRatio,
                    // Use ValueListenableBuilder to react to video state changes
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _videoPlayerController,
                      builder: (context, value, child) {
                        return Stack(
                          alignment: Alignment.bottomCenter,
                          children: <Widget>[
                            VideoPlayer(_videoPlayerController),
                            // Custom play/pause overlay
                            GestureDetector(
                              onTap: () {
                                value.isPlaying
                                    ? _videoPlayerController.pause()
                                    : _videoPlayerController.play();
                              },
                              child: Container(
                                color: value.isPlaying && !value.isBuffering // Only show overlay if paused or buffering
                                    ? Colors.transparent
                                    : Colors.black26,
                                child: value.isPlaying && !value.isBuffering
                                    ? const SizedBox.shrink() // Hide play icon if playing and not buffering
                                    : Center(
                                        child: value.isBuffering
                                            ? const CircularProgressIndicator(color: Colors.white) // Show buffering indicator
                                            : const Icon(
                                                Icons.play_circle_fill,
                                                color: Colors.white,
                                                size: 80.0,
                                              ),
                                      ),
                              ),
                            ),
                            VideoProgressIndicator(_videoPlayerController, allowScrubbing: true),
                          ],
                        );
                      }
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _videoPlayerController,
                  builder: (context, value, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            value.isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 36,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            value.isPlaying
                                ? _videoPlayerController.pause()
                                : _videoPlayerController.play();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop, size: 36, color: Colors.blue),
                          onPressed: () {
                            _videoPlayerController.pause();
                            _videoPlayerController.seekTo(Duration.zero);
                          },
                        ),
                        // Volume control
                        IconButton(
                          icon: Icon(
                            value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                            size: 36,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            _videoPlayerController.setVolume(value.volume == 0 ? 1.0 : 0.0);
                          },
                        ),
                      ],
                    );
                  }
                ),
              ),
            ],
          );
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else {
          // Fallback if video is null or initialization failed (and _initializeVideoPlayerFuture is null)
          return const Center(
            child: Text(
              'No video available for this guide or error loading video.',
              style: TextStyle(color: Colors.black54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }
      },
    );
  }

  // Helper to build markdown content UI
  Widget _buildMarkdownContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: widget.markdownContent != null
          ? MarkdownBody(data: widget.markdownContent!)
          : const Center(
              child: Text(
                'No content available for this guide.',
                style: TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),
            ),
    );
  }
}
