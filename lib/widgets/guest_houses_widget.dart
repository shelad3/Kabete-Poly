import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/house.dart';
import '../services/cube_service.dart';
import '../utils/term_utils.dart';

class GuestHousesWidget extends StatelessWidget {
  const GuestHousesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('houses').orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final houses = snapshot.data?.docs ?? [];
        if (houses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_work, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text('No houses listed yet', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Cubicle Houses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            ),
            ...houses.map((doc) {
              final house = House.fromJson(doc.data() as Map<String, dynamic>, doc.id);
              return _HouseCard(house: house);
            }),
          ],
        );
      },
    );
  }
}

class _HouseCard extends StatelessWidget {
  final House house;
  const _HouseCard({required this.house});

  @override
  Widget build(BuildContext context) {
    final isBoys = house.category == 'boys';
    final color = isBoys ? Colors.blue : Colors.pink;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(isBoys ? Icons.male : Icons.female, color: color),
        ),
        title: Text(house.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${house.totalCubes} cubes${house.reservedForNewStudents ? ' • New Students' : ''}',
            style: TextStyle(color: house.reservedForNewStudents ? Colors.orange[700] : Colors.grey[600], fontSize: 12)),
        children: [
          _CubeOccupancyList(houseId: house.id),
        ],
      ),
    );
  }
}

class _CubeOccupancyList extends StatelessWidget {
  final String houseId;
  const _CubeOccupancyList({required this.houseId});

  @override
  Widget build(BuildContext context) {
    final term = TermUtils.getCurrentTerm();
    final year = TermUtils.getCurrentYear();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cubes')
          .where('houseId', isEqualTo: houseId)
          .where('isActive', isEqualTo: true)
          .orderBy('cubeNumber')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator());
        final cubes = snap.data!.docs;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: cubes.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final cubeNum = (data['cubeNumber'] as num?)?.toInt() ?? 0;
              final maxOcc = (data['maxOccupancy'] as num?)?.toInt() ?? 4;
              return FutureBuilder<int>(
                future: CubeService().getBookedCountForCube(doc.id, term, year),
                builder: (_, countSnap) {
                  final booked = countSnap.data ?? 0;
                  final free = maxOcc - booked;
                  final isFull = free <= 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFull ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isFull ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'C$cubeNum${isFull ? ' (Full)' : ' ($free free)'}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: isFull ? Colors.red[700] : Colors.green[700]),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
