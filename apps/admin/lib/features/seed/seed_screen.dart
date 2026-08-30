/// 种子信件管理：列表 / 新建 / 编辑（实时预览）/ 下架恢复。
///
/// 编辑器 = blocks（文本块 + 图片块经 uploads）+ 落点 + 天气 + 投放方式。
/// 右栏实时预览用合成 AdminLetterDetail 走 LetterReading 同源口径。
/// theme 绑定红线：新建固定 natsu 默认皮肤，编辑不给改。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/models/admin.dart';
import '../../data/models/enums.dart';
import '../../shared/letter_preview_panel.dart';
import '../../shared/widgets.dart' show confirmAction, showNotice;
import 'image_picker_gateway.dart';

enum SeedPhase { loading, ready, empty, error }

/// AI 辅助类型（与 apps/app 写信页同款语义：候选预览，采纳才生效）。
enum AiAssistKind { polish, poem }

/// 短诗候选校验：压成非空行列表；行数超过 4（俳句体裁上限）视为废稿。
/// 返回 null = 不可采纳。
List<String>? validatePoemCandidate(String raw) {
  final lines = raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty || lines.length > 4) return null;
  return lines;
}

class SeedListState {
  const SeedListState({
    this.phase = SeedPhase.loading,
    this.items = const [],
    this.editing, // null = 列表态；SeedDraft.empty() = 新建
    this.notice,
  });

  final SeedPhase phase;
  final List<AdminLetterSummary> items;

  /// 编辑中的草稿（新建与编辑共用）。
  final SeedDraft? editing;
  final ({String message, int seq})? notice;

  SeedListState copyWith({
    SeedPhase? phase,
    List<AdminLetterSummary>? items,
    SeedDraft? editing,
    bool closeEditor = false,
    ({String message, int seq})? notice,
  }) => SeedListState(
    phase: phase ?? this.phase,
    items: items ?? this.items,
    editing: closeEditor ? null : (editing ?? this.editing),
    notice: notice,
  );
}

/// 编辑器草稿（与 API 形状解耦）。
class SeedDraft {
  SeedDraft({
    this.id,
    List<String>? textBlocks,
    List<String>? photoRefs,
    this.deliveryMode = DeliveryMode.drift,
    this.lat = '',
    this.lon = '',
    this.placeLabel = '',
    this.weatherText = '',
    this.createdAtText = '',
    this.poem,
  }) : textBlocks = textBlocks ?? [''],
       photoRefs = photoRefs ?? [];

  SeedDraft.empty() : this();

  /// 从详情装载（编辑态）。
  factory SeedDraft.fromDetail(AdminLetterDetail d) {
    final texts = [
      for (final b in d.blocks)
        if (b.type == 'text') b.text ?? '',
    ];
    final photos = [
      for (final b in d.blocks)
        if (b.type == 'photo') b.ref ?? '',
    ];
    return SeedDraft(
      id: d.id,
      textBlocks: texts,
      photoRefs: photos,
      deliveryMode: d.deliveryMode,
      lat: d.lat?.toStringAsFixed(6) ?? '',
      lon: d.lon?.toStringAsFixed(6) ?? '',
      placeLabel: d.placeLabel ?? '',
      weatherText: d.weather?.text ?? '',
      createdAtText: _formatCreatedAt(d.createdAt),
      poem: _nonBlank(d.poem),
    );
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  final String? id;
  final List<String> textBlocks;
  final List<String> photoRefs;
  DeliveryMode deliveryMode;
  String lat;
  String lon;
  String placeLabel;
  String weatherText;

  /// 已采纳的 AI 短诗（null = 无诗；编辑态从详情装载，随保存提交）。
  String? poem;

  /// 落款时间原文（YYYY-MM-DD HH:mm；空 = 现在落笔）。
  String createdAtText;

  bool get isNew => id == null;

  /// blocks 非空（至少 1 块）由 UI 保证；照片 ≤3 在保存时校验。
  bool get canSave =>
      textBlocks.any((t) => t.trim().isNotEmpty) || photoRefs.isNotEmpty;
}

/// 'YYYY-MM-DD HH:mm' → 本地 DateTime；空返回 null；格式错抛 FormatException。
DateTime? _parseCreatedAt(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})(?: (\d{1,2}):(\d{2}))?$')
      .firstMatch(text);
  if (m == null) {
    throw const FormatException('落款时间格式应为 YYYY-MM-DD HH:mm');
  }
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4) ?? '0'),
    int.parse(m.group(5) ?? '0'),
  );
}

/// 本地时间 → 'YYYY-MM-DD HH:mm'（分钟粒度，与信纸 meta「只到日 + 时段」口径对齐）。
String _formatCreatedAt(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

/// 本地时间 → 带时区偏移的 ISO（后端 pydantic 可解析 aware datetime）。
String _toIsoWithOffset(DateTime dt) {
  final off = dt.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.toIso8601String()}$sign${two(off.inHours.abs())}${two(off.inMinutes % 60)}';
}

class SeedController extends Notifier<SeedListState> {
  int _noticeSeq = 0;

  @override
  SeedListState build() => const SeedListState();

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
  }

  void _notify(String message) {
    _noticeSeq += 1;
    state = state.copyWith(notice: (message: message, seq: _noticeSeq));
  }

  Future<void> refresh() async {
    try {
      final page = await ref.read(adminApiProvider).seedLetters();
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: page.items.isEmpty ? SeedPhase.empty : SeedPhase.ready,
        items: page.items,
      );
    } on ApiFailure {
      if (!ref.mounted) return;
      state = state.copyWith(phase: SeedPhase.error);
    }
  }

  void openCreate() {
    state = state.copyWith(editing: SeedDraft.empty());
  }

  void openEdit(AdminLetterSummary item) async {
    try {
      final detail = await ref.read(adminApiProvider).letter(item.id);
      if (!ref.mounted) return;
      state = state.copyWith(editing: SeedDraft.fromDetail(detail));
    } on ApiFailure catch (e) {
      _notify(e.message);
    }
  }

  void closeEditor() {
    state = state.copyWith(closeEditor: true);
  }

  Future<void> save(
    SeedDraft draft, {
    required String lat,
    required String lon,
    required List<String> textBlocks,
    required String placeLabel,
    required String weatherText,
    String? poem,
    DateTime? createdAt,
  }) async {
    final photos = draft.photoRefs.length;
    if (photos > 3) {
      _notify('一封信最多夹三张照片');
      return;
    }
    if (draft.deliveryMode == DeliveryMode.stay &&
        (double.tryParse(lat) == null || double.tryParse(lon) == null)) {
      _notify('「留在这里」需要有效的经纬度');
      return;
    }

    final body = <String, dynamic>{
      'blocks': [
        for (final t in textBlocks)
          if (t.trim().isNotEmpty) {'type': 'text', 'text': t.trim()},
        for (final ref in draft.photoRefs) {'type': 'photo', 'ref': ref},
      ],
      'delivery_mode': draft.deliveryMode.name,
      // 地名/天气/短诗由编辑器 controller 传入（draft 上的同名字段不随输入更新）
      'place_label': placeLabel.isEmpty ? null : placeLabel,
      'weather': weatherText.isEmpty ? null : {'text': weatherText},
      'poem': (poem == null || poem.trim().isEmpty) ? null : poem.trim(),
      if (draft.deliveryMode == DeliveryMode.stay) 'lat': double.parse(lat),
      if (draft.deliveryMode == DeliveryMode.stay) 'lon': double.parse(lon),
      if (createdAt != null) 'created_at': _toIsoWithOffset(createdAt),
    };

    try {
      if (draft.isNew) {
        await ref.read(adminApiProvider).createSeedLetter(body);
        _notify('种子信已入池');
      } else {
        await ref.read(adminApiProvider).updateSeedLetter(draft.id!, body);
        _notify('种子信已更新');
      }
      if (!ref.mounted) return;
      state = state.copyWith(closeEditor: true);
      await refresh();
    } on ApiFailure catch (e) {
      _notify(e.message);
    }
  }

  Future<void> takeDown(String id) async {
    try {
      await ref
          .read(adminApiProvider)
          .transitionLetter(id, LetterStatus.takenDown);
      _notify('已下架');
      await refresh();
    } on ApiFailure catch (e) {
      _notify(e.message);
    }
  }

  Future<void> restore(String id) async {
    try {
      await ref
          .read(adminApiProvider)
          .transitionLetter(id, LetterStatus.public);
      _notify('已恢复公开');
      await refresh();
    } on ApiFailure catch (e) {
      _notify(e.message);
    }
  }

  /// Web 文件选择 → uploads → 返回 URL（管理端传图，uploads 双身份已放宽）。
  Future<String?> pickAndUploadImage() async {
    final picked = await ref.read(imagePickerBridgeProvider).pickImage();
    if (picked == null) return null;
    return ref
        .read(adminApiProvider)
        .uploadImage(
          filename: picked.filename,
          bytes: picked.bytes,
          contentType: picked.contentType,
        );
  }
}

/// 图片选择桥 provider（平台经条件导出决定）。
final imagePickerBridgeProvider = Provider<ImagePickerBridge>(
  (ref) => createImagePickerBridge(),
);

final seedControllerProvider = NotifierProvider<SeedController, SeedListState>(
  SeedController.new,
);

class SeedScreen extends ConsumerStatefulWidget {
  const SeedScreen({super.key});

  @override
  ConsumerState<SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends ConsumerState<SeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(seedControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(seedControllerProvider);

    ref.listen<SeedListState>(seedControllerProvider, (prev, next) {
      final n = next.notice;
      if (n != null && prev?.notice?.seq != n.seq) {
        showNotice(context, n.message);
      }
    });

    final editing = state.editing;
    if (editing != null) {
      return SeedEditor(draft: editing);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('种子信件'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () =>
                  ref.read(seedControllerProvider.notifier).openCreate(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建种子信'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: switch (state.phase) {
                SeedPhase.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                SeedPhase.empty => const Center(child: Text('池里还没有种子信')),
                SeedPhase.error => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('列表加载失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.read(seedControllerProvider.notifier).refresh(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
                SeedPhase.ready => ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, i) {
                    final item = state.items[i];
                    final takenDown = item.status == LetterStatus.takenDown;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          item.preview ?? '（纯照片信）',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${item.deliveryMode == DeliveryMode.stay ? '留' : '投'} · '
                          '${item.placeLabel ?? '无落点'} · '
                          '${item.createdAt.month}月${item.createdAt.day}日',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              takenDown ? '已下架' : '公开中',
                              style: TextStyle(
                                color: takenDown
                                    ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () => ref
                                  .read(seedControllerProvider.notifier)
                                  .openEdit(item),
                              child: const Text('编辑'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final controller = ref.read(
                                  seedControllerProvider.notifier,
                                );
                                if (takenDown) {
                                  await controller.restore(item.id);
                                } else {
                                  final ok = await confirmAction(
                                    context,
                                    title: '下架这封种子信？',
                                    message: '下架后不再入池，可随时恢复。',
                                    confirmLabel: '下架',
                                    destructive: true,
                                  );
                                  if (ok) await controller.takeDown(item.id);
                                }
                              },
                              child: Text(takenDown ? '恢复' : '下架'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 编辑器：左表单 + 右实时预览。
class SeedEditor extends ConsumerStatefulWidget {
  const SeedEditor({super.key, required this.draft});

  final SeedDraft draft;

  @override
  ConsumerState<SeedEditor> createState() => _SeedEditorState();
}

class _SeedEditorState extends ConsumerState<SeedEditor> {
  late SeedDraft _draft;
  final List<TextEditingController> _blockControllers = [];
  final _placeController = TextEditingController();
  final _weatherController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _createdAtController = TextEditingController();
  bool _uploading = false;

  // AI 辅助（采纳制）：候选只在预览弹窗里，采纳才写回正文/短诗。
  String? _poem;
  AiAssistKind? _aiBusy;
  bool _aiUnavailable = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _poem = _draft.poem;
    for (final text in _draft.textBlocks) {
      _blockControllers.add(TextEditingController(text: text));
    }
    if (_blockControllers.isEmpty) {
      _blockControllers.add(TextEditingController());
    }
    _placeController.text = _draft.placeLabel;
    _weatherController.text = _draft.weatherText;
    _latController.text = _draft.lat;
    _lonController.text = _draft.lon;
    _createdAtController.text = _draft.createdAtText;
    // 右栏实时预览消费这些字段，输入时触发重建
    for (final c in [
      _placeController,
      _weatherController,
      _createdAtController,
    ]) {
      c.addListener(_onMetaChanged);
    }
  }

  void _onMetaChanged() {
    if (mounted) setState(() {});
  }

  // ---------- AI 辅助（采纳制，与 apps/app 写信页同款语义） ----------

  /// 非空文本块（下标 → 原文），润色按块独立请求，采纳时逐块替换。
  Map<int, String> get _nonEmptyTexts => {
    for (var i = 0; i < _blockControllers.length; i++)
      if (_blockControllers[i].text.trim().isNotEmpty)
        i: _blockControllers[i].text,
  };

  String get _plainText =>
      _nonEmptyTexts.values.map((t) => t.trim()).join('\n\n');

  Future<void> _suggestPolish() async {
    if (_aiBusy != null || _aiUnavailable) return;
    final texts = _nonEmptyTexts;
    if (texts.isEmpty) {
      showNotice(context, '先写一点正文，再请 AI 帮忙润色');
      return;
    }
    final total = texts.values.fold<int>(0, (sum, t) => sum + t.length);
    if (total > Env.letterMaxChars) {
      showNotice(context, '正文太长了，精简到 ${Env.letterMaxChars} 字以内再润色');
      return;
    }

    setState(() => _aiBusy = AiAssistKind.polish);
    final polished = <int, String>{};
    try {
      final api = ref.read(adminApiProvider);
      for (final entry in texts.entries) {
        final value = (await api.polish(entry.value)).trim();
        if (value.isEmpty || value.length > Env.letterMaxChars) {
          if (mounted) showNotice(context, '这次润色没有得到可采纳的结果');
          return;
        }
        polished[entry.key] = value;
      }
    } on ApiFailure catch (e) {
      if (mounted) _handleAiFailure(e);
      return;
    } finally {
      if (mounted) setState(() => _aiBusy = null);
    }

    final totalPolished = polished.values.fold<int>(
      0,
      (sum, value) => sum + value.length,
    );
    if (totalPolished > Env.letterMaxChars) {
      if (mounted) showNotice(context, '这次润色后的正文太长了，没有采纳');
      return;
    }
    if (!mounted) return;
    await _showAiSuggestion(
      title: '润色后的正文',
      content: polished.values.join('\n\n'),
      onAdopt: () {
        // 采纳前校验原文未被改动，改过则整体作废（不把半封润色混进原文）。
        final unchanged = polished.entries.every(
          (entry) => _blockControllers[entry.key].text == texts[entry.key],
        );
        if (!unchanged) {
          showNotice(context, '正文已经改过了，请重新润色');
          return;
        }
        setState(() {
          for (final entry in polished.entries) {
            _blockControllers[entry.key].text = entry.value;
          }
        });
        showNotice(context, '已采纳润色，仍可以继续修改');
      },
    );
  }

  Future<void> _suggestPoem() async {
    if (_aiBusy != null || _aiUnavailable) return;
    final source = _plainText;
    if (source.isEmpty) {
      showNotice(context, '先写一点正文，再从里面找一首短诗');
      return;
    }
    if (source.length > Env.letterMaxChars) {
      showNotice(context, '正文太长了，精简到 ${Env.letterMaxChars} 字以内再生成短诗');
      return;
    }

    setState(() => _aiBusy = AiAssistKind.poem);
    List<String>? lines;
    try {
      final raw = await ref.read(adminApiProvider).poem(source);
      lines = validatePoemCandidate(raw);
      if (lines == null && mounted) {
        showNotice(context, '这次没有找到合适的短诗');
      }
    } on ApiFailure catch (e) {
      lines = null;
      if (mounted) _handleAiFailure(e);
    } finally {
      if (mounted) setState(() => _aiBusy = null);
    }
    if (lines == null || !mounted) return;
    final poemText = lines.join('\n');

    await _showAiSuggestion(
      title: '从信里找到的短诗',
      content: poemText,
      poem: true,
      onAdopt: () {
        if (_plainText != source) {
          showNotice(context, '正文已经改过了，请重新生成短诗');
          return;
        }
        setState(() => _poem = poemText);
        showNotice(context, '短诗已夹进信里');
      },
    );
  }

  void _clearPoem() {
    setState(() => _poem = null);
    showNotice(context, '已移除短诗');
  }

  void _handleAiFailure(ApiFailure error) {
    if (error.isDegradable) {
      setState(() => _aiUnavailable = true);
      showNotice(context, 'AI 暂时没有回应，继续手写就好');
      return;
    }
    showNotice(context, error.message);
  }

  Future<void> _showAiSuggestion({
    required String title,
    required String content,
    required VoidCallback onAdopt,
    bool poem = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360, maxWidth: 480),
          child: SingleChildScrollView(
            child: Text(
              content,
              style: poem
                  ? const TextStyle(height: 1.8, fontStyle: FontStyle.italic)
                  : null,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('保留原稿'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onAdopt();
            },
            child: const Text('采纳'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _blockControllers) {
      c.dispose();
    }
    for (final c in [
      _placeController,
      _weatherController,
      _createdAtController,
    ]) {
      c.removeListener(_onMetaChanged);
    }
    _placeController.dispose();
    _weatherController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _createdAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              ref.read(seedControllerProvider.notifier).closeEditor(),
        ),
        title: Text(_draft.isNew ? '新建种子信' : '编辑种子信'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(onPressed: _save, child: const Text('保存')),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左：表单
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('正文块', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _blockControllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _blockControllers[i],
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: '第 ${i + 1} 块',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          IconButton(
                            tooltip: '删除此块',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: _blockControllers.length <= 1
                                ? null
                                : () => setState(() {
                                    _blockControllers.removeAt(i).dispose();
                                  }),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _blockControllers.length >= 20
                          ? null
                          : () => setState(() {
                              _blockControllers.add(TextEditingController());
                            }),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('加一块'),
                    ),
                  ),
                  _AiAssistRow(
                    hasContent: _nonEmptyTexts.isNotEmpty,
                    hasPoem: _poem != null,
                    unavailable: _aiUnavailable,
                    busy: _aiBusy,
                    onPolish: _suggestPolish,
                    onPoem: _suggestPoem,
                    onRemovePoem: _clearPoem,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '照片（≤3，走 uploads）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final ref in _draft.photoRefs)
                        Chip(
                          label: Text(
                            'photo ${ref.length > 24 ? '…${ref.substring(ref.length - 16)}' : ref}',
                          ),
                          onDeleted: () => setState(() {
                            _draft.photoRefs.remove(ref);
                          }),
                        ),
                      InputChip(
                        label: Text(_uploading ? '上传中…' : '＋ 上传图片'),
                        onPressed: _uploading ? null : _upload,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('投放与落点', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<DeliveryMode>(
                    segments: const [
                      ButtonSegment(
                        value: DeliveryMode.drift,
                        label: Text('投递漂流'),
                      ),
                      ButtonSegment(
                        value: DeliveryMode.stay,
                        label: Text('留在原地'),
                      ),
                    ],
                    selected: {_draft.deliveryMode},
                    onSelectionChanged: (s) =>
                        setState(() => _draft.deliveryMode = s.first),
                  ),
                  const SizedBox(height: 8),
                  if (_draft.deliveryMode == DeliveryMode.stay)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '纬度 lat',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lonController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '经度 lon',
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _placeController,
                    decoration: const InputDecoration(labelText: '地点名（可选）'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _weatherController,
                    decoration: const InputDecoration(
                      labelText: '天气（可选，如「小雨」）',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _createdAtController,
                    decoration: const InputDecoration(
                      labelText: '落款时间（可选，YYYY-MM-DD HH:mm）',
                      hintText: '留空 = 现在落笔；种子信常回溯到过去更有年代感',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // 右：实时预览
          Expanded(
            flex: 2,
            child: LetterPreviewPanel(detail: _syntheticDetail()),
          ),
        ],
      ),
    );
  }

  /// 表单态 → 合成详情（仅供预览渲染；不落库）。
  DateTime? _tryParseCreatedAt() {
    try {
      return _parseCreatedAt(_createdAtController.text);
    } on FormatException {
      return null;
    }
  }

  AdminLetterDetail _syntheticDetail() {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    final weatherText = _weatherController.text.trim();
    final poem = _poem?.trim();
    return AdminLetterDetail(
      id: _draft.id ?? 'preview',
      blocks: [
        for (final c in _blockControllers)
          if (c.text.trim().isNotEmpty)
            AdminBlock(type: 'text', text: c.text.trim()),
        for (final ref in _draft.photoRefs) AdminBlock(type: 'photo', ref: ref),
      ],
      themeId: 'natsu',
      deliveryMode: _draft.deliveryMode,
      placeLabel: _placeController.text.trim().isEmpty
          ? null
          : _placeController.text.trim(),
      weather: weatherText.isEmpty ? null : AdminWeather(text: weatherText),
      counts: const LetterCounts(),
      createdAt: _tryParseCreatedAt() ?? DateTime.now(),
      status: LetterStatus.public,
      lat: lat,
      lon: lon,
      poem: (poem == null || poem.isEmpty) ? null : poem,
    );
  }

  Future<void> _upload() async {
    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(seedControllerProvider.notifier)
          .pickAndUploadImage();
      if (url != null && mounted) {
        setState(() => _draft.photoRefs.add(url));
      }
    } on ApiFailure catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final createdAtText = _createdAtController.text.trim();
    if (createdAtText.isNotEmpty) {
      try {
        _parseCreatedAt(createdAtText);
      } on FormatException catch (e) {
        if (mounted) showNotice(context, e.message);
        return;
      }
    }
    final ok = await confirmAction(
      context,
      title: _draft.isNew ? '入池这封种子信？' : '保存修改？',
      message: _draft.isNew ? '保存后直接公开入池，App 用户即可抽到。' : '修改立即生效，对已读到旧版的读者不回溯。',
      confirmLabel: _draft.isNew ? '入池' : '保存',
    );
    if (!ok) return;
    await ref
        .read(seedControllerProvider.notifier)
        .save(
          _draft,
          lat: _latController.text.trim(),
          lon: _lonController.text.trim(),
          textBlocks: [for (final c in _blockControllers) c.text],
          placeLabel: _placeController.text.trim(),
          weatherText: _weatherController.text.trim(),
          poem: _poem,
          createdAt: _tryParseCreatedAt(),
        );
  }
}

/// 种子信编辑器的 AI 辅助入口（与 apps/app 写信页 _AiAssistBar 同款语义：
/// 候选先预览、用户明确采纳；这里只呈现状态与动作，不直接调接口）。
class _AiAssistRow extends StatelessWidget {
  const _AiAssistRow({
    required this.hasContent,
    required this.hasPoem,
    required this.unavailable,
    required this.busy,
    required this.onPolish,
    required this.onPoem,
    required this.onRemovePoem,
  });

  final bool hasContent;
  final bool hasPoem;
  final bool unavailable;
  final AiAssistKind? busy;
  final VoidCallback onPolish;
  final VoidCallback onPoem;
  final VoidCallback onRemovePoem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (unavailable) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('AI 暂时没有回应，继续手写就好', style: theme.textTheme.bodySmall),
      );
    }

    final enabled = hasContent && busy == null;
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: enabled ? onPolish : null,
            icon: busy == AiAssistKind.polish
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_outlined, size: 18),
            label: Text(busy == AiAssistKind.polish ? '正在润色…' : 'AI 润色'),
          ),
          OutlinedButton.icon(
            onPressed: enabled ? onPoem : null,
            icon: busy == AiAssistKind.poem
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.format_quote_outlined, size: 18),
            label: Text(
              busy == AiAssistKind.poem
                  ? '正在找诗…'
                  : hasPoem
                  ? '重写短诗'
                  : '生成短诗',
            ),
          ),
          if (hasPoem)
            TextButton(
              onPressed: busy == null ? onRemovePoem : null,
              child: const Text('移除短诗'),
            ),
        ],
      ),
    );
  }
}
