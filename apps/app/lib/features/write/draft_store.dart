/// 写信草稿的本地持久化（F2 · DraftStore）。
///
/// 只保证「离开/断网不丢编辑」，不做离线发送队列：版本化 JSON 存
/// 应用支持目录，选中的图片复制进 `write_draft_images/`（picker 缓存
/// 目录随时可能被系统清掉，不能直接引用）。防抖由控制器负责，
/// 这里只做无状态的读写与文件管理。
///
/// JSON 的 schema 归 WriteController 所有（它知道怎么与 WriteState 互转），
/// 本类只认键值对 —— 避免数据模型与存储实现互相 import。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DraftStore {
  DraftStore({Future<Directory> Function()? baseDirFactory})
    : _baseDirFactory = baseDirFactory ?? getApplicationSupportDirectory;

  static const int draftVersion = 1;

  final Future<Directory> Function() _baseDirFactory;

  /// 图片文件名去重的自增序号
  int seq = 0;

  Future<Directory> get _base => _baseDirFactory();

  Future<Directory> get _imagesDir async {
    final dir = Directory(p.join((await _base).path, 'write_draft_images'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _draftFile(String key) async {
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File(p.join((await _base).path, 'draft_$safe.json'));
  }

  // ---------- 草稿 JSON ----------

  Future<void> saveJson(String key, Map<String, Object?> json) async {
    final file = await _draftFile(key);
    await file.writeAsString(jsonEncode(json), flush: true);
  }

  /// 读草稿。版本不认识（升级后的旧格式）视为没有草稿并清掉，
  /// 不做迁移——草稿是易失数据，不值得写迁移代码。
  Future<Map<String, Object?>?> loadJson(String key) async {
    final file = await _draftFile(key);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final json = Map<String, Object?>.from(decoded);
      if (json['version'] != draftVersion) {
        await file.delete();
        return null;
      }
      return json;
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> clear(String key) async {
    final file = await _draftFile(key);
    if (await file.exists()) await file.delete();
  }

  // ---------- 图片副本 ----------

  /// 把字节落成草稿图片，返回文件名（非全路径）。
  Future<String> saveImageBytes(List<int> bytes, String ext) async {
    final name = 'img_${DateTime.now().microsecondsSinceEpoch}_$seq.$ext';
    seq++;
    await File(p.join((await _imagesDir).path, name))
        .writeAsBytes(bytes, flush: true);
    return name;
  }

  /// 草稿图片的绝对路径（恢复草稿时用）。
  Future<String> imagePath(String filename) async =>
      p.join((await _imagesDir).path, filename);

  Future<void> deleteImage(String filename) async {
    final file = File(p.join((await _imagesDir).path, filename));
    if (await file.exists()) await file.delete();
  }

  /// 清掉草稿引用的所有图片（寄出成功后调用）。
  Future<void> deleteImages(Iterable<String> filenames) async {
    for (final name in filenames) {
      await deleteImage(name);
    }
  }
}

final draftStoreProvider = Provider<DraftStore>((_) => DraftStore());
