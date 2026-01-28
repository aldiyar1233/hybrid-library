from django.db import models
from django.conf import settings

class Genre(models.Model):
    name = models.CharField(max_length=100, unique=True, verbose_name='Название жанра')
    description = models.TextField(blank=True, null=True, verbose_name='Описание')
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = 'Жанр'
        verbose_name_plural = 'Жанры'
        ordering = ['name']
    
    def __str__(self):
        return self.name


class Book(models.Model):
    STATUS_CHOICES = (
        ('available', 'Свободна'),
        ('reserved', 'Забронирована'),
        ('taken', 'Выдана'),
    )
    
    title = models.CharField(max_length=255, verbose_name='Название книги')
    author = models.CharField(max_length=255, verbose_name='Автор')
    description = models.TextField(verbose_name='Описание')
    genre = models.ForeignKey(
        Genre, 
        on_delete=models.SET_NULL, 
        null=True, 
        related_name='books',
        verbose_name='Жанр'
    )
    year_published = models.IntegerField(verbose_name='Год издания')
    isbn = models.CharField(max_length=13, blank=True, null=True, unique=True, verbose_name='ISBN')
    cover_image = models.ImageField(
        upload_to='covers/', 
        blank=True, 
        null=True,
        verbose_name='Обложка книги'
    )
    pdf_file = models.FileField(
        upload_to='pdfs/', 
        blank=True, 
        null=True,
        verbose_name='PDF файл'
    )
    status = models.CharField(
        max_length=20, 
        choices=STATUS_CHOICES, 
        default='available',
        verbose_name='Статус'
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Дата добавления')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Дата обновления')
    
    class Meta:
        verbose_name = 'Книга'
        verbose_name_plural = 'Книги'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.title} - {self.author}"


class Reservation(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Ожидает подтверждения'),
        ('confirmed', 'Подтверждена'),
        ('taken', 'Книга выдана'),
        ('returned', 'Книга возвращена'),
        ('cancelled', 'Отменена'),
    )
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='reservations',
        verbose_name='Пользователь'
    )
    book = models.ForeignKey(
        Book, 
        on_delete=models.CASCADE, 
        related_name='reservations',
        verbose_name='Книга'
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        verbose_name='Статус бронирования'
    )
    reservation_date = models.DateTimeField(auto_now_add=True, verbose_name='Дата бронирования')
    confirmed_date = models.DateTimeField(blank=True, null=True, verbose_name='Дата подтверждения')
    taken_date = models.DateTimeField(blank=True, null=True, verbose_name='Дата выдачи')
    return_date = models.DateTimeField(blank=True, null=True, verbose_name='Дата возврата')

    # Планируемая дата и время получения книги
    pickup_date = models.DateField(blank=True, null=True, verbose_name='Планируемая дата получения')
    pickup_time = models.TimeField(blank=True, null=True, verbose_name='Планируемое время получения')

    user_comment = models.TextField(blank=True, null=True, verbose_name='Комментарий пользователя')
    admin_comment = models.TextField(blank=True, null=True, verbose_name='Комментарий администратора')
    
    class Meta:
        verbose_name = 'Бронирование'
        verbose_name_plural = 'Бронирования'
        ordering = ['-reservation_date']
    
    def __str__(self):
        return f"{self.user.username} - {self.book.title} ({self.get_status_display()})"