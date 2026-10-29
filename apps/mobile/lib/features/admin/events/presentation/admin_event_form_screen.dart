import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/api_models.dart';
import '../../../../core/providers.dart';
import '../application/admin_events_controller.dart';
import '../application/event_time.dart';

class AdminEventFormScreen extends ConsumerStatefulWidget {
  const AdminEventFormScreen({super.key, this.eventId});

  final String? eventId;

  bool get isEdit => eventId != null;

  @override
  ConsumerState<AdminEventFormScreen> createState() =>
      _AdminEventFormScreenState();
}

class _AdminEventFormScreenState extends ConsumerState<AdminEventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _placeName = TextEditingController();
  final _address = TextEditingController();
  final _floorWidth = TextEditingController(text: '20');
  final _floorHeight = TextEditingController(text: '20');
  final _rssiThreshold = TextEditingController(text: '-75');
  final _minBeacons = TextEditingController(text: '1');
  final _coverageRadius = TextEditingController();
  final _pathLoss = TextEditingController(text: '2');

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Beacon> _beacons = [];
  Event? _event;
  String _timezone = 'Asia/Jakarta';
  late DateTime _startsAt;
  late DateTime _endsAt;
  final Map<String, EventBeaconInput> _placements = {};

  List<String> get _timezones {
    final values = [...eventTimezones];
    final current = _event?.timezone;
    if (current != null && current.isNotEmpty && !values.contains(current)) {
      values.add(current);
    }
    return values;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _startsAt = wallTimeFromUtc(now.add(const Duration(hours: 1)), _timezone);
    _endsAt = wallTimeFromUtc(now.add(const Duration(hours: 3)), _timezone);
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _placeName.dispose();
    _address.dispose();
    _floorWidth.dispose();
    _floorHeight.dispose();
    _rssiThreshold.dispose();
    _minBeacons.dispose();
    _coverageRadius.dispose();
    _pathLoss.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final beacons = await api.listBeacons();
      final event = widget.eventId == null
          ? null
          : await api.getEvent(widget.eventId!);
      if (!mounted) return;

      final timezone = event?.timezone ?? _timezone;
      setState(() {
        _beacons = beacons;
        _event = event;
        _timezone = timezone;
        _title.text = event?.title ?? '';
        _description.text = event?.description ?? '';
        _placeName.text = event?.placeName ?? '';
        _address.text = event?.address ?? '';
        _floorWidth.text = (event?.floorWidthM ?? 20).toString();
        _floorHeight.text = (event?.floorHeightM ?? 20).toString();
        _rssiThreshold.text = (event?.rssiThresholdDbm ?? -75).toString();
        _minBeacons.text = (event?.minBeacons ?? 1).toString();
        _coverageRadius.text = event?.coverageRadiusM?.toString() ?? '';
        _pathLoss.text = (event?.pathLossExponent ?? 2).toString();
        _startsAt = event == null
            ? wallTimeFromUtc(
                DateTime.now().toUtc().add(const Duration(hours: 1)),
                timezone,
              )
            : wallTimeFromUtc(event.startsAt, timezone);
        _endsAt = event == null
            ? wallTimeFromUtc(
                DateTime.now().toUtc().add(const Duration(hours: 3)),
                timezone,
              )
            : wallTimeFromUtc(event.endsAt, timezone);
        _placements
          ..clear()
          ..addEntries(
            (event?.beacons ?? const <EventBeacon>[]).map(
              (beacon) => MapEntry(
                beacon.beaconId,
                EventBeaconInput(
                  beaconId: beacon.beaconId,
                  x: beacon.x,
                  y: beacon.y,
                  txPowerOverride: beacon.txPowerOverride,
                ),
              ),
            ),
          );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _toggleBeacon(Beacon beacon) {
    setState(() {
      if (_placements.containsKey(beacon.id)) {
        _placements.remove(beacon.id);
      } else {
        final offset = _defaultPlacement(
          _placements.length,
          double.tryParse(_floorWidth.text) ?? 20,
          double.tryParse(_floorHeight.text) ?? 20,
        );
        _placements[beacon.id] = EventBeaconInput(
          beaconId: beacon.id,
          x: offset.dx,
          y: offset.dy,
        );
      }
    });
  }

  Offset _defaultPlacement(int index, double width, double height) {
    final columns = math.max(1, math.min(4, math.sqrt(index + 1).ceil()));
    final x =
        2 +
        (index % columns) *
            ((width - 4).clamp(2, double.infinity) /
                (columns == 1 ? 1 : columns - 1));
    final y =
        2 + (index ~/ columns) * ((height - 4).clamp(2, double.infinity) / 3);
    return Offset(_snap(x.clamp(0, width)), _snap(y.clamp(0, height)));
  }

  double _snap(double value) => (value * 2).round() / 2;

  Future<void> _pickDateTime({required bool start}) async {
    final initial = start ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _startsAt = value;
      } else {
        _endsAt = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_placements.isEmpty) {
      setState(() => _error = 'Attach at least one beacon to the event.');
      return;
    }
    if (!_endsAt.isAfter(_startsAt)) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }

    final width = double.tryParse(_floorWidth.text) ?? 20;
    final height = double.tryParse(_floorHeight.text) ?? 20;
    final beacons = _placements.values
        .map(
          (placement) => EventBeaconInput(
            beaconId: placement.beaconId,
            x: placement.x.clamp(0, width),
            y: placement.y.clamp(0, height),
            txPowerOverride: placement.txPowerOverride,
          ),
        )
        .toList();

    final input = EventInput(
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      placeName: _placeName.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      startsAt: wallTimeToUtc(_startsAt, _timezone),
      endsAt: wallTimeToUtc(_endsAt, _timezone),
      timezone: _timezone,
      floorWidthM: width,
      floorHeightM: height,
      rssiThresholdDbm: int.tryParse(_rssiThreshold.text) ?? -75,
      minBeacons: int.tryParse(_minBeacons.text) ?? 1,
      coverageRadiusM: _coverageRadius.text.trim().isEmpty
          ? null
          : double.tryParse(_coverageRadius.text),
      pathLossExponent: double.tryParse(_pathLoss.text) ?? 2,
      beacons: beacons,
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final saved = widget.eventId == null
          ? await api.createEvent(input)
          : await api.updateEvent(widget.eventId!, input);
      if (!mounted) return;
      ref.invalidate(adminEventsProvider);
      ref.invalidate(adminEventDetailProvider(saved.id));
      context.go('/manage-events/${saved.id}');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit event' : 'Create event'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload form data',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _loading || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(
              _saving
                  ? 'Saving…'
                  : widget.isEdit
                  ? 'Save changes'
                  : 'Create event',
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (_error != null)
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_error!),
                        ),
                      ),
                    _section(
                      'Event details',
                      children: [
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Title is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _placeName,
                          decoration: const InputDecoration(
                            labelText: 'Place name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Place is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _address,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_timezone),
                          initialValue: _timezone,
                          decoration: const InputDecoration(
                            labelText: 'Timezone',
                            border: OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: _timezones
                              .map(
                                (zone) => DropdownMenuItem(
                                  value: zone,
                                  child: Text(zone),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _timezone = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _dateTimeTile(
                          'Starts at',
                          _startsAt,
                          () => _pickDateTime(start: true),
                        ),
                        _dateTimeTile(
                          'Ends at',
                          _endsAt,
                          () => _pickDateTime(start: false),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    _section(
                      'Coverage & floor',
                      children: [
                        _numberField(
                          _floorWidth,
                          'Floor width (m)',
                          min: 1,
                          step: 0.5,
                        ),
                        _numberField(
                          _floorHeight,
                          'Floor height (m)',
                          min: 1,
                          step: 0.5,
                        ),
                        _numberField(
                          _rssiThreshold,
                          'RSSI threshold (dBm)',
                          min: -120,
                          max: 0,
                          hint: 'Minimum signal strength a beacon must reach. -75 is a good start; closer to 0 requires the phone to be nearer.',
                        ),
                        _numberField(_minBeacons, 'Minimum beacons', min: 1),
                        _numberField(
                          _coverageRadius,
                          'Coverage radius (m)',
                          min: 1,
                          step: 0.5,
                          hint: 'Optional. Requires 3+ positioned beacons; the estimated point must be inside this radius.',
                        ),
                        _numberField(
                          _pathLoss,
                          'Path-loss exponent',
                          min: 0.1,
                          step: 0.1,
                          hint: 'How quickly signal fades with distance. 2 = open space; 2.5–3.5 = indoor spaces.',
                        ),
                      ],
                    ),
                    _section(
                      'Beacons (${_placements.length} selected)',
                      children: [
                        const Text(
                          'Tap a beacon to attach or remove it. Floor positions are assigned automatically. Confirm the real GPS location from the event detail screen.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        if (_beacons.isEmpty)
                          const Text(
                            'No active beacons. Register one in the Beacon Scanner first.',
                          )
                        else
                          ..._beacons.map(
                            (beacon) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: CheckboxListTile(
                                value: _placements.containsKey(beacon.id),
                                onChanged: (_) => _toggleBeacon(beacon),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(beacon.label),
                                subtitle: Text(
                                  beacon.identityKey,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _section(String title, {required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    double? min,
    double? max,
    double step = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: hint,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final parsed = double.tryParse(value ?? '');
          if (parsed == null) return 'Enter a number';
          if (min != null && parsed < min) return 'Minimum is $min';
          if (max != null && parsed > max) return 'Maximum is $max';
          return null;
        },
      ),
    );
  }

  Widget _dateTimeTile(String label, DateTime value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(formatWallTime(value, 'EEE, d MMM yyyy · HH:mm')),
      trailing: const Icon(Icons.edit_calendar),
      onTap: onTap,
    );
  }
}
