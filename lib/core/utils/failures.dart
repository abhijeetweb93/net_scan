abstract class Failure {
  final String message;
  final Object? cause;

  const Failure({required this.message, this.cause});

  @override
  String toString() => 'Failure($message)';
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.cause});
}

class PermissionFailure extends Failure {
  const PermissionFailure({required super.message, super.cause});
}

class ScanCancelledFailure extends Failure {
  const ScanCancelledFailure() : super(message: 'Scan was cancelled');
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({required super.message, super.cause});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.cause});
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure({required super.message, super.cause});
}

class NoNetworkFailure extends Failure {
  const NoNetworkFailure()
      : super(message: 'No WiFi network detected. Please connect to a WiFi network.');
}
