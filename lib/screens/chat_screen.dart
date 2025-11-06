import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart'; // Needed for getting user location for requests
import 'package:latlong2/latlong.dart'; // Needed for LatLng type
import 'package:autofix/screens/call_screen.dart'; // --- NEW: Import the call screen ---

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatPartnerName;
  final String currentUserId;
  final String chatPartnerId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatPartnerName,
    required this.currentUserId,
    required this.chatPartnerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  bool _isUploadingMedia = false;
  String? _currentUserRole; // State to hold the user's role
  LatLng? _currentUserLocation; // State for user's location

  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, Future<void>> _initializeVideoPlayerFutures = {};

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
    _loadUserRole(); // Fetch the user's role when the screen loads
  }

  void _subscribeToMessages() {
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.chatId)
        .order('created_at', ascending: true);
  }

  Future<void> _loadUserRole() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _currentUserRole = response['role'];
        });
      }
    } catch (e) {
      debugPrint("Error loading user role: $e");
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _formatMessageTime(String isoDateString) {
    try {
      final DateTime dateTime = DateTime.parse(isoDateString).toLocal();
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    XFile? mediaFile;
    if (isVideo) {
      mediaFile = await _picker.pickVideo(source: source);
    } else {
      mediaFile = await _picker.pickImage(source: source);
    }

    if (mediaFile != null) {
      await _uploadAndSendMessage(File(mediaFile.path), isVideo: isVideo);
    } else if (mounted) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('No media selected.')),
      );
    }
  }

  Future<void> _uploadAndSendMessage(File mediaFile, {required bool isVideo}) async {
    setState(() {
      _isUploadingMedia = true;
    });

    try {
      final String fileExtension = mediaFile.path.split('.').last;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String path = 'chats/${widget.chatId}/${widget.currentUserId}/$timestamp.$fileExtension';

      await supabase.storage
          .from('chat_media')
          .upload(path, mediaFile,
              fileOptions: FileOptions(
                  upsert: true,
                  contentType: isVideo ? 'video/$fileExtension' : 'image/$fileExtension'));

      final String publicUrl = supabase.storage.from('chat_media').getPublicUrl(path);

      await _sendMessage(
        content: isVideo ? 'Video 📹' : 'Image 📸',
        messageType: isVideo ? 'video' : 'image',
        mediaUrl: publicUrl,
      );
    } on StorageException catch (e) {
      if (!mounted) return;
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error uploading media: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('An unexpected error occurred during media upload: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
        });
      }
    }
  }

  Future<void> _sendMessage({
    String? content,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    final text = _messageController.text.trim();

    if (messageType == 'text' && text.isEmpty) return;
    if (messageType != 'text' && (mediaUrl == null || mediaUrl.isEmpty)) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Media URL is missing for media message.')),
      );
      return;
    }

    if (messageType == 'text') {
      _messageController.clear();
    }

    try {
      await supabase.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': widget.currentUserId,
        'receiver_id': widget.chatPartnerId,
        'content': content ?? text,
        'message_type': messageType,
        'media_url': mediaUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      await supabase.from('chats').update({
        'last_message_at': DateTime.now().toIso8601String(),
        'last_message_content': content ?? text,
      }).eq('id', widget.chatId);

    } on PostgrestException catch (e) {
      if (!mounted) return;
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error sending message: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
      );
    }
  }

  void _showImageSourceSelectionSheet({required bool isVideo}) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(isVideo ? 'Pick Video from Gallery' : 'Pick Image from Gallery'),
                onTap: () {
                  Navigator.pop(bc);
                  _pickMedia(ImageSource.gallery, isVideo: isVideo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(isVideo ? 'Capture Video from Camera' : 'Capture Image from Camera'),
                onTap: () {
                  Navigator.pop(bc);
                  _pickMedia(ImageSource.camera, isVideo: isVideo);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _clearConversation() async {
    bool confirmClear = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Conversation?'),
          content: const Text('Are you sure you want to permanently delete all messages in this chat for both users? This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirmClear) return;

    try {
      await supabase.from('messages').delete().eq('chat_id', widget.chatId);
      await supabase.from('chats').update({
        'last_message_content': 'Conversation deleted',
        'last_message_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.chatId);

      if (!mounted) return;
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Conversation deleted successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error deleting conversation: ${e.toString()}')),
      );
    }
  }

  // --- NEW: Service 
  //t Logic ---

  Future<void> _getCurrentLocationForRequest() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
          throw Exception('Location permissions are denied.');
        }
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if(mounted){
        setState(() {
           _currentUserLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      if(mounted){
        snackbarKey.currentState?.showSnackBar(SnackBar(content: Text('Could not get location: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _requestServiceFromChat() async {
    await _getCurrentLocationForRequest();
    if (_currentUserLocation == null) {
        snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Could not get your location to make a request.'), backgroundColor: Colors.red));
        return;
    }

    final notes = await _showNotesDialog();
    if (notes == null) return; // User cancelled

    try {
      await supabase.from('service_requests').insert({
        'requester_id': widget.currentUserId,
        'mechanic_id': widget.chatPartnerId, // Assign directly to this mechanic
        'requester_location': 'POINT(${_currentUserLocation!.longitude} ${_currentUserLocation!.latitude})',
        'requester_notes': notes,
        'status': 'pending', // Starts as pending for the mechanic to accept
      });
      if(mounted){
         snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Service request sent directly to this mechanic!'), backgroundColor: Colors.green));
      }
    } catch (e) {
       if(mounted){
        snackbarKey.currentState?.showSnackBar(SnackBar(content: Text('Failed to send request: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<String?> _showNotesDialog() {
    final notesController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add Notes for Mechanic'),
          content: TextField(
            controller: notesController,
            decoration: const InputDecoration(hintText: 'Describe your vehicle issue...'),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('Send Request'),
              onPressed: () => Navigator.of(dialogContext).pop(notesController.text.trim()),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chatPartnerName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
        actions: [
          // --- NEW: Conditional "Request Service" Button ---
          if (_currentUserRole == 'driver')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                onPressed: _requestServiceFromChat,
                icon: const Icon(Icons.build, size: 18),
                label: const Text('Request Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          
          // --- NEW: Audio Call Button ---
          IconButton(
            icon: const Icon(Icons.call, color: Colors.blue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallScreen(
                    // Use the chatId as the unique call room ID
                    callID: widget.chatId,
                  ),
                ),
              );
            },
            tooltip: 'Start Audio Call',
          ),
          // --- End Call Button ---

          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _clearConversation,
            tooltip: 'Delete Conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Connection timed out. Please check your network.',
                          style: TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _subscribeToMessages();
                            });
                          },
                          child: const Text('Reconnect'),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('Say hello! No messages yet.'));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser = message['sender_id'] == widget.currentUserId;
                    final messageType = message['message_type'] as String? ?? 'text';
                    final mediaUrl = message['media_url'] as String?;
                    final messageId = message['id'].toString();

                    if (messageType == 'video' && mediaUrl != null && !_videoControllers.containsKey(messageId)) {
                      final controller = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
                      _videoControllers[messageId] = controller;
                      _initializeVideoPlayerFutures[messageId] = controller.initialize();
                    }

                    return Align(
                      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? Colors.blue[100] : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(isCurrentUser ? 16 : 0),
                            topRight: Radius.circular(isCurrentUser ? 0 : 16),
                            bottomLeft: const Radius.circular(16),
                            bottomRight: const Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (messageType == 'image' && mediaUrl != null)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.6,
                                ),
                                child: Image.network(
                                  mediaUrl,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.broken_image, color: Colors.red);
                                  },
                                ),
                              )
                            else if (messageType == 'video' && mediaUrl != null)
                              FutureBuilder(
                                future: _initializeVideoPlayerFutures[messageId],
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.done) {
                                    final VideoPlayerController videoController = _videoControllers[messageId]!;
                                    return ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                                        maxHeight: 250,
                                      ),
                                      child: AspectRatio(
                                        aspectRatio: videoController.value.aspectRatio,
                                        child: Stack(
                                          alignment: Alignment.bottomCenter,
                                          children: <Widget>[
                                            VideoPlayer(videoController),
                                            VideoProgressIndicator(videoController, allowScrubbing: true),
                                            Center(
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    videoController.value.isPlaying
                                                        ? videoController.pause()
                                                        : videoController.play();
                                                  });
                                                },
                                                child: CircleAvatar(
                                                  radius: 25,
                                                  backgroundColor: Colors.black.withOpacity(0.6),
                                                  child: Icon(
                                                    videoController.value.isPlaying
                                                        ? Icons.pause
                                                        : Icons.play_arrow,
                                                    color: Colors.white,
                                                    size: 30,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      width: MediaQuery.of(context).size.width * 0.6,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(color: Colors.white),
                                      ),
                                    );
                                  }
                                },
                              )
                            else
                              Text(
                                message['content'],
                                style: const TextStyle(fontSize: 16),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              _formatMessageTime(message['created_at']),
                              style: const TextStyle(fontSize: 10, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploadingMedia)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Colors.blue),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  heroTag: 'send_button_tag',
                  onPressed: () => _sendMessage(),
                  mini: true,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
                const SizedBox(width: 4.0),
                FloatingActionButton(
                  heroTag: 'image_button_tag',
                  onPressed: () => _showImageSourceSelectionSheet(isVideo: false),
                  mini: true,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.image, color: Colors.white),
                ),
                 const SizedBox(width: 4.0),
                FloatingActionButton(
                  heroTag: 'video_button_tag',
                  onPressed: () => _showImageSourceSelectionSheet(isVideo: true),
                  mini: true,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.video_library, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

