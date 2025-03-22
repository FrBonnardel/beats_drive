import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'music_models.g.dart';

class Album {
  final String id;
  final String name;
  final String artist;
  final Uint8List? artwork;
  final List<Song> songs;
  final int year;
  final String albumArtUri;

  Album({
    required this.id,
    required this.name,
    required this.artist,
    this.artwork,
    required this.songs,
    this.year = 0,
    required this.albumArtUri,
  });

  int get totalDuration => songs.fold(0, (sum, song) => sum + song.duration);
  
  String get displayName => name.isEmpty ? 'Unknown Album' : name;
  String get displayArtist => artist.isEmpty ? 'Unknown Artist' : artist;
}

class Artist {
  final String id;
  final String name;
  final List<Album> albums;
  final List<Song> songs;

  Artist({
    required this.id,
    required this.name,
    required this.albums,
    required this.songs,
  });

  int get totalSongs => songs.length;
  int get totalAlbums => albums.length;
  String get displayName => name.isEmpty ? 'Unknown Artist' : name;
}

@HiveType(typeId: 0)
class Song {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String artist;
  @HiveField(3)
  final String album;
  @HiveField(4)
  final String albumId;
  @HiveField(5)
  final int duration;
  @HiveField(6)
  final String uri;
  @HiveField(7)
  final int trackNumber;
  @HiveField(8)
  final int year;
  @HiveField(9)
  final int dateAdded;
  @HiveField(10)
  final String albumArtUri;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.duration,
    required this.uri,
    required this.trackNumber,
    required this.year,
    required this.dateAdded,
    required this.albumArtUri,
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'album_id': albumId,
      'duration': duration,
      'uri': uri,
      'track': trackNumber,
      'year': year,
      'date_added': dateAdded,
      'album_art_uri': albumArtUri,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: (map['_id']?.toString()) ?? '',
      title: map['title'] as String? ?? 'Unknown Title',
      artist: map['artist'] as String? ?? 'Unknown Artist',
      album: map['album'] as String? ?? 'Unknown Album',
      albumId: (map['album_id']?.toString()) ?? '',
      duration: map['duration'] as int? ?? 0,
      uri: map['uri'] as String? ?? '',
      trackNumber: map['track'] as int? ?? 0,
      year: map['year'] as int? ?? 0,
      dateAdded: map['date_added'] as int? ?? 0,
      albumArtUri: map['album_art_uri'] as String? ?? '',
    );
  }

  String get displayTitle => title.isEmpty ? 'Unknown Title' : title;
  String get displayArtist => artist.isEmpty ? 'Unknown Artist' : artist;
  String get displayAlbum => album.isEmpty ? 'Unknown Album' : album;

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumId,
    int? duration,
    String? uri,
    int? trackNumber,
    int? year,
    int? dateAdded,
    String? albumArtUri,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      duration: duration ?? this.duration,
      uri: uri ?? this.uri,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
      dateAdded: dateAdded ?? this.dateAdded,
      albumArtUri: albumArtUri ?? this.albumArtUri,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          albumId == other.albumId &&
          duration == other.duration &&
          uri == other.uri &&
          trackNumber == other.trackNumber &&
          year == other.year &&
          dateAdded == other.dateAdded &&
          albumArtUri == other.albumArtUri;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      artist.hashCode ^
      album.hashCode ^
      albumId.hashCode ^
      duration.hashCode ^
      uri.hashCode ^
      trackNumber.hashCode ^
      year.hashCode ^
      dateAdded.hashCode ^
      albumArtUri.hashCode;
}

class Playlist {
  final String id;
  final String name;
  final List<Song> songs;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Playlist({
    required this.id,
    required this.name,
    required this.songs,
    required this.createdAt,
    required this.modifiedAt,
  });

  int get totalDuration => songs.fold(0, (sum, song) => sum + song.duration);
  int get songCount => songs.length;

  Playlist copyWith({
    String? name,
    List<Song>? songs,
    DateTime? modifiedAt,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
    );
  }
} 