import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class InteractiveTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;

  const InteractiveTimePicker({super.key, required this.initialTime});

  static Future<TimeOfDay?> show(BuildContext context, TimeOfDay initialTime) {
    return showDialog<TimeOfDay>(
      context: context,
      builder: (context) => InteractiveTimePicker(initialTime: initialTime),
    );
  }

  @override
  State<InteractiveTimePicker> createState() => _InteractiveTimePickerState();
}

class _InteractiveTimePickerState extends State<InteractiveTimePicker> {
  bool _use24h = false; // initialized safely; corrected in didChangeDependencies
  late int _selectedHour;
  late int _selectedMinute;
  late int _selectedPeriod; // 0 for AM, 1 for PM

  bool _isEditingHour = false;
  bool _isEditingMinute = false;

  late FixedExtentScrollController _hourScrollController;
  late FixedExtentScrollController _minuteScrollController;
  late FixedExtentScrollController _periodScrollController;

  final _hourTextController = TextEditingController();
  final _minuteTextController = TextEditingController();

  final _hourFocusNode = FocusNode();
  final _minuteFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
    _selectedPeriod = widget.initialTime.period == DayPeriod.am ? 0 : 1;

    _hourScrollController = FixedExtentScrollController(
      initialItem: _getHourScrollIndex(_selectedHour),
    );
    _minuteScrollController = FixedExtentScrollController(
      initialItem: _selectedMinute,
    );
    _periodScrollController = FixedExtentScrollController(
      initialItem: _selectedPeriod,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUse24h = MediaQuery.alwaysUse24HourFormatOf(context);
    if (newUse24h != _use24h) {
      _use24h = newUse24h;
      // Correct the hour scroll position now that we know the real format.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hourScrollController.hasClients) {
          _hourScrollController.jumpToItem(_getHourScrollIndex(_selectedHour));
        }
      });
    }
  }

  @override
  void dispose() {
    _hourScrollController.dispose();
    _minuteScrollController.dispose();
    _periodScrollController.dispose();
    _hourTextController.dispose();
    _minuteTextController.dispose();
    _hourFocusNode.dispose();
    _minuteFocusNode.dispose();
    super.dispose();
  }

  int _getHourScrollIndex(int hour) {
    if (_use24h) {
      return hour;
    } else {
      // 12h format: hour ranges 1-12
      final hour12 = hour % 12;
      final displayHour = hour12 == 0 ? 12 : hour12;
      return displayHour - 1; // 0-indexed for picker
    }
  }

  int _getHourFromScrollIndex(int index) {
    if (_use24h) {
      return index;
    } else {
      final displayHour = index + 1;
      if (_selectedPeriod == 0) {
        // AM: 12 AM is 0, 1-11 AM is 1-11
        return displayHour == 12 ? 0 : displayHour;
      } else {
        // PM: 12 PM is 12, 1-11 PM is 13-23
        return displayHour == 12 ? 12 : displayHour + 12;
      }
    }
  }

  void _submitHour() {
    final text = _hourTextController.text;
    final value = int.tryParse(text);
    if (value != null) {
      int newHour = _selectedHour;
      if (_use24h) {
        if (value >= 0 && value <= 23) {
          newHour = value;
        }
      } else {
        if (value >= 1 && value <= 12) {
          if (_selectedPeriod == 0) {
            newHour = value == 12 ? 0 : value;
          } else {
            newHour = value == 12 ? 12 : value + 12;
          }
        }
      }
      setState(() {
        _selectedHour = newHour;
        _isEditingHour = false;
        _hourScrollController.jumpToItem(_getHourScrollIndex(newHour));
      });
    } else {
      setState(() {
        _isEditingHour = false;
      });
    }
  }

  void _submitMinute() {
    final text = _minuteTextController.text;
    final value = int.tryParse(text);
    if (value != null && value >= 0 && value <= 59) {
      setState(() {
        _selectedMinute = value;
        _isEditingMinute = false;
        _minuteScrollController.jumpToItem(value);
      });
    } else {
      setState(() {
        _isEditingMinute = false;
      });
    }
  }

  Widget _buildHourColumn(ThemeData theme) {
    if (_isEditingHour) {
      return SizedBox(
        width: 70,
        height: 120,
        child: Center(
          child: TextField(
            controller: _hourTextController,
            focusNode: _hourFocusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _submitHour(),
            onTapOutside: (_) => _submitHour(),
          ),
        ),
      );
    }

    final int maxHours = _use24h ? 24 : 12;

    return SizedBox(
      width: 70,
      height: 150,
      child: Localizations.override(
        context: context,
        delegates: const [DefaultCupertinoLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        child: CupertinoPicker(
          scrollController: _hourScrollController,
          itemExtent: 40,
          onSelectedItemChanged: (index) {
            setState(() {
              _selectedHour = _getHourFromScrollIndex(index);
            });
          },
          children: List.generate(maxHours, (index) {
            final displayVal = _use24h ? index : index + 1;
            final displayStr = displayVal.toString().padLeft(2, '0');
            final isSelected = _use24h
                ? _selectedHour == index
                : _getHourScrollIndex(_selectedHour) == index;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (isSelected) {
                  setState(() {
                    _hourTextController.text = displayVal.toString();
                    _isEditingHour = true;
                  });
                }
              },
              child: Center(
                child: Text(
                  displayStr,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMinuteColumn(ThemeData theme) {
    if (_isEditingMinute) {
      return SizedBox(
        width: 70,
        height: 120,
        child: Center(
          child: TextField(
            controller: _minuteTextController,
            focusNode: _minuteFocusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _submitMinute(),
            onTapOutside: (_) => _submitMinute(),
          ),
        ),
      );
    }

    return SizedBox(
      width: 70,
      height: 150,
      child: Localizations.override(
        context: context,
        delegates: const [DefaultCupertinoLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        child: CupertinoPicker(
          scrollController: _minuteScrollController,
          itemExtent: 40,
          onSelectedItemChanged: (index) {
            setState(() {
              _selectedMinute = index;
            });
          },
          children: List.generate(60, (index) {
            final displayStr = index.toString().padLeft(2, '0');
            final isSelected = _selectedMinute == index;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (isSelected) {
                  setState(() {
                    _minuteTextController.text = index.toString();
                    _isEditingMinute = true;
                  });
                }
              },
              child: Center(
                child: Text(
                  displayStr,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPeriodColumn(ThemeData theme) {
    if (_use24h) return const SizedBox.shrink();

    return SizedBox(
      width: 70,
      height: 150,
      child: Localizations.override(
        context: context,
        delegates: const [DefaultCupertinoLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        child: CupertinoPicker(
          scrollController: _periodScrollController,
          itemExtent: 40,
          onSelectedItemChanged: (index) {
            setState(() {
              _selectedPeriod = index;
              // Update selected hour format
              final hour12 = _selectedHour % 12;
              final displayHour = hour12 == 0 ? 12 : hour12;
              if (index == 0) {
                _selectedHour = displayHour == 12 ? 0 : displayHour;
              } else {
                _selectedHour = displayHour == 12 ? 12 : displayHour + 12;
              }
            });
          },
          children: ['AM', 'PM'].map((p) {
            final isSelected = (p == 'AM' && _selectedPeriod == 0) ||
                (p == 'PM' && _selectedPeriod == 1);
            return Center(
              child: Text(
                p,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Time',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a selected number to type it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHourColumn(theme),
                const SizedBox(width: 8),
                Text(
                  ':',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                _buildMinuteColumn(theme),
                if (!_use24h) ...[
                  const SizedBox(width: 12),
                  _buildPeriodColumn(theme),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
