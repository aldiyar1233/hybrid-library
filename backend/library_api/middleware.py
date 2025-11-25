class CorsMediaMiddleware:
    """
    Добавляет CORS заголовки для media файлов (PDF, изображения)
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        
        # Если это media файл, добавляем CORS заголовки
        if request.path.startswith('/media/'):
            response['Access-Control-Allow-Origin'] = '*'
            response['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
            response['Access-Control-Allow-Headers'] = '*'
            response['Cross-Origin-Resource-Policy'] = 'cross-origin'
            response['Cross-Origin-Embedder-Policy'] = 'require-corp'
        
        return response