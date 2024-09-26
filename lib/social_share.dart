import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class SocialShare {
  static const MethodChannel _channel = const MethodChannel('social_share');

  static Future<String?> shareInstagramStory({
    required String appId,
    required String imagePath,
    String? backgroundTopColor,
    String? backgroundBottomColor,
    String? backgroundImagePath,
    String? backgroundVideoPath,
    String? attributionURL,
  }) async {
    return shareMetaStory(
      appId: appId,
      platform: "shareInstagramStory",
      imagePath: imagePath,
      backgroundTopColor: backgroundTopColor,
      backgroundBottomColor: backgroundBottomColor,
      attributionURL: attributionURL,
      backgroundImagePath: backgroundImagePath,
      backgroundVideoPath: backgroundVideoPath,
    );
  }

  /// Shares a story on Facebook with optional background video.
  static Future<String?> shareFacebookStory({
    required String appId,
    String? imagePath,
    String? backgroundTopColor,
    String? backgroundBottomColor,
    String? backgroundImagePath,
    String? backgroundVideoPath,
    String? attributionURL,
  }) async {
    return shareMetaStory(
      appId: appId,
      platform: "shareFacebookStory",
      imagePath: imagePath,
      backgroundTopColor: backgroundTopColor,
      backgroundBottomColor: backgroundBottomColor,
      attributionURL: attributionURL,
      backgroundImagePath: backgroundImagePath,
      backgroundVideoPath: backgroundVideoPath,
    );
  }

  /// General method to share stories on Meta platforms (Instagram/Facebook).
  static Future<String?> shareMetaStory({
    required String appId,
    required String platform,
    String? imagePath,
    String? backgroundTopColor,
    String? backgroundBottomColor,
    String? attributionURL,
    String? backgroundImagePath,
    String? backgroundVideoPath,
  }) async {
    var _imagePath = imagePath;
    var _backgroundImagePath = backgroundImagePath;
    var _backgroundVideoPath = backgroundVideoPath;

    if (Platform.isAndroid) {
      var stickerFilename = "stickerAsset.png";
      await reSaveImage(imagePath, stickerFilename);
      _imagePath = stickerFilename;

      if (backgroundImagePath != null) {
        var backgroundImageFilename = backgroundImagePath.split("/").last;
        await reSaveImage(backgroundImagePath, backgroundImageFilename);
        _backgroundImagePath = backgroundImageFilename;
      }

      if (backgroundVideoPath != null) {
        var backgroundVideoFilename = backgroundVideoPath.split("/").last;
        await reSaveFile(backgroundVideoPath, backgroundVideoFilename);
        _backgroundVideoPath = backgroundVideoFilename;
      }
    }

    Map<String, dynamic> args = <String, dynamic>{
      "stickerImage": _imagePath,
      "backgroundTopColor": backgroundTopColor,
      "backgroundBottomColor": backgroundBottomColor,
      "attributionURL": attributionURL,
      "appId": appId
    };

    if (_backgroundImagePath != null) {
      args["backgroundImage"] = _backgroundImagePath;
    }

    if (_backgroundVideoPath != null) {
      args["backgroundVideo"] = _backgroundVideoPath;
    }

    final String? response = await _channel.invokeMethod(platform, args);
    return response;
  }

  /// Shares a tweet on Twitter.
  static Future<String?> shareTwitter(
    String captionText, {
    List<String>? hashtags,
    String? url,
    String? trailingText,
  }) async {
    // Caption
    var _captionText = captionText;

    // Hashtags
    if (hashtags != null && hashtags.isNotEmpty) {
      final tags = hashtags.map((t) => '#$t ').join(' ');
      _captionText = _captionText + "\n" + tags.toString();
    }

    // URL
    String _url = '';
    if (url != null) {
      if (Platform.isAndroid) {
        _url = Uri.parse(url).toString().replaceAll('#', "%23");
      } else {
        _url = Uri.parse(url).toString();
      }
      _captionText = _captionText + "\n" + _url;
    }

    if (trailingText != null) {
      _captionText = _captionText + "\n" + trailingText;
    }

    Map<String, dynamic> args = <String, dynamic>{
      "captionText": _captionText + " ",
    };
    final String? version = await _channel.invokeMethod('shareTwitter', args);
    return version;
  }

  /// Shares a message via SMS.
  static Future<String?> shareSms(String message,
      {String? url, String? trailingText}) async {
    Map<String, dynamic>? args;
    if (Platform.isIOS) {
      if (url == null) {
        args = <String, dynamic>{
          "message": message,
        };
      } else {
        args = <String, dynamic>{
          "message": message + " ",
          "urlLink": Uri.parse(url).toString(),
          "trailingText": trailingText
        };
      }
    } else if (Platform.isAndroid) {
      args = <String, dynamic>{
        "message": message + (url ?? '') + (trailingText ?? ''),
      };
    }
    final String? version = await _channel.invokeMethod('shareSms', args);
    return version;
  }

  /// Copies text or image to the clipboard.
  static Future<String?> copyToClipboard({String? text, String? image}) async {
    final Map<String, dynamic> args = <String, dynamic>{
      "content": text,
      "image": image,
    };
    final String? response =
        await _channel.invokeMethod('copyToClipboard', args);
    return response;
  }

  /// Presents native share options.
  static Future<bool?> shareOptions(String contentText,
      {String? imagePath}) async {
    Map<String, dynamic> args;

    var _imagePath = imagePath;
    if (Platform.isAndroid) {
      if (imagePath != null) {
        var stickerFilename = "stickerAsset.png";
        await reSaveImage(imagePath, stickerFilename);
        _imagePath = stickerFilename;
      }
    }
    args = <String, dynamic>{"image": _imagePath, "content": contentText};
    final bool? version = await _channel.invokeMethod('shareOptions', args);
    return version;
  }

  /// Shares content on WhatsApp.
  static Future<String?> shareWhatsapp(String content) async {
    final Map<String, dynamic> args = <String, dynamic>{"content": content};
    final String? version = await _channel.invokeMethod('shareWhatsapp', args);
    return version;
  }

  /// Checks which apps are installed for sharing.
  static Future<Map?> checkInstalledAppsForShare() async {
    final Map? apps = await _channel.invokeMethod('checkInstalledApps');
    return apps;
  }

  /// Shares content on Telegram.
  static Future<String?> shareTelegram(String content) async {
    final Map<String, dynamic> args = <String, dynamic>{"content": content};
    final String? version = await _channel.invokeMethod('shareTelegram', args);
    return version;
  }

  // Utility Methods

  /// Resaves an image to the temporary directory with a new filename.
  static Future<bool> reSaveImage(String? imagePath, String filename) async {
    if (imagePath == null) {
      return false;
    }
    final tempDir = await getTemporaryDirectory();

    File file = File(imagePath);
    Uint8List bytes = await file.readAsBytes();
    final stickerAssetPath = '${tempDir.path}/$filename';
    file = await File(stickerAssetPath).create();
    await file.writeAsBytes(bytes);
    return true;
  }

  /// Resaves a generic file (e.g., video) to the temporary directory with a new filename.
  static Future<bool> reSaveFile(String? filePath, String filename) async {
    if (filePath == null) {
      return false;
    }
    final tempDir = await getTemporaryDirectory();

    File file = File(filePath);
    Uint8List bytes = await file.readAsBytes();
    final fileAssetPath = '${tempDir.path}/$filename';
    file = await File(fileAssetPath).create();
    await file.writeAsBytes(bytes);
    return true;
  }
}
