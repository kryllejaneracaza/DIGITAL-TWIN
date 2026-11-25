import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/building_provider.dart';
import '../providers/room_provider.dart';
import '../providers/sensor_provider.dart';
import '../services/appliance_service.dart';
import '../models/appliance_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color primaryGreen = Color(0xFF125838);

  List<ApplianceModel>? _appliances;
  String? _applianceError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDashboard();
    });
  }

  Future<void> _refreshDashboard() async {
    final buildingProvider = context.read<BuildingProvider>();
    final roomProvider = context.read<RoomProvider>();
    final sensorProvider = context.read<SensorProvider>();

    await Future.wait([
      buildingProvider.fetchBuildings(),
      roomProvider.fetchAllRooms(),
      sensorProvider.fetchSensors(),
      _fetchAppliances(),
    ]);
  }

  Future<void> _fetchAppliances() async {
    try {
      final result = await context.read<ApplianceService>().getAppliances();

      if (!mounted) return;

      setState(() {
        _appliances = result;
        _applianceError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _appliances = null;
        _applianceError = e.toString();
      });
    }
  }

  int get _onlineSensors {
    final sensors = context.read<SensorProvider>().sensors;

    return sensors.where((sensor) {
      final status = sensor.status?.toLowerCase();

      return status == 'online' || status == 'connected' || status == 'active';
    }).length;
  }

  int get _offlineSensors {
    final sensors = context.read<SensorProvider>().sensors;

    return sensors.where((sensor) {
      final status = sensor.status?.toLowerCase();

      return status == 'offline' ||
          status == 'disconnected' ||
          status == 'inactive';
    }).length;
  }

  int get _activeAppliances {
    return _appliances?.where((item) => item.isOn).length ?? 0;
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: primaryGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: primaryGreen, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF183B2B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF183B2B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 21),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF183B2B),
          ),
        ),
      ],
    );
  }

  Widget _buildSensorOverview(int totalSensors) {
    final online = _onlineSensors;
    final offline = _offlineSensors;
    final unknown = totalSensors - online - offline;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _sensorStatusItem(
                  'Online',
                  online,
                  const Color(0xFF16834A),
                ),
              ),
              Expanded(
                child: _sensorStatusItem(
                  'Offline',
                  offline,
                  Colors.red.shade600,
                ),
              ),
              Expanded(
                child: _sensorStatusItem(
                  'Unknown',
                  unknown,
                  Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: totalSensors == 0 ? 0 : online / totalSensors,
              minHeight: 9,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF16834A),
            ),
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              totalSensors == 0
                  ? 'No sensor data available yet.'
                  : '$online of $totalSensors sensors reporting online.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensorStatusItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildApplianceOverview() {
    if (_appliances == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _applianceError == null
                    ? 'Loading appliance information...'
                    : 'Appliance information is currently unavailable.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );
    }

    final total = _appliances!.length;
    final on = _activeAppliances;
    final off = total - on;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _sensorStatusItem('Total', total, primaryGreen)),
              Expanded(
                child: _sensorStatusItem('ON', on, const Color(0xFF16834A)),
              ),
              Expanded(child: _sensorStatusItem('OFF', off, Colors.grey)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Appliance status from the backend',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buildings = context.watch<BuildingProvider>();
    final rooms = context.watch<RoomProvider>();
    final sensors = context.watch<SensorProvider>();

    final isLoading =
        buildings.isLoading || rooms.isLoading || sensors.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF8EF),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'EcoBuild Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _refreshDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh dashboard',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: primaryGreen,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Welcome to EcoBuild!',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF183B2B),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Monitor your buildings, rooms, sensors, and appliances.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 20),

            if (isLoading)
              const LinearProgressIndicator(
                color: primaryGreen,
                backgroundColor: Color(0xFFD6EBDD),
              ),

            const SizedBox(height: 15),

            const Text(
              'System Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF183B2B),
              ),
            ),

            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.75,
              children: [
                _buildStatCard(
                  title: 'Buildings',
                  value: '${buildings.buildings.length}',
                  icon: Icons.business_rounded,
                  color: primaryGreen,
                  subtitle: 'Registered buildings',
                ),
                _buildStatCard(
                  title: 'Rooms',
                  value: '${rooms.rooms.length}',
                  icon: Icons.meeting_room_rounded,
                  color: primaryGreen,
                  subtitle: 'Registered rooms',
                ),
                _buildStatCard(
                  title: 'Sensors',
                  value: '${sensors.sensors.length}',
                  icon: Icons.sensors_rounded,
                  color: primaryGreen,
                  subtitle: 'Registered sensors',
                ),
                _buildStatCard(
                  title: 'Active Appliances',
                  value: _appliances == null ? '--' : '$_activeAppliances',
                  icon: Icons.electrical_services_rounded,
                  color: primaryGreen,
                  subtitle: 'Currently switched ON',
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildSectionTitle('Sensor Monitoring', Icons.sensors),

            const SizedBox(height: 12),

            _buildSensorOverview(sensors.sensors.length),

            const SizedBox(height: 24),

            _buildSectionTitle(
              'Appliance Monitoring',
              Icons.power_settings_new,
            ),

            const SizedBox(height: 12),

            _buildApplianceOverview(),

            const SizedBox(height: 22),

            if (buildings.errorMessage != null ||
                rooms.errorMessage != null ||
                sensors.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Some dashboard information could not be loaded. Pull down to refresh.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 15),

            Center(
              child: Text(
                'EcoBuild • Smart Building Monitoring System',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
