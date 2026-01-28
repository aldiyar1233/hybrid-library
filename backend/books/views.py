from rest_framework import generics, filters, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny  # ✅ ДОБАВЛЕНО
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Q
from django.db import transaction
from .models import Genre, Book, Reservation
from .serializers import (
    GenreSerializer,
    BookSerializer,
    BookListSerializer,
    ReservationSerializer,
    ReservationCreateSerializer
)


# ==================== ЖАНРЫ ====================

class GenreListView(generics.ListAPIView):
    """
    Список всех жанров
    GET /api/genres/
    """
    queryset = Genre.objects.all()
    serializer_class = GenreSerializer
    permission_classes = [AllowAny]  #  ВРЕМЕННО ИЗМЕНЕНО для тестирования


class GenreCreateView(generics.CreateAPIView):
    """
    Создание жанра (только для админов)
    POST /api/genres/create/
    """
    queryset = Genre.objects.all()
    serializer_class = GenreSerializer
    permission_classes = [IsAdminUser]


# ==================== КНИГИ ====================

class BookListView(generics.ListAPIView):
    """
    Список всех книг с поиском и фильтрацией
    GET /api/books/
    """
    queryset = Book.objects.select_related('genre').all()
    serializer_class = BookListSerializer
    permission_classes = [AllowAny]  #  ВРЕМЕННО ИЗМЕНЕНО для тестирования
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['genre', 'status', 'year_published']
    search_fields = ['title', 'author', 'description']
    ordering_fields = ['title', 'author', 'year_published', 'created_at']
    ordering = ['-created_at']


class BookDetailView(generics.RetrieveAPIView):
    """
    Детальная информация о книге
    GET /api/books/<id>/
    """
    queryset = Book.objects.all()
    serializer_class = BookSerializer
    permission_classes = [AllowAny]  #  ВРЕМЕННО ИЗМЕНЕНО для тестирования


class BookCreateView(generics.CreateAPIView):
    """
    Создание книги (только для админов)
    POST /api/books/create/
    """
    queryset = Book.objects.all()
    serializer_class = BookSerializer
    permission_classes = [IsAdminUser]


class BookUpdateView(generics.UpdateAPIView):
    """
    Обновление книги (только для админов)
    PUT/PATCH /api/books/<id>/update/
    """
    queryset = Book.objects.all()
    serializer_class = BookSerializer
    permission_classes = [IsAdminUser]


class BookDeleteView(generics.DestroyAPIView):
    """
    Удаление книги (только для админов)
    DELETE /api/books/<id>/delete/
    """
    queryset = Book.objects.all()
    serializer_class = BookSerializer
    permission_classes = [IsAdminUser]
    
class GenreUpdateView(generics.UpdateAPIView):
    """
    Обновление жанра (только админ)
    PUT/PATCH /api/genres/<id>/update/
    """
    queryset = Genre.objects.all()
    serializer_class = GenreSerializer
    permission_classes = [IsAdminUser]


class GenreDeleteView(generics.DestroyAPIView):
    """
    Удаление жанра (только админ)
    DELETE /api/genres/<id>/delete/
    """
    queryset = Genre.objects.all()
    serializer_class = GenreSerializer
    permission_classes = [IsAdminUser]

    def delete(self, request, *args, **kwargs):
        genre = self.get_object()

        if Book.objects.filter(genre=genre).exists():
            return Response(
                {'error': 'Нельзя удалить жанр, к которому привязаны книги'},
                status=status.HTTP_400_BAD_REQUEST
            )

        return super().delete(request, *args, **kwargs)

@api_view(['GET'])
@permission_classes([AllowAny])  # ✅ ВРЕМЕННО ИЗМЕНЕНО для тестирования
def search_books(request):
    """
    Расширенный поиск книг (регистронезависимый)
    GET /api/books/search/?q=название
    """
    query = request.GET.get('q', '')

    if not query:
        return Response(
            {'error': 'Параметр поиска "q" обязателен'},
            status=status.HTTP_400_BAD_REQUEST
        )

    books = Book.objects.select_related('genre').filter(
        Q(title__icontains=query) |
        Q(author__icontains=query) |
        Q(description__icontains=query)
    )

    serializer = BookListSerializer(books, many=True, context={'request': request})
    return Response(serializer.data)


# ==================== БРОНИРОВАНИЯ ====================

class ReservationListView(generics.ListAPIView):
    """
    Список бронирований текущего пользователя
    GET /api/reservations/
    """
    serializer_class = ReservationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Reservation.objects.select_related('book', 'user').filter(user=self.request.user)


class ReservationCreateView(generics.CreateAPIView):
    """
    Создание бронирования
    POST /api/reservations/create/
    """
    queryset = Reservation.objects.all()
    serializer_class = ReservationCreateSerializer
    permission_classes = [IsAuthenticated]


class ReservationDetailView(generics.RetrieveAPIView):
    """
    Детали бронирования
    GET /api/reservations/<id>/
    """
    queryset = Reservation.objects.select_related('book', 'user').all()
    serializer_class = ReservationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if self.request.user.user_type == 'admin':
            return Reservation.objects.select_related('book', 'user').all()
        return Reservation.objects.select_related('book', 'user').filter(user=self.request.user)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@transaction.atomic()
def cancel_reservation(request, pk):
    """
    Отмена бронирования
    POST /api/reservations/<id>/cancel/
    """
    try:
        reservation = Reservation.objects.get(pk=pk, user=request.user)
    except Reservation.DoesNotExist:
        return Response(
            {'error': 'Бронирование не найдено'},
            status=status.HTTP_404_NOT_FOUND
        )

    if reservation.status not in ['pending', 'confirmed']:
        return Response(
            {'error': 'Это бронирование нельзя отменить'},
            status=status.HTTP_400_BAD_REQUEST
        )

    reservation.status = 'cancelled'
    reservation.save()

    reservation.book.status = 'available'
    reservation.book.save()

    return Response(
        {'message': 'Бронирование отменено'},
        status=status.HTTP_200_OK
    )


# ==================== АДМИН ЭНДПОИНТЫ ====================

class AllReservationsView(generics.ListAPIView):
    """
    Все бронирования (только для админов)
    GET /api/admin/reservations/
    """
    queryset = Reservation.objects.select_related('book', 'user').all()
    serializer_class = ReservationSerializer
    permission_classes = [IsAdminUser]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['status', 'user', 'book']
    ordering = ['-reservation_date']


@api_view(['POST'])
@permission_classes([IsAdminUser])
def confirm_reservation(request, pk):
    """
    Подтвердить бронирование (только админ)
    POST /api/admin/reservations/<id>/confirm/
    """
    from django.utils import timezone
    
    try:
        reservation = Reservation.objects.get(pk=pk)
    except Reservation.DoesNotExist:
        return Response(
            {'error': 'Бронирование не найдено'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    if reservation.status != 'pending':
        return Response(
            {'error': 'Это бронирование уже обработано'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    reservation.status = 'confirmed'
    reservation.confirmed_date = timezone.now()
    reservation.save()
    
    return Response(
        ReservationSerializer(reservation).data,
        status=status.HTTP_200_OK
    )


@api_view(['POST'])
@permission_classes([IsAdminUser])
@transaction.atomic()
def mark_as_taken(request, pk):
    """
    Отметить книгу как выданную (только админ)
    POST /api/admin/reservations/<id>/taken/
    """
    from django.utils import timezone

    try:
        reservation = Reservation.objects.get(pk=pk)
    except Reservation.DoesNotExist:
        return Response(
            {'error': 'Бронирование не найдено'},
            status=status.HTTP_404_NOT_FOUND
        )

    if reservation.status != 'confirmed':
        return Response(
            {'error': 'Бронирование должно быть подтверждено'},
            status=status.HTTP_400_BAD_REQUEST
        )

    reservation.status = 'taken'
    reservation.taken_date = timezone.now()
    reservation.save()

    reservation.book.status = 'taken'
    reservation.book.save()

    return Response(
        ReservationSerializer(reservation).data,
        status=status.HTTP_200_OK
    )


@api_view(['POST'])
@permission_classes([IsAdminUser])
@transaction.atomic()
def mark_as_returned(request, pk):
    """
    Отметить книгу как возвращенную (только админ)
    POST /api/admin/reservations/<id>/returned/
    """
    from django.utils import timezone

    try:
        reservation = Reservation.objects.get(pk=pk)
    except Reservation.DoesNotExist:
        return Response(
            {'error': 'Бронирование не найдено'},
            status=status.HTTP_404_NOT_FOUND
        )

    if reservation.status != 'taken':
        return Response(
            {'error': 'Книга должна быть выдана'},
            status=status.HTTP_400_BAD_REQUEST
        )

    reservation.status = 'returned'
    reservation.return_date = timezone.now()
    reservation.save()

    reservation.book.status = 'available'
    reservation.book.save()

    return Response(
        ReservationSerializer(reservation).data,
        status=status.HTTP_200_OK
    )