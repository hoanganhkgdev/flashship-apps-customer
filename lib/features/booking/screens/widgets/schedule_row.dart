import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ScheduleRow extends StatefulWidget {
  final ValueChanged<DateTime?> onChanged;
  const ScheduleRow({super.key, required this.onChanged});

  @override
  State<ScheduleRow> createState() => _ScheduleRowState();
}

class _ScheduleRowState extends State<ScheduleRow> {
  bool _enabled = false;
  DateTime? _scheduled;

  Future<void> _pick() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (dt.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thời gian đặt lịch phải cách hiện tại ít nhất 5 phút')),
      );
      return;
    }
    setState(() => _scheduled = dt);
    widget.onChanged(dt);
  }

  void _toggle(bool value) {
    setState(() {
      _enabled   = value;
      _scheduled = null;
    });
    widget.onChanged(null);
    if (value) _pick();
  }

  String get _label {
    if (_scheduled == null) return 'Chọn thời gian';
    final d = _scheduled!;
    return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}  ${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _enabled
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _enabled ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggle(!_enabled),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: _enabled ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đặt lịch trước',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _enabled ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _enabled,
                  onChanged: _toggle,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                ),
              ]),
            ),
          ),
          if (_enabled) ...[
            Divider(height: 1, color: AppColors.primary.withValues(alpha: 0.15)),
            InkWell(
              onTap: _pick,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    _label,
                    style: TextStyle(
                      fontSize: 14,
                      color: _scheduled != null ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: _scheduled != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
