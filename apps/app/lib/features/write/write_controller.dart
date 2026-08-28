/// 写信页控制器（F2 最小闭环）——视图外的全部控制逻辑。
///
/// MVC 分工：`write_screen.dart` + `widgets/` 只管布局与交互挂接；
/// 本类持有唯一的可变状态 [WriteState]：图文块流、落款/宛名、落点、
/// 留/投选择、照片上传进度、校验与提交。
///
/// 编辑模型：一封信 = 文本段与照片块的有序流。**文本段只由照片分隔**
/// （换行留在段内，后端 TextBlock 允许 `\n`），且 blocks 恒以文本段收尾
/// ——哪怕空串——保证「在末尾继续写」永远有落点。所见即所得由视图层
/// 为每个文本段渲染一个无边框 TextField 实现，本类不碰 TextEditingController。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/controllers/location_controller.dart';
import '../../core/env.dart';
import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/device/image_gateway.dart';
import '../../data/models/letter.dart';
import 'draft_store.dart';

// ---------- 编辑态模型 ----------

/// 信件内容块。id 供视图做稳定 key 与光标锚点。
sealed class WriteBlock {
  const WriteBlock({required this.id});

  final int id;
}

final class WriteTextBlock extends WriteBlock {
  const WriteTextBlock({required super.id, required this.text});

  final String text;
}

enum PhotoUploadPhase { pending, uploading, uploaded, failed }

final class WritePhotoBlock extends WriteBlock {
  const WritePhotoBlock({
    required super.id,
    required this.localPath,
    this.remoteUrl,
    this.phase = PhotoUploadPhase.pending,
  });

  /// 草稿图片副本的绝对路径（渲染用）；草稿 JSON 里只存文件名。
  final String localPath;

  /// 上传成功后的服务端 URL（提交时填进 photo block 的 ref）。
  final String? remoteUrl;

  final PhotoUploadPhase phase;
}

/// 落点：坐标 + 可公开展示的地名。**改地名不改坐标**（PRD 6.1）；
/// 只有地名没有坐标时，不得提交 stay。
class DropPoint {
  const DropPoint({this.lat, this.lon, this.label});

  final double? lat;
  final double? lon;
  final String? label;
}

/// 定位候选：消费全局 LocationController 后、用户确认前的中间态。
class LocationCandidate {
  const LocationCandidate({required this.lat, required this.lon, this.label});

  final double lat;
  final double lon;
  final String? label;
}

/// 一次性提示（视图层 ref.listen 后弹 NatsuToast）。
/// seq 单调递增，同一句话连发两次也能被听见。
typedef WriteNotice = ({String message, int seq});

/// 焦点请求：插完照片把光标放回正文断点处。
typedef WriteFocusRequest = ({int blockId, int offset, int seq});

class WriteState {
  /// 非空 [now] 由控制器随生命周期推进（进页置初值、前台每 30 秒、
  /// 回前台时刷新）——纸尾日期时间永远与「此刻」一致，草稿恢复也不例外。
  WriteState({
    this.parentLetterId,
    this.blocks = const [],
    this.signature = '',
    this.addressee = '',
    this.dropPoint,
    this.weather,
    this.deliveryMode,
    this.locationBusy = false,
    this.sending = false,
    this.restored = false,
    this.notice,
    this.focusRequest,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  final DateTime now;

  /// 非空即回信语境（复用同一写信流，提交走 createReply）。
  final String? parentLetterId;
  final List<WriteBlock> blocks;
  final String signature;
  final String addressee;
  final DropPoint? dropPoint;
  final Weather? weather;

  /// 留/投二选一——初始 null，**不许有默认值悄悄带过**（PRD 6.1）。
  final DeliveryMode? deliveryMode;

  final bool locationBusy;
  final bool sending;

  /// 本次进入页面时恢复了历史草稿（用于提示与测试）。
  final bool restored;

  final WriteNotice? notice;
  final WriteFocusRequest? focusRequest;

  int get textCharCount => blocks.whereType<WriteTextBlock>().fold(
    0,
    (sum, block) => sum + block.text.length,
  );

  int get photoCount => photos.length;

  /// 信内照片，按实际所在位置排序（图片托盘的顺序依据）。
  List<WritePhotoBlock> get photos => [
    for (final block in blocks)
      if (block is WritePhotoBlock) block,
  ];

  WriteState copyWith({
    List<WriteBlock>? blocks,
    String? signature,
    String? addressee,
    Object? dropPoint = _unset,
    Object? weather = _unset,
    Object? deliveryMode = _unset,
    bool? locationBusy,
    bool? sending,
    bool? restored,
    WriteNotice? notice,
    Object? focusRequest = _unset,
    DateTime? now,
  }) {
    return WriteState(
      parentLetterId: parentLetterId,
      blocks: blocks ?? this.blocks,
      signature: signature ?? this.signature,
      addressee: addressee ?? this.addressee,
      dropPoint: dropPoint == _unset ? this.dropPoint : dropPoint as DropPoint?,
      weather: weather == _unset ? this.weather : weather as Weather?,
      deliveryMode: deliveryMode == _unset
          ? this.deliveryMode
          : deliveryMode as DeliveryMode?,
      locationBusy: locationBusy ?? this.locationBusy,
      sending: sending ?? this.sending,
      restored: restored ?? this.restored,
      notice: notice ?? this.notice,
      focusRequest: focusRequest == _unset
          ? this.focusRequest
          : focusRequest as WriteFocusRequest?,
      now: now ?? this.now,
    );
  }

  static const _unset = Object();
}

// ---------- provider ----------

/// 图片选择网关（测试用 fake 注入缝），仿 locationGatewayProvider 模式。
final imageGatewayProvider = Provider<ImageGateway>(
  (_) => const ImagePickerGateway(),
);

final writeControllerProvider = NotifierProvider<WriteController, WriteState>(
  WriteController.new,
);

// ---------- 控制器 ----------

class WriteController extends Notifier<WriteState> {
  @override
  WriteState build() {
    ref.onDispose(() {
      _saveDebounce?.cancel();
      _clockTimer?.cancel();
    });
    return WriteState(blocks: [WriteTextBlock(id: 0, text: '')]);
  }

  /// 文本块的 id 序列（跨恢复递增，保证 key 稳定不撞）。
  int _idSeq = 1;

  /// 光标锚点：视图上报的（blockId, offset）。只在控制器里存，
  /// 不进 state——它不驱动渲染。
  int? _cursorBlockId;
  int _cursorOffset = 0;

  Timer? _saveDebounce;
  Timer? _clockTimer;
  bool _uploading = false;

  String get _draftKey =>
      state.parentLetterId == null ? 'write' : 'reply_${state.parentLetterId}';

  // ---------- 生命周期 ----------

  /// 进入写信页时调用（initState）：确定回信语境，重置为空态并尝试恢复草稿。
  Future<void> start({String? parentLetterId}) async {
    _saveDebounce?.cancel();
    _clockTimer?.cancel();
    _cursorBlockId = null;
    _idSeq = 1;
    state = WriteState(
      parentLetterId: parentLetterId,
      blocks: const [WriteTextBlock(id: 0, text: '')],
    );
    _startClock();
    unawaited(_autoFillWeather());

    final store = ref.read(draftStoreProvider);
    final json = await store.loadJson(_draftKey);
    if (!ref.mounted) return; // 页面已离开：恢复作废
    if (json == null || json['parent'] != parentLetterId) return;
    await _restoreFromDraft(store, json);
  }

  /// 纸尾日期时间的活钟：前台每 30 秒看一眼，分钟真的走了才推一拍，
  /// 避免无谓的整纸重建。页面离开时随 onDispose 停掉。
  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!ref.mounted) return;
      final now = DateTime.now();
      if (now.hour == state.now.hour && now.minute == state.now.minute) {
        return;
      }
      state = state.copyWith(now: now);
    });
  }

  /// 页面回到前台（视图的 AppLifecycleListener 转发）：时间立即对表，
  /// 已有落点就顺手把天气也刷新到最新。
  void onResumed() {
    if (!ref.mounted) return;
    state = state.copyWith(now: DateTime.now());
    final dp = state.dropPoint;
    if (dp?.lat != null && dp?.lon != null) {
      unawaited(_refreshWeather(dp!.lat!, dp.lon!));
    } else {
      unawaited(_autoFillWeather());
    }
  }

  /// 进页静默补天气：全局定位「现成」就拿来用（已授权才会 ready，
  /// 不主动弹权限窗打断写信），取不到就不显示——可降级模块不打扰人。
  Future<void> _autoFillWeather() async {
    if (state.weather != null) return;
    try {
      if (ref.read(locationControllerProvider).phase != LocationPhase.ready) {
        await ref
            .read(locationControllerProvider.notifier)
            .locate(requestPermission: false);
      }
      if (!ref.mounted) return;
      final coord = ref.read(locationControllerProvider).coordinate;
      if (coord == null) return;
      await _refreshWeather(coord.latitude, coord.longitude);
    } on Exception {
      // 定位/天气任一环节挂了都就此打住：没有天气就没有
    }
  }

  Future<void> _restoreFromDraft(
    DraftStore store,
    Map<String, Object?> json,
  ) async {
    final rawBlocks = json['blocks'];
    if (rawBlocks is! List) return;

    final blocks = <WriteBlock>[];
    for (final raw in rawBlocks) {
      if (!ref.mounted) return;
      if (raw is! Map) continue;
      final map = Map<String, Object?>.from(raw);
      switch (map['kind']) {
        case 'text':
          blocks.add(
            WriteTextBlock(id: _idSeq++, text: (map['text'] as String?) ?? ''),
          );
        case 'photo':
          final file = map['file'] as String?;
          if (file == null || file.isEmpty) continue;
          final path = await store.imagePath(file);
          blocks.add(
            WritePhotoBlock(
              id: _idSeq++,
              localPath: path,
              // 已上传过的直接复用 URL；没有的补传
              remoteUrl: map['url'] as String?,
              phase: map['url'] == null
                  ? PhotoUploadPhase.pending
                  : PhotoUploadPhase.uploaded,
            ),
          );
        default:
          continue;
      }
    }
    if (blocks.isEmpty) return;
    if (blocks.last is! WriteTextBlock) {
      blocks.add(WriteTextBlock(id: _idSeq++, text: ''));
    }

    state = state.copyWith(
      blocks: blocks,
      signature: (json['signature'] as String?) ?? '',
      addressee: (json['addressee'] as String?) ?? '',
      restored: true,
    );
    _notice('已恢复上次的草稿');

    final pending = [
      for (final photo in state.photos)
        if (photo.phase == PhotoUploadPhase.pending) photo.id,
    ];
    if (pending.isNotEmpty) unawaited(_uploadPhotos(pending));
    // 落点/投递方式不进草稿（地点随定位走）；坐标天气由进页的
    // _autoFillWeather 统一静默补，这里不重复取。
  }

  // ---------- 文本 ----------

  /// 视图回调：某文本段内容变化（每个字符都来，不防抖——所见即所得）。
  void updateText(int blockId, String text) {
    _mutate(
      (s) => s.copyWith(
        blocks: [
          for (final block in s.blocks)
            if (block is WriteTextBlock && block.id == blockId)
              WriteTextBlock(id: block.id, text: text)
            else
              block,
        ],
      ),
    );
  }

  /// 视图回调：光标锚点（插入照片的位置依据）。
  void reportCursor(int blockId, int offset) {
    _cursorBlockId = blockId;
    _cursorOffset = offset;
  }

  // ---------- 照片 ----------

  /// 从系统选图器取图并**插入当前光标处**（无锚点则插到末尾照片之后）。
  /// 插入即复制进草稿目录并开始顺序上传——寄出前一定传完。
  Future<void> addPhotosAtCursor() async {
    final remaining = Env.letterMaxImages - state.photoCount;
    if (remaining <= 0) {
      _notice('一封信最多夹三张照片');
      return;
    }
    final picked = await ref
        .read(imageGatewayProvider)
        .pickImages(maxCount: remaining);
    if (!ref.mounted) return; // 选图期间页面已离开
    if (picked.isEmpty) return;

    final store = ref.read(draftStoreProvider);
    final photos = <WritePhotoBlock>[];
    for (final image in picked) {
      final mime = image.mime;
      if (mime == null) {
        _notice('有一张图认不出格式，换一张试试');
        continue;
      }
      final file = await store.saveImageBytes(image.bytes, _extOf(mime));
      final path = await store.imagePath(file);
      photos.add(WritePhotoBlock(id: _idSeq++, localPath: path));
    }
    if (photos.isEmpty) return;

    // 光标锚点处的文本段一分为二，照片夹在中间；锚点失效则落末尾
    final anchorId = _cursorBlockId;
    WriteTextBlock? anchor;
    for (final block in state.blocks) {
      if (block is WriteTextBlock && block.id == anchorId) anchor = block;
    }

    final blocks = <WriteBlock>[];
    WriteTextBlock? afterBlock;
    if (anchor != null) {
      final offset = _cursorOffset.clamp(0, anchor.text.length);
      final before = anchor.text.substring(0, offset);
      final after = anchor.text.substring(offset);
      for (final block in state.blocks) {
        if (block.id == anchor.id) {
          if (before.isNotEmpty) {
            blocks.add(WriteTextBlock(id: _idSeq++, text: before));
          }
          blocks.addAll(photos);
          afterBlock = WriteTextBlock(id: _idSeq++, text: after);
          blocks.add(afterBlock);
        } else {
          blocks.add(block);
        }
      }
    } else {
      // 无锚点：照片落在信的末尾。尾文本段是空的就让它继续收尾，
      // 非空则在照片后面补一个新的空尾段（保持不变量）
      final last = state.blocks.last;
      final trailingEmpty = last is WriteTextBlock && last.text.isEmpty;
      blocks.addAll(
        state.blocks.take(
          trailingEmpty ? state.blocks.length - 1 : state.blocks.length,
        ),
      );
      blocks.addAll(photos);
      afterBlock = WriteTextBlock(id: _idSeq++, text: '');
      blocks.add(afterBlock);
    }

    final focus = afterBlock == null
        ? null
        : (
            blockId: afterBlock.id,
            offset: afterBlock.text.length,
            seq: (state.focusRequest?.seq ?? 0) + 1,
          );
    state = state.copyWith(blocks: blocks);
    state = state.copyWith(focusRequest: focus);
    _scheduleSave();
    unawaited(_uploadPhotos([for (final photo in photos) photo.id]));
  }

  /// 移除一张照片（托盘/纸面照片弹层里的「移除」）。若照片两侧都是
  /// 文本段，自动把前后两段合并成一段，光标落在缝合点——删掉一张夹在
  /// 文字中间的照片，不该留下一条无来由的断痕。
  Future<void> removePhoto(int blockId) async {
    final blocks = state.blocks;
    final index = blocks.indexWhere((block) => block.id == blockId);
    if (index < 0 || blocks[index] is! WritePhotoBlock) return;
    final photo = blocks[index] as WritePhotoBlock;

    WriteTextBlock? prev;
    WriteTextBlock? next;
    if (index > 0 && blocks[index - 1] is WriteTextBlock) {
      prev = blocks[index - 1] as WriteTextBlock;
    }
    if (index < blocks.length - 1 && blocks[index + 1] is WriteTextBlock) {
      next = blocks[index + 1] as WriteTextBlock;
    }

    List<WriteBlock> nextBlocks;
    WriteFocusRequest? focus;
    if (prev != null && next != null) {
      // 用换行缝合：后一段从新的一行续写，而不是直接黏在前段行尾。
      // 沿用前段的 id：该字段留在树上不重建，缝点光标请求才有锚。
      final merged = WriteTextBlock(
        id: prev.id,
        text: '${prev.text}\n${next.text}',
      );
      nextBlocks = [
        ...blocks.sublist(0, index - 1),
        merged,
        ...blocks.sublist(index + 2),
      ];
      focus = (
        blockId: merged.id,
        offset: prev.text.length + 1, // 换行符之后＝新行行首
        seq: (state.focusRequest?.seq ?? 0) + 1,
      );
    } else {
      nextBlocks = [
        for (final block in blocks)
          if (block.id != blockId) block,
      ];
    }
    state = state.copyWith(blocks: nextBlocks, focusRequest: focus);

    // 草稿图片删除是尽力而为：文件被占用/已消失不该打断移除本身
    try {
      await ref
          .read(draftStoreProvider)
          .deleteImage(p.basename(photo.localPath));
    } on Exception {
      // 留给草稿目录的定期清理
    }
    if (ref.mounted) _scheduleSave();
  }

  Future<void> retryUpload(int blockId) => _uploadPhotos([blockId]);

  /// 顺序上传（一次一张，F2 路线图要求）。互斥：已在传则直接返回。
  Future<void> _uploadPhotos(List<int> ids) async {
    if (_uploading || ids.isEmpty) return;
    _uploading = true;
    try {
      final api = ref.read(uploadsApiProvider);
      for (final id in ids) {
        if (!ref.mounted) return; // 页面离开后飞行中的上传就地终止
        WritePhotoBlock? photo;
        for (final block in state.blocks) {
          if (block is WritePhotoBlock && block.id == id) photo = block;
        }
        if (photo == null || photo.phase == PhotoUploadPhase.uploaded) continue;
        if (!_setPhotoPhase(id, PhotoUploadPhase.uploading)) continue;
        try {
          final bytes = await File(photo.localPath).readAsBytes();
          final resp = await api.uploadImage(
            filename: p.basename(photo.localPath),
            bytes: bytes,
            contentType: sniffImageMime(bytes) ?? 'image/jpeg',
          );
          if (!ref.mounted) return;
          _mutate(
            (s) => s.copyWith(
              blocks: [
                for (final block in s.blocks)
                  if (block is WritePhotoBlock && block.id == id)
                    WritePhotoBlock(
                      id: block.id,
                      localPath: block.localPath,
                      remoteUrl: resp.url,
                      phase: PhotoUploadPhase.uploaded,
                    )
                  else
                    block,
              ],
            ),
          );
        } on ApiFailure catch (error) {
          if (!ref.mounted) return;
          _setPhotoPhase(id, PhotoUploadPhase.failed);
          _notice('有一张照片没传上去：${error.message}');
        } on FileSystemException {
          if (!ref.mounted) return;
          _setPhotoPhase(id, PhotoUploadPhase.failed);
          _notice('草稿图片不见了，移除后重新选一张');
        }
      }
    } finally {
      _uploading = false;
    }
  }

  bool _setPhotoPhase(int id, PhotoUploadPhase phase) {
    var found = false;
    final next = <WriteBlock>[];
    for (final block in state.blocks) {
      if (block is WritePhotoBlock && block.id == id) {
        found = true;
        next.add(
          WritePhotoBlock(
            id: block.id,
            localPath: block.localPath,
            remoteUrl: block.remoteUrl,
            phase: phase,
          ),
        );
      } else {
        next.add(block);
      }
    }
    if (found) state = state.copyWith(blocks: next);
    return found;
  }

  // ---------- 表单 ----------

  void setSignature(String value) =>
      _mutate((s) => s.copyWith(signature: value));

  void setAddressee(String value) =>
      _mutate((s) => s.copyWith(addressee: value));

  // ---------- 落点 ----------

  /// 消费全局 LocationController 的候选值：必要时弹权限，拿到坐标后
  /// 用逆地名单预填。返回 null 表示失败（原因已 notice）。
  Future<LocationCandidate?> acquireLocationCandidate() async {
    if (state.locationBusy) return null;
    state = state.copyWith(locationBusy: true);
    try {
      final location = ref.read(locationControllerProvider.notifier);
      if (ref.read(locationControllerProvider).phase != LocationPhase.ready) {
        await location.locate(requestPermission: true);
      }
      if (!ref.mounted) return null;
      switch (ref.read(locationControllerProvider).phase) {
        case LocationPhase.ready:
          break;
        case LocationPhase.serviceDisabled:
          _notice('定位服务没有开');
          return null;
        case LocationPhase.permissionDenied:
          _notice('没有拿到定位权限');
          return null;
        case LocationPhase.permissionPermanentlyDenied:
          _notice('定位权限被永久拒绝了，去系统设置里打开');
          return null;
        case LocationPhase.failed:
        case LocationPhase.idle:
        case LocationPhase.loading:
          _notice('暂时拿不到位置，稍后再试');
          return null;
      }
      final coord = ref.read(locationControllerProvider).coordinate;
      if (coord == null) return null;
      String? label;
      try {
        label = await ref
            .read(geoApiProvider)
            .reverse(coord.latitude, coord.longitude);
        if (!ref.mounted) return null;
      } on ApiFailure {
        label = null; // 逆地理挂了不拦落点，让用户自己命名
      }
      return LocationCandidate(
        lat: coord.latitude,
        lon: coord.longitude,
        label: label,
      );
    } finally {
      if (ref.mounted) state = state.copyWith(locationBusy: false);
    }
  }

  /// 用户在弹层里确认落点。**改地名不改坐标**；
  /// 只有地名没有坐标时，stay 的提交校验会拦下。
  void confirmDropPoint({
    required double? lat,
    required double? lon,
    required String label,
  }) {
    final trimmed = label.trim();
    _mutate(
      (s) => s.copyWith(
        dropPoint: DropPoint(
          lat: lat,
          lon: lon,
          label: trimmed.isEmpty ? null : trimmed,
        ),
      ),
    );
    if (lat != null && lon != null) unawaited(_refreshWeather(lat, lon));
  }

  void clearDropPoint() => _mutate((s) => s.copyWith(dropPoint: null));

  Future<void> _refreshWeather(double lat, double lon) async {
    try {
      final weather = await ref
          .read(weatherApiProvider)
          .getCurrentWeather(lat, lon);
      if (!ref.mounted) return;
      state = state.copyWith(weather: weather);
    } on ApiFailure {
      // 可降级模块：取不到就不显示，不打扰写信的人
    }
  }

  // ---------- 投递与提交 ----------

  void setDelivery(DeliveryMode mode) =>
      _mutate((s) => s.copyWith(deliveryMode: mode));

  /// 校验 + 寄出。成功返回落库后的本人视角（草稿已清、状态已重置），
  /// 视图负责 toast 与返回上一页；失败返回 null，原因经 notice 通知。
  Future<LetterOwned?> send() async {
    if (state.sending) return null;
    final problem = _validate();
    if (problem != null) {
      _notice(problem);
      return null;
    }

    state = state.copyWith(sending: true);
    try {
      // 还在路上的照片先传完（顺序、互斥）
      final pending = [
        for (final photo in state.photos)
          if (photo.phase != PhotoUploadPhase.uploaded) photo.id,
      ];
      if (pending.isNotEmpty) await _uploadPhotos(pending);
      if (!ref.mounted) return null;
      if (state.photos.any(
        (photo) => photo.phase != PhotoUploadPhase.uploaded,
      )) {
        _notice('照片还没有传完，稍等一下再寄');
        return null;
      }

      final request = _buildRequest();
      final parent = state.parentLetterId;
      final api = ref.read(lettersApiProvider);
      final owned = parent == null
          ? await api.create(request)
          : await api.createReply(parent, request);
      if (!ref.mounted) return null; // 寄出期间页面已离开：落库即成功

      await _clearDraft();
      _cursorBlockId = null;
      state = WriteState(
        parentLetterId: parent,
        blocks: [WriteTextBlock(id: _idSeq++, text: '')],
      );
      // 状态由审核决定（默认 pending）——没有「发布成功页」，落库即结束
      return owned;
    } on ApiFailure catch (error) {
      _notice(error.message);
      return null;
    } finally {
      if (state.sending) state = state.copyWith(sending: false);
    }
  }

  /// 客户端校验，镜像产品与协议约束（docs/PRD.md 6.1 + API 契约）。
  /// 返回叙事化的违规句——给写信人看的话，不是错误码。
  String? _validate() {
    final mode = state.deliveryMode;
    if (mode == null) return '还没有选择寄往何处';

    final texts = [
      for (final block in state.blocks)
        if (block is WriteTextBlock) block.text,
    ];
    final total = texts.fold<int>(0, (sum, text) => sum + text.length);
    if (total == 0) return '信还没有写';
    if (total > Env.letterMaxChars) {
      return '一封信最多写 ${Env.letterMaxChars} 字，现在有 $total 字';
    }
    for (final text in texts) {
      if (text.length > Env.textBlockMaxChars) {
        return '一个段落最多 ${Env.textBlockMaxChars} 字';
      }
    }
    final contentBlocks = _contentBlocks().length;
    if (contentBlocks > Env.letterMaxBlocks) {
      return '一封信最多 ${Env.letterMaxBlocks} 个段落';
    }
    if (state.photoCount > Env.letterMaxImages) return '一封信最多夹三张照片';
    if (state.signature.length > Env.signatureMaxChars) return '落款太长了';
    if (state.addressee.length > Env.addresseeMaxChars) return '收信人名字太长了';

    final drop = state.dropPoint;
    if (drop?.label != null && drop!.label!.length > Env.placeLabelMaxChars) {
      return '地点名太长了';
    }
    if (mode == DeliveryMode.stay && (drop?.lat == null || drop?.lon == null)) {
      return '留在这里需要先确定一个落点';
    }
    return null;
  }

  /// 提交口径的内容块：空文本段剔除（后端 TextBlock 要求非空）。
  List<WriteBlock> _contentBlocks() => [
    for (final block in state.blocks)
      if (block is WritePhotoBlock ||
          (block is WriteTextBlock && block.text.isNotEmpty))
        block,
  ];

  LetterCreateRequest _buildRequest() {
    final blocks = <LetterBlock>[];
    for (final block in state.blocks) {
      switch (block) {
        case WriteTextBlock(:final text):
          if (text.isNotEmpty) {
            blocks.add(LetterBlock(type: 'text', text: text));
          }
        case WritePhotoBlock(:final remoteUrl):
          if (remoteUrl != null) {
            blocks.add(LetterBlock(type: 'photo', ref: remoteUrl));
          }
      }
    }
    final drop = state.dropPoint;
    return LetterCreateRequest(
      blocks: blocks,
      // P0 固定夏主题默认皮肤；音乐/标签/AI 不进首个闭环（F2 路线图）
      themeId: 'natsu',
      signature: _nullIfBlank(state.signature),
      addressee: _nullIfBlank(state.addressee),
      deliveryMode: state.deliveryMode!,
      lat: drop?.lat,
      lon: drop?.lon,
      placeLabel: drop?.label,
      weather: state.weather,
    );
  }

  // ---------- 草稿持久化 ----------

  void _mutate(WriteState Function(WriteState) change) {
    state = change(state);
    _scheduleSave();
  }

  void _notice(String message) {
    state = state.copyWith(
      notice: (message: message, seq: (state.notice?.seq ?? 0) + 1),
    );
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_persist()),
    );
  }

  /// 有没有「手动填入」的内容：文本、照片、落款、收信人。
  /// 落点与投递方式不算——地点随定位走、模式不算内容，
  /// 只有这些时不存草稿。
  bool get _hasManualContent =>
      state.textCharCount > 0 ||
      state.photoCount > 0 ||
      state.signature.trim().isNotEmpty ||
      state.addressee.trim().isNotEmpty;

  Future<void> _persist() async {
    if (!ref.mounted) return;
    final store = ref.read(draftStoreProvider);
    try {
      if (_hasManualContent) {
        await store.saveJson(_draftKey, _toDraftJson());
      } else {
        // 写满又删光：草稿就该消失，而不是留下一份空壳
        await store.clear(_draftKey);
      }
    } on FileSystemException {
      // 磁盘满/权限异常：草稿尽力而为，不打断写信
    }
  }

  Map<String, Object?> _toDraftJson() {
    return {
      'version': DraftStore.draftVersion,
      'parent': state.parentLetterId,
      'blocks': [
        for (final block in state.blocks)
          switch (block) {
            WriteTextBlock(:final text) => {'kind': 'text', 'text': text},
            WritePhotoBlock(:final localPath, :final remoteUrl) => {
              'kind': 'photo',
              'file': p.basename(localPath),
              'url': ?remoteUrl,
            },
          },
      ],
      'signature': state.signature,
      'addressee': state.addressee,
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _clearDraft() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    final store = ref.read(draftStoreProvider);
    await store.clear(_draftKey);
    await store.deleteImages([
      for (final block in state.blocks)
        if (block is WritePhotoBlock) p.basename(block.localPath),
    ]);
  }
}

String? _nullIfBlank(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _extOf(String mime) => switch (mime) {
  'image/png' => 'png',
  'image/webp' => 'webp',
  _ => 'jpg',
};
