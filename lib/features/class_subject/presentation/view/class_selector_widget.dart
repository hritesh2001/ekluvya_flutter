import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../data/models/class_model.dart';
import '../viewmodel/class_subject_viewmodel.dart';

/// Compact pill button that shows the selected class name.
///
/// Tapping opens a [ModalBottomSheet] listing all available classes.
/// Designed for placement in a dark gradient header — uses white text
/// and a semi-transparent white border so it reads on any dark background.
class ClassSelectorWidget extends StatelessWidget {
  const ClassSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<ClassSubjectViewModel, (ClassModel?, bool)>(
      selector: (_, vm) => (vm.selectedClass, vm.classesLoading),
      builder: (context, data, _) {
        final (selectedClass, isLoading) = data;

        if (isLoading) {
          return _LoadingPill();
        }

        final label = selectedClass?.title ?? 'SELECT CLASS';

        // Design: plain "CLASS 7 ▼" — no border, no background box.
        // White text + chevron on the gradient header.
        return GestureDetector(
          onTap: () => _showClassPicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClassPicker(BuildContext context) {
    final vm = context.read<ClassSubjectViewModel>();
    if (!vm.classesHasData) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _ClassPickerSheet(
        classes: vm.classes,
        selected: vm.selectedClass,
        onSelect: (cls) {
          vm.selectClass(cls);
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
  }
}

// ── Loading pill skeleton ─────────────────────────────────────────────────────

class _LoadingPill extends StatefulWidget {
  @override
  State<_LoadingPill> createState() => _LoadingPillState();
}

class _LoadingPillState extends State<_LoadingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: 90,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _ClassPickerSheet extends StatelessWidget {
  const _ClassPickerSheet({
    required this.classes,
    required this.selected,
    required this.onSelect,
  });

  final List<ClassModel> classes;
  final ClassModel? selected;
  final ValueChanged<ClassModel> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Select Class',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Class list ───────────────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: classes.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final cls = classes[index];
                final isSelected = cls.id == selected?.id;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  title: Text(
                    cls.title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? colors.brand
                          : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                      fontSize: 14,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: colors.brand, size: 20)
                      : null,
                  onTap: () => onSelect(cls),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
