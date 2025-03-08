import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:beats_drive/services/album_art_service.dart';

class MetadataService {
  static final Map<String, Map<String, dynamic>> _metadataCache = {};
  static const int _maxCacheSize = 5000;
  static const int _headerSize = 64 * 1024;

  static Future<Map<String, dynamic>> getMetadata(String filePath) async {
    try {
      // Get album ID from the file path
      final albumId = await _getAlbumId(filePath);
      
      // Get album artwork if available
      Uint8List? albumArt;
      if (albumId != null) {
        albumArt = await AlbumArtService.getAlbumArt(albumId);
      }

      return {
        'title': _getFileName(filePath),
        'artist': 'Unknown Artist', // You can implement artist detection if needed
        'album': 'Unknown Album', // You can implement album detection if needed
        'albumArt': albumArt,
        'duration': 0, // You can implement duration detection if needed
      };
    } catch (e) {
      print('Error getting metadata: $e');
      return {
        'title': _getFileName(filePath),
        'artist': 'Unknown Artist',
        'album': 'Unknown Album',
        'albumArt': null,
        'duration': 0,
      };
    }
  }

  static String _getFileName(String filePath) {
    final parts = filePath.split('/');
    return parts.last;
  }

  static Future<String?> _getAlbumId(String filePath) async {
    try {
      final result = await const MethodChannel('com.beats_drive/media_store')
          .invokeMethod('getAlbumId', {'filePath': filePath});
      return result as String?;
    } catch (e) {
      print('Error getting album ID: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getMetadataBatch(List<String> filePaths) async {
    // Process files in parallel with a maximum of 50 concurrent operations
    final futures = <Future<Map<String, dynamic>>>[];
    for (var i = 0; i < filePaths.length; i += 50) {
      final batch = filePaths.skip(i).take(50).toList();
      futures.addAll(batch.map((path) => getMetadata(path)));
    }
    return Future.wait(futures);
  }

  static void _readMP3Metadata(List<int> bytes, Map<String, dynamic> result, String nameWithoutExt) {
    // Look for ID3v2 header
    if (bytes.length >= 10 && 
        bytes[0] == 0x49 && // 'I'
        bytes[1] == 0x44 && // 'D'
        bytes[2] == 0x33) { // '3'
      
      // ID3v2 header found
      final version = bytes[3];
      final flags = bytes[4];
      final size = (bytes[5] << 21) | (bytes[6] << 14) | (bytes[7] << 7) | bytes[8];
      
      debugPrint('Found ID3v2.$version tag, size: $size bytes');
      
      // Read ID3v2 frames
      var offset = 10;
      while (offset < size + 10 && offset < bytes.length - 10) {
        final frameId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final frameSize = (bytes[offset + 4] << 24) | 
                        (bytes[offset + 5] << 16) | 
                        (bytes[offset + 6] << 8) | 
                        bytes[offset + 7];
        final frameFlags = (bytes[offset + 8] << 8) | bytes[offset + 9];
        
        if (frameSize > 0 && frameSize < bytes.length - offset) {
          final frameData = bytes.sublist(offset + 10, offset + 10 + frameSize);
          _processID3v2Frame(frameId, frameData, result);
        }
        
        offset += 10 + frameSize;
      }
    }

    // Look for ID3v1 tag at the end
    if (bytes.length >= 128) {
      final id3v1Offset = bytes.length - 128;
      if (bytes[id3v1Offset] == 0x54 && // 'T'
          bytes[id3v1Offset + 1] == 0x41 && // 'A'
          bytes[id3v1Offset + 2] == 0x47) { // 'G'
        
        // Only use ID3v1 if we haven't found better metadata
        if (result['title'] == nameWithoutExt) {
          result['title'] = String.fromCharCodes(bytes.sublist(id3v1Offset + 3, id3v1Offset + 33)).trim();
          result['artist'] = String.fromCharCodes(bytes.sublist(id3v1Offset + 33, id3v1Offset + 63)).trim();
          result['album'] = String.fromCharCodes(bytes.sublist(id3v1Offset + 63, id3v1Offset + 93)).trim();
          result['year'] = String.fromCharCodes(bytes.sublist(id3v1Offset + 93, id3v1Offset + 97)).trim();
          result['comment'] = String.fromCharCodes(bytes.sublist(id3v1Offset + 97, id3v1Offset + 126)).trim();
          result['track'] = bytes[id3v1Offset + 126];
          result['genre'] = _getGenreName(bytes[id3v1Offset + 127]);
        }
      }
    }
  }

  static void _processID3v2Frame(String frameId, List<int> frameData, Map<String, dynamic> result) {
    switch (frameId) {
      case 'TIT2': // Title
        result['title'] = _decodeText(frameData);
        break;
      case 'TPE1': // Artist
        result['artist'] = _decodeText(frameData);
        break;
      case 'TALB': // Album
        result['album'] = _decodeText(frameData);
        break;
      case 'TYER': // Year
        result['year'] = _decodeText(frameData);
        break;
      case 'TCON': // Genre
        result['genre'] = _decodeText(frameData);
        break;
      case 'COMM': // Comment
        result['comment'] = _decodeText(frameData);
        break;
      case 'TRCK': // Track number
        result['track'] = int.tryParse(_decodeText(frameData)) ?? 0;
        break;
      case 'APIC': // Picture
        final picture = _extractPicture(frameData);
        if (picture != null) {
          result['albumArt'] = picture;
          result['mimeType'] = _getMimeType(frameData);
        }
        break;
    }
  }

  static String? _getMimeType(List<int> frameData) {
    if (frameData.length < 2) return null;
    
    final textEncoding = frameData[0];
    final mimeTypeLength = frameData.indexOf(0, 1);
    if (mimeTypeLength == -1) return null;
    
    return String.fromCharCodes(frameData.sublist(1, mimeTypeLength));
  }

  static Uint8List? _extractPicture(List<int> frameData) {
    try {
      if (frameData.length < 2) {
        debugPrint('Picture frame data too short: ${frameData.length} bytes');
        return null;
      }
      
      final textEncoding = frameData[0];
      final mimeTypeLength = frameData.indexOf(0, 1);
      if (mimeTypeLength == -1) {
        debugPrint('No null terminator found for MIME type');
        return null;
      }
      
      final mimeType = String.fromCharCodes(frameData.sublist(1, mimeTypeLength));
      debugPrint('Found picture with MIME type: $mimeType');
      
      if (!mimeType.startsWith('image/')) {
        debugPrint('Invalid MIME type for picture: $mimeType');
        return null;
      }
      
      final pictureType = frameData[mimeTypeLength + 1];
      final descriptionLength = frameData.indexOf(0, mimeTypeLength + 2);
      if (descriptionLength == -1) {
        debugPrint('No null terminator found for description');
        return null;
      }
      
      final pictureData = frameData.sublist(descriptionLength + 1);
      debugPrint('Extracted picture data: ${pictureData.length} bytes');
      
      // Basic validation of image data
      if (pictureData.length < 4) {
        debugPrint('Picture data too short: ${pictureData.length} bytes');
        return null;
      }
      
      // Check for common image format signatures
      final isJPEG = pictureData[0] == 0xFF && pictureData[1] == 0xD8;
      final isPNG = pictureData[0] == 0x89 && pictureData[1] == 0x50;
      
      if (!isJPEG && !isPNG) {
        debugPrint('Unsupported image format in ID3v2 frame. First bytes: ${pictureData[0].toRadixString(16)}, ${pictureData[1].toRadixString(16)}');
        return null;
      }
      
      return Uint8List.fromList(pictureData);
    } catch (e, stackTrace) {
      debugPrint('Error extracting picture: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  static void _readM4AMetadata(List<int> headerBytes, Map<String, dynamic> result) {
    // Look for ftyp box at the start
    if (headerBytes.length >= 8 && 
        headerBytes[4] == 0x66 && // 'f'
        headerBytes[5] == 0x74 && // 't'
        headerBytes[6] == 0x79 && // 'y'
        headerBytes[7] == 0x70) { // 'p'
      
      // Look for metadata atoms in header
      var offset = 0;
      while (offset < headerBytes.length - 8) {
        final size = (headerBytes[offset] << 24) | 
                    (headerBytes[offset + 1] << 16) | 
                    (headerBytes[offset + 2] << 8) | 
                    headerBytes[offset + 3];
        final type = String.fromCharCodes(headerBytes.sublist(offset + 4, offset + 8));
        
        if (size > 0 && size <= headerBytes.length - offset) {
          switch (type) {
            case 'meta':
              _readM4AMetaAtom(headerBytes.sublist(offset + 8, offset + size), result);
              break;
            case 'udta':
              _readM4AUserDataAtom(headerBytes.sublist(offset + 8, offset + size), result);
              break;
          }
        }
        
        offset += size;
      }
    }
  }

  static void _readM4AMetaAtom(List<int> data, Map<String, dynamic> result) {
    var offset = 0;
    while (offset < data.length - 8) {
      final size = (data[offset] << 24) | 
                  (data[offset + 1] << 16) | 
                  (data[offset + 2] << 8) | 
                  data[offset + 3];
      final type = String.fromCharCodes(data.sublist(offset + 4, offset + 8));
      
      if (size > 0 && size <= data.length - offset) {
        final atomData = data.sublist(offset + 8, offset + size);
        switch (type) {
          case '©nam': // Title
            result['title'] = _decodeM4AText(atomData);
            break;
          case '©ART': // Artist
            result['artist'] = _decodeM4AText(atomData);
            break;
          case '©alb': // Album
            result['album'] = _decodeM4AText(atomData);
            break;
          case '©day': // Year
            result['year'] = _decodeM4AText(atomData);
            break;
          case '©gen': // Genre
            result['genre'] = _decodeM4AText(atomData);
            break;
          case '©cmt': // Comment
            result['comment'] = _decodeM4AText(atomData);
            break;
          case '©trk': // Track
            result['track'] = int.tryParse(_decodeM4AText(atomData)) ?? 0;
            break;
          case 'covr': // Cover art
            result['albumArt'] = _extractM4APicture(atomData);
            break;
        }
      }
      
      offset += size;
    }
  }

  static void _readM4AUserDataAtom(List<int> data, Map<String, dynamic> result) {
    // Similar to meta atom but with different structure
    // Implementation depends on specific M4A format version
  }

  static void _readFLACMetadata(List<int> headerBytes, Map<String, dynamic> result) {
    // Look for FLAC header
    if (headerBytes.length >= 4 && 
        headerBytes[0] == 0x66 && // 'f'
        headerBytes[1] == 0x4C && // 'L'
        headerBytes[2] == 0x61 && // 'a'
        headerBytes[3] == 0x43) { // 'C'
      
      // Read metadata blocks from header
      var offset = 4;
      while (offset < headerBytes.length - 4) {
        final isLast = (headerBytes[offset] & 0x80) != 0;
        final blockType = headerBytes[offset] & 0x7F;
        final blockSize = (headerBytes[offset + 1] << 16) | 
                         (headerBytes[offset + 2] << 8) | 
                         headerBytes[offset + 3];
        
        if (blockSize > 0 && offset + 4 + blockSize <= headerBytes.length) {
          final blockData = headerBytes.sublist(offset + 4, offset + 4 + blockSize);
          _processFLACMetadataBlock(blockType, blockData, result);
        }
        
        offset += 4 + blockSize;
        if (isLast) break;
      }
    }
  }

  static void _processFLACMetadataBlock(int blockType, List<int> blockData, Map<String, dynamic> result) {
    switch (blockType) {
      case 4: // Vorbis Comment
        _readVorbisComment(blockData, result);
        break;
      case 6: // Picture
        result['albumArt'] = _extractFLACPicture(blockData);
        break;
    }
  }

  static void _readVorbisComment(List<int> data, Map<String, dynamic> result) {
    // Skip vendor string length and vendor string
    var offset = 4;
    final vendorLength = (data[0] << 0) | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
    offset += 4 + vendorLength;
    
    // Read comment count
    final commentCount = (data[offset] << 0) | (data[offset + 1] << 8) | 
                        (data[offset + 2] << 16) | (data[offset + 3] << 24);
    offset += 4;
    
    // Read comments
    for (var i = 0; i < commentCount && offset < data.length - 4; i++) {
      final commentLength = (data[offset] << 0) | (data[offset + 1] << 8) | 
                          (data[offset + 2] << 16) | (data[offset + 3] << 24);
      offset += 4;
      
      if (offset + commentLength <= data.length) {
        final comment = String.fromCharCodes(data.sublist(offset, offset + commentLength));
        final parts = comment.split('=');
        if (parts.length == 2) {
          final key = parts[0].toUpperCase();
          final value = parts[1];
          
          switch (key) {
            case 'TITLE':
              result['title'] = value;
              break;
            case 'ARTIST':
              result['artist'] = value;
              break;
            case 'ALBUM':
              result['album'] = value;
              break;
            case 'DATE':
              result['year'] = value;
              break;
            case 'GENRE':
              result['genre'] = value;
              break;
            case 'DESCRIPTION':
              result['comment'] = value;
              break;
            case 'TRACKNUMBER':
              result['track'] = int.tryParse(value) ?? 0;
              break;
          }
        }
      }
      
      offset += commentLength;
    }
  }

  static Uint8List? _extractFLACPicture(List<int> data) {
    try {
      if (data.length < 32) {
        debugPrint('FLAC picture data too short: ${data.length} bytes');
        return null;
      }
      
      // Skip picture type
      var offset = 4;
      
      // Read MIME type length and MIME type
      final mimeTypeLength = (data[offset] << 24) | (data[offset + 1] << 16) | 
                           (data[offset + 2] << 8) | data[offset + 3];
      offset += 4;
      
      if (offset + mimeTypeLength > data.length) {
        debugPrint('Invalid MIME type length: $mimeTypeLength');
        return null;
      }
      
      final mimeType = String.fromCharCodes(data.sublist(offset, offset + mimeTypeLength));
      debugPrint('Found FLAC picture with MIME type: $mimeType');
      
      if (!mimeType.startsWith('image/')) {
        debugPrint('Invalid MIME type for FLAC picture: $mimeType');
        return null;
      }
      
      offset += mimeTypeLength;
      
      // Skip description length and description
      final descriptionLength = (data[offset] << 24) | (data[offset + 1] << 16) | 
                              (data[offset + 2] << 8) | data[offset + 3];
      offset += 4 + descriptionLength;
      
      // Skip width, height, color depth, color index count
      offset += 16;
      
      // Read picture data length
      final pictureLength = (data[offset] << 24) | (data[offset + 1] << 16) | 
                          (data[offset + 2] << 8) | data[offset + 3];
      offset += 4;
      
      debugPrint('FLAC picture data length: $pictureLength bytes');
      
      if (offset + pictureLength > data.length) {
        debugPrint('Invalid FLAC picture data length: $pictureLength');
        return null;
      }
      
      final pictureData = data.sublist(offset, offset + pictureLength);
      
      // Basic validation of image data
      if (pictureData.length < 4) {
        debugPrint('FLAC picture data too short: ${pictureData.length} bytes');
        return null;
      }
      
      // Check for common image format signatures
      final isJPEG = pictureData[0] == 0xFF && pictureData[1] == 0xD8;
      final isPNG = pictureData[0] == 0x89 && pictureData[1] == 0x50;
      
      if (!isJPEG && !isPNG) {
        debugPrint('Unsupported image format in FLAC file. First bytes: ${pictureData[0].toRadixString(16)}, ${pictureData[1].toRadixString(16)}');
        return null;
      }
      
      return Uint8List.fromList(pictureData);
    } catch (e, stackTrace) {
      debugPrint('Error extracting FLAC picture: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  static void _readWAVMetadata(List<int> headerBytes, Map<String, dynamic> result) {
    // WAV files typically store metadata in the LIST chunk
    if (headerBytes.length >= 12 && 
        headerBytes[0] == 0x52 && // 'R'
        headerBytes[1] == 0x49 && // 'I'
        headerBytes[2] == 0x46 && // 'F'
        headerBytes[3] == 0x46) { // 'F'
      
      var offset = 12;
      while (offset < headerBytes.length - 8) {
        final chunkId = String.fromCharCodes(headerBytes.sublist(offset, offset + 4));
        final chunkSize = (headerBytes[offset + 4] << 0) | 
                         (headerBytes[offset + 5] << 8) | 
                         (headerBytes[offset + 6] << 16) | 
                         (headerBytes[offset + 7] << 24);
        
        if (chunkId == 'LIST' && offset + 8 + chunkSize <= headerBytes.length) {
          final listData = headerBytes.sublist(offset + 8, offset + 8 + chunkSize);
          _readWAVListChunk(listData, result);
        }
        
        offset += 8 + chunkSize;
      }
    }
  }

  static void _readWAVListChunk(List<int> data, Map<String, dynamic> result) {
    if (data.length < 4) return;
    
    final listType = String.fromCharCodes(data.sublist(0, 4));
    if (listType == 'INFO') {
      var offset = 4;
      while (offset < data.length - 8) {
        final subChunkId = String.fromCharCodes(data.sublist(offset, offset + 4));
        final subChunkSize = (data[offset + 4] << 0) | 
                           (data[offset + 5] << 8) | 
                           (data[offset + 6] << 16) | 
                           (data[offset + 7] << 24);
        
        if (offset + 8 + subChunkSize <= data.length) {
          final subChunkData = data.sublist(offset + 8, offset + 8 + subChunkSize);
          _processWAVInfoSubChunk(subChunkId, subChunkData, result);
        }
        
        offset += 8 + subChunkSize;
      }
    }
  }

  static void _processWAVInfoSubChunk(String chunkId, List<int> data, Map<String, dynamic> result) {
    final value = String.fromCharCodes(data).trim();
    
    switch (chunkId) {
      case 'INAM': // Title
        result['title'] = value;
        break;
      case 'IART': // Artist
        result['artist'] = value;
        break;
      case 'IPRD': // Album
        result['album'] = value;
        break;
      case 'ICRD': // Year
        result['year'] = value;
        break;
      case 'IGNR': // Genre
        result['genre'] = value;
        break;
      case 'ICMT': // Comment
        result['comment'] = value;
        break;
      case 'ITRK': // Track
        result['track'] = int.tryParse(value) ?? 0;
        break;
    }
  }

  static void _readOGGMetadata(List<int> headerBytes, Map<String, dynamic> result) {
    // OGG files store metadata in Vorbis Comments
    if (headerBytes.length >= 4 && 
        headerBytes[0] == 0x4F && // 'O'
        headerBytes[1] == 0x67 && // 'g'
        headerBytes[2] == 0x67 && // 'g'
        headerBytes[3] == 0x53) { // 'S'
      
      // Look for Vorbis Comments in header
      var offset = 4;
      while (offset < headerBytes.length - 8) {
        final segmentSize = headerBytes[offset];
        if (offset + 1 + segmentSize <= headerBytes.length) {
          final segmentData = headerBytes.sublist(offset + 1, offset + 1 + segmentSize);
          _readVorbisComment(segmentData, result);
        }
        offset += 1 + segmentSize;
      }
    }
  }

  static String _decodeText(List<int> data) {
    if (data.isEmpty) return '';
    
    // Get text encoding from first byte
    final encoding = data[0];
    final textData = data.sublist(1);
    
    try {
      switch (encoding) {
        case 0: // ISO-8859-1
          return String.fromCharCodes(textData);
        case 1: // UTF-16 with BOM
          if (textData.length >= 2) {
            final bom = (textData[0] << 8) | textData[1];
            if (bom == 0xFEFF) { // UTF-16BE
              return String.fromCharCodes(textData.sublist(2), 0, textData.length - 2);
            } else if (bom == 0xFFFE) { // UTF-16LE
              final bytes = <int>[];
              for (var i = 2; i < textData.length; i += 2) {
                if (i + 1 < textData.length) {
                  bytes.add(textData[i + 1]);
                  bytes.add(textData[i]);
                }
              }
              return String.fromCharCodes(bytes);
            }
          }
          return String.fromCharCodes(textData);
        case 2: // UTF-16BE without BOM
          return String.fromCharCodes(textData);
        case 3: // UTF-8
          return String.fromCharCodes(textData);
        default:
          // Try UTF-8 first, then fallback to ISO-8859-1
          try {
            return String.fromCharCodes(textData);
          } catch (e) {
            return String.fromCharCodes(textData);
          }
      }
    } catch (e) {
      debugPrint('Error decoding text: $e');
      return '';
    }
  }

  static String _decodeM4AText(List<int> data) {
    if (data.length < 8) return '';
    
    // Skip version and flags
    var offset = 8;
    
    // Skip language code
    offset += 4;
    
    // Read text length
    final textLength = (data[offset] << 24) | 
                      (data[offset + 1] << 16) | 
                      (data[offset + 2] << 8) | 
                      data[offset + 3];
    offset += 4;
    
    if (offset + textLength <= data.length) {
      return String.fromCharCodes(data.sublist(offset, offset + textLength));
    }
    
    return '';
  }

  static Uint8List? _extractM4APicture(List<int> data) {
    try {
      if (data.length < 8) {
        debugPrint('M4A picture data too short: ${data.length} bytes');
        return null;
      }
      
      // Skip version and flags
      var offset = 4;
      
      // Read data size
      final dataSize = (data[offset] << 24) | 
                      (data[offset + 1] << 16) | 
                      (data[offset + 2] << 8) | 
                      data[offset + 3];
      offset += 4;
      
      debugPrint('M4A picture data size: $dataSize bytes');
      
      // Validate data size
      if (dataSize <= 0 || dataSize > data.length - offset) {
        debugPrint('Invalid M4A picture data size: $dataSize (total data length: ${data.length})');
        return null;
      }
      
      // Extract picture data
      final pictureData = data.sublist(offset, offset + dataSize);
      debugPrint('Extracted M4A picture data: ${pictureData.length} bytes');
      
      // Basic validation of image data
      if (pictureData.length < 4) {
        debugPrint('M4A picture data too short: ${pictureData.length} bytes');
        return null;
      }
      
      // Check for common image format signatures
      final isJPEG = pictureData[0] == 0xFF && pictureData[1] == 0xD8;
      final isPNG = pictureData[0] == 0x89 && pictureData[1] == 0x50;
      
      if (!isJPEG && !isPNG) {
        debugPrint('Unsupported image format in M4A file. First bytes: ${pictureData[0].toRadixString(16)}, ${pictureData[1].toRadixString(16)}');
        return null;
      }
      
      return Uint8List.fromList(pictureData);
    } catch (e, stackTrace) {
      debugPrint('Error extracting M4A picture: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  static String _getGenreName(int index) {
    // Standard ID3v1 genres
    const genres = [
      'Blues', 'Classic Rock', 'Country', 'Dance', 'Disco', 'Funk', 'Grunge',
      'Hip-Hop', 'Jazz', 'Metal', 'New Age', 'Oldies', 'Other', 'Pop', 'R&B',
      'Rap', 'Reggae', 'Rock', 'Techno', 'Industrial', 'Alternative', 'Ska',
      'Death Metal', 'Pranks', 'Soundtrack', 'Euro-Techno', 'Ambient',
      'Trip-Hop', 'Vocal', 'Jazz+Funk', 'Fusion', 'Trance', 'Classical',
      'Instrumental', 'Acid', 'House', 'Game', 'Sound Clip', 'Gospel',
      'Noise', 'Alternative Rock', 'Bass', 'Soul', 'Punk', 'Space',
      'Meditative', 'Instrumental Pop', 'Instrumental Rock', 'Ethnic',
      'Gothic', 'Darkwave', 'Techno-Industrial', 'Electronic', 'Pop-Folk',
      'Eurodance', 'Dream', 'Southern Rock', 'Comedy', 'Cult', 'Gangsta',
      'Top 40', 'Christian Rap', 'Pop/Funk', 'Jungle', 'Native American',
      'Cabaret', 'New Wave', 'Psychadelic', 'Rave', 'Showtunes', 'Trailer',
      'Lo-Fi', 'Tribal', 'Acid Punk', 'Acid Jazz', 'Polka', 'Retro',
      'Musical', 'Rock & Roll', 'Hard Rock', 'Folk', 'Folk-Rock',
      'National Folk', 'Swing', 'Fast Fusion', 'Bebob', 'Latin', 'Revival',
      'Celtic', 'Bluegrass', 'Avantgarde', 'Gothic Rock', 'Progressive Rock',
      'Psychedelic Rock', 'Symphonic Rock', 'Slow Rock', 'Big Band',
      'Chorus', 'Easy Listening', 'Acoustic', 'Humour', 'Speech', 'Chanson',
      'Opera', 'Chamber Music', 'Sonata', 'Symphony', 'Booty Bass', 'Primus',
      'Porn Groove', 'Satire', 'Slow Jam', 'Club', 'Tango', 'Samba',
      'Folklore', 'Ballad', 'Power Ballad', 'Rhythmic Soul', 'Freestyle',
      'Duet', 'Punk Rock', 'Drum Solo', 'A capella', 'Euro-House',
      'Dance Hall', 'Goa', 'Drum & Bass', 'Club-House', 'Hardcore',
      'Terror', 'Indie', 'BritPop', 'Negerpunk', 'Polsk Punk', 'Beat',
      'Christian Gangsta Rap', 'Heavy Metal', 'Black Metal', 'Crossover',
      'Contemporary Christian', 'Christian Rock', 'Merengue', 'Salsa',
      'Thrash Metal', 'Anime', 'Jpop', 'Synthpop'
    ];
    
    return index < genres.length ? genres[index] : '';
  }
} 