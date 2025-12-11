import 'dart:async';
import 'package:flutter/material.dart';

class InactivityService with WidgetsBindingObserver {
  static final InactivityService _instance = InactivityService._internal();
  factory InactivityService() => _instance;
  InactivityService._internal();

  Timer? _inactivityTimer;
  VoidCallback? _onInactivityTimeout;
  DateTime? _lastActiveTime;
  bool _isAppInBackground = false;
  bool _isObserverAdded = false;
  
  // For testing: 30 seconds, for production: 15 minutes
  static const Duration inactivityDuration = Duration(seconds: 30);

  /// Start monitoring inactivity
  void startMonitoring(VoidCallback onTimeout) {
    print('🔵 startMonitoring called');
    _onInactivityTimeout = onTimeout;
    _lastActiveTime = DateTime.now();
    
    // Add observer only once
    if (!_isObserverAdded) {
      print('🔵 Adding WidgetsBindingObserver');
      WidgetsBinding.instance.addObserver(this);
      _isObserverAdded = true;
    } else {
      print('🔵 Observer already added, skipping');
    }
    
    _resetTimer();
    print('🔵 startMonitoring completed. Timer set for ${inactivityDuration.inSeconds} seconds');
  }

  /// Reset the inactivity timer (call on any user interaction)
  void resetTimer() {
    if (!_isAppInBackground) {
      _lastActiveTime = DateTime.now();
      _resetTimer();
      print('🔄 Timer reset at ${DateTime.now()}');
    }
  }

  /// Stop monitoring (call on logout)
  void stopMonitoring() {
    print('🔴 stopMonitoring called');
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _lastActiveTime = null;
    
    // Remove observer
    if (_isObserverAdded) {
      print('🔴 Removing WidgetsBindingObserver');
      WidgetsBinding.instance.removeObserver(this);
      _isObserverAdded = false;
    }
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityDuration, () {
      print('⏰ Inactivity timeout reached - Calling logout callback');
      _onInactivityTimeout?.call();
    });
  }

  /// Handle app lifecycle changes (tab switching, backgrounding, etc.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 ========================================');
    print('📱 App lifecycle state changed: $state');
    print('📱 Current time: ${DateTime.now()}');
    print('📱 Last active time: $_lastActiveTime');
    print('📱 Observer added: $_isObserverAdded');
    print('📱 ========================================');
    
    switch (state) {
      case AppLifecycleState.paused:
        print('⏸️ App PAUSED - Recording time and stopping timer');
        _isAppInBackground = true;
        _lastActiveTime = DateTime.now();
        _inactivityTimer?.cancel();
        print('⏸️ Paused at: $_lastActiveTime');
        break;
        
      case AppLifecycleState.resumed:
        print('▶️ App RESUMED - Checking inactivity duration');
        _isAppInBackground = false;
        
        if (_lastActiveTime != null) {
          final inactiveDuration = DateTime.now().difference(_lastActiveTime!);
          print('⏱️ Was inactive for: ${inactiveDuration.inSeconds} seconds (${inactiveDuration.inMinutes} minutes)');
          print('⏱️ Threshold: ${inactivityDuration.inSeconds} seconds');
          
          if (inactiveDuration >= inactivityDuration) {
            print('❌ EXCEEDED LIMIT - Triggering logout');
            _onInactivityTimeout?.call();
          } else {
            print('✅ Within limit - Restarting timer');
            print('✅ Remaining time: ${inactivityDuration.inSeconds - inactiveDuration.inSeconds} seconds');
            _resetTimer();
          }
        } else {
          print('⚠️ No last active time recorded!');
        }
        break;
        
      case AppLifecycleState.inactive:
        print('⏸️ App INACTIVE (transitional state)');
        break;
        
      case AppLifecycleState.detached:
        print('🔌 App DETACHED');
        break;
        
      case AppLifecycleState.hidden:
        print('👻 App HIDDEN');
        break;
    }
  }

  /// Clean up observer
  void dispose() {
    print('🗑️ Disposing InactivityService');
    WidgetsBinding.instance.removeObserver(this);
    stopMonitoring();
    _isObserverAdded = false;
  }
}