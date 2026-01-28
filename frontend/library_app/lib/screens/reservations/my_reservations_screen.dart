import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/reservation.dart';
import '../../config/constants.dart';
import '../../widgets/loading_widget.dart';
import '../books/book_detail_screen.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({Key? key}) : super(key: key);

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final _apiService = ApiService();
  List<Reservation> _reservations = [];
  bool _isLoading = true;
  String? _error;

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
      final response = await _apiService.get(AppConstants.reservationsEndpoint);

      if (response.statusCode == 200) {
        final dynamic responseBody = jsonDecode(response.body);
        
        // ✅ ИСПРАВЛЕНО: Обработка пагинации как в book_list_screen
        List<dynamic> data;
        
        if (responseBody is Map && responseBody.containsKey('results')) {
          data = responseBody['results'];
        } else if (responseBody is List) {
          data = responseBody;
        } else {
          throw Exception('Неверный формат данных');
        }
        
        setState(() {
          _reservations = data.map((json) => Reservation.fromJson(json)).toList();
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

  Future<void> _cancelReservation(Reservation reservation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отмена бронирования'),
        content: const Text('Вы уверены, что хотите отменить бронирование?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _apiService.post(
        '${AppConstants.reservationsEndpoint}${reservation.id}/cancel/',
        {},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Бронирование отменено'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReservations();
      } else {
        final error = _apiService.handleError(response);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: 'Загрузка бронирований...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReservations,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_reservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'У вас пока нет бронирований',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Подсчет статистики
    final totalReservations = _reservations.length;
    final activeReservations = _reservations
        .where((r) => r.isPending || r.isConfirmed || r.isTaken)
        .length;
    final returnedBooks = _reservations.where((r) => r.isReturned).length;

    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reservations.length + 1, // +1 для карточек статистики
        itemBuilder: (context, index) {
          // Первый элемент - статистика
          if (index == 0) {
            return Column(
              children: [
                _buildStatisticsSection(
                  totalReservations,
                  activeReservations,
                  returnedBooks,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Мои бронирования',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }

          // Остальные элементы - карточки бронирований
          final reservation = _reservations[index - 1];
          return _buildReservationCard(reservation);
        },
      ),
    );
  }

  Widget _buildStatisticsSection(
    int total,
    int active,
    int returned,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.library_books,
            iconColor: Colors.blue,
            title: 'Всего',
            value: total.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.pending_actions,
            iconColor: Colors.orange,
            title: 'Активные',
            value: active.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle,
            iconColor: Colors.green,
            title: 'Возвращено',
            value: returned.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [iconColor.withOpacity(0.1), iconColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
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
                  _formatDate(reservation.reservationDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (reservation.bookDetails != null) ...[
              Text(
                reservation.bookDetails!.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reservation.bookDetails!.author,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            // Планируемое время получения
            if (reservation.pickupDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.green[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Планируемое получение:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: Colors.grey[700]),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(reservation.pickupDate!),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (reservation.pickupTime != null) ...[
                                const SizedBox(width: 12),
                                Icon(Icons.schedule, size: 14, color: Colors.grey[700]),
                                const SizedBox(width: 4),
                                Text(
                                  reservation.pickupTime!.substring(0, 5),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                      'Ваш комментарий:',
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
            if (reservation.adminComment != null &&
                reservation.adminComment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Комментарий админа:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation.adminComment!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Timeline визуализация
            _buildTimeline(reservation),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (reservation.bookDetails != null)
                  TextButton.icon(
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Подробнее'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookDetailScreen(
                            book: reservation.bookDetails!,
                          ),
                        ),
                      );
                    },
                  ),
                if (reservation.isPending || reservation.isConfirmed)
                  TextButton.icon(
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Отменить'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _cancelReservation(reservation),
                  ),
              ],
            ),
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

  Widget _buildTimeline(Reservation reservation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Статус бронирования:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTimelineStep(
                icon: Icons.add_circle,
                label: 'Создано',
                isCompleted: true,
                isActive: reservation.isPending && !reservation.isConfirmed,
                color: Colors.blue,
              ),
              _buildTimelineConnector(isActive: reservation.isConfirmed || reservation.isTaken || reservation.isReturned),
              _buildTimelineStep(
                icon: Icons.check_circle,
                label: 'Подтверждено',
                isCompleted: reservation.isConfirmed || reservation.isTaken || reservation.isReturned,
                isActive: reservation.isConfirmed && !reservation.isTaken,
                color: Colors.green,
              ),
              _buildTimelineConnector(isActive: reservation.isTaken || reservation.isReturned),
              _buildTimelineStep(
                icon: Icons.menu_book,
                label: 'Получено',
                isCompleted: reservation.isTaken || reservation.isReturned,
                isActive: reservation.isTaken && !reservation.isReturned,
                color: Colors.purple,
              ),
              _buildTimelineConnector(isActive: reservation.isReturned),
              _buildTimelineStep(
                icon: Icons.assignment_turned_in,
                label: 'Возвращено',
                isCompleted: reservation.isReturned,
                isActive: reservation.isReturned,
                color: Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String label,
    required bool isCompleted,
    required bool isActive,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted || isActive ? color : Colors.grey[300],
              border: Border.all(
                color: isActive ? color : Colors.transparent,
                width: 3,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isCompleted || isActive ? Colors.white : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isCompleted || isActive ? color : Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineConnector({required bool isActive}) {
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.only(bottom: 30),
      color: isActive ? Colors.green : Colors.grey[300],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}