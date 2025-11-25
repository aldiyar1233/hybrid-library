import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
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
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBooks();
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
      if (query.isEmpty) {
        _filteredBooks = _books;
      } else {
        _filteredBooks = _books.where((book) {
          final titleLower = book.title.toLowerCase();
          final authorLower = book.author.toLowerCase();
          final queryLower = query.toLowerCase();
          
          return titleLower.contains(queryLower) || 
                 authorLower.contains(queryLower) ||
                 (book.genreName?.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }
    });
    
    LoggerService.userAction('Поиск книг', {'query': query, 'results': _filteredBooks.length});
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              BookDetailScreen(book: book),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      ).then((_) => _loadBooks());
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
              _isSearching
                  ? 'Ничего не найдено'
                  : 'Книги не найдены',
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