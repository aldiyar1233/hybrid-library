class Book {
  final int id;
  final String title;
  final String author;
  final String? description;  // ✅ nullable
  final int? genreId;
  final String? genreName;
  final int yearPublished;
  final String? isbn;
  final String? coverImageUrl;
  final String? pdfFileUrl;
  final String status;
  final DateTime? createdAt;

  Book({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    this.genreId,
    this.genreName,
    required this.yearPublished,
    this.isbn,
    this.coverImageUrl,
    this.pdfFileUrl,
    required this.status,
    this.createdAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Без названия',  // ✅ fallback
      author: json['author'] as String? ?? 'Неизвестный автор',  // ✅ fallback
      description: json['description'] as String?,  // ✅ может быть null
      genreId: json['genre'] as int?,
      genreName: json['genre_name'] as String?,
      yearPublished: json['year_published'] as int? ?? 0,  // ✅ fallback
      isbn: json['isbn'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      pdfFileUrl: json['pdf_file_url'] as String?,
      status: json['status'] as String? ?? 'available',  // ✅ fallback
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  bool get isAvailable => status == 'available';
  bool get isReserved => status == 'reserved';
  bool get isTaken => status == 'taken';

  String get statusText {
    switch (status) {
      case 'available':
        return 'Свободна';
      case 'reserved':
        return 'Забронирована';
      case 'taken':
        return 'Выдана';
      default:
        return 'Неизвестно';
    }
  }
}