// lib/screens/guide_viewer_screen.dart (Flexible Content Loading)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // For loading local assets
import 'package:flutter_markdown/flutter_markdown.dart'; // For rendering Markdown

class GuideViewerScreen extends StatefulWidget {
  final String guideTitle;
  final String? guideAssetPath; // Now nullable
  final String? markdownContent; // New: optional direct markdown content

  const GuideViewerScreen({
    Key? key,
    required this.guideTitle,
    this.guideAssetPath, // Make it optional
    this.markdownContent, // Make it optional
  }) : super(key: key);

  @override
  _GuideViewerScreenState createState() => _GuideViewerScreenState();
}

class _GuideViewerScreenState extends State<GuideViewerScreen> {
  String _displayContent = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGuideContent();
  }

  Future<void> _loadGuideContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (widget.markdownContent != null) {
      // If direct content is provided, use it immediately
      setState(() {
        _displayContent = widget.markdownContent!;
        _isLoading = false;
      });
      print('DEBUG: Loaded guide content directly from widget property.');
    } else if (widget.guideAssetPath != null) {
      // Otherwise, try to load from asset path
      try {
        final String content = await rootBundle.loadString(widget.guideAssetPath!);
        setState(() {
          _displayContent = content;
          _isLoading = false;
        });
        print('DEBUG: Loaded guide content from asset: ${widget.guideAssetPath}');
      } catch (e) {
        setState(() {
          _error = 'Failed to load guide from asset: $e';
          _isLoading = false;
        });
        print('ERROR: Failed to load guide from asset: ${widget.guideAssetPath} - $e');
      }
    } else {
      // Neither assetPath nor markdownContent was provided
      setState(() {
        _error = 'No guide content or asset path provided.';
        _isLoading = false;
      });
      print('ERROR: GuideViewerScreen received no content or asset path.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.guideTitle),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Markdown(
                  data: _displayContent,
                  padding: const EdgeInsets.all(16.0),
                  styleSheet: MarkdownStyleSheet(
                    h1: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold),
                    h2: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    p: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black87, height: 1.5),
                  ),
                ),
    );
  }
}
