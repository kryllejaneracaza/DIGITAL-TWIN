import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sensor_model.dart';
import '../providers/sensor_provider.dart';

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  static const Color primaryGreen = Color(0xFF125838);
  static const Color backgroundColor = Color(0xFFEAF8EF);
  static const Color lightGreen = Color(0xFFD9EFE1);
  static const Color darkText = Color(0xFF183B2B);

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSensors();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSensors() async {
    await context.read<SensorProvider>().fetchSensors();
  }

  Future<void> _refreshSensors() async {
    await _loadSensors();
  }

  String _formatSensorType(String type) {
    if (type.trim().isEmpty) return 'Unknown';

    return type
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _getSensorCategory(String type) {
    final value = type.toLowerCase();

    if (value.contains('temperature') || value.contains('temp')) {
      return 'Temperature';
    }

    if (value.contains('humidity') || value.contains('humid')) {
      return 'Humidity';
    }

    if (value.contains('occupancy') ||
        value.contains('motion') ||
        value.contains('presence')) {
      return 'Occupancy';
    }

    return 'Other';
  }

  IconData _getSensorIcon(String type) {
    switch (_getSensorCategory(type)) {
      case 'Temperature':
        return Icons.thermostat_rounded;
      case 'Humidity':
        return Icons.water_drop_rounded;
      case 'Occupancy':
        return Icons.people_alt_rounded;
      default:
        return Icons.sensors_rounded;
    }
  }

  bool? _getOnlineStatus(String? status) {
    if (status == null) return null;

    final value = status.toLowerCase().trim();

    if (['online', 'connected', 'active'].contains(value)) {
      return true;
    }

    if (['offline', 'disconnected', 'inactive'].contains(value)) {
      return false;
    }

    return null;
  }

  String _getReading(SensorModel sensor) {
    if (sensor.reading == null) return '--';

    if (_getSensorCategory(sensor.type) == 'Occupancy') {
      final occupied = sensor.occupancyDetected;

      if (occupied == true) return 'Occupied';
      if (occupied == false) return 'Unoccupied';
    }

    if (sensor.reading is bool) {
      return sensor.reading ? 'Yes' : 'No';
    }

    return sensor.reading.toString();
  }

  String _getReadingWithUnit(SensorModel sensor) {
    final reading = _getReading(sensor);

    if (reading == '--' ||
        reading == 'Occupied' ||
        reading == 'Unoccupied' ||
        sensor.unit == null ||
        sensor.unit!.trim().isEmpty) {
      return reading;
    }

    return '$reading ${sensor.unit}';
  }

  String _formatLastUpdated(DateTime? date) {
    if (date == null) return 'Last updated: Unknown';

    final localDate = date.toLocal();

    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return 'Updated: ${localDate.day}/${localDate.month}/${localDate.year} $hour:$minute';
  }

  List<SensorModel> _filterSensors(List<SensorModel> sensors) {
    if (_searchQuery.trim().isEmpty) return sensors;

    final query = _searchQuery.toLowerCase().trim();

    return sensors.where((sensor) {
      return sensor.name.toLowerCase().contains(query) ||
          sensor.type.toLowerCase().contains(query) ||
          sensor.roomId.toLowerCase().contains(query) ||
          sensor.buildingId.toLowerCase().contains(query) ||
          sensor.id.toLowerCase().contains(query);
    }).toList();
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 9),
            Text(
              value,
              style: const TextStyle(
                color: primaryGreen,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search sensor, type, room or building...',
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: primaryGreen),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: primaryGreen, width: 1.3),
        ),
      ),
    );
  }

  Widget _statusBadge(String? status) {
    final onlineStatus = _getOnlineStatus(status);

    final label = onlineStatus == true
        ? 'Online'
        : onlineStatus == false
        ? 'Offline'
        : 'Unknown';

    final color = onlineStatus == true
        ? Colors.green
        : onlineStatus == false
        ? Colors.red
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _readingContainer(SensorModel sensor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT READING',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _getReadingWithUnit(sensor),
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationRow({required IconData icon, required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensorCard(SensorModel sensor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 51,
                width: 51,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _getSensorIcon(sensor.type),
                  color: primaryGreen,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sensor.name,
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatSensorType(sensor.type),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _statusBadge(sensor.status),
            ],
          ),

          const SizedBox(height: 17),

          _readingContainer(sensor),

          const SizedBox(height: 15),

          _informationRow(
            icon: Icons.meeting_room_outlined,
            label:
                'Room ID: ${sensor.roomId.isEmpty ? 'Unavailable' : sensor.roomId}',
          ),

          _informationRow(
            icon: Icons.apartment_outlined,
            label:
                'Building ID: ${sensor.buildingId.isEmpty ? 'Unavailable' : sensor.buildingId}',
          ),

          _informationRow(
            icon: Icons.access_time_rounded,
            label: _formatLastUpdated(sensor.lastUpdated),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 15),
      child: Column(
        children: [
          Icon(icon, size: 65, color: primaryGreen.withValues(alpha: 0.40)),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.red, size: 43),
          const SizedBox(height: 12),
          const Text(
            'Unable to Load Sensors',
            style: TextStyle(color: darkText, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _refreshSensors,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sensorProvider = context.watch<SensorProvider>();
    final sensors = sensorProvider.sensors;
    final filteredSensors = _filterSensors(sensors);

    final onlineCount = sensors
        .where((sensor) => _getOnlineStatus(sensor.status) == true)
        .length;

    final offlineCount = sensors
        .where((sensor) => _getOnlineStatus(sensor.status) == false)
        .length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Sensors',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh sensors',
            onPressed: _refreshSensors,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryGreen,
          onRefresh: _refreshSensors,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 25),
            children: [
              const Text(
                'Sensor Monitoring',
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Monitor sensor readings and connection status across your buildings.',
                style: TextStyle(
                  color: Color(0xFF718579),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  _summaryCard(
                    title: 'Total Sensors',
                    value: '${sensors.length}',
                    icon: Icons.sensors_rounded,
                    iconColor: primaryGreen,
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    title: 'Online',
                    value: '$onlineCount',
                    icon: Icons.wifi_rounded,
                    iconColor: Colors.green,
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    title: 'Offline',
                    value: '$offlineCount',
                    icon: Icons.wifi_off_rounded,
                    iconColor: Colors.red,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _searchBar(),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Sensors',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filteredSensors.length} found',
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (sensorProvider.isLoading && sensors.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  ),
                )
              else if (sensorProvider.errorMessage != null && sensors.isEmpty)
                _errorState(sensorProvider.errorMessage!)
              else if (sensors.isEmpty)
                _emptyState(
                  icon: Icons.sensors_off_rounded,
                  title: 'No Sensors Yet',
                  message:
                      'Sensors registered by your backend will appear here.',
                )
              else if (filteredSensors.isEmpty)
                _emptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No Matching Sensors',
                  message:
                      'Try searching with another sensor name, type, room, or building.',
                )
              else
                ...filteredSensors.map(_sensorCard),

              if (sensorProvider.errorMessage != null &&
                  sensors.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Refresh failed: ${sensorProvider.errorMessage}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
