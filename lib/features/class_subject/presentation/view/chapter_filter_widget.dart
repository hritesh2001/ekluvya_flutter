import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/chapter_model.dart';
import '../viewmodel/class_subject_viewmodel.dart';

// ── Palette — white surface ───────────────────────────────────────────────────

const Color _labelColor = Color(0xFF1A1A1A);
const Color _pillBg   = Color(0xFF1A1A1A);
const Color _pillText = Colors.white;

// ─────────────────────────────────────────────────────────────────────────────

/// Filter bar on the white surface below the gradient header.
///
/// Layout:
///   Chapters   [BASIC MATHEMATICS ▼]
///
/// Displays the selected chapter name as a tappable pill.
/// Tapping opens a bottom sheet listing all chapters from the real API.
class ChapterFilterWidget extends StatelessWidget {
  const ChapterFilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<ClassSubjectViewModel,
        (List<ChapterModel>, ChapterModel?, bool)>(
      selector: (_, vm) =>
          (vm.chapters, vm.selectedChapter, vm.chaptersLoading),
      builder: (context, data, _) {
        final (chapters, selectedChapter, loading) = data;

        return SizedBox(
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── "Chapters" label ──────────────────────────────────
              const Text(
                'Chapters',
                style: TextStyle(
                  color: _labelColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(width: 12),

              // ── Chapter picker pill ───────────────────────────────
              if (loading)
                const _LoadingPill()
              else if (chapters.isNotEmpty)
                _ChapterPill(
                  label: selectedChapter?.title ?? chapters.first.title,
                  onTap: () => _showChapterPicker(
                    context,
                    chapters: chapters,
                    selected: selectedChapter,
                    onSelect: context.read<ClassSubjectViewModel>().selectChapter,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showChapterPicker(
    BuildContext context, {
    required List<ChapterModel> chapters,
    required ChapterModel? selected,
    required ValueChanged<ChapterModel> onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _ChapterPickerSheet(
        chapters: chapters,
        selected: selected,
        onSelect: (ch) {
          onSelect(ch);
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
  }
}

// ── Loading pill ──────────────────────────────────────────────────────────────

class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _pillBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const SizedBox(
        width: 80,
        height: 14,
        child: LinearProgressIndicator(
          backgroundColor: Colors.transparent,
          color: Colors.white54,
        ),
      ),
    );
  }
}

// ── Chapter pill button ───────────────────────────────────────────────────────

class _ChapterPill extends StatelessWidget {
  const _ChapterPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _pillBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _pillText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _pillText,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _ChapterPickerSheet extends StatelessWidget {
  const _ChapterPickerSheet({
    required this.chapters,
    required this.selected,
    required this.onSelect,
  });

  final List<ChapterModel> chapters;
  final ChapterModel? selected;
  final ValueChanged<ChapterModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Chapter',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: chapters.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final ch = chapters[i];
                final isSelected = ch.id == selected?.id;
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    ch.title,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFFE91E63)
                          : const Color(0xFF1A1A1A),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFFE91E63), size: 18)
                      : null,
                  onTap: () => onSelect(ch),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
