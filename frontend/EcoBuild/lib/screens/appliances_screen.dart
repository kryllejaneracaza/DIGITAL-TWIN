import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appliance_model.dart';
import '../services/appliance_service.dart';

class AppliancesScreen extends StatefulWidget {
  const AppliancesScreen({super.key});

  @override
  State<AppliancesScreen> createState() => _AppliancesScreenState();
}

class _AppliancesScreenState extends State<AppliancesScreen> {
  List<ApplianceModel> _appliances = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';

  final Set<String> _updatingAppliances = {};

  @override
  void initState() {
    super.initState();
    _loadAppliances();
  }

  Future<void> _loadAppliances() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final service = context.read<ApplianceService>();
      final appliances = await service.getAppliances();

      if (!mounted) return;

      setState(() {
        _appliances = appliances;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAppliance(ApplianceModel appliance) async {
    if (_updatingAppliances.contains(appliance.id)) return;

    final newPowerState = !appliance.isOn;

    setState(() {
      _updatingAppliances.add(appliance.id);
    });

    try {
      final updatedAppliance = await context
          .read<ApplianceService>()
          .setAppliancePower(appliance.id, newPowerState);

      if (!mounted) return;

      setState(() {
        final index = _appliances.indexWhere((item) => item.id == appliance.id);

        if (index != -1) {
          _appliances[index] = updatedAppliance;
        }

        _updatingAppliances.remove(appliance.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${appliance.name} updated successfully.'),
          backgroundColor: const Color(0xFF125838),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _updatingAppliances.remove(appliance.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update ${appliance.name}: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<ApplianceModel> get _filteredAppliances {
    if (_searchQuery.trim().isEmpty) {
      return _appliances;
    }

    final query = _searchQuery.toLowerCase().trim();

    return _appliances.where((appliance) {
      return appliance.name.toLowerCase().contains(query) ||
          appliance.type.toLowerCase().contains(query) ||
          appliance.roomId.toLowerCase().contains(query) ||
          appliance.buildingId.toLowerCase().contains(query);
    }).toList();
  }

  int get _onCount => _appliances.where((appliance) => appliance.isOn).length;

  int get _offCount => _appliances.where((appliance) => !appliance.isOn).length;

  double get _totalPowerUsage {
    return _appliances.where((appliance) => appliance.isOn).fold(0.0, (
      total,
      appliance,
    ) {
      return total + (appliance.powerUsage ?? 0);
    });
  }

  IconData _getApplianceIcon(String type) {
    final value = type.toLowerCase();

    if (value.contains('light') || value.contains('lamp')) {
      return Icons.lightbulb_outline;
    }

    if (value.contains('fan')) {
      return Icons.air;
    }

    if (value.contains('air') || value.contains('ac')) {
      return Icons.ac_unit;
    }

    if (value.contains('computer') || value.contains('pc')) {
      return Icons.computer;
    }

    if (value.contains('projector')) {
      return Icons.connected_tv;
    }

    if (value.contains('tv') || value.contains('television')) {
      return Icons.tv;
    }

    if (value.contains('outlet') || value.contains('socket')) {
      return Icons.power;
    }

    return Icons.electrical_services;
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Color(0xFF183B2B),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplianceCard(ApplianceModel appliance) {
    final isOn = appliance.isOn;
    final isUpdating = _updatingAppliances.contains(appliance.id);

    final statusColor = isOn ? const Color(0xFF16834A) : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOn
              ? const Color(0xFF16834A).withValues(alpha: 0.20)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _getApplianceIcon(appliance.type),
                  color: statusColor,
                  size: 25,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appliance.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF183B2B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appliance.type,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              if (isUpdating)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF125838),
                  ),
                )
              else
                Switch(
                  value: isOn,
                  activeThumbColor: const Color(0xFF16834A),
                  onChanged: (_) => _toggleAppliance(appliance),
                ),
            ],
          ),

          const SizedBox(height: 14),

          Divider(color: Colors.grey.shade200),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.circle, size: 9, color: statusColor),
              const SizedBox(width: 6),
              Text(
                isOn ? 'ON' : 'OFF',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(),

              Icon(
                Icons.meeting_room_outlined,
                size: 15,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 5),

              Flexible(
                child: Text(
                  'Room: ${appliance.roomId.isEmpty ? 'N/A' : appliance.roomId}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              Icon(
                Icons.business_outlined,
                size: 15,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 5),

              Expanded(
                child: Text(
                  'Building: ${appliance.buildingId.isEmpty ? 'N/A' : appliance.buildingId}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),

              Icon(Icons.bolt, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 4),

              Text(
                appliance.powerUsage == null
                    ? '--'
                    : '${appliance.powerUsage!.toStringAsFixed(2)} W',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF183B2B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF125838)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 55,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to Load Appliances',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: _loadAppliances,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF125838),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_appliances.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAppliances,
        color: const Color(0xFF125838),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 110),
            Icon(
              Icons.electrical_services_outlined,
              size: 65,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            const Center(
              child: Text(
                'No Appliances Found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF183B2B),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: Text(
                  'Appliances will appear here once they are added through the backend.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filteredAppliances;

    return RefreshIndicator(
      onRefresh: _loadAppliances,
      color: const Color(0xFF125838),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
        children: [
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 55, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No matching appliances found.'),
                ],
              ),
            )
          else
            ...filtered.map(_buildApplianceCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF125838),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Appliances',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadAppliances,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh appliances',
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appliance Management',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF183B2B),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Monitor and manage connected building appliances.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    _buildSummaryCard(
                      title: 'Total',
                      value: '${_appliances.length}',
                      icon: Icons.devices,
                      color: const Color(0xFF125838),
                    ),
                    const SizedBox(width: 9),
                    _buildSummaryCard(
                      title: 'ON',
                      value: '$_onCount',
                      icon: Icons.power,
                      color: const Color(0xFF16834A),
                    ),
                    const SizedBox(width: 9),
                    _buildSummaryCard(
                      title: 'OFF',
                      value: '$_offCount',
                      icon: Icons.power_off,
                      color: Colors.grey,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: Colors.orange.shade700),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Power usage of ON appliances',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${_totalPowerUsage.toStringAsFixed(2)} W',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF125838),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 13),

                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search appliances...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Connected Appliances',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF183B2B),
                  ),
                ),
              ],
            ),
          ),

          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}
