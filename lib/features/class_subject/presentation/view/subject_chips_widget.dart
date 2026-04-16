import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/subject_item_model.dart';
import '../viewmodel/class_subject_viewmodel.dart';
import 'class_subject_shimmer_widget.dart';

// ── Brand gradient colours ────────────────────────────────────────────────────
const Color _gradPink   = Color(0xFFE91E63);
const Color _gradOrange = Color(0xFFFF5722);

// ─────────────────────────────────────────────────────────────────────────────

/// Horizontally scrollable subject filter chips.
///
/// UX pattern (education-app best practice):
///   • Chips are content-sized — full subject name, no truncation.
///   • User can swipe naturally OR tap the arrow buttons (scroll-by-amount).
///   • Left/right edge fade hints that more chips exist off-screen.
///   • Selected chip auto-scrolls to centre on each selection change.
///   • All touch targets ≥ 44 × 44 px (WCAG / Material / Apple HIG).
///
/// Selected  → white capsule, gradient text (pink → orange).
/// Unselected → transparent capsule, white border (1.8 px), white text.
class SubjectChipsWidget extends StatelessWidget {
  const SubjectChipsWidget({super.key});

  static const double _stripHeight = 44.0;

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
            ClassSubjectLoadState.initial ||
            ClassSubjectLoadState.loading =>
              const ClassSubjectShimmerWidget(),

            ClassSubjectLoadState.error => _SubjectErrorRow(
                onRetry: () =>
                    context.read<ClassSubjectViewModel>().retrySubjects(),
              ),

            ClassSubjectLoadState.loaded => subjects.isEmpty
                ? const _EmptyRow()
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

// ── Chips row — free-scroll with arrow-scroll helpers ─────────────────────────

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

  // One GlobalKey per subject so we can scroll it into view.
  late final List<GlobalKey> _chipKeys;

  // How far the arrows scroll per tap (roughly one chip width).
  static const double _scrollStep = 96.0;

  @override
  void initState() {
    super.initState();
    _chipKeys = List.generate(widget.subjects.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(_ChipsRow old) {
    super.didUpdateWidget(old);
    // New subjects list — rebuild keys.
    if (old.subjects.length != widget.subjects.length) {
      _chipKeys
        ..clear()
        ..addAll(
            List.generate(widget.subjects.length, (_) => GlobalKey()));
    }
    // Selected chip changed — bring it into view.
    if (old.selected?.id != widget.selected?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    final idx =
        widget.subjects.indexWhere((s) => s.id == widget.selected?.id);
    if (idx < 0 || idx >= _chipKeys.length) return;
    final ctx = _chipKeys[idx].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5, // centre the chip in the viewport
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _scrollBy(double delta) {
    if (!_ctrl.hasClients) return;
    _ctrl.animateTo(
      (_ctrl.offset + delta).clamp(0.0, _ctrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left arrow ──────────────────────────────────────────────────
        _ArrowButton(
          icon: Icons.chevron_left_rounded,
          onTap: () => _scrollBy(-_scrollStep),
        ),

        // ── Scrollable chip list with fade edges ────────────────────────
        Expanded(
          child: ShaderMask(
            // Fade 14 px on each edge to hint there's more content.
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.06, 0.94, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ListView.separated(
              controller: _ctrl,
              scrollDirection: Axis.horizontal,
              // Horizontal padding gives space for the fade zone.
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              physics: const BouncingScrollPhysics(),
              itemCount: widget.subjects.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final subject = widget.subjects[i];
                return KeyedSubtree(
                  key: _chipKeys[i],
                  child: _SubjectChip(
                    label: subject.title,
                    isSelected: subject.id == widget.selected?.id,
                    onTap: () => widget.onSelect(subject),
                  ),
                );
              },
            ),
          ),
        ),

        // ── Right arrow ─────────────────────────────────────────────────
        _ArrowButton(
          icon: Icons.chevron_right_rounded,
          onTap: () => _scrollBy(_scrollStep),
        ),
      ],
    );
  }
}

// ── Arrow scroll-hint button ──────────────────────────────────────────────────

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // opaque so transparent pixels inside the box still register taps
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,   // meets 44 px minimum touch target
        height: SubjectChipsWidget._stripHeight,
        child: Center(
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

// ── Single animated capsule chip ──────────────────────────────────────────────

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool   isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          // Height fills the row; no fixed width — chip sizes to label.
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(50), // full capsule
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 2.5 : 1.8,
            ),
          ),
          alignment: Alignment.center,
          child: _ChipLabel(label: label, isSelected: isSelected),
        ),
      ),
    );
  }
}

// ── Label: gradient text on selected, plain white on unselected ───────────────

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label, required this.isSelected});

  final String label;
  final bool   isSelected;

  static const _textGradient = LinearGradient(
    colors: [_gradPink, _gradOrange],
  );

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: 0.3,
      color: Colors.white, // base colour required for ShaderMask
    );

    if (!isSelected) {
      return Text(label, style: style);
    }

    return ShaderMask(
      shaderCallback: (bounds) => _textGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(label, style: style),
    );
  }
}

// ── Fallback states ───────────────────────────────────────────────────────────

class _EmptyRow extends StatelessWidget {
  const _EmptyRow();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No subjects available',
        style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Could not load subjects',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38),
                borderRadius: BorderRadius.circular(50),
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
