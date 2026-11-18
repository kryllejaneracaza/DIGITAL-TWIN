import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room_model.dart';
import '../providers/room_provider.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  static const Color primaryGreen = Color(0xFF125838);
  static const Color backgroundColor = Color(0xFFF1F5F2);
  static const Color lightGreen = Color(0xFFD6EDD5);

  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RoomProvider>().fetchAllRooms();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String getFloorName(int? floor) {
    const floors = [
      'Ground Floor',
      'First Floor',
      'Second Floor',
      'Third Floor',
      'Fourth Floor',
      'Fifth Floor',
    ];

    if (floor == null || floor < 0 || floor >= floors.length) {
      return 'Unassigned Floor';
    }

    return floors[floor];
  }

  List<RoomModel> filterRooms(List<RoomModel> rooms) {
    if (searchQuery.trim().isEmpty) {
      return rooms;
    }

    final query = searchQuery.toLowerCase().trim();

    return rooms.where((room) {
      return room.name.toLowerCase().contains(query) ||
          room.buildingId.toLowerCase().contains(query) ||
          getFloorName(room.floor).toLowerCase().contains(query);
    }).toList();
  }

  Future<void> refreshRooms() async {
    await context.read<RoomProvider>().fetchAllRooms();
  }

  Widget buildSearchBar() {
    return TextField(
      controller: searchController,
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search room or building...',
        prefixIcon: const Icon(Icons.search, color: primaryGreen),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  searchController.clear();
                  setState(() {
                    searchQuery = '';
                  });
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget buildRoomCard(RoomModel room) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              height: 55,
              width: 55,
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.meeting_room_rounded,
                color: primaryGreen,
                size: 29,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          getFloorName(room.floor),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.apartment, size: 14, color: Colors.grey),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Building ID: ${room.buildingId}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (room.description != null &&
                      room.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      room.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 15, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 55),
      child: Column(
        children: [
          Icon(icon, size: 55, color: Colors.grey.shade400),
          const SizedBox(height: 14),
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
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = context.watch<RoomProvider>();
    final filteredRooms = filterRooms(roomProvider.rooms);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryGreen,
          onRefresh: refreshRooms,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Rooms',
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'View and monitor rooms across all buildings.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 22),

              // Room summary
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.meeting_room_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Registered Rooms',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${roomProvider.rooms.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh rooms',
                      onPressed: roomProvider.isLoading ? null : refreshRooms,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Search
              buildSearchBar(),

              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Rooms',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filteredRooms.length} found',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (roomProvider.isLoading && roomProvider.rooms.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  ),
                )
              else if (roomProvider.errorMessage != null &&
                  roomProvider.rooms.isEmpty)
                buildEmptyState(
                  icon: Icons.cloud_off,
                  title: 'Unable to Load Rooms',
                  message: roomProvider.errorMessage!,
                )
              else if (filteredRooms.isEmpty)
                buildEmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: searchQuery.isEmpty
                      ? 'No Rooms Yet'
                      : 'No Matching Rooms',
                  message: searchQuery.isEmpty
                      ? 'Rooms added to your buildings will appear here.'
                      : 'Try searching with another room name or building ID.',
                )
              else
                ...filteredRooms.map(buildRoomCard),

              if (roomProvider.errorMessage != null &&
                  roomProvider.rooms.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Refresh failed: ${roomProvider.errorMessage}',
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
