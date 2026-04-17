import '../../data/models/badge_model.dart';

abstract class BadgeRepository {
  Future<List<ChannelBadgeData>> getChapterBadges({
    required String courseId,
    required String chapterId,
  });
}
