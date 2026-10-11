import 'app/bootstrap.dart';
import 'app/app_flavor.dart';

/// Production entry point.
/// Run with: flutter run --flavor prod -t lib/main_prod.dart
Future<void> main() => bootstrap(AppFlavor.prod);
