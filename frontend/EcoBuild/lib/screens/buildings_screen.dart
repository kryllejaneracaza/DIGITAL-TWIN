import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/building_model.dart';
import '../providers/building_provider.dart';
import 'building_details_screen.dart';

class BuildingsScreen extends StatefulWidget {
  const BuildingsScreen({super.key});

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen> {
  static const Color primaryGreen = Color(0xFF125838);
  static const Color backgroundColor = Color(0xFFEAF8EF);
  static const Color lightGreen = Color(0xFFD9EFE1);
  static const Color darkText = Color(0xFF183B2B);

  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasLoaded) return;

      _hasLoaded = true;
      context.read<BuildingProvider>().fetchBuildings();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<BuildingModel> filteredBuildings(List<BuildingModel> buildings) {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) return buildings;

    return buildings.where((building) {
      return building.name.toLowerCase().contains(query) ||
          (building.address ?? '').toLowerCase().contains(query);
    }).toList();
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> showAddBuildingDialog() async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (dialogContext, updateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.add_business_rounded, color: primaryGreen),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add New Building',
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(
                      controller: nameController,
                      label: 'Building Name',
                      hint: 'Enter building name',
                      icon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 15),
                    _dialogField(
                      controller: locationController,
                      label: 'Location',
                      hint: 'Enter building location',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 15),
                    _dialogField(
                      controller: descriptionController,
                      label: 'Description',
                      hint: 'Enter building description',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final location = locationController.text.trim();
                          final description = descriptionController.text.trim();

                          if (name.isEmpty || location.isEmpty) {
                            showMessage(
                              'Please enter a building name and location.',
                              isError: true,
                            );
                            return;
                          }

                          final provider = context.read<BuildingProvider>();

                          final alreadyExists = provider.buildings.any(
                            (building) =>
                                building.name.toLowerCase() ==
                                name.toLowerCase(),
                          );

                          if (alreadyExists) {
                            showMessage(
                              'This building already exists.',
                              isError: true,
                            );
                            return;
                          }

                          updateDialog(() => isSaving = true);

                          final building = BuildingModel(
                            id: '',
                            name: name,
                            address: location,
                            description: description.isEmpty
                                ? null
                                : description,
                          );

                          bool success = false;

                          try {
                            success = await provider.addBuilding(building);
                          } catch (e) {
                            debugPrint('Add Building Error: $e');
                          }

                          if (!mounted) return;

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }

                          if (success) {
                            showMessage('$name added successfully!');
                            await refreshBuildings();
                          } else {
                            showMessage(
                              provider.errorMessage ??
                                  'Unable to add building.',
                              isError: true,
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Add Building',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    locationController.dispose();
    descriptionController.dispose();
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryGreen),
        filled: true,
        fillColor: backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> refreshBuildings() async {
    await context.read<BuildingProvider>().fetchBuildings();
  }

  void openBuildingDetails(BuildingModel building) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuildingDetailsScreen(
          buildingId: building.id,
          buildingName: building.name,
          location: building.address ?? 'Location not specified',
          description: building.description ?? 'No description available.',
        ),
      ),
    );
  }

  Widget _buildHeaderCard(int totalBuildings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              size: 30,
              color: primaryGreen,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Buildings',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF52745F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalBuildings',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Registered buildings in EcoBuild',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.business_rounded,
            size: 28,
            color: Color(0xFFB5D8C1),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingCard(BuildingModel building) {
    return Card(
      elevation: 1,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openBuildingDetails(building),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  size: 39,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      building.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            building.address ?? 'No location specified',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'View building details',
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: primaryGreen,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator(color: primaryGreen));
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 55, color: Colors.grey),
            const SizedBox(height: 13),
            const Text(
              'Unable to load buildings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryGreen,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 17),
            ElevatedButton.icon(
              onPressed: refreshBuildings,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('TRY AGAIN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 35),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.apartment_rounded,
              size: 42,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No buildings found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            searchQuery.isEmpty
                ? 'Add your first building to get started.'
                : 'Try searching with a different name or location.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddBuildingDialog,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text(
          'ADD BUILDING',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Buildings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: refreshBuildings,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh buildings',
          ),
          const SizedBox(width: 5),
        ],
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Consumer<BuildingProvider>(
              builder: (context, provider, child) {
                final buildings = filteredBuildings(provider.buildings);

                if (provider.isLoading && provider.buildings.isEmpty) {
                  return _buildLoadingView();
                }

                if (provider.errorMessage != null &&
                    provider.buildings.isEmpty) {
                  return _buildErrorView(provider.errorMessage!);
                }

                return RefreshIndicator(
                  onRefresh: refreshBuildings,
                  color: primaryGreen,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Building Management',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Manage and monitor your registered buildings.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildHeaderCard(provider.buildings.length),

                      const SizedBox(height: 22),

                      TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search buildings...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: primaryGreen,
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() {
                                      searchQuery = '';
                                    });
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          const Icon(
                            Icons.business_rounded,
                            color: primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Building List',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                          ),
                          Text(
                            '${buildings.length} found',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 13),

                      if (buildings.isEmpty)
                        _buildEmptyView()
                      else
                        ...buildings.map(_buildBuildingCard),

                      const SizedBox(height: 70),

                      const Center(
                        child: Text(
                          'EcoBuild • Smart Building Monitoring System',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
