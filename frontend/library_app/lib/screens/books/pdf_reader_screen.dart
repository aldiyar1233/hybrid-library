import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../../services/logger_service.dart';
import '../../widgets/loading_widget.dart';

class PdfReaderScreen extends StatefulWidget {
  final String pdfUrl;
  final String bookTitle;

  const PdfReaderScreen({
    Key? key,
    required this.pdfUrl,
    required this.bookTitle,
  }) : super(key: key);

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> 
    with TickerProviderStateMixin {
  
  // Контроллеры
  PdfController? _pdfController;
  final TextEditingController _pageInputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late AnimationController _toolbarAnimationController;
  late AnimationController _fabAnimationController;
  
  // Состояния
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isToolbarVisible = true;
  bool _isNightMode = false;
  bool _isSinglePageMode = true;
  double _zoomLevel = 1.0;
  bool _isSearching = false;
  bool _showThumbnails = false;
  bool _showOutline = false;
  
  // Закладки и заметки
  List<int> _bookmarks = [];
  Map<int, String> _pageNotes = {};
  
  // Таймеры
  Timer? _toolbarTimer;
  Timer? _pageIndicatorTimer;
  bool _showPageIndicator = false;
  
  // История навигации
  List<int> _navigationHistory = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    
    _toolbarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _loadPdf();
    _loadSavedData();
    _startToolbarTimer();
    
    // Скрываем системный UI для полноэкранного режима
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _pageInputController.dispose();
    _searchController.dispose();
    _noteController.dispose();
    _toolbarAnimationController.dispose();
    _fabAnimationController.dispose();
    _toolbarTimer?.cancel();
    _pageIndicatorTimer?.cancel();
    
    // Возвращаем системный UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    
    super.dispose();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      LoggerService.info('Загрузка PDF: ${widget.bookTitle}');
      
      final response = await http.get(Uri.parse(widget.pdfUrl));
      
      if (response.statusCode == 200) {
        final document = await PdfDocument.openData(response.bodyBytes);
        
        setState(() {
          _pdfController = PdfController(
            document: Future.value(document),
            initialPage: _currentPage,
          );
          _totalPages = document.pagesCount;
          _isLoading = false;
        });
        
        LoggerService.info('PDF загружен: $_totalPages страниц');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
      LoggerService.error('Ошибка загрузки PDF', e);
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _showPageIndicator = true;
    });
    
    // Добавляем в историю навигации
    if (_historyIndex < _navigationHistory.length - 1) {
      _navigationHistory = _navigationHistory.sublist(0, _historyIndex + 1);
    }
    _navigationHistory.add(page);
    _historyIndex = _navigationHistory.length - 1;
    
    // Показываем индикатор страницы
    _pageIndicatorTimer?.cancel();
    _pageIndicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showPageIndicator = false);
      }
    });
    
    LoggerService.debug('Страница изменена: $page/$_totalPages');
  }

  void _startToolbarTimer() {
    _toolbarTimer?.cancel();
    _toolbarTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isSearching) {
        _toggleToolbar();
      }
    });
  }

  void _toggleToolbar() {
    setState(() {
      _isToolbarVisible = !_isToolbarVisible;
    });
    
    if (_isToolbarVisible) {
      _toolbarAnimationController.forward();
      _fabAnimationController.forward();
      _startToolbarTimer();
    } else {
      _toolbarAnimationController.reverse();
      _fabAnimationController.reverse();
    }
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _pdfController?.jumpToPage(page);
      LoggerService.userAction('Переход на страницу', {'page': page});
    }
  }

  void _showGoToPageDialog() {
    _pageInputController.text = _currentPage.toString();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Перейти на страницу'),
        content: TextField(
          controller: _pageInputController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Номер страницы (1-$_totalPages)',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final page = int.tryParse(value);
            if (page != null) {
              Navigator.pop(context);
              _goToPage(page);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(_pageInputController.text);
              if (page != null) {
                Navigator.pop(context);
                _goToPage(page);
              }
            },
            child: const Text('Перейти'),
          ),
        ],
      ),
    );
  }

  void _toggleBookmark() {
    setState(() {
      if (_bookmarks.contains(_currentPage)) {
        _bookmarks.remove(_currentPage);
        _showSnackBar('Закладка удалена');
      } else {
        _bookmarks.add(_currentPage);
        _bookmarks.sort();
        _showSnackBar('Закладка добавлена');
      }
    });
    _saveBookmarks();
  }

  void _showBookmarks() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Закладки',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: _bookmarks.isEmpty
                  ? const Center(child: Text('Нет закладок'))
                  : ListView.builder(
                      itemCount: _bookmarks.length,
                      itemBuilder: (context, index) {
                        final page = _bookmarks[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              '$page',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text('Страница $page'),
                          subtitle: _pageNotes.containsKey(page)
                              ? Text(
                                  _pageNotes[page]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() => _bookmarks.remove(page));
                              _saveBookmarks();
                              Navigator.pop(context);
                              _showBookmarks();
                            },
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _goToPage(page);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _addNote() {
    _noteController.text = _pageNotes[_currentPage] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Заметка для страницы $_currentPage'),
        content: TextField(
          controller: _noteController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Введите заметку...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (_noteController.text.isNotEmpty) {
                  _pageNotes[_currentPage] = _noteController.text;
                } else {
                  _pageNotes.remove(_currentPage);
                }
              });
              _saveNotes();
              Navigator.pop(context);
              _showSnackBar('Заметка сохранена');
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showNotes() {
    final notesPages = _pageNotes.keys.toList()..sort();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Заметки',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: notesPages.isEmpty
                  ? const Center(child: Text('Нет заметок'))
                  : ListView.builder(
                      itemCount: notesPages.length,
                      itemBuilder: (context, index) {
                        final page = notesPages[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                '$page',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text('Страница $page'),
                            subtitle: Text(
                              _pageNotes[page]!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setState(() => _pageNotes.remove(page));
                                _saveNotes();
                                Navigator.pop(context);
                                _showNotes();
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _goToPage(page);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf() async {
    try {
      _showSnackBar('Подготовка к отправке...');
      
      final response = await http.get(Uri.parse(widget.pdfUrl));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.bookTitle}.pdf');
      await file.writeAsBytes(response.bodyBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Книга: ${widget.bookTitle}',
      );
      
      LoggerService.userAction('PDF отправлен', {'title': widget.bookTitle});
    } catch (e) {
      _showSnackBar('Ошибка отправки');
      LoggerService.error('Ошибка отправки PDF', e);
    }
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
    });
    _showSnackBar(_isNightMode ? 'Ночной режим включен' : 'Ночной режим выключен');
  }

  void _zoom(bool zoomIn) {
    setState(() {
      if (zoomIn) {
        _zoomLevel = (_zoomLevel + 0.25).clamp(1.0, 3.0);
      } else {
        _zoomLevel = (_zoomLevel - 0.25).clamp(1.0, 3.0);
      }
    });
  }

  void _togglePageMode() {
    setState(() {
      _isSinglePageMode = !_isSinglePageMode;
    });
    _showSnackBar(_isSinglePageMode ? 'Одна страница' : 'Непрерывная прокрутка');
  }

  void _navigateBack() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _goToPage(_navigationHistory[_historyIndex]);
    }
  }

  void _navigateForward() {
    if (_historyIndex < _navigationHistory.length - 1) {
      _historyIndex++;
      _goToPage(_navigationHistory[_historyIndex]);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadSavedData() async {
    // Здесь можно загрузить сохраненные закладки и заметки из SharedPreferences
    // Для примера оставлю заглушку
  }

  Future<void> _saveBookmarks() async {
    // Сохранение закладок в SharedPreferences
  }

  Future<void> _saveNotes() async {
    // Сохранение заметок в SharedPreferences
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: _isNightMode 
        ? Colors.black 
        : (isDark ? const Color(0xFF111827) : Colors.white),
      body: Stack(
        children: [
          // PDF Viewer
          if (!_isLoading && _error == null)
            GestureDetector(
              onTap: _toggleToolbar,
              child: ColorFiltered(
                colorFilter: _isNightMode
                  ? const ColorFilter.mode(
                      Colors.amber,
                      BlendMode.modulate,
                    )
                  : const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.multiply,
                    ),
                child: PdfView(
                  controller: _pdfController!,
                  onPageChanged: _onPageChanged,
                  scrollDirection: _isSinglePageMode 
                    ? Axis.horizontal 
                    : Axis.vertical,
                  pageSnapping: _isSinglePageMode,
                  physics: const BouncingScrollPhysics(),
                  builders: PdfViewBuilders<DefaultBuilderOptions>(
                    options: const DefaultBuilderOptions(
                      loaderSwitchDuration: Duration(milliseconds: 200),
                    ),
                    documentLoaderBuilder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                    pageLoaderBuilder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                    errorBuilder: (_, error) => Center(
                      child: Text(
                        'Ошибка: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // Loading
          if (_isLoading)
            const Center(child: LoadingWidget(message: 'Загрузка PDF...')),
          
          // Error
          if (_error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPdf,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          
          // Top Toolbar
          AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: Offset(0, _isToolbarVisible ? 0 : -1),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.bookTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Закладка
                      IconButton(
                        icon: Icon(
                          _bookmarks.contains(_currentPage)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                          color: Colors.white,
                        ),
                        onPressed: _toggleBookmark,
                      ),
                      // Меню
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          switch (value) {
                            case 'bookmarks':
                              _showBookmarks();
                              break;
                            case 'notes':
                              _showNotes();
                              break;
                            case 'share':
                              _sharePdf();
                              break;
                            case 'night':
                              _toggleNightMode();
                              break;
                            case 'mode':
                              _togglePageMode();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'bookmarks',
                            child: Row(
                              children: [
                                Icon(Icons.bookmarks_outlined),
                                SizedBox(width: 12),
                                Text('Закладки'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'notes',
                            child: Row(
                              children: [
                                Icon(Icons.note_outlined),
                                SizedBox(width: 12),
                                Text('Заметки'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'night',
                            child: Row(
                              children: [
                                Icon(_isNightMode 
                                  ? Icons.light_mode 
                                  : Icons.dark_mode),
                                const SizedBox(width: 12),
                                Text(_isNightMode 
                                  ? 'Обычный режим' 
                                  : 'Ночной режим'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'mode',
                            child: Row(
                              children: [
                                Icon(_isSinglePageMode
                                  ? Icons.view_stream
                                  : Icons.view_carousel),
                                const SizedBox(width: 12),
                                Text(_isSinglePageMode
                                  ? 'Непрерывная прокрутка'
                                  : 'По страницам'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_outlined),
                                SizedBox(width: 12),
                                Text('Поделиться'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom Toolbar
          AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: Offset(0, _isToolbarVisible ? 0 : 1),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      if (_totalPages > 0)
                        Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: LinearProgressIndicator(
                            value: _currentPage / _totalPages,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Controls
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // История назад
                            IconButton(
                              icon: const Icon(Icons.undo, color: Colors.white),
                              onPressed: _historyIndex > 0 
                                ? _navigateBack 
                                : null,
                            ),
                            // Предыдущая страница
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: Colors.white),
                              onPressed: _currentPage > 1
                                ? () => _pdfController?.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  )
                                : null,
                            ),
                            // Номер страницы
                            InkWell(
                              onTap: _showGoToPageDialog,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_currentPage / $_totalPages',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // Следующая страница
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: Colors.white),
                              onPressed: _currentPage < _totalPages
                                ? () => _pdfController?.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  )
                                : null,
                            ),
                            // История вперед
                            IconButton(
                              icon: const Icon(Icons.redo, color: Colors.white),
                              onPressed: _historyIndex < _navigationHistory.length - 1
                                ? _navigateForward
                                : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Page Indicator (появляется при смене страницы)
          if (_showPageIndicator)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    'Страница $_currentPage из $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          
          // Floating Action Button для заметок
          Positioned(
            right: 16,
            bottom: 80,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: _isToolbarVisible ? 1 : 0,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Theme.of(context).primaryColor,
                onPressed: _addNote,
                child: const Icon(Icons.note_add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}