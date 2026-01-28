import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/logger_service.dart';
import '../../models/book.dart';
import '../../widgets/book_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../config/constants.dart';
import 'book_detail_screen.dart';

class BookListScreen extends StatefulWidget {
  const BookListScreen({Key? key}) : super(key: key);

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Book> _books = [];
  List<Book> _filteredBooks = [];
  List<Book> _recentlyViewedBooks = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  String _selectedStatus = 'all'; // all, available, reserved, issued

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentlyViewedIds = prefs.getStringList('recently_viewed') ?? [];

      if (recentlyViewedIds.isEmpty) {
        setState(() => _recentlyViewedBooks = []);
        return;
      }

      // Фильтруем книги из _books по сохраненным ID
      final recentBooks = <Book>[];
      for (final idString in recentlyViewedIds) {
        final id = int.tryParse(idString);
        if (id != null) {
          final book = _books.firstWhere(
            (b) => b.id == id,
            orElse: () => Book(
              id: -1,
              title: '',
              author: '',
              description: '',
              yearPublished: 0,
              status: '',
            ),
          );
          if (book.id != -1) {
            recentBooks.add(book);
          }
        }
      }

      setState(() => _recentlyViewedBooks = recentBooks);
    } catch (e) {
      // Игнорируем ошибки
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      LoggerService.info('Загрузка списка книг');
      final response = await _apiService.get(AppConstants.booksEndpoint);

      if (response.statusCode == 200) {
        final dynamic responseBody = jsonDecode(response.body);

        List<dynamic> data;
        if (responseBody is Map && responseBody.containsKey('results')) {
          data = responseBody['results'];
        } else if (responseBody is List) {
          data = responseBody;
        } else {
          throw Exception('Неверный формат данных');
        }

        setState(() {
          _books = data.map((json) => Book.fromJson(json)).toList();
          _filteredBooks = _books;
          _isLoading = false;
        });

        LoggerService.info('Загружено книг: ${_books.length}');

        // Загружаем недавно просмотренные после загрузки всех книг
        _loadRecentlyViewed();
      } else {
        setState(() {
          _error = _apiService.handleError(response);
          _isLoading = false;
        });
        LoggerService.error('Ошибка загрузки книг', _error);
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
      LoggerService.error('Критическая ошибка загрузки книг', e);
    }
  }

  void _searchBooks(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
    });
    _applyFilters();
    LoggerService.userAction(
        'Поиск книг', {'query': query, 'results': _filteredBooks.length});
  }

  void _changeStatusFilter(String status) {
    setState(() {
      _selectedStatus = status;
    });
    _applyFilters();
    LoggerService.userAction('Фильтр по статусу', {'status': status});
  }

  void _applyFilters() {
    setState(() {
      _filteredBooks = _books.where((book) {
        // Фильтр по статусу
        bool matchesStatus = true;
        if (_selectedStatus == 'available') {
          matchesStatus = book.isAvailable;
        } else if (_selectedStatus == 'reserved') {
          matchesStatus = book.isReserved;
        } else if (_selectedStatus == 'issued') {
          matchesStatus = book.isTaken;
        }

        // Фильтр по поиску
        bool matchesSearch = true;
        if (_isSearching) {
          final titleLower = book.title.toLowerCase();
          final authorLower = book.author.toLowerCase();
          final queryLower = _searchController.text.toLowerCase();

          matchesSearch = titleLower.contains(queryLower) ||
              authorLower.contains(queryLower) ||
              (book.genreName?.toLowerCase().contains(queryLower) ?? false);
        }

        return matchesStatus && matchesSearch;
      }).toList();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchBooks('');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Поисковая панель
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchBooks,
                    decoration: InputDecoration(
                      hintText: 'Поиск книг, авторов, жанров...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                if (_isSearching) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_filteredBooks.length}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Недавно просмотренные книги
          if (_recentlyViewedBooks.isNotEmpty) _buildRecentlyViewed(),
          // Фильтр по статусу
          _buildStatusFilter(),
          // Контент
          Expanded(
            child: _isLoading
                ? const ShimmerLoading(isGrid: true)
                : _error != null
                    ? _buildErrorWidget()
                    : _filteredBooks.isEmpty
                        ? _buildEmptyWidget()
                        : _buildBooksGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyViewed() {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.history, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Вы недавно смотрели',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _recentlyViewedBooks.length,
              itemBuilder: (context, index) {
                final book = _recentlyViewedBooks[index];
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookDetailScreen(book: book),
                      ),
                    );
                    // Перезагружаем недавно просмотренные после возврата
                    _loadRecentlyViewed();
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: book.coverImageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: book.coverImageUrl!,
                                  height: 140,
                                  width: 110,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: Colors.grey[300],
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.book),
                                  ),
                                )
                              : Container(
                                  height: 140,
                                  width: 110,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.book),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'Все',
              value: 'all',
              icon: Icons.library_books,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Доступные',
              value: 'available',
              icon: Icons.check_circle,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Забронированные',
              value: 'reserved',
              icon: Icons.schedule,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Выданные',
              value: 'issued',
              icon: Icons.menu_book,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final isSelected = _selectedStatus == value;
    final chipColor = color ?? Theme.of(context).primaryColor;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : chipColor,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => _changeStatusFilter(value),
      backgroundColor: chipColor.withOpacity(0.1),
      selectedColor: chipColor,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : chipColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: chipColor.withOpacity(isSelected ? 1.0 : 0.3),
        width: isSelected ? 2 : 1,
      ),
    );
  }

  Widget _buildBooksGrid() {
    return RefreshIndicator(
      onRefresh: _loadBooks,
      child: AnimationLimiter(
        child: GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _filteredBooks.length,
          itemBuilder: (context, index) {
            final book = _filteredBooks[index];
            return AnimationConfiguration.staggeredGrid(
              position: index,
              duration: const Duration(milliseconds: 375),
              columnCount: 2,
              child: ScaleAnimation(
                scale: 0.95,
                child: FadeInAnimation(
                  child: BookCard(
                    book: book,
                    onTap: () {
                      LoggerService.userAction('Открытие книги', {
                        'book_id': book.id,
                        'book_title': book.title,
                      });
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  BookDetailScreen(book: book),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Упс! Что-то пошло не так',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBooks,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching ? Icons.search_off : Icons.library_books_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'Ничего не найдено' : 'Книги не найдены',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _isSearching
                  ? 'Попробуйте изменить поисковый запрос'
                  : 'Библиотека пока пуста',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_isSearching) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear),
                label: const Text('Очистить поиск'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
