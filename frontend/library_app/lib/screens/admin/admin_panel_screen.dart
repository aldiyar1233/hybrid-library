import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/reservation.dart';
import '../../widgets/loading_widget.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _apiService = ApiService();
  List<Reservation> _reservations = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

Future<void> _loadReservations() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    final response = await _apiService.get('/api/admin/reservations/');

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);
      
      // ✅ ИСПРАВЛЕНО: обработка пагинации
      List<dynamic> reservationsData;
      if (data is Map && data.containsKey('results')) {
        reservationsData = data['results'];
      } else if (data is List) {
        reservationsData = data;
      } else {
        throw Exception('Неверный формат данных');
      }
      
      setState(() {
        _reservations = reservationsData.map((json) => Reservation.fromJson(json)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = _apiService.handleError(response);
        _isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      _error = 'Ошибка загрузки: $e';
      _isLoading = false;
    });
  }
}

  Future<void> _confirmReservation(Reservation reservation) async {
    try {
      final response = await _apiService.post(
        '/api/admin/reservations/${reservation.id}/confirm/',
        {},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Бронирование подтверждено'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReservations();
      } else {
        final error = _apiService.handleError(response);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markAsTaken(Reservation reservation) async {
    try {
      final response = await _apiService.post(
        '/api/admin/reservations/${reservation.id}/taken/',
        {},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Книга отмечена как выданная'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReservations();
      } else {
        final error = _apiService.handleError(response);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markAsReturned(Reservation reservation) async {
    try {
      final response = await _apiService.post(
        '/api/admin/reservations/${reservation.id}/returned/',
        {},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Книга отмечена как возвращенная'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReservations();
      } else {
        final error = _apiService.handleError(response);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Reservation> get _filteredReservations {
    if (_filter == 'all') return _reservations;
    if (_filter == 'pending') {
      return _reservations.where((r) => r.isPending).toList();
    }
    if (_filter == 'confirmed') {
      return _reservations.where((r) => r.isConfirmed).toList();
    }
    if (_filter == 'taken') {
      return _reservations.where((r) => r.isTaken).toList();
    }
    return _reservations;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Все', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Ожидают', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Подтверждены', 'confirmed'),
                const SizedBox(width: 8),
                _buildFilterChip('Выданы', 'taken'),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const LoadingWidget(message: 'Загрузка бронирований...')
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 60, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(_error!),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadReservations,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    )
                  : _filteredReservations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox,
                                  size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Нет бронирований',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadReservations,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredReservations.length,
                            itemBuilder: (context, index) {
                              final reservation = _filteredReservations[index];
                              return _buildReservationCard(reservation);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusChip(reservation),
                Text(
                  'ID: ${reservation.id}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (reservation.userDetails != null) ...[
              Row(
                children: [
                  const Icon(Icons.person, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    reservation.userDetails!.username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    reservation.userDetails!.email,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            if (reservation.bookDetails != null) ...[
              Row(
                children: [
                  const Icon(Icons.book, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reservation.bookDetails!.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                reservation.bookDetails!.author,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            if (reservation.userComment != null &&
                reservation.userComment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Комментарий пользователя:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation.userComment!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildActionButtons(reservation),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Reservation reservation) {
    Color color;
    IconData icon;

    if (reservation.isPending) {
      color = Colors.orange;
      icon = Icons.schedule;
    } else if (reservation.isConfirmed) {
      color = Colors.blue;
      icon = Icons.check_circle_outline;
    } else if (reservation.isTaken) {
      color = Colors.purple;
      icon = Icons.menu_book;
    } else if (reservation.isReturned) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else {
      color = Colors.grey;
      icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            reservation.statusDisplay,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Reservation reservation) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (reservation.isPending)
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Подтвердить'),
            onPressed: () => _confirmReservation(reservation),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        if (reservation.isConfirmed)
          ElevatedButton.icon(
            icon: const Icon(Icons.local_library, size: 18),
            label: const Text('Выдана'),
            onPressed: () => _markAsTaken(reservation),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        if (reservation.isTaken)
          ElevatedButton.icon(
            icon: const Icon(Icons.assignment_return, size: 18),
            label: const Text('Возвращена'),
            onPressed: () => _markAsReturned(reservation),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}