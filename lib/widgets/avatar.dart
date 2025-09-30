// lib/widgets/avatar.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // For supabase client

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.imageUrl,
    required this.onUpload,
  });

  final String? imageUrl;
  final void Function(String imageUrl) onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: (imageUrl != null) ? NetworkImage(imageUrl!) : null,
              child: (imageUrl == null)
                  ? const Icon(Icons.person, size: 60, color: Colors.grey)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final imageFile =
                        await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 300,
                          maxHeight: 300
                        );
                    if (imageFile == null) {
                      return;
                    }
                    try {
                      final bytes = await imageFile.readAsBytes();
                      final fileExt = imageFile.path.split('.').last;
                      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
                      final filePath = fileName;

                      await supabase.storage.from('avatars').uploadBinary(
                            filePath,
                            bytes,
                            fileOptions: FileOptions(contentType: imageFile.mimeType),
                          );

                      final imageUrlResponse = supabase.storage
                          .from('avatars')
                          .getPublicUrl(filePath);
                          
                      onUpload(imageUrlResponse);

                    } on StorageException catch (error) {
                       if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error.message),
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                    } catch (error) {
                       if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Unexpected error occurred'),
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}