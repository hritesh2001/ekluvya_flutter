import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/subject_item_model.dart';
import '../viewmodel/class_subject_viewmodel.dart';
import 'class_subject_shimmer_widget.dart';

// ── Chip palette (always visible on the orange-purple gradient header) ────────

/// Selected chip: solid white fill, dark label — stands out on gradient.
const Color _selectedBg = Colors.white;
const Color _selectedText = Color(0xFF1A0A2E);

/// Unselected chip: white outline, white label — sits lightly on gradient.
const Color _unselectedBorder = Color(0x80FFFFFF); // 50 % white
const Color _unselectedText = Colors.white;

// ─────────────────────────────────────────────────────────────────────────────

/// Horizontal scrollable subject filter chips.
///
/// Always occupies [_stripHeight] = 48 px, so the header band never
/// collapses whether the state is loading, loaded, error or empty.
///
/// States:
///   • loading / initial → [ClassSubjectShimmerWidget] (white shimmer pills)
///   • error             → inline retry row
///   • loaded + empty    → single "No subjects" stub chip
///   • loaded + data     → tappable animated chips
class SubjectChipsWidget extends StatelessWidget {
  const SubjectChipsWidget({super.key});

  static const double _stripHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return Selector<ClassSubjectViewModel,
        (ClassSubjectLoadState, List<SubjectItemModel>, SubjectItemModel?)>(
      selector: (_, vm) =>
          (vm.subjectsState, vm.subjects, vm.selectedSubject),
      builder: (context, data, _) {
        final (state, subjects, selected) = data;

        return SizedBox(
          height: _stripHeight,
          child: switch (state) {
            // ── Still loading — white shimmer pills ──────────────────
            ClassSubjectLoadState.initial ||
            ClassSubjectLoadState.loading =>
              const ClassSubjectShimmerWidget(),

            // ── Error ────────────────────────────────────────────────
            ClassSubjectLoadState.error => _SubjectErrorRow(
                onRetry: () =>
                    context.read<ClassSubjectViewModel>().retrySubjects(),
              ),

            // ── Loaded ───────────────────────────────────────────────
            ClassSubjectLoadState.loaded => subjects.isEmpty
                ? _EmptyRow()
                : _ChipsRow(
                    subjects: subjects,
                    selected: selected,
                    onSelect: (s) =>
                        context.read<ClassSubjectViewModel>().selectSubject(s),
                  ),
          },
        );
      },
    );
  }
}

// ── Chips row (stateful for the scroll controller) ────────────────────────────

class _ChipsRow extends StatefulWidget {
  const _ChipsRow({
    required this.subjects,
    required this.selected,
    required this.onSelect,
  });

  final List<SubjectItemModel> subjects;
  final SubjectItemModel? selected;
  final ValueChanged<SubjectItemModel> onSelect;

  @override
  State<_ChipsRow> createState() => _ChipsRowState();
}

class _ChipsRowState extends State<_ChipsRow> {
  final ScrollController _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      itemCount: widget.subjects.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final subject = widget.subjects[i];
        final isSelected = subject.id == widget.selected?.id;
        return _SubjectChip(
          label: subject.title,
          isSelected: isSelected,
          onTap: () => widget.onSelect(subject),
        );
      },
    );
  }
}

// ── Single animated chip ──────────────────────────────────────────────────────

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : _unselectedBorder,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _selectedText : _unselectedText,
            fontSize: 12,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ── Fallback states ───────────────────────────────────────────────────────────

class _EmptyRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Center(
        child: Text(
          'No subjects available',
          style: TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SubjectErrorRow extends StatelessWidget {
  const _SubjectErrorRow({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Could not load subjects',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
