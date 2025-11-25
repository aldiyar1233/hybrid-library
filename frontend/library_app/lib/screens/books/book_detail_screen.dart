import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Бронирование книги'),
        content: TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Комментарий (необязательно)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _commentController.text),
            child: const Text('Забронировать'),
          ),
        ],
      ),
    );

    if (comment == null) return;

    setState(() => _isReserving = true);

    try {
      final response = await _apiService.post(
        '${AppConstants.reservationsEndpoint}create/',
        {
          'book': widget.book.id,
          'user_comment': comment,
        },
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
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
            bookTitle: widget.book.title ?? 'Книга',  // ← ИСПРАВЛЕНО
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
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: CustomButton(
                            text: widget.book.isAvailable ? 'Бронь' : 'Недоступна',
                            onPressed: widget.book.isAvailable ? _reserveBook : null,
                            isLoading: _isReserving,
                            icon: Icons.bookmark_add,
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
                      onPressed: widget.book.isAvailable ? _reserveBook : null,
                      isLoading: _isReserving,
                      icon: Icons.bookmark_add,
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