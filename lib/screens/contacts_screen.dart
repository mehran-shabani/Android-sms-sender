import 'dart:async';

import 'package:flutter/material.dart';

import '../models/contact_record.dart';
import '../services/local_db_service.dart';
import '../services/send_queue_service.dart';
import '../widgets/status_badge.dart';
import 'preview_screen.dart';

enum ContactFilter { all, valid, invalid, duplicate, pending, sent, failed }

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  ContactFilter _filter = ContactFilter.all;
  late Future<List<ContactRecord>> _contactsFuture;
  Timer? _refreshDebounce;
  Timer? _searchDebounce;
  String _appliedQuery = '';
  List<ContactRecord>? _filteredContactsCache;
  List<ContactRecord>? _filteredContactsCacheSource;
  int? _filteredContactsCacheCount;
  ContactFilter? _filteredContactsCacheFilter;
  String? _filteredContactsCacheQuery;
  int _selectedCount = 0;

  @override
  void initState() {
    super.initState();
    _contactsFuture = LocalDbService.instance.getAllContacts();
    _loadSelectedCount();
    _searchController.addListener(_onSearchChanged);
    SendQueueService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    SendQueueService.instance.removeListener(_refresh);
    _refreshDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchDebounce = null;
      if (!mounted) return;

      final nextQuery = _searchController.text.trim().toLowerCase();
      if (nextQuery == _appliedQuery) return;

      setState(() {
        _appliedQuery = nextQuery;
      });
    });
  }

  Future<void> _loadSelectedCount() async {
    final count = await LocalDbService.instance.getSelectedContactsCount();
    if (!mounted) return;
    setState(() => _selectedCount = count);
  }

  void _refresh() {
    if (_refreshDebounce?.isActive ?? false) return;

    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      _refreshDebounce = null;
      if (!mounted) return;

      setState(() {
        _contactsFuture = LocalDbService.instance.getAllContacts();
      });
      _loadSelectedCount();
    });
  }

  Future<void> _setContactSelected(ContactRecord contact, bool selected) async {
    final id = contact.id;
    if (id == null || selected == contact.isSelected) return;

    setState(() {
      _contactsFuture = _contactsFuture.then((contacts) {
        return contacts
            .map((item) => item.id == id
                ? item.copyWith(isSelected: selected)
                : item)
            .toList();
      });
      _selectedCount += selected ? 1 : -1;
      if (_selectedCount < 0) _selectedCount = 0;
    });

    try {
      await LocalDbService.instance.setContactSelected(id, selected);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _contactsFuture = LocalDbService.instance.getAllContacts();
      });
      await _loadSelectedCount();
      rethrow;
    }
  }

  List<ContactRecord> _applyFilters(List<ContactRecord> contacts) {
    final query = _appliedQuery;
    final cachedContacts = _filteredContactsCache;
    if (cachedContacts != null &&
        identical(_filteredContactsCacheSource, contacts) &&
        _filteredContactsCacheCount == contacts.length &&
        _filteredContactsCacheFilter == _filter &&
        _filteredContactsCacheQuery == query) {
      return cachedContacts;
    }

    final filteredContacts = contacts.where((contact) {
      final matchesFilter = switch (_filter) {
        ContactFilter.all => true,
        ContactFilter.valid => contact.isValidPhone,
        ContactFilter.invalid => !contact.isValidPhone,
        ContactFilter.duplicate => contact.isDuplicate,
        ContactFilter.pending => contact.status == ContactStatus.pending,
        ContactFilter.sent => contact.status == ContactStatus.sent,
        ContactFilter.failed => contact.status == ContactStatus.failed,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return contact.phone.toLowerCase().contains(query) ||
          contact.rawPhone.toLowerCase().contains(query) ||
          contact.fullName.toLowerCase().contains(query) ||
          contact.firstName.toLowerCase().contains(query) ||
          contact.lastName.toLowerCase().contains(query) ||
          contact.token.toLowerCase().contains(query);
    }).toList();

    _filteredContactsCache = filteredContacts;
    _filteredContactsCacheSource = contacts;
    _filteredContactsCacheCount = contacts.length;
    _filteredContactsCacheFilter = _filter;
    _filteredContactsCacheQuery = query;

    return filteredContacts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مخاطبین'),
        actions: [
          IconButton(
            tooltip: 'پیش‌نمایش همه در انتظار',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PreviewScreen()),
            ),
            icon: const Icon(Icons.preview),
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'جستجو در نام، شماره یا توکن',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ContactFilter.values.map((filter) {
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(filter)),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Text('انتخاب‌شده: $_selectedCount')),
                TextButton(
                  onPressed: _selectedCount == 0
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const PreviewScreen(selectedOnly: true),
                            ),
                          ),
                  child: const Text('پیش‌نمایش انتخاب‌شده‌ها'),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PreviewScreen()),
                  ),
                  child: const Text('پیش‌نمایش همه در انتظار'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ContactRecord>>(
              future: _contactsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final contacts = _applyFilters(snapshot.data ?? const []);
                if (contacts.isEmpty) {
                  return const Center(child: Text('مخاطبی برای نمایش وجود ندارد.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final displayName = contact.fullName.trim().isNotEmpty
                          ? contact.fullName
                          : '${contact.firstName} ${contact.lastName}'.trim();
                      final id = contact.id;
                      final selected = contact.isSelected;
                      return Card(
                        child: CheckboxListTile(
                          value: selected,
                          onChanged: id == null
                              ? null
                              : (value) {
                                  _setContactSelected(contact, value ?? false);
                                },
                          title: Text(displayName.isEmpty ? 'بدون نام' : displayName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'شماره: ${contact.phone.isEmpty ? contact.rawPhone : contact.phone}',
                              ),
                              Text('توکن: ${contact.token}'),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: StatusBadge(status: contact.status),
                              ),
                            ],
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(ContactFilter filter) {
    return switch (filter) {
      ContactFilter.all => 'همه',
      ContactFilter.valid => 'معتبر',
      ContactFilter.invalid => 'نامعتبر',
      ContactFilter.duplicate => 'تکراری',
      ContactFilter.pending => 'در انتظار',
      ContactFilter.sent => 'ارسال‌شده',
      ContactFilter.failed => 'ناموفق',
    };
  }
}
