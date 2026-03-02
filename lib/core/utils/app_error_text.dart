import 'package:firebase_core/firebase_core.dart';

String appErrorText(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'deadline-exceeded':
        return 'Request timed out. Please retry.';
      case 'permission-denied':
        return 'You do not have permission for this action.';
      default:
        return error.message ?? 'Something went wrong.';
    }
  }
  return error.toString();
}
