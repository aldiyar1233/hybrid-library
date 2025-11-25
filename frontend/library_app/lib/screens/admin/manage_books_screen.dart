import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import '../../models/book.dart';
import '../../models/genre.dart';
import '../../widgets/loading_widget.dart';
import '../books/book_detail_screen.dart';

class ManageBooksScreen extends StatefulWidget {
  const ManageBooksScreen({Key? key}) : super(key: key);

  @override
  State<ManageBooksScreen> createState() => _ManageBooksScreenState();
}

class _ManageBooksScreenState extends State<ManageBooksScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _yearController = TextEditingController();
  final _isbnController = TextEditingController();
  final _genreNameController = TextEditingController();
  final _genreDescriptionController = TextEditingController();
  
  List<Book> _books = [];
  List<Genre> _genres = [];
  Genre? _selectedGenre;
  String? _selectedStatus;
  Book? _editingBook;
  
  bool _isLoading = true;
  String? _error;
  bool _isProcessing = false;
  bool _showBookForm = false;
  bool _showGenreForm = false;
  
  String _searchQuery = '';
  String? _filterStatus;
  Genre? _filterGenre;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _yearController.dispose();
    _isbnController.dispose();
    _genreNameController.dispose();
    _genreDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final booksResponse = await _apiService.get('/api/books/');
      final genresResponse = await _apiService.get('/api/genres/');

      if (booksResponse.statusCode == 200 && genresResponse.statusCode == 200) {
        final dynamic booksBody = jsonDecode(booksResponse.body);
        final dynamic genresBody = jsonDecode(genresResponse.body);
        
        List<dynamic> booksData;
        if (booksBody is Map && booksBody.containsKey('results')) {
          booksData = booksBody['results'];
        } else if (booksBody is List) {
          booksData = booksBody;
        } else {
          throw Exception('Неверный формат данных книг');
        }
        
        List<dynamic> genresData;
        if (genresBody is Map && genresBody.containsKey('results')) {
          genresData = genresBody['results'];
        } else if (genresBody is List) {
          genresData = genresBody;
        } else {
          genresData = [];
        }

        setState(() {
          _books = booksData.map((json) => Book.fromJson(json)).toList();
          _genres = genresData.map((json) => Genre.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Ошибка загрузки данных: ${booksResponse.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGenre == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите жанр'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final bookData = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'description': _descriptionController.text.trim(),
        'genre': _selectedGenre!.id,
        'year_published': int.parse(_yearController.text.trim()),
        'isbn': _isbnController.text.trim().isNotEmpty 
            ? _isbnController.text.trim() 
            : null,
        'status': _selectedStatus ?? 'available',
      };

      http.Response response;
      String successMessage;

      if (_editingBook != null) {
        response = await _apiService.put('/api/books/${_editingBook!.id}/update/', bookData);
        successMessage = 'Книга обновлена';
      } else {
        response = await _apiService.post('/api/books/create/', bookData);
        successMessage = 'Книга добавлена';
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
        );
        _clearBookForm();
        setState(() {
          _showBookForm = false;
          _editingBook = null;
        });
        _loadData();
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
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _editBook(Book book) {
    setState(() {
      _editingBook = book;
      _titleController.text = book.title;
      _authorController.text = book.author;
      _descriptionController.text = book.description ?? '';
      _yearController.text = book.yearPublished.toString();
      _isbnController.text = book.isbn ?? '';
      _selectedGenre = _genres.firstWhere(
        (g) => g.id == book.genreId,
        orElse: () => _genres.first,
      );
      _selectedStatus = book.status;
      _showBookForm = true;
    });
  }

  Future<void> _deleteBook(Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление книги'),
        content: Text('Удалить "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _apiService.delete('/api/books/${book.id}/delete/');
      if (response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Книга удалена'), backgroundColor: Colors.green),
        );
        _loadData();
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

  Future<void> _updateBookStatus(Book book, String newStatus) async {
    try {
      final response = await _apiService.put(
        '/api/books/${book.id}/update/',
        {
          'title': book.title,
          'author': book.author,
          'description': book.description ?? '',
          'genre': book.genreId,
          'year_published': book.yearPublished,
          'status': newStatus,
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус изменен на "${_getStatusText(newStatus)}"'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
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

  void _clearBookForm() {
    _titleController.clear();
    _authorController.clear();
    _descriptionController.clear();
    _yearController.clear();
    _isbnController.clear();
    setState(() {
      _selectedGenre = null;
      _selectedStatus = null;
      _editingBook = null;
    });
  }

  Future<void> _saveGenre() async {
    if (_genreNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название жанра'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final response = await _apiService.post('/api/genres/create/', {
        'name': _genreNameController.text.trim(),
        'description': _genreDescriptionController.text.trim(),
      });

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Жанр добавлен'), backgroundColor: Colors.green),
        );
        _clearGenreForm();
        setState(() => _showGenreForm = false);
        _loadData();
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
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _clearGenreForm() {
    _genreNameController.clear();
    _genreDescriptionController.clear();
  }

  List<Book> get _filteredBooks {
    return _books.where((book) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!book.title.toLowerCase().contains(query) &&
            !book.author.toLowerCase().contains(query)) {
          return false;
        }
      }
      if (_filterStatus != null && book.status != _filterStatus) {
        return false;
      }
      if (_filterGenre != null && book.genreId != _filterGenre!.id) {
        return false;
      }
      return true;
    }).toList();
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available': return 'Доступна';
      case 'reserved': return 'Забронирована';
      case 'taken': return 'Выдана';
      default: return 'Неизвестно';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available': return Colors.green;
      case 'reserved': return Colors.orange;
      case 'taken': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление книгами'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.book), text: 'Книги (${_books.length})'),
            Tab(icon: const Icon(Icons.category), text: 'Жанры (${_genres.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Загрузка данных...')
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBooksTab(),
                    _buildGenresTab(),
                  ],
                ),
    );
  }

  Widget _buildBooksTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Поиск книг...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: Icon(_showBookForm ? Icons.close : Icons.add),
                    label: Text(_showBookForm ? 'Отмена' : 'Добавить'),
                    onPressed: () {
                      setState(() {
                        _showBookForm = !_showBookForm;
                        if (!_showBookForm) _clearBookForm();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_showBookForm) _buildBookForm(),
        Expanded(
          child: _filteredBooks.isEmpty
              ? Center(child: Text('Нет книг'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredBooks.length,
                    itemBuilder: (context, index) => _buildBookCard(_filteredBooks[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBookForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Название *'),
              validator: (v) => v == null || v.isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Автор *'),
              validator: (v) => v == null || v.isEmpty ? 'Введите автора' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Genre>(
              value: _selectedGenre,
              decoration: const InputDecoration(labelText: 'Жанр *'),
              items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
              onChanged: (v) => setState(() => _selectedGenre = v),
              validator: (v) => v == null ? 'Выберите жанр' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearController,
              decoration: const InputDecoration(labelText: 'Год *'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Введите год';
                final year = int.tryParse(v);
                if (year == null || year < 1000 || year > DateTime.now().year) {
                  return 'Неверный год';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _clearBookForm();
                    setState(() => _showBookForm = false);
                  },
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _saveBook,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(Book book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(book.author),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: () => _editBook(book),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteBook(book),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenresTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Управление жанрами', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: Icon(_showGenreForm ? Icons.close : Icons.add),
                label: Text(_showGenreForm ? 'Отмена' : 'Добавить'),
                onPressed: () {
                  setState(() {
                    _showGenreForm = !_showGenreForm;
                    if (!_showGenreForm) _clearGenreForm();
                  });
                },
              ),
            ],
          ),
        ),
        if (_showGenreForm)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _genreNameController,
                  decoration: const InputDecoration(labelText: 'Название жанра *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _genreDescriptionController,
                  decoration: const InputDecoration(labelText: 'Описание'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _saveGenre,
                  child: const Text('Добавить'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _genres.length,
            itemBuilder: (context, index) {
              final genre = _genres[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.category),
                  title: Text(genre.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: genre.description != null ? Text(genre.description!) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}