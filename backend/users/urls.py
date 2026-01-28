from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path('register/', views.RegisterView.as_view(), name='register'),
    path('login/', views.login_view, name='login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('profile/', views.user_profile_view, name='user-profile'),
    path('profile/update/', views.update_profile_view, name='update-profile'),
    path('password/change/', views.change_password_view, name='change-password'),

]