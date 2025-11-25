from rest_framework import serializers
from .models import Genre, Book, Reservation
from users.serializers import UserSerializer

class GenreSerializer(serializers.ModelSerializer):
    class Meta:
        model = Genre
        fields = ('id', 'name', 'description', 'created_at')
        read_only_fields = ('id', 'created_at')

class BookSerializer(serializers.ModelSerializer):
    genre_name = serializers.CharField(source='genre.name', read_only=True)
    cover_image_url = serializers.SerializerMethodField()
    pdf_file_url = serializers.SerializerMethodField()
    
    class Meta:
        model = Book
        fields = ('id', 'title', 'author', 'description', 'genre', 'genre_name',
                  'year_published', 'isbn', 'cover_image', 'cover_image_url',
                  'pdf_file', 'pdf_file_url', 'status', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')
    
    def get_cover_image_url(self, obj):
        # ✅ ИСПРАВЛЕНО: добавлена проверка на существование файла
        if obj.cover_image and hasattr(obj.cover_image, 'url'):
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.cover_image.url)
            return obj.cover_image.url
        return None
    
    def get_pdf_file_url(self, obj):
        # ✅ ИСПРАВЛЕНО: добавлена проверка на существование файла
        if obj.pdf_file and hasattr(obj.pdf_file, 'url'):
            request = self.context.get('request')
            if request:
                url = request.build_absolute_uri(obj.pdf_file.url)
                print(f'📄 PDF URL для книги {obj.title}: {url}')  # Для отладки
                return url
            return obj.pdf_file.url
        print(f'⚠️ PDF отсутствует для книги {obj.title}')  # Для отладки
        return None

class BookListSerializer(serializers.ModelSerializer):
    genre_name = serializers.CharField(source='genre.name', read_only=True)
    cover_image_url = serializers.SerializerMethodField()
    pdf_file_url = serializers.SerializerMethodField()
    
    class Meta:
        model = Book
        fields = ('id', 'title', 'author', 'description', 'genre_name', 'year_published',
                  'cover_image_url', 'pdf_file_url', 'status')  # ✅ ДОБАВЛЕНО description
    
    def get_cover_image_url(self, obj):
        if obj.cover_image and hasattr(obj.cover_image, 'url'):
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.cover_image.url)
            return obj.cover_image.url
        return None
    
    # ✅ ДОБАВЛЕНО: метод для PDF URL в списке книг
    def get_pdf_file_url(self, obj):
        if obj.pdf_file and hasattr(obj.pdf_file, 'url'):
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.pdf_file.url)
            return obj.pdf_file.url
        return None

class ReservationSerializer(serializers.ModelSerializer):
    user_details = UserSerializer(source='user', read_only=True)
    book_details = BookListSerializer(source='book', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Reservation
        fields = ('id', 'user', 'user_details', 'book', 'book_details', 
                  'status', 'status_display', 'reservation_date', 
                  'confirmed_date', 'taken_date', 'return_date',
                  'user_comment', 'admin_comment')
        read_only_fields = ('id', 'reservation_date', 'confirmed_date', 
                           'taken_date', 'return_date')

class ReservationCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Reservation
        fields = ('book', 'user_comment')
    
    def validate_book(self, value):
        if value.status != 'available':
            raise serializers.ValidationError("Эта книга недоступна для бронирования.")
        return value
    
    def create(self, validated_data):
        user = self.context['request'].user
        book = validated_data['book']
        
        active_reservation = Reservation.objects.filter(
            user=user,
            book=book,
            status__in=['pending', 'confirmed', 'taken']
        ).exists()
        
        if active_reservation:
            raise serializers.ValidationError("У вас уже есть активное бронирование этой книги.")
        
        reservation = Reservation.objects.create(
            user=user,
            book=book,
            user_comment=validated_data.get('user_comment', ''),
            status='pending'
        )
        
        book.status = 'reserved'
        book.save()
        
        return reservation