class ApiConstants {
  // Override with --dart-define=API_BASE_URL=https://your-backend.example
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://almighty-haphazard-pawing.ngrok-free.dev',
  );
}
