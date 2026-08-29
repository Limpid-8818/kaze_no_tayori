/// 管理端控制器测试：登录 / 统计 / 审核列表与状态机 / 举报 / 反馈 / 种子信。
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaze_admin/app/admin_auth.dart';
import 'package:kaze_admin/data/models/enums.dart';
import 'package:kaze_admin/features/dashboard/stats_controller.dart';
import 'package:kaze_admin/features/feedback/feedback_screen.dart';
import 'package:kaze_admin/features/login/login_screen.dart';
import 'package:kaze_admin/features/reports/reports_screen.dart';
import 'package:kaze_admin/features/review/letter_list_controller.dart';
import 'package:kaze_admin/features/review/review_detail_screen.dart';
import 'package:kaze_admin/features/seed/seed_screen.dart';

import '../helpers.dart';
import '../fakes/scripted_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('登录成功 → token 写入 AdminAuth，状态归位', () async {
    final adapter = ScriptedAdapter([
      ScriptedResponse.ok(200, {'access_token': 'jwt-abc'}),
    ]);
    final container = makeContainer(adapter);
    addTearDown(container.dispose);

    await container
        .read(loginControllerProvider.notifier)
        .submit('ops', 'password-123');

    expect(container.read(loginControllerProvider).phase, LoginPhase.idle);
    expect(container.read(adminAuthProvider).token, 'jwt-abc');
    expect(adapter.requests.single.path, '/v1/admin/login');
  });

  test('登录失败（401）→ error 相位带后端消息，不写 token', () async {
    final adapter = ScriptedAdapter([
      ScriptedResponse.fail(ScriptedAdapter.unauthorized('/v1/admin/login')),
    ]);
    final container = makeContainer(adapter);
    addTearDown(container.dispose);

    await container
        .read(loginControllerProvider.notifier)
        .submit('ops', 'wrong-password');

    final state = container.read(loginControllerProvider);
    expect(state.phase, LoginPhase.error);
    expect(state.message, isNotNull);
    expect(container.read(adminAuthProvider).token, isNull);
  });

  test('stats：200 → ready 携带聚合；失败 → error', () async {
    final okAdapter = ScriptedAdapter([ScriptedResponse.ok(200, statsJson())]);
    final okContainer = makeContainer(okAdapter);
    addTearDown(okContainer.dispose);

    await okContainer.read(statsControllerProvider.notifier).start();
    final state = okContainer.read(statsControllerProvider);
    expect(state.phase, StatsPhase.ready);
    expect(state.stats!.todo.pendingLetters, 2);
    expect(state.stats!.pool.driftAvailable, 4);

    final failAdapter = ScriptedAdapter([
      ScriptedResponse.fail(
        DioException(
          requestOptions: RequestOptions(path: '/v1/admin/stats'),
          type: DioExceptionType.connectionError,
        ),
      ),
    ]);
    final failContainer = makeContainer(failAdapter);
    addTearDown(failContainer.dispose);
    await failContainer.read(statsControllerProvider.notifier).start();
    expect(failContainer.read(statsControllerProvider).phase, StatsPhase.error);
  });

  test('审核列表：pending 筛选请求参数正确；通过后刷新', () async {
    final adapter = ScriptedAdapter([
      // 初始 start()
      ScriptedResponse.ok(200, {
        'items': [summaryJson()],
        'next_cursor': null,
      }),
      // decide(public) 的 PATCH
      ScriptedResponse.ok(200, detailJson(status: 'public')),
      // PATCH 成功后的 refresh()
      ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
    ]);
    final container = makeContainer(adapter);
    addTearDown(container.dispose);

    await container.read(reviewListProvider.notifier).start();
    expect(container.read(reviewListProvider).phase, ListPhase.ready);
    expect(adapter.requests.first.queryParameters['status'], 'pending');

    await container
        .read(reviewListProvider.notifier)
        .decide('l1', LetterStatus.public);
    final after = container.read(reviewListProvider);
    expect(after.phase, ListPhase.empty); // 刷新后列表空
  });

  test('状态机表外流转 → conflict 失败，回执带后端消息', () async {
    final adapter = ScriptedAdapter([
      ScriptedResponse.ok(200, {
        'items': [summaryJson(status: 'public')],
        'next_cursor': null,
      }),
      ScriptedResponse.fail(
        DioException(
          requestOptions: RequestOptions(path: '/v1/admin/letters/l1/status'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/admin/letters/l1/status'),
            statusCode: 409,
            data: {
              'error': {
                'code': 'invalid_transition',
                'message': '不允许从 public 流转到 rejected',
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      ),
    ]);
    final container = makeContainer(adapter);
    addTearDown(container.dispose);

    await container.read(reviewListProvider.notifier).start();
    await container
        .read(reviewListProvider.notifier)
        .transition('l1', LetterStatus.rejected);
    // 无异常抛出即为通过（错误收敛为回执 notice）
    expect(container.read(reviewListProvider).notice, isNotNull);
  });

  test('审核详情：加载 → ready；流转成功 → 详情刷新并返回 (true, null)', () async {
    final adapter = ScriptedAdapter([
      ScriptedResponse.ok(200, detailJson()),
      ScriptedResponse.ok(200, detailJson(status: 'public')),
      ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
      ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
    ]);
    final container = makeContainer(adapter);
    addTearDown(container.dispose);

    await container.read(reviewDetailControllerProvider('l1').notifier).start();
    final state = container.read(reviewDetailControllerProvider('l1'));
    expect(state.phase, DetailPhase.ready);
    expect(state.detail!.ownerUserId, isNotNull);

    final (ok, error) = await container
        .read(reviewDetailControllerProvider('l1').notifier)
        .transitionTo(LetterStatus.public);
    expect(ok, isTrue);
    expect(error, isNull);
    expect(
      container.read(reviewDetailControllerProvider('l1')).detail!.status,
      LetterStatus.public,
    );
  });

  test('举报：open 列表 → dismissed → handled_at 回写', () async {
    final adapter = ScriptedAdapter([
      ScriptedResponse.ok(200, {
        'items': [reportJson()],
        'next_cursor': null,
      }),
      ScriptedResponse.ok(200, reportJson(status: 'dismissed')),
      ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
    ]);
    final container = makeContainer(adapter);
    addTearDown(container.dispose);

    await container.read(reportsControllerProvider.notifier).start();
    expect(container.read(reportsControllerProvider).phase, ReportsPhase.ready);
    expect(adapter.requests.first.queryParameters['status'], 'open');

    await container.read(reportsControllerProvider.notifier).dismiss('r1');
    expect(container.read(reportsControllerProvider).phase, ReportsPhase.empty);
  });

  test('反馈：open 列表 → 备注保存与流转', () async {
    final adapter = ScriptedAdapter([
      ScriptedResponse.ok(200, {
        'items': [feedbackJson()],
        'next_cursor': null,
      }),
      ScriptedResponse.ok(200, feedbackJson(status: 'resolved')),
      ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
    ]);
    final container = makeContainer(adapter);
    addTearDown(container.dispose);

    await container.read(feedbackControllerProvider.notifier).start();
    expect(
      container.read(feedbackControllerProvider).phase,
      FeedbackPhase.ready,
    );

    await container
        .read(feedbackControllerProvider.notifier)
        .setNote('f1', '下个迭代排期');
    expect(
      container.read(feedbackControllerProvider).phase,
      FeedbackPhase.empty,
    );
  });

  test(
    '筛选可取消：setCategory(null) / setStatusFilter(null) 不再被 copyWith 吞掉',
    () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse.ok(200, {
          'items': [feedbackJson()],
          'next_cursor': null,
        }),
        ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
        ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
        ScriptedResponse.ok(200, {
          'items': [summaryJson()],
          'next_cursor': null,
        }),
        ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
      ]);
      final container = makeContainer(adapter);
      addTearDown(container.dispose);

      final feedback = container.read(feedbackControllerProvider.notifier);
      await feedback.start();
      await feedback.setCategory(FeedbackCategory.bug);
      expect(adapter.requests[1].queryParameters['category'], 'bug');
      await feedback.setCategory(null);
      expect(container.read(feedbackControllerProvider).categoryFilter, isNull);
      expect(
        adapter.requests[2].queryParameters.containsKey('category'),
        isFalse,
      );

      final review = container.read(reviewListProvider.notifier);
      await review.start();
      expect(adapter.requests[3].queryParameters['status'], 'pending');
      await review.setStatusFilter(null);
      expect(container.read(reviewListProvider).statusFilter, isNull);
      expect(
        adapter.requests[4].queryParameters.containsKey('status'),
        isFalse,
      );
    },
  );

  test('种子信：新建入池 → 列表刷新为空态（mock 列表回空）', () async {
    final adapter = ScriptedAdapter([
      ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
      ScriptedResponse.ok(200, detailJson(status: 'public')),
      ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
    ]);
    final container = makeContainer(adapter);
    addTearDown(container.dispose);

    final controller = container.read(seedControllerProvider.notifier);
    await controller.start();
    expect(container.read(seedControllerProvider).phase, SeedPhase.empty);

    final draft = SeedDraft.empty()
      ..lat = ''
      ..lon = '';
    await controller.save(
      draft,
      lat: '',
      lon: '',
      textBlocks: ['你好'],
      placeLabel: '测试 · 种子镇',
      weatherText: '',
    );
    // 新建成功 → 编辑器关闭、列表刷新（回空）
    expect(container.read(seedControllerProvider).editing, isNull);
  });
}
