import 'package:flutter/material.dart';
import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';
// Add your other imports here

class SharedMediaPreview extends StatelessWidget {
  final List<dynamic> sharedMedia;
  final bool isSharing;

  const SharedMediaPreview({
    Key? key,
    required this.sharedMedia,
    required this.isSharing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isSharing || sharedMedia.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sharing ${sharedMedia.length} ${sharedMedia.length == 1 ? 'item' : 'items'}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            height: _getMediaHeight(),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sharedMedia.length,
              itemBuilder: (context, index) {
                final media = sharedMedia[index];
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: _buildMediaItem(media),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _getMediaHeight() {
    // Check if any media is text type to adjust height accordingly
    bool hasTextMedia = sharedMedia.any((media) => media.type == SharedMediaType.text);
    return hasTextMedia ? 140 : 120;
  }

  bool _isYouTubeLink(String text) {
    return text.contains(RegExp(r'(youtube\.com|youtu\.be)'));
  }

  String? _extractYouTubeId(String url) {
    RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    Match? match = regExp.firstMatch(url);
    return match?.group(1);
  }

  Widget _buildMediaItem(media) {
    if (media.type == SharedMediaType.text) {
      return _buildTextMediaItem(media);
    }

    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildMediaContent(media),
        ),
      ),
    );
  }

  Widget _buildTextMediaItem(media) {
    String content = media.path?.toString() ?? '';
    bool isYouTube = _isYouTubeLink(content);
    String? youtubeId = isYouTube ? _extractYouTubeId(content) : null;

    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 200, // Full width for text
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // YouTube preview if it's a YouTube link
              if (isYouTube && youtubeId != null)
                Container(
                  height: 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Image.network(
                        'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg',
                        width: double.infinity,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.red.shade50,
                          child: Icon(Icons.video_library,
                              color: Colors.red.shade400, size: 24),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'YouTube',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

              // Text content
              Container(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isYouTube ? Icons.link : Icons.text_fields,
                          color: Colors.blue.shade600,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isYouTube ? 'YouTube Link' : 'Text',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      content,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                      maxLines: isYouTube ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent(media) {
    switch (media.type) {
      case SharedMediaType.image:
        return Stack(
          children: [
            Image.file(
              File(media.path),
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 100,
                height: 100,
                color: Colors.grey.shade100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.red.shade400, size: 24),
                    SizedBox(height: 4),
                    Text('Error', style: TextStyle(fontSize: 10, color: Colors.red.shade400)),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'IMG',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );

      case SharedMediaType.video:
        return Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade50, Colors.red.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(Icons.videocam, color: Colors.red.shade600, size: 30),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'VID',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
              ),
            ),
          ],
        );

      default: // Document/File
        return Container(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.insert_drive_file, color: Colors.green.shade600, size: 24),
              ),
              SizedBox(height: 6),
              Expanded(
                child: Text(
                  _getFileName(media.path),
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              Text(
                _getFileSize(media.path),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
    }
  }

  String _getFileName(String path) {
    try {
      return path.split('/').last;
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getFileSize(String path) {
    try {
      if (File(path).existsSync()) {
        double sizeInKB = File(path).lengthSync() / 1024;
        return '${sizeInKB.toStringAsFixed(1)} KB';
      }
    } catch (e) {
    }
    return 'Unknown';
  }
}
