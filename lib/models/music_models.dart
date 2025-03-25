import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'music_models.g.dart';

@HiveType(typeId: 2)
class Album {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String artist;

  @HiveField(3)
  final List<Song> songs;

  @HiveField(4)
  final int? year;

  @HiveField(5)
  final String? albumArtUri;

  Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.songs,
    this.year,
    this.albumArtUri,
  });

  int get totalDuration => songs.fold(0, (sum, song) => sum + song.duration);
  
  String get displayName => name.isEmpty ? 'Unknown Album' : name;
  String get displayArtist => artist.isEmpty ? 'Unknown Artist' : artist;

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'songs': songs.map((song) => song.toJson()).toList(),
      'year': year,
      'albumArtUri': albumArtUri,
    };
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      songs: (json['songs'] as List<dynamic>?)
          ?.map((songJson) => Song.fromJson(songJson as Map<String, dynamic>))
          .toList() ?? [],
      year: json['year'] as int?,
      albumArtUri: json['albumArtUri'] as String?,
    );
  }
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
  @HiveField(11)
  final int dateModified;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.duration,
    required this.uri,
    required this.albumArtUri,
    required this.trackNumber,
    required this.year,
    required this.dateAdded,
    this.dateModified = 0,
  });

  // Empty constructor for creating placeholder songs
  Song.empty()
      : id = '',
        title = '',
        artist = '',
        album = '',
        albumId = '',
        duration = 0,
        uri = '',
        albumArtUri = '',
        trackNumber = 0,
        year = 0,
        dateAdded = 0,
        dateModified = 0;

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumId': albumId,
      'duration': duration,
      'uri': uri,
      'albumArtUri': albumArtUri,
      'trackNumber': trackNumber,
      'year': year,
      'dateAdded': dateAdded,
      'dateModified': dateModified,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      albumId: json['albumId'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      uri: json['uri'] as String? ?? '',
      albumArtUri: json['albumArtUri'] as String? ?? '',
      trackNumber: json['trackNumber'] as int? ?? 0,
      year: json['year'] as int? ?? 0,
      dateAdded: json['dateAdded'] as int? ?? 0,
      dateModified: json['dateModified'] as int? ?? 0,
    );
  }

  // Equality operator
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uri == other.uri;

  @override
  int get hashCode => id.hashCode ^ uri.hashCode;

  // Display getters
  String get displayTitle => title.isEmpty ? 'Unknown Title' : title;
  String get displayArtist => artist.isEmpty ? 'Unknown Artist' : artist;
  String get displayAlbum => album.isEmpty ? 'Unknown Album' : album;

  // CopyWith method
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
    int? dateModified,
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
      dateModified: dateModified ?? this.dateModified,
    );
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Unknown Title',
      artist: map['artist']?.toString() ?? 'Unknown Artist',
      album: map['album']?.toString() ?? 'Unknown Album',
      albumId: map['album_id']?.toString() ?? '',
      duration: map['duration'] as int? ?? 0,
      uri: map['_data']?.toString() ?? '',
      albumArtUri: map['album_art_uri']?.toString() ?? '',
      trackNumber: map['track'] as int? ?? 0,
      year: map['year'] as int? ?? 0,
      dateAdded: map['date_added'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool get isEmpty => id.isEmpty && title.isEmpty && artist.isEmpty && album.isEmpty;
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