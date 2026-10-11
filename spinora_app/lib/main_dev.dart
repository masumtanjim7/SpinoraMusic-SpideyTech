import 'app/bootstrap.dart';
import 'app/app_flavor.dart';

/// Dev entry point.
/// Run with: flutter run --flavor dev -t lib/main_dev.dart
Future<void> main() => bootstrap(AppFlavor.dev);
