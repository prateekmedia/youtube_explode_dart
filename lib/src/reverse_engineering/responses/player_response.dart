import 'dart:convert';

import 'package:http_parser/http_parser.dart';

import '../../extensions/helpers_extension.dart';
import 'stream_info_provider.dart';

class PlayerResponse {
  // Json parsed map
  final Map<String, dynamic> _root;

  Iterable<StreamInfoProvider> _muxedStreams;
  Iterable<StreamInfoProvider> _adaptiveStreams;
  List<StreamInfoProvider> _streams;
  Iterable<ClosedCaptionTrack> _closedCaptionTrack;
  String _videoPlayabilityError;

  String get playabilityStatus => _root['playabilityStatus']['status'];

  bool get isVideoAvailable => playabilityStatus.toLowerCase() != 'error';

  bool get isVideoPlayable => playabilityStatus.toLowerCase() == 'ok';

  String get videoTitle => _root['videoDetails']['title'];

  String get videoAuthor => _root['videoDetails']['author'];

  DateTime get videoUploadDate => DateTime.parse(
      _root['microformat']['playerMicroformatRenderer']['uploadDate']);

  String get videoChannelId => _root['videoDetails']['channelId'];

  Duration get videoDuration =>
      Duration(seconds: int.parse(_root['videoDetails']['lengthSeconds']));

  Iterable<String> get videoKeywords =>
      _root['videoDetails']['keywords']?.cast<String>() ?? const [];

  String get videoDescription => _root['videoDetails']['shortDescription'];

  int get videoViewCount => int.parse(_root['videoDetails']['viewCount']);

  // Can be null
  String get previewVideoId =>
      _root
          .get('playabilityStatus')
          ?.get('errorScreen')
          ?.get('playerLegacyDesktopYpcTrailerRenderer')
          ?.getValue('trailerVideoId') ??
      Uri.splitQueryString(_root
              .get('playabilityStatus')
              ?.get('errorScreen')
              ?.get('')
              ?.get('ypcTrailerRenderer')
              ?.getValue('playerVars') ??
          '')['video_id'];

  bool get isLive => _root.get('videoDetails')?.getValue('isLive') ?? false;

  // Can be null
  String get hlsManifestUrl =>
      _root.get('streamingData')?.getValue('hlsManifestUrl');

  // Can be null
  String get dashManifestUrl =>
      _root.get('streamingData')?.getValue('dashManifestUrl');

  Iterable<StreamInfoProvider> get muxedStreams => _muxedStreams ??= _root
          ?.get('streamingData')
          ?.getValue('formats')
          ?.map((e) => _StreamInfo(e))
          ?.cast<StreamInfoProvider>() ??
      const <StreamInfoProvider>[];

  Iterable<StreamInfoProvider> get adaptiveStreams => _adaptiveStreams ??= _root
          ?.get('streamingData')
          ?.getValue('adaptiveFormats')
          ?.map((e) => _StreamInfo(e))
          ?.cast<StreamInfoProvider>() ??
      const <StreamInfoProvider>[];

  List<StreamInfoProvider> get streams =>
      _streams ??= [...muxedStreams, ...adaptiveStreams];

  Iterable<ClosedCaptionTrack> get closedCaptionTrack =>
      _closedCaptionTrack ??= _root
              .get('captions')
              ?.get('playerCaptionsTracklistRenderer')
              ?.getValue('captionTracks')
              ?.map((e) => ClosedCaptionTrack(e))
              ?.cast<ClosedCaptionTrack>() ??
          const [];

  PlayerResponse(this._root);

  String getVideoPlayabilityError() => _videoPlayabilityError ??=
      _root.get('playabilityStatus')?.getValue('reason');

  PlayerResponse.parse(String raw) : _root = json.decode(raw);
}

class ClosedCaptionTrack {
  // Json parsed map
  final Map<String, dynamic> _root;

  String get url => _root['baseUrl'];

  String get languageCode => _root['languageCode'];

  String get languageName => _root['name']['simpleText'];

  bool get autoGenerated => _root['vssId'].toLowerCase().startsWith("a.");

  ClosedCaptionTrack(this._root);
}

class _StreamInfo extends StreamInfoProvider {
  static final _contentLenExp = RegExp(r'[\?&]clen=(\d+)');

  // Json parsed map
  final Map<String, dynamic> _root;

  int _bitrate;
  String _container;
  int _contentLength;
  int _framerate;
  String _signature;
  String _signatureParameter;
  int _tag;
  String _url;

  @override
  int get bitrate => _bitrate ??= _root['bitrate'];

  @override
  String get container => _container ??= mimeType.subtype;

  @override
  int get contentLength =>
      _contentLength ??= int.tryParse(_root['contentLength'] ?? '') ??
          _contentLenExp.firstMatch(url)?.group(1);

  @override
  int get framerate => _framerate ??= _root['fps'];

  @override
  String get signature =>
      _signature ??= Uri.splitQueryString(_root['signatureCipher'] ?? '')['s'];

  @override
  String get signatureParameter => _signatureParameter ??=
      Uri.splitQueryString(_root['cipher'] ?? '')['sp'] ??
          Uri.splitQueryString(_root['signatureCipher'] ?? '')['sp'];

  @override
  int get tag => _tag ??= _root['itag'];

  @override
  String get url => _url ??= _getUrl();

  String _getUrl() {
    var url = _root['url'];
    url ??= Uri.splitQueryString(_root['cipher'] ?? '')['url'];
    url ??= Uri.splitQueryString(_root['signatureCipher'] ?? '')['url'];
    return url;
  }

  bool _isAudioOnly;
  MediaType _mimeType;
  String _codecs;

  @override
  String get videoCodec =>
      isAudioOnly ? null : codecs.split(',').first.trim().nullIfWhitespace;

  @override
  int get videoHeight => _root['height'];

  @override
  String get videoQualityLabel => _root['qualityLabel'];

  @override
  int get videoWidth => _root['width'];

  bool get isAudioOnly => _isAudioOnly ??= mimeType.type == 'audio';

  MediaType get mimeType => _mimeType ??= MediaType.parse(_root['mimeType']);

  String get codecs =>
      _codecs ??= mimeType?.parameters['codecs']?.toLowerCase();

  @override
  String get audioCodec =>
      isAudioOnly ? codecs : _getAudioCodec(codecs.split(','))?.trim();

  String _getAudioCodec(List<String> codecs) {
    if (codecs.length == 1) {
      return null;
    }
    return codecs.last;
  }

  _StreamInfo(this._root);
}
