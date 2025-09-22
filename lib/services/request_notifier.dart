import 'package:flutter/material.dart';

/// A simple ValueNotifier to manage the state of new service requests.
///
/// This allows any part of the widget tree to listen for changes and update
/// the UI, such as showing or hiding a notification badge.
class RequestNotifier extends ValueNotifier<bool> {
  RequestNotifier() : super(false);

  /// Call this to show the notification indicator.
  void show() {
    value = true;
  }

  /// Call this to hide the notification indicator.
  void hide() {
    value = false;
  }
}
