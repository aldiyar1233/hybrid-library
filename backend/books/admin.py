from django.contrib import admin
from .models import Genre, Book, Reservation

@admin.register(Genre)
class GenreAdmin(admin.ModelAdmin):
    list_display = ('name', 'description', 'created_at')
    search_fields = ('name',)
    ordering = ('name',)

@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    list_display = ('title', 'author', 'genre', 'year_published', 'status', 'created_at')
    list_filter = ('status', 'genre', 'year_published', 'created_at')
    search_fields = ('title', 'author', 'isbn', 'description')
    ordering = ('-created_at',)
    
    fieldsets = (
        ('Основная информация', {
            'fields': ('title', 'author', 'description', 'genre', 'year_published', 'isbn')
        }),
        ('Файлы', {
            'fields': ('cover_image', 'pdf_file')
        }),
        ('Статус', {
            'fields': ('status',)
        }),
    )
    
    readonly_fields = ('created_at', 'updated_at')

@admin.register(Reservation)
class ReservationAdmin(admin.ModelAdmin):
    list_display = ('user', 'book', 'status', 'reservation_date', 'taken_date')
    list_filter = ('status', 'reservation_date', 'taken_date')
    search_fields = ('user__username', 'user__email', 'book__title')
    ordering = ('-reservation_date',)
    
    fieldsets = (
        ('Основная информация', {
            'fields': ('user', 'book', 'status')
        }),
        ('Даты', {
            'fields': ('reservation_date', 'confirmed_date', 'taken_date', 'return_date')
        }),
        ('Комментарии', {
            'fields': ('user_comment', 'admin_comment')
        }),
    )
    
    readonly_fields = ('reservation_date',)
    
    actions = ['confirm_reservation', 'mark_as_taken', 'mark_as_returned']
    
    def confirm_reservation(self, request, queryset):
        from django.utils import timezone
        updated = queryset.filter(status='pending').update(
            status='confirmed',
            confirmed_date=timezone.now()
        )
        self.message_user(request, f'Подтверждено {updated} бронирований.')
    confirm_reservation.short_description = "Подтвердить выбранные бронирования"
    
    def mark_as_taken(self, request, queryset):
        from django.utils import timezone
        updated = queryset.filter(status='confirmed').update(
            status='taken',
            taken_date=timezone.now()
        )
        for reservation in queryset.filter(status='taken'):
            reservation.book.status = 'taken'
            reservation.book.save()
        self.message_user(request, f'Отмечено как выданные: {updated} бронирований.')
    mark_as_taken.short_description = "Отметить как выданные"
    
    def mark_as_returned(self, request, queryset):
        from django.utils import timezone
        updated = queryset.filter(status='taken').update(
            status='returned',
            return_date=timezone.now()
        )
        for reservation in queryset.filter(status='returned'):
            reservation.book.status = 'available'
            reservation.book.save()
        self.message_user(request, f'Отмечено как возвращенные: {updated} бронирований.')
    mark_as_returned.short_description = "Отметить как возвращенные"