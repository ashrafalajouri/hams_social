import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService(this._auth, this._rtdb);

  final FirebaseAuth _auth;
  final FirebaseDatabase _rtdb;

  DatabaseReference? _statusRef;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DatabaseEvent>? _connectedSub;

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);

    _authSub = _auth.authStateChanges().listen((user) async {
      await _connectedSub?.cancel();
      _connectedSub = null;
      if (user == null) {
        _statusRef = null;
        return;
      }
      await _setup(user.uid);
    });

    final u = _auth.currentUser;
    if (u != null) await _setup(u.uid);
  }

  Future<void> _setup(String uid) async {
    final ref = _rtdb.ref('status/$uid');
    _statusRef = ref;

    final connectedRef = _rtdb.ref('.info/connected');
    _connectedSub = connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value == true;
      if (!connected) return;

      await ref.onDisconnect().set({
        'state': 'offline',
        'lastChangedAt': ServerValue.timestamp,
      });

      await ref.set({
        'state': 'online',
        'lastChangedAt': ServerValue.timestamp,
      });
    });
  }

  Future<void> setAwayOrOnline(bool online) async {
    final ref = _statusRef;
    if (ref == null) return;
    await ref.set({
      'state': online ? 'online' : 'away',
      'lastChangedAt': ServerValue.timestamp,
    });
  }

  Future<void> setOffline() async {
    final ref = _statusRef;
    if (ref == null) return;
    await ref.set({
      'state': 'offline',
      'lastChangedAt': ServerValue.timestamp,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(setAwayOrOnline(true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      unawaited(setAwayOrOnline(false));
    }
  }

  Future<void> disposeService() async {
    WidgetsBinding.instance.removeObserver(this);
    await _connectedSub?.cancel();
    await _authSub?.cancel();
  }
}
