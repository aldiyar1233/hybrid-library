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

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();

  List<Reservation> _reservations = [];
  bool _isLoading = true;
  bool _isActionLoading = false; // чтобы не нажимали кнопки много раз
  String? _error;
  String _filter = 'all';

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadReservations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // -------------------------
  // LOAD
  // -------------------------
  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.get('/api/admin/reservations/');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        List<dynamic> reservationsData;
        if (data is Map && data.containsKey('results')) {
          reservationsData = data['results'];
        } else if (data is List) {
          reservationsData = data;
        } else {
          throw Exception('Неверный формат данных');
        }

        setState(() {
          _reservations = reservationsData
              .map((json) => Reservation.fromJson(json))
              .toList();
          _isLoading = false;
        });
        _animationController.forward(from: 0);
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

  // -------------------------
  // CONFIRM DIALOG (Да/Нет)
  // -------------------------
  Future<bool> _askConfirm({
    required String title,
    required String message,
    String cancelText = 'Нет',
    String okText = 'Да',
    Color? okColor,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: okColor,
              foregroundColor: Colors.white,
            ),
            child: Text(okText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  String _reservationShortInfo(Reservation r) {
    final book = r.bookDetails?.title;
    final user = r.userDetails?.username;
    final parts = <String>[];
    if (book != null && book.trim().isNotEmpty) parts.add('Книга: $book');
    if (user != null && user.trim().isNotEmpty)
      parts.add('Пользователь: $user');
    parts.add('ID: ${r.id}');
    return parts.join('\n');
  }

  void _showNiceSnack(String text, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // -------------------------
  // ACTIONS (API)
  // -------------------------
  Future<void> _confirmReservation(Reservation reservation) async {
    setState(() => _isActionLoading = true);
    try {
      final response = await _apiService.post(
        '/api/admin/reservations/${reservation.id}/confirm/',
        {},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        _showNiceSnack(
            'Бронирование подтверждено', Colors.blue, Icons.check_circle);
        await _loadReservations();
      } else {
        final error = _apiService.handleError(response);
        if (!mounted) return;
        _showNiceSnack(error, Colors.red, Icons.error_outline);
      }
    } catch (e) {
      if (!mounted) return;
      _showNiceSnack('Ошибка: $e', Colors.red, Icons.error_outline);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _markAsTaken(Reservation reservation) async {
    setState(() => _isActionLoading = true);
    try {
      final response = await _apiService.post(
        '/api/admin/reservations/${reservation.id}/taken/',
        {},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        _showNiceSnack('Книга выдана', Colors.purple, Icons.menu_book);
        await _loadReservations();
      } else {
        final error = _apiService.handleError(response);
        if (!mounted) return;
        _showNiceSnack(error, Colors.red, Icons.error_outline);
      }
    } catch (e) {
      if (!mounted) return;
      _showNiceSnack('Ошибка: $e', Colors.red, Icons.error_outline);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _markAsReturned(Reservation reservation) async {
    setState(() => _isActionLoading = true);
    try {
      final response = await _apiService.post(
        '/api/admin/reservations/${reservation.id}/returned/',
        {},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        _showNiceSnack(
            'Книга возвращена', Colors.green, Icons.assignment_turned_in);
        await _loadReservations();
      } else {
        final error = _apiService.handleError(response);
        if (!mounted) return;
        _showNiceSnack(error, Colors.red, Icons.error_outline);
      }
    } catch (e) {
      if (!mounted) return;
      _showNiceSnack('Ошибка: $e', Colors.red, Icons.error_outline);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // -------------------------
  // FILTERS / COUNTS
  // -------------------------
  List<Reservation> get _filteredReservations {
    if (_filter == 'all') return _reservations;
    if (_filter == 'pending')
      return _reservations.where((r) => r.isPending).toList();
    if (_filter == 'confirmed')
      return _reservations.where((r) => r.isConfirmed).toList();
    if (_filter == 'taken')
      return _reservations.where((r) => r.isTaken).toList();
    return _reservations;
  }

  int get _pendingCount => _reservations.where((r) => r.isPending).length;
  int get _confirmedCount => _reservations.where((r) => r.isConfirmed).length;
  int get _takenCount => _reservations.where((r) => r.isTaken).length;
  int get _returnedCount => _reservations.where((r) => r.isReturned).length;

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isLoading && _error == null) _buildDashboard(),

        // Фильтры
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                    'Все', 'all', _reservations.length, Colors.grey),
                const SizedBox(width: 8),
                _buildFilterChip(
                    'Ожидают', 'pending', _pendingCount, Colors.orange),
                const SizedBox(width: 8),
                _buildFilterChip(
                    'Подтверждены', 'confirmed', _confirmedCount, Colors.blue),
                const SizedBox(width: 8),
                _buildFilterChip('Выданы', 'taken', _takenCount, Colors.purple),
              ],
            ),
          ),
        ),

        // Список бронирований
        Expanded(
          child: _isLoading
              ? const LoadingWidget(message: 'Загрузка бронирований...')
              : _error != null
                  ? _buildErrorState()
                  : _filteredReservations.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadReservations,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredReservations.length,
                            itemBuilder: (context, index) {
                              final reservation = _filteredReservations[index];
                              return FadeTransition(
                                opacity: _animationController,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.3, 0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: Interval(
                                        (index * 0.08).clamp(0.0, 1.0),
                                        1.0,
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                  ),
                                  child: _buildReservationCard(reservation),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
              child: _buildStatCard(
                  'Ожидают', _pendingCount, Colors.orange, Icons.schedule)),
          const SizedBox(width: 12),
          Expanded(
              child: _buildStatCard('Подтверждены', _confirmedCount,
                  Colors.blue, Icons.check_circle)),
          const SizedBox(width: 12),
          Expanded(
              child: _buildStatCard(
                  'Выданы', _takenCount, Colors.purple, Icons.menu_book)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count, Color color) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          ),
          const SizedBox(height: 24),
          Text(
            'Ошибка загрузки',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadReservations,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    if (_filter == 'pending') {
      message = 'Нет ожидающих бронирований';
      icon = Icons.check_circle_outline;
    } else if (_filter == 'confirmed') {
      message = 'Нет подтвержденных бронирований';
      icon = Icons.pending_actions;
    } else if (_filter == 'taken') {
      message = 'Нет выданных книг';
      icon = Icons.library_books;
    } else {
      message = 'Пока нет бронирований';
      icon = Icons.inbox;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Новые запросы появятся здесь',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(reservation),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ID: ${reservation.id}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (reservation.userDetails != null) _buildUserBlock(reservation),
              const SizedBox(height: 12),
              if (reservation.bookDetails != null) _buildBookBlock(reservation),
              if (reservation.pickupDate != null) ...[
                const SizedBox(height: 12),
                _buildPickupBlock(reservation),
              ],
              if (reservation.userComment != null &&
                  reservation.userComment!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildCommentBlock(reservation),
              ],
              const SizedBox(height: 16),
              _buildActionButtons(reservation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserBlock(Reservation reservation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue[200],
            child: Text(
              reservation.userDetails!.username[0].toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation.userDetails!.username,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  reservation.userDetails!.email,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookBlock(Reservation reservation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.book, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation.bookDetails!.title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  reservation.bookDetails!.author,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupBlock(Reservation reservation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available, color: Colors.purple[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Планируемое получение:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple[900],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[700]),
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
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey[700]),
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
    );
  }

  Widget _buildCommentBlock(Reservation reservation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.comment, size: 18, color: Colors.amber[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Комментарий:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reservation.userComment ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            reservation.statusDisplay,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Reservation reservation) {
    final disabled = _isActionLoading;

    return Row(
      children: [
        if (reservation.isPending)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Подтвердить'),
              onPressed: disabled
                  ? null
                  : () async {
                      final ok = await _askConfirm(
                        title: 'Подтверждение брони',
                        message:
                            'Вы точно хотите подтвердить эту бронь?\n\n${_reservationShortInfo(reservation)}',
                        okText: 'Да, подтвердить',
                        cancelText: 'Нет',
                        okColor: Colors.blue,
                        icon: Icons.check_circle_outline,
                      );
                      if (!ok) return;
                      await _confirmReservation(reservation);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        if (reservation.isConfirmed)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.local_library, size: 18),
              label: const Text('Выдать'),
              onPressed: disabled
                  ? null
                  : () async {
                      final ok = await _askConfirm(
                        title: 'Выдача книги',
                        message:
                            'Вы точно хотите отметить книгу как выданную?\n\n${_reservationShortInfo(reservation)}',
                        okText: 'Да, выдать',
                        cancelText: 'Нет',
                        okColor: Colors.purple,
                        icon: Icons.menu_book,
                      );
                      if (!ok) return;
                      await _markAsTaken(reservation);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        if (reservation.isTaken)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.assignment_return, size: 18),
              label: const Text('Вернуть'),
              onPressed: disabled
                  ? null
                  : () async {
                      final ok = await _askConfirm(
                        title: 'Возврат книги',
                        message:
                            'Вы точно хотите отметить книгу как возвращённую?\n\n${_reservationShortInfo(reservation)}',
                        okText: 'Да, вернуть',
                        cancelText: 'Нет',
                        okColor: Colors.green,
                        icon: Icons.assignment_turned_in,
                      );
                      if (!ok) return;
                      await _markAsReturned(reservation);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
