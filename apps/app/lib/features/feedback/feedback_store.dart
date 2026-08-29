/// 反馈页状态：类型单选 + 正文 + 提交生命周期。
///
/// 手写 Notifier（项目惯例，无 codegen）；成功后 submitted=true，
/// 页面切换到确认态，由用户点「好的」返回设置页。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../data/api/feedback_api.dart';
import '../../data/api/providers.dart';

class FeedbackState {
  const FeedbackState({
    this.category = FeedbackCategory.bug,
    this.content = '',
    this.submitting = false,
    this.submitted = false,
    this.errorMessage,
  });

  final FeedbackCategory category;
  final String content;
  final bool submitting;
  final bool submitted;

  /// 提交失败的可读原因；null = 无错误。
  final String? errorMessage;

  bool get canSubmit => content.trim().isNotEmpty && !submitting && !submitted;

  FeedbackState copyWith({
    FeedbackCategory? category,
    String? content,
    bool? submitting,
    bool? submitted,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FeedbackState(
      category: category ?? this.category,
      content: content ?? this.content,
      submitting: submitting ?? this.submitting,
      submitted: submitted ?? this.submitted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class FeedbackController extends Notifier<FeedbackState> {
  @override
  FeedbackState build() => const FeedbackState();

  void setCategory(FeedbackCategory category) =>
      state = state.copyWith(category: category);

  /// 输入即清错：让用户改完立刻能重试，而不是对着旧错误发呆。
  void setContent(String value) =>
      state = state.copyWith(content: value, clearError: true);

  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(submitting: true, clearError: true);
    try {
      await ref
          .read(feedbackApiProvider)
          .submit(category: state.category, content: state.content.trim());
      state = state.copyWith(submitting: false, submitted: true);
    } on ApiFailure catch (error) {
      state = state.copyWith(submitting: false, errorMessage: error.message);
    }
  }
}

final feedbackProvider = NotifierProvider<FeedbackController, FeedbackState>(
  FeedbackController.new,
);
