import 'app/app_flavor.dart';
import 'app/bootstrap.dart';

/// Default application entry point.
///
/// Delegates to [bootstrap] with [AppFlavor.dev] flavor.
/// For production builds, use `lib/main_prod.dart`.
Future<void> main() => bootstrap(AppFlavor.dev);

