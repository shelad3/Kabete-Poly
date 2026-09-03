// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import '../../models/listing.dart';
import '../../services/listing_service.dart';
import '../../widgets/feature_gate.dart';
import '../../widgets/state_views.dart';
import 'listing_detail_screen.dart';

/// Formats an integer amount as "KES 12,000".
String formatKes(int? amount) {
  if (amount == null) return 'KES --';
  final digits = amount.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return 'KES $buf';
}

/// The Kejani tab — apartment/rental listings near campus.
///
/// Shown in both the guest home tabs and the community tabs.
class KejaniTab extends StatelessWidget {
  const KejaniTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: 'kejani',
      child: const _KejaniBody(),
    );
  }
}

class _KejaniBody extends StatefulWidget {
  const _KejaniBody();

  @override
  State<_KejaniBody> createState() => _KejaniBodyState();
}

class _KejaniBodyState extends State<_KejaniBody> {
  final ListingService _service = ListingService();
  String _selectedArea = 'All';
  String? _selectedRoomType;

  @override
  Widget build(BuildContext context) {
    final stream = _service.getAllListingsStream();

    return Column(
      children: [
        _buildFilterBar(context),
        Expanded(
          child: StreamBuilder<List<Listing>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var listings = snap.data ?? const <Listing>[];
              if (_selectedArea != 'All') {
                listings =
                    listings.where((l) => l.area == _selectedArea).toList();
              }
              if (_selectedRoomType != null) {
                listings = listings.where((l) => l.roomOptions.any(
                    (r) => r.type == _selectedRoomType)).toList();
              }
              if (listings.isEmpty) return _buildEmpty(context);
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: listings.length,
                itemBuilder: (context, i) => _ListingCard(
                  listing: listings[i],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _areaChip(context, 'All'),
                ...kListingAreas.map((a) => _areaChip(context, a)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: DropdownButtonFormField<String?>(
              initialValue: _selectedRoomType,
              decoration: InputDecoration(
                labelText: 'Room type',
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Any'),
                ),
                ...kListingRoomTypes.map(
                  (t) => DropdownMenuItem<String?>(value: t, child: Text(t)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedRoomType = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaChip(BuildContext context, String area) {
    final selected = _selectedArea == area;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(area),
        selected: selected,
        onSelected: (_) => setState(() => _selectedArea = area),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return const EmptyState(
      icon: Icons.apartment,
      title: 'No rental listings yet',
      subtitle: 'Check back soon for apartments around Kabete.',
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Listing listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = listing.startingPrice;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListingDetailScreen(listing: listing),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (listing.coverImage.isNotEmpty)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(
                  listing.coverImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.apartment, size: 48),
                  ),
                ),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.apartment,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (price != null)
                        Text(
                          'From ${formatKes(price)}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        listing.area,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (listing.roomOptions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: listing.roomOptions.map((r) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            r.type,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
