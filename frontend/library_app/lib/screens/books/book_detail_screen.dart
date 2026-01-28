import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/book.dart';
import '../../services/api_service.dart';
import '../../config/constants.dart';
import '../../widgets/custom_button.dart';
import 'pdf_reader_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _apiService = ApiService();
  final _commentController = TextEditingController();
  bool _isReserving = false;

  @override
  void initState() {
    super.initState();
    _saveRecentlyViewed();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _saveRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentlyViewed =
          prefs.getStringList('recently_viewed') ?? [];

      // Удаляем книгу, если она уже есть в списке
      recentlyViewed.remove(widget.book.id.toString());

      // Добавляем книгу в начало списка
      recentlyViewed.insert(0, widget.book.id.toString());

      // Ограничиваем список 10 элементами
      if (recentlyViewed.length > 10) {
        recentlyViewed = recentlyViewed.sublist(0, 10);
      }

      await prefs.setStringList('recently_viewed', recentlyViewed);
    } catch (e) {
      // Игнорируем ошибки сохранения
    }
  }

  Future<void> _reserveBook() async {
    if (!widget.book.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Эта книга недоступна для бронирования'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ReservationDialog(
        commentController: _commentController,
      ),
    );

    if (result == null) return;

    setState(() => _isReserving = true);

    try {
      final requestData = {
        'book': widget.book.id,
        'user_comment': result['comment'] ?? '',
      };

      // Добавляем дату и время, если выбраны
      if (result['pickup_date'] != null) {
        requestData['pickup_date'] = result['pickup_date'];
      }
      if (result['pickup_time'] != null) {
        requestData['pickup_time'] = result['pickup_time'];
      }

      final response = await _apiService.post(
        '${AppConstants.reservationsEndpoint}create/',
        requestData,
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        // Очищаем комментарий после успешного бронирования
        _commentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Книга успешно забронирована!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
    } finally {
      setState(() => _isReserving = false);
    }
  }

  void _openPdfReader() {
    if (widget.book.pdfFileUrl != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfReaderScreen(
            pdfUrl: widget.book.pdfFileUrl!,
            bookTitle: widget.book.title ?? 'Книга', // ← ИСПРАВЛЕНО
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF файл недоступен'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали книги'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Обложка книги
            if (widget.book.coverImageUrl != null)
              Hero(
                tag: 'book_${widget.book.id}',
                child: SizedBox(
                  height: 400,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: widget.book.coverImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.book, size: 100),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок и автор
                  Text(
                    widget.book.title ?? 'Без названия',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.book.author ?? 'Неизвестный автор',
                    style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),

                  // Чипы информации
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: Icons.calendar_today,
                        label: '${widget.book.yearPublished}',
                      ),
                      const SizedBox(width: 8),
                      if (widget.book.genreName != null)
                        _buildInfoChip(
                          icon: Icons.category,
                          label: widget.book.genreName!,
                        ),
                      const SizedBox(width: 8),
                      _buildStatusChip(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ISBN
                  if (widget.book.isbn != null) ...[
                    Text(
                      'ISBN: ${widget.book.isbn}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Описание
                  const Text(
                    'Описание',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.book.description ?? 'Описание отсутствует',
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 32),

// Кнопки: Читать онлайн и Забронировать
                  if (widget.book.pdfFileUrl != null)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: CustomButton(
                              text: 'Читать',
                              onPressed: _openPdfReader,
                              icon: Icons.menu_book,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: CustomButton(
                              text: widget.book.isAvailable
                                  ? 'Бронь'
                                  : 'Недоступна',
                              onPressed:
                                  widget.book.isAvailable ? _reserveBook : null,
                              isLoading: _isReserving,
                              icon: Icons.bookmark_add,
                              gradient: widget.book.isAvailable
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF5C6BC0),
                                        Color(0xFF7E57C2)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      height: 48,
                      child: CustomButton(
                        text: widget.book.isAvailable ? 'Бронь' : 'Недоступна',
                        onPressed:
                            widget.book.isAvailable ? _reserveBook : null,
                        isLoading: _isReserving,
                        icon: Icons.bookmark_add,
                        gradient: widget.book.isAvailable
                            ? const LinearGradient(
                                colors: [Color(0xFF5C6BC0), Color(0xFF7E57C2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    IconData icon;

    if (widget.book.isAvailable) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (widget.book.isReserved) {
      color = Colors.orange;
      icon = Icons.schedule;
    } else {
      color = Colors.red;
      icon = Icons.block;
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
            widget.book.statusText,
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
}

// Диалог бронирования с выбором даты и времени
class _ReservationDialog extends StatefulWidget {
  final TextEditingController commentController;

  const _ReservationDialog({required this.commentController});

  @override
  State<_ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<_ReservationDialog> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      // locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Бронирование книги'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: widget.commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Комментарий (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Когда вы заберете книгу?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate != null
                          ? _formatDate(_selectedDate!)
                          : 'Выберите дату',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate != null
                            ? Colors.black87
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Text(
                      _selectedTime != null
                          ? _formatTime(_selectedTime!)
                          : 'Выберите время',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedTime != null
                            ? Colors.black87
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            final result = <String, dynamic>{
              'comment': widget.commentController.text,
            };
            if (_selectedDate != null) {
              // Формат для API: YYYY-MM-DD
              final year = _selectedDate!.year.toString();
              final month = _selectedDate!.month.toString().padLeft(2, '0');
              final day = _selectedDate!.day.toString().padLeft(2, '0');
              result['pickup_date'] = '$year-$month-$day';
            }
            if (_selectedTime != null) {
              // Формат для API: HH:MM:SS
              final hour = _selectedTime!.hour.toString().padLeft(2, '0');
              final minute = _selectedTime!.minute.toString().padLeft(2, '0');
              result['pickup_time'] = '$hour:$minute:00';
            }
            Navigator.pop(context, result);
          },
          child: const Text('Забронировать'),
        ),
      ],
    );
  }
}
