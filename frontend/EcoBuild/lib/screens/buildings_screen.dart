import 'package:flutter/material.dart';
import 'building_details_screen.dart';

class BuildingItem {
  final String name;
  final String location;
  final String description;
  final List<BuildingRoom> rooms;

  BuildingItem({
    required this.name,
    required this.location,
    required this.description,
    required this.rooms,
  });
}

class BuildingsScreen extends StatefulWidget {
  const BuildingsScreen({super.key});

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen> {
  static const Color primaryGreen = Color(0xFF125838);
  static const Color lightGreen = Color(0xFFD6EDD5);
  static const Color backgroundColor = Color(0xFFF1F5F2);

  final TextEditingController searchController = TextEditingController();

  late List<BuildingItem> buildings;

  String searchQuery = '';

  @override
  void initState() {
    super.initState();

    buildings = [
      BuildingItem(
        name: 'Comp Lab',
        location: 'Computer Laboratory',
        description:
            'Computer laboratory building with smart monitoring '
            'and connected room sensors.',
        rooms: [
          BuildingRoom(name: 'Computer Room 1', floor: 'Ground Floor'),
          BuildingRoom(name: 'Computer Room 2', floor: 'First Floor'),
        ],
      ),
      BuildingItem(
        name: 'Mech Lab',
        location: 'Mechanical Laboratory',
        description:
            'Mechanical laboratory building for equipment '
            'monitoring and smart space management.',
        rooms: [
          BuildingRoom(name: 'Workshop 1', floor: 'Ground Floor'),
          BuildingRoom(name: 'Workshop 2', floor: 'Ground Floor'),
          BuildingRoom(name: 'Testing Room', floor: 'First Floor'),
          BuildingRoom(name: 'Storage Room', floor: 'First Floor'),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<BuildingItem> get filteredBuildings {
    if (searchQuery.trim().isEmpty) {
      return buildings;
    }

    return buildings.where((building) {
      return building.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          building.location.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  void showAddBuildingDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Add New Building',
            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Building Name',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final location = locationController.text.trim();
                final description = descriptionController.text.trim();

                if (name.isEmpty || location.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter a building name and location.',
                      ),
                    ),
                  );
                  return;
                }

                final alreadyExists = buildings.any(
                  (building) =>
                      building.name.toLowerCase() == name.toLowerCase(),
                );

                if (alreadyExists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This building already exists.'),
                    ),
                  );
                  return;
                }

                setState(() {
                  buildings.add(
                    BuildingItem(
                      name: name,
                      location: location,
                      description: description.isEmpty
                          ? 'No description available.'
                          : description,
                      rooms: [],
                    ),
                  );
                });

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name added successfully!'),
                    backgroundColor: primaryGreen,
                  ),
                );
              },
              child: const Text('ADD BUILDING'),
            ),
          ],
        );
      },
    ).then((_) {
      nameController.dispose();
      locationController.dispose();
      descriptionController.dispose();
    });
  }

  void openBuildingDetails(BuildingItem building) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuildingDetailsScreen(
          buildingName: building.name,
          location: building.location,
          description: building.description,
          initialRooms: building.rooms,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Widget buildingCard(BuildingItem building) {
    return Card(
      elevation: 3,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openBuildingDetails(building),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 115,
                height: 85,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: primaryGreen,
                  size: 55,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      building.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${building.rooms.length} Rooms',
                      style: const TextStyle(
                        color: Color(0xFF52745F),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      building.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget addBuildingCard() {
    return InkWell(
      onTap: showAddBuildingDialog,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        height: 105,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 43, color: primaryGreen),
            SizedBox(width: 15),
            Text(
              'Add Building',
              style: TextStyle(
                color: primaryGreen,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Buildings',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search buildings...',
                      prefixIcon: const Icon(Icons.search, color: primaryGreen),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Expanded(
                    child: ListView(
                      children: [
                        ...filteredBuildings.map(buildingCard),

                        if (filteredBuildings.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(
                              child: Text(
                                'No buildings found.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),

                        const SizedBox(height: 5),

                        addBuildingCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
