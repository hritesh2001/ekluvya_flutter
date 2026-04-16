import '../../data/models/channel_model.dart';

/// Contract between the domain and data layers for channel/partner content.
///
/// The ViewModel depends only on this interface, never on the concrete
/// implementation — enabling easy testing and future data-source swaps.
abstract class ChannelRepository {
  /// Fetches the list of content channels for the given filter combination.
  ///
  /// [chapterId] is optional — pass an empty string to fetch content for
  /// the entire subject without a chapter filter.
  Future<List<ChannelModel>> getChannels({
    required String courseId,
    required String classId,
    required String subjectId,
    String chapterId,
  });
}
