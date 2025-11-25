from django.urls import path
from . import views

urlpatterns = [
    # Жанры
    path('genres/', views.GenreListView.as_view(), name='genre-list'),
    path('genres/create/', views.GenreCreateView.as_view(), name='genre-create'),
    
    # Книги
    path('books/', views.BookListView.as_view(), name='book-list'),
    path('books/search/', views.search_books, name='book-search'),
    path('books/create/', views.BookCreateView.as_view(), name='book-create'),
    path('books/<int:pk>/', views.BookDetailView.as_view(), name='book-detail'),
    path('books/<int:pk>/update/', views.BookUpdateView.as_view(), name='book-update'),
    path('books/<int:pk>/delete/', views.BookDeleteView.as_view(), name='book-delete'),
    
    # Бронирования
    path('reservations/', views.ReservationListView.as_view(), name='reservation-list'),
    path('reservations/create/', views.ReservationCreateView.as_view(), name='reservation-create'),
    path('reservations/<int:pk>/', views.ReservationDetailView.as_view(), name='reservation-detail'),
    path('reservations/<int:pk>/cancel/', views.cancel_reservation, name='reservation-cancel'),
    
    # Админ
    path('admin/reservations/', views.AllReservationsView.as_view(), name='admin-reservations'),
    path('admin/reservations/<int:pk>/confirm/', views.confirm_reservation, name='admin-confirm'),
    path('admin/reservations/<int:pk>/taken/', views.mark_as_taken, name='admin-taken'),
    path('admin/reservations/<int:pk>/returned/', views.mark_as_returned, name='admin-returned'),
]