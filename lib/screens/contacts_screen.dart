import 'dart:async';

import 'package:flutter/material.dart';

import '../models/contact_record.dart';
import '../services/local_db_service.dart';
import '../services/send_queue_service.dart';
import '../widgets/status_badge.dart';
import 'preview_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  static const _pageSize = 60;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  ContactListFilter _filter = ContactListFilter.all;
  Timer? _refreshDebounce;
  Timer? _searchDebounce;
  String _appliedQuery = '';
  List<ContactRecord> _contacts = const [];
  int _selectedCount = 0;
  int _loadGeneration = 0;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    SendQueueService.instance.addListener(_refresh);
    unawaited(_loadSelectedCount());
    unawaited(_reloadContacts());
  }

  @override
  void dispose() {
    SendQueueService.instance.removeListener(_refresh);
    _refreshDebounce?.cancel();
    _searchDebounce?.cancel();
    _scrollController.dispose();
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

      _appliedQuery = nextQuery;
      unawaited(_reloadContacts());
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingInitial) return;
    if (_scrollController.position.extentAfter < 480) {
      unawaited(_loadMoreContacts());
    }
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

      unawaited(_reloadContacts(keepCurrentItems: _contacts.isNotEmpty));
      unawaited(_loadSelectedCount());
    });
  }

  Future<void> _reloadContacts({bool keepCurrentItems = false}) async {
    final generation = ++_loadGeneration;
    setState(() {
      _loadingInitial = !keepCurrentItems;
      _loadingMore = keepCurrentItems;
      _hasMore = true;
      _error = null;
      if (!keepCurrentItems) _contacts = const [];
    });

    try {
      final contacts = await LocalDbService.instance.getContactsPage(
        limit: _pageSize,
        offset: 0,
        filter: _filter,
        query: _appliedQuery,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _contacts = contacts;
        _hasMore = contacts.length == _pageSize;
        _loadingInitial = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _loadingInitial = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMoreContacts() async {
    if (_loadingMore || !_hasMore) return;

    final generation = _loadGeneration;
    setState(() => _loadingMore = true);
    try {
      final nextContacts = await LocalDbService.instance.getContactsPage(
        limit: _pageSize,
        offset: _contacts.length,
        filter: _filter,
        query: _appliedQuery,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _contacts = [..._contacts, ...nextContacts];
        _hasMore = nextContacts.length == _pageSize;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _loadingMore = false;
      });
    }
  }

  Future<void> _setContactSelected(ContactRecord contact, bool selected) async {
    final id = contact.id;
    if (id == null || selected == contact.isSelected) return;

    setState(() {
      _contacts = [
        for (final item in _contacts)
          item.id == id ? item.copyWith(isSelected: selected) : item,
      ];
      _selectedCount += selected ? 1 : -1;
      if (_selectedCount < 0) _selectedCount = 0;
    });

    try {
      await LocalDbService.instance.setContactSelected(id, selected);
    } catch (_) {
      if (!mounted) return;
      await _reloadContacts(keepCurrentItems: true);
      await _loadSelectedCount();
      rethrow;
    }
  }

  void _setFilter(ContactListFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    unawaited(_reloadContacts());
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
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
          IconButton(
            tooltip: 'تازه‌سازی',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'جستجو در نام، شماره یا توکن',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'پاک کردن جستجو',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ContactListFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = ContactListFilter.values[index];
                return FilterChip(
                  label: Text(_filterLabel(filter)),
                  selected: _filter == filter,
                  onSelected: (_) => _setFilter(filter),
                );
              },
            ),
          ),
          _SelectionActions(
            selectedCount: _selectedCount,
            onPreviewSelected: _selectedCount == 0
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PreviewScreen(selectedOnly: true),
                      ),
                    ),
            onPreviewAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PreviewScreen()),
            ),
          ),
          Expanded(child: _buildContactsList()),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    if (_loadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _contacts.isEmpty) {
      return _ErrorState(message: _error!, onRetry: _reloadContacts);
    }

    if (_contacts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reloadContacts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('مخاطبی برای نمایش وجود ندارد.')),
          ],
        ),
      );
    }

    final itemCount =
        _contacts.length + (_loadingMore || _error != null ? 1 : 0);
    return RefreshIndicator(
      onRefresh: _reloadContacts,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _contacts.length) {
            if (_error != null) {
              return _InlineError(message: _error!, onRetry: _loadMoreContacts);
            }
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return _ContactCard(
            key: ValueKey(_contacts[index].id ?? _contacts[index].sourceRow),
            contact: _contacts[index],
            onSelectedChanged: _setContactSelected,
          );
        },
      ),
    );
  }

  String _filterLabel(ContactListFilter filter) {
    return switch (filter) {
      ContactListFilter.all => 'همه',
      ContactListFilter.valid => 'معتبر',
      ContactListFilter.invalid => 'نامعتبر',
      ContactListFilter.duplicate => 'تکراری',
      ContactListFilter.pending => 'در انتظار',
      ContactListFilter.sent => 'ارسال‌شده',
      ContactListFilter.failed => 'ناموفق',
    };
  }
}

class _SelectionActions extends StatelessWidget {
  const _SelectionActions({
    required this.selectedCount,
    required this.onPreviewSelected,
    required this.onPreviewAll,
  });

  final int selectedCount;
  final VoidCallback? onPreviewSelected;
  final VoidCallback onPreviewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final countLabel = Text(
            'انتخاب‌شده: $selectedCount',
            style: Theme.of(context).textTheme.titleSmall,
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPreviewSelected,
                icon: const Icon(Icons.checklist),
                label: const Text('انتخابی'),
              ),
              TextButton.icon(
                onPressed: onPreviewAll,
                icon: const Icon(Icons.schedule),
                label: const Text('در انتظار'),
              ),
            ],
          );

          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                countLabel,
                const SizedBox(height: 8),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: countLabel),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    super.key,
    required this.contact,
    required this.onSelectedChanged,
  });

  final ContactRecord contact;
  final Future<void> Function(ContactRecord contact, bool selected)
      onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final displayName = contact.displayName;
    final phone = contact.phone.isEmpty ? contact.rawPhone : contact.phone;
    return Card(
      child: CheckboxListTile(
        value: contact.isSelected,
        onChanged: contact.id == null
            ? null
            : (value) => onSelectedChanged(contact, value ?? false),
        title: Text(
          displayName.isEmpty ? 'بدون نام' : displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phone.isEmpty ? 'شماره ثبت نشده' : phone,
                textDirection: TextDirection.ltr,
              ),
              if (contact.token.isNotEmpty)
                Text(
                  'توکن: ${contact.token}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(status: contact.status),
                  if (!contact.isValidPhone)
                    const _MiniFlag(
                      icon: Icons.warning_amber,
                      label: 'شماره نامعتبر',
                    ),
                  if (contact.isDuplicate)
                    const _MiniFlag(icon: Icons.copy, label: 'تکراری'),
                ],
              ),
            ],
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 8),
      ),
    );
  }
}

class _MiniFlag extends StatelessWidget {
  const _MiniFlag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
          ],
        ),
      ),
    );
  }
}
