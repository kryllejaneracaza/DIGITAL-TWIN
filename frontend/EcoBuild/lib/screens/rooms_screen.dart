import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room_model.dart';
import '../providers/room_provider.dart';
import '../providers/building_provider.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  static const Color primaryGreen = Color(0xFF125838);
  static const Color backgroundColor = Color(0xFFEAF8EF);
  static const Color lightGreen = Color(0xFFD9EFE1);
  static const Color darkText = Color(0xFF183B2B);

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  final List<String> _floors = [
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final roomProvider = context.read<RoomProvider>();
    final buildingProvider = context.read<BuildingProvider>();

    await Future.wait([
      roomProvider.fetchAllRooms(),
      buildingProvider.fetchBuildings(),
    ]);
  }

  Future<void> _refreshRooms() async {
    await _loadData();
  }

  String _floorName(int? floor) {
    if (floor == null || floor < 0 || floor >= _floors.length) {
      return 'Unassigned Floor';
    }

    return _floors[floor];
  }

  String _buildingName(String buildingId) {
    final buildings = context.read<BuildingProvider>().buildings;

    for (final building in buildings) {
      if (building.id == buildingId) {
        return building.name;
      }
    }

    return 'Building ID: $buildingId';
  }

  List<RoomModel> _filteredRooms(List<RoomModel> rooms) {
    if (_searchQuery.isEmpty) return rooms;

    return rooms.where((room) {
      final buildingName = _buildingName(room.buildingId).toLowerCase();

      return room.name.toLowerCase().contains(_searchQuery) ||
          buildingName.contains(_searchQuery) ||
          _floorName(room.floor).toLowerCase().contains(_searchQuery) ||
          room.description?.toLowerCase().contains(_searchQuery) == true;
    }).toList();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRoomDialog({RoomModel? room}) {
    final nameController = TextEditingController(text: room?.name ?? '');
    final descriptionController = TextEditingController(
      text: room?.description ?? '',
    );

    final buildings = context.read<BuildingProvider>().buildings;

    String? selectedBuildingId = room?.buildingId;
    int selectedFloor = room?.floor ?? 0;
    bool isSaving = false;

    if (selectedBuildingId == null ||
        !buildings.any((building) => building.id == selectedBuildingId)) {
      selectedBuildingId = buildings.isNotEmpty ? buildings.first.id : null;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, updateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                room == null ? 'Add New Room' : 'Edit Room',
                style: const TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'Room Name',
                        hintText: 'Enter room name',
                        prefixIcon: const Icon(
                          Icons.meeting_room_rounded,
                          color: primaryGreen,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: primaryGreen,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: selectedBuildingId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Building',
                        prefixIcon: const Icon(
                          Icons.apartment_rounded,
                          color: primaryGreen,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: buildings.map((building) {
                        return DropdownMenuItem<String>(
                          value: building.id,
                          child: Text(
                            building.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              updateDialog(() {
                                selectedBuildingId = value;
                              });
                            },
                    ),

                    if (buildings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'No buildings available. Add a building first.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      initialValue: selectedFloor,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Floor',
                        prefixIcon: const Icon(
                          Icons.layers_rounded,
                          color: primaryGreen,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: List.generate(_floors.length, (index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text(_floors[index]),
                        );
                      }),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                updateDialog(() {
                                  selectedFloor = value;
                                });
                              }
                            },
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: descriptionController,
                      enabled: !isSaving,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Enter room description',
                        prefixIcon: const Icon(
                          Icons.description_outlined,
                          color: primaryGreen,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                  onPressed: isSaving || buildings.isEmpty
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final description = descriptionController.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a room name.'),
                              ),
                            );
                            return;
                          }

                          if (selectedBuildingId == null) return;

                          final roomProvider = dialogContext
                              .read<RoomProvider>();

                          final duplicate = roomProvider.rooms.any((item) {
                            return item.id != room?.id &&
                                item.buildingId == selectedBuildingId &&
                                item.floor == selectedFloor &&
                                item.name.toLowerCase() == name.toLowerCase();
                          });

                          if (duplicate) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'This room already exists in this building and floor.',
                                ),
                              ),
                            );
                            return;
                          }

                          updateDialog(() {
                            isSaving = true;
                          });

                          final roomData = RoomModel(
                            id: room?.id ?? '',
                            buildingId: selectedBuildingId!,
                            name: name,
                            floor: selectedFloor,
                            description: description.isEmpty
                                ? null
                                : description,
                            status: room?.status,
                          );

                          final bool success;

                          if (room == null) {
                            success = await roomProvider.addRoom(roomData);
                          } else {
                            success = await roomProvider.editRoom(
                              room.id,
                              roomData,
                            );
                          }

                          if (!mounted || !dialogContext.mounted) return;

                          if (success) {
                            Navigator.pop(dialogContext);

                            _showMessage(
                              room == null
                                  ? '$name added successfully!'
                                  : '$name updated successfully!',
                            );
                          } else {
                            updateDialog(() {
                              isSaving = false;
                            });

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  roomProvider.errorMessage ??
                                      'Unable to save room.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(room == null ? 'ADD ROOM' : 'SAVE CHANGES'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      descriptionController.dispose();
    });
  }

  Future<void> _deleteRoom(RoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Delete Room?',
            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${room.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<RoomProvider>().removeRoom(room.id);

    if (!mounted) return;

    if (success) {
      _showMessage('${room.name} deleted successfully!');
    } else {
      final error = context.read<RoomProvider>().errorMessage;
      _showMessage(error ?? 'Unable to delete room.', isError: true);
    }
  }

  Widget _overviewCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 8),
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
            Icon(icon, color: primaryGreen, size: 27),
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

  Widget _roomCard(RoomModel room) {
    final buildingName = _buildingName(room.buildingId);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
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
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.meeting_room_rounded,
                color: primaryGreen,
                size: 29,
              ),
            ),
            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.apartment_rounded,
                        color: primaryGreen,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          buildingName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        color: primaryGreen,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _floorName(room.floor),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (room.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      room.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF718579),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (room.status?.isNotEmpty == true) ...[
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: lightGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        room.status!,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            PopupMenuButton<String>(
              tooltip: 'Room options',
              icon: const Icon(Icons.more_vert, color: primaryGreen),
              onSelected: (value) {
                if (value == 'edit') {
                  _showRoomDialog(room: room);
                } else if (value == 'delete') {
                  _deleteRoom(room);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: primaryGreen),
                      SizedBox(width: 10),
                      Text('Edit Room'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Delete Room'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, color: primaryGreen.withValues(alpha: 0.45), size: 65),
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
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 42),
          const SizedBox(height: 10),
          const Text(
            'Unable to load rooms',
            style: TextStyle(color: darkText, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _refreshRooms,
            icon: const Icon(Icons.refresh),
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
    final roomProvider = context.watch<RoomProvider>();
    final rooms = roomProvider.rooms;
    final filteredRooms = _filteredRooms(rooms);

    final buildingCount = rooms
        .map((room) => room.buildingId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Rooms',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh rooms',
            onPressed: _refreshRooms,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 5),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoomDialog(),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Room',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryGreen,
          onRefresh: _refreshRooms,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
            children: [
              const Text(
                'Room Management',
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage and organize rooms across your buildings.',
                style: TextStyle(color: Color(0xFF718579), fontSize: 13),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  _overviewCard(
                    icon: Icons.meeting_room_rounded,
                    title: 'Total Rooms',
                    value: '${rooms.length}',
                  ),
                  const SizedBox(width: 10),
                  _overviewCard(
                    icon: Icons.apartment_rounded,
                    title: 'Buildings',
                    value: '$buildingCount',
                  ),
                  const SizedBox(width: 10),
                  _overviewCard(
                    icon: Icons.layers_rounded,
                    title: 'Floors',
                    value: rooms
                        .map((room) => room.floor)
                        .whereType<int>()
                        .toSet()
                        .length
                        .toString(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search rooms or buildings...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: primaryGreen,
                  ),
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
                    borderSide: const BorderSide(
                      color: primaryGreen,
                      width: 1.3,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

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
                    '${filteredRooms.length} Rooms',
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 13),

              if (roomProvider.isLoading && rooms.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(35),
                  child: Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  ),
                )
              else if (roomProvider.errorMessage != null && rooms.isEmpty)
                _errorState(roomProvider.errorMessage!)
              else if (rooms.isEmpty)
                _emptyState(
                  icon: Icons.meeting_room_outlined,
                  title: 'No Rooms Yet',
                  message:
                      'There are currently no rooms available. Add a room after creating a building.',
                )
              else if (filteredRooms.isEmpty)
                _emptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No Matching Rooms',
                  message:
                      'We could not find any rooms matching "$_searchQuery". Try another search.',
                )
              else
                ...filteredRooms.map(_roomCard),
            ],
          ),
        ),
      ),
    );
  }
}
