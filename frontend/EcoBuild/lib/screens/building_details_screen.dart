import 'package:flutter/material.dart';

class BuildingRoom {
  final String name;
  final String floor;
  final int sensorCount;

  BuildingRoom({required this.name, required this.floor, this.sensorCount = 0});
}

class BuildingDetailsScreen extends StatefulWidget {
  final String buildingName;
  final String location;
  final String description;
  final List<BuildingRoom> initialRooms;

  const BuildingDetailsScreen({
    super.key,
    required this.buildingName,
    required this.location,
    required this.description,
    required this.initialRooms,
  });

  @override
  State<BuildingDetailsScreen> createState() => _BuildingDetailsScreenState();
}

class _BuildingDetailsScreenState extends State<BuildingDetailsScreen> {
  static const Color primaryGreen = Color(0xFF125838);
  static const Color lightGreen = Color(0xFFD6EDD5);
  static const Color backgroundColor = Color(0xFFF1F5F2);

  late final List<BuildingRoom> rooms;

  final List<String> floors = [
    'Ground Floor',
    'First Floor',
    'Second Floor',
    'Third Floor',
    'Fourth Floor',
    'Fifth Floor',
  ];

  @override
  void initState() {
    super.initState();
    rooms = widget.initialRooms;
  }

  int get totalSensors {
    return rooms.fold(0, (total, room) => total + room.sensorCount);
  }

  List<BuildingRoom> roomsOnFloor(String floor) {
    return rooms.where((room) => room.floor == floor).toList();
  }

  void showAddRoomDialog() {
    final nameController = TextEditingController();
    String selectedFloor = floors.first;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, updateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Add New Room',
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Room Name',
                      prefixIcon: const Icon(
                        Icons.meeting_room,
                        color: primaryGreen,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  DropdownButtonFormField<String>(
                    initialValue: selectedFloor,
                    decoration: InputDecoration(
                      labelText: 'Select Floor',
                      prefixIcon: const Icon(Icons.layers, color: primaryGreen),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: floors.map((floor) {
                      return DropdownMenuItem(value: floor, child: Text(floor));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        updateDialog(() {
                          selectedFloor = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final roomName = nameController.text.trim();

                    if (roomName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a room name.'),
                        ),
                      );
                      return;
                    }

                    final exists = rooms.any(
                      (room) =>
                          room.name.toLowerCase() == roomName.toLowerCase() &&
                          room.floor == selectedFloor,
                    );

                    if (exists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This room already exists on this floor.',
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      rooms.add(
                        BuildingRoom(name: roomName, floor: selectedFloor),
                      );
                    });

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$roomName added successfully!'),
                        backgroundColor: primaryGreen,
                      ),
                    );
                  },
                  child: const Text('ADD ROOM'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
    });
  }

  Widget buildingInformationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 155,
            width: double.infinity,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              size: 90,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            widget.buildingName,
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.location_on, color: primaryGreen, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.location,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            widget.description,
            style: const TextStyle(
              color: Color(0xFF52745F),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget overviewCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: primaryGreen, size: 27),
            const SizedBox(height: 8),
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

  Widget floorSection(String floor) {
    final floorRooms = roomsOnFloor(floor);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        iconColor: primaryGreen,
        collapsedIconColor: primaryGreen,
        leading: const Icon(Icons.layers_rounded, color: primaryGreen),
        title: Text(
          floor,
          style: const TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${floorRooms.length} Rooms',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        children: [
          if (floorRooms.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No rooms added on this floor yet.',
                style: TextStyle(color: Colors.grey),
              ),
            ),

          ...floorRooms.map((room) {
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.meeting_room, color: primaryGreen),
              ),
              title: Text(
                room.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryGreen,
                ),
              ),
              subtitle: Text(
                '${room.sensorCount} Sensors',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 15,
                color: Colors.grey,
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddRoomDialog,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: primaryGreen),
                      ),
                      const Expanded(
                        child: Text(
                          'Building Details',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
                    children: [
                      const Text(
                        'Building Information',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 13),

                      buildingInformationCard(),

                      const SizedBox(height: 24),

                      const Text(
                        'Building Overview',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 13),

                      Row(
                        children: [
                          overviewCard(
                            icon: Icons.meeting_room,
                            title: 'Total Rooms',
                            value: '${rooms.length}',
                          ),
                          const SizedBox(width: 10),
                          overviewCard(
                            icon: Icons.sensors,
                            title: 'Total Sensors',
                            value: '$totalSensors',
                          ),
                          const SizedBox(width: 10),
                          overviewCard(
                            icon: Icons.wifi,
                            title: 'Connection',
                            value: 'Offline',
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Floors & Rooms',
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${rooms.length} Total',
                            style: const TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 13),

                      ...floors.map(floorSection),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
