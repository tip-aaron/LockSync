import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lock_sync/main.dart';
import 'package:lock_sync/screens/lock_control_screen.dart';
import 'package:lock_sync/screens/system_check_screen.dart';

void main() {
  testWidgets('LockSync landing page renders 6-digit PIN pad and keypad',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LockSyncApp());

    // Verify brand and PIN elements
    expect(find.text('Your lock, redefined.'), findsOneWidget);
    expect(find.text('ENTER PASSWORD'), findsOneWidget);
    expect(find.text('Enter 6-digit master passcode'), findsOneWidget);
    expect(find.text('DEFAULT PASSCODE: 123456'), findsOneWidget);

    // Verify 6 PIN dots
    for (int i = 0; i < 6; i++) {
      expect(find.byKey(Key('pin_dot_$i')), findsOneWidget);
    }

    // Verify 0-9 Keypad keys exist
    for (int i = 0; i <= 9; i++) {
      expect(find.byKey(Key('pin_key_$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('pin_key_clear')), findsOneWidget);
    expect(find.byKey(const Key('pin_key_backspace')), findsOneWidget);
  });

  testWidgets('Test PIN entry with wrong pin and default 123456 pin login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LockSyncApp());

    // Type 6 digits of wrong PIN (e.g. 9 9 9 9 9 9)
    for (int i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('pin_key_9')));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump();

    // Verify error state
    expect(find.text('INCORRECT PASSWORD'), findsOneWidget);

    // Wait for auto-reset (650ms)
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Enter 6-digit master passcode'), findsOneWidget);

    // Type the correct default PIN: 1 2 3 4 5 6
    for (int i = 1; i <= 6; i++) {
      await tester.tap(find.byKey(Key('pin_key_$i')));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump();

    // Verify success state
    expect(find.text('ACCESS GRANTED'), findsOneWidget);

    // Pump past the transition delay
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    // Verify navigated to SystemCheckScreen
    expect(find.byType(SystemCheckScreen), findsOneWidget);
  });

  testWidgets(
      'Entering 123456 PIN navigates through SystemCheckScreen to LockControlScreen and tests lock control',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LockSyncApp());

    // Enter 123456
    for (int i = 1; i <= 6; i++) {
      await tester.tap(find.byKey(Key('pin_key_$i')));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 350));

    // Verify SystemCheckScreen is reached with only the ring and LOCKSYNC in the center
    expect(find.byType(SystemCheckScreen), findsOneWidget);
    expect(find.text('CHECKING SYSTEM STATUS'), findsNothing);
    final ringBrandFinder = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('LOCKSYNC'),
    );
    expect(ringBrandFinder, findsOneWidget);

    // Pump past diagnostic check (1400ms)
    await tester.pump(const Duration(milliseconds: 1400));
    // Pump past ring disappearance (300ms)
    await tester.pump(const Duration(milliseconds: 320));
    // Pump past 1.0s pause (1000ms)
    await tester.pump(const Duration(milliseconds: 1020));
    // Pump past welcome fade in (350ms)
    await tester.pump(const Duration(milliseconds: 380));

    // Verify online verified confirmation appears with ONLY "WELCOME TO LOCKSYNC"
    expect(find.text('WELCOME TO LOCKSYNC'), findsOneWidget);
    expect(find.text('LOGGED IN'), findsNothing);

    // Pump past hold (1500ms) and route transition into LockControlScreen
    await tester.pump(const Duration(milliseconds: 1520));
    await tester.pumpAndSettle();

    // Verify LockControlScreen is reached
    expect(find.byType(LockControlScreen), findsOneWidget);
    expect(find.text('LOCKER 01'), findsOneWidget);
    expect(find.text('CONNECTED DEVICE'), findsOneWidget);

    // Verify SYSTEM ONLINE was removed from header
    expect(find.text('SYSTEM ONLINE'), findsNothing);

    // Verify 3-column status panel
    expect(find.text('SIGNAL'), findsOneWidget);
    expect(find.text('DEVICE'), findsOneWidget);
    expect(find.text('STATE'), findsOneWidget);
    expect(find.text('STRONG'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);

    // Verify main lock and biometric actions in LOCKED state
    expect(find.text('LOCKED'), findsNWidgets(2)); // in circle and in status panel
    expect(find.text('TAP TO UNLOCK'), findsOneWidget);
    expect(find.text('UNLOCK WITH BIOMETRICS'), findsOneWidget);

    // Verify history section is removed from lock screen body
    expect(find.text('RECENT ACTIVITY'), findsNothing);

    // Verify persistent bottom navigation layout: HISTORY on left, circular LOCK in middle, SETTINGS on right
    expect(find.byKey(const Key('bottom_nav_HISTORY')), findsOneWidget);
    expect(find.byKey(const Key('bottom_nav_LOCK_circular')), findsOneWidget);
    expect(find.byKey(const Key('bottom_nav_SETTINGS')), findsOneWidget);

    // Tap main lock circle in middle to unlock
    await tester.tap(find.byKey(const Key('main_lock_circle_button')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify UNLOCKED state
    expect(find.text('UNLOCKED'), findsOneWidget);
    expect(find.text('TAP TO LOCK'), findsOneWidget);
    expect(find.text('LOCK DEVICE'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);

    // Tap main lock circle in middle to lock back
    await tester.tap(find.byKey(const Key('main_lock_circle_button')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify locked back
    expect(find.text('LOCKED'), findsNWidgets(2));
    expect(find.text('TAP TO UNLOCK'), findsOneWidget);
  });

  testWidgets('Test bottom navigation switching between HISTORY, LOCK, and SETTINGS',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LockControlScreen(),
      ),
    );

    // Tap HISTORY on left side of bottom nav
    await tester.tap(find.byKey(const Key('bottom_nav_HISTORY')));
    await tester.pumpAndSettle();

    // Verify access history tab content is rendered with clean HISTORY LOG header
    expect(find.text('HISTORY LOG'), findsOneWidget);
    expect(find.text('AUDIT TRAIL'), findsNothing);
    expect(find.text('EVENTS'), findsNothing);
    expect(find.text('Verified access records streamed from Arduino EEPROM.'), findsNothing);
    expect(find.text('Locker unlocked'), findsWidgets);

    // Tap circular middle LOCK button to return to lock screen
    await tester.tap(find.byKey(const Key('bottom_nav_LOCK_circular')));
    await tester.pumpAndSettle();

    // Verify back on main lock control
    expect(find.text('TAP TO UNLOCK'), findsOneWidget);
    expect(find.text('HISTORY LOG'), findsNothing);

    // Tap SETTINGS on right side of bottom nav
    await tester.tap(find.byKey(const Key('bottom_nav_SETTINGS')));
    await tester.pumpAndSettle();

    // Verify settings tab content renders the 2 buttons
    expect(find.text('DEVICE SETTINGS'), findsOneWidget);
    expect(find.text('DEVICE INFORMATION'), findsOneWidget);
    expect(find.text('CHANGE PASSWORD'), findsOneWidget);

    // Tap Device Information button to verify dialog opens
    await tester.tap(find.byKey(const Key('device_information_button')));
    await tester.pumpAndSettle();
    expect(find.text('Arduino Nano ESP32'), findsOneWidget);
    expect(find.text('v2.4.1 (Latest)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('close_device_info_dialog_button')));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'LockControlScreen fixed top header is centered without SYSTEM ONLINE',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LockControlScreen(),
      ),
    );

    // Verify SYSTEM ONLINE is removed from the fixed top header
    expect(find.text('SYSTEM ONLINE'), findsNothing);

    // Verify the LOCKSYNC wordmark RichText is present
    final wordmarkFinder = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('LOCKSYNC'),
    );
    expect(wordmarkFinder, findsOneWidget);

    // Verify wordmark is centered
    final RichText wordmark = tester.widget(wordmarkFinder);
    expect(wordmark.textAlign, TextAlign.center);
  });

  testWidgets(
      'SystemCheckScreen online flow shows LOGGED IN, WELCOME TO LOCKSYNC, then fades into LockControlScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SystemCheckScreen(
          checkDuration: Duration(milliseconds: 200),
          ringFadeDuration: Duration(milliseconds: 100),
          pauseBeforeWelcomeDuration: Duration(milliseconds: 200),
          welcomeFadeDuration: Duration(milliseconds: 100),
          holdDuration: Duration(milliseconds: 300),
          fadeDuration: Duration(milliseconds: 150),
        ),
      ),
    );

    // Initial checking state: only ring with LOCKSYNC inside (no checking system text)
    expect(find.text('CHECKING SYSTEM STATUS'), findsNothing);
    final ringBrandFinder = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('LOCKSYNC'),
    );
    expect(ringBrandFinder, findsOneWidget);

    // Advance past check duration (200ms)
    await tester.pump(const Duration(milliseconds: 220));
    // Advance past ring disappearance (100ms)
    await tester.pump(const Duration(milliseconds: 120));
    // Advance past 1.5s pause (in test 200ms)
    await tester.pump(const Duration(milliseconds: 220));
    // Advance past welcome fade in (100ms)
    await tester.pump(const Duration(milliseconds: 120));

    // Welcome view has now appeared with ONLY "WELCOME TO LOCKSYNC"
    expect(find.text('WELCOME TO LOCKSYNC'), findsOneWidget);
    expect(find.text('LOGGED IN'), findsNothing);

    // Advance past hold (300ms) and route fade into LockControlScreen
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byType(LockControlScreen), findsOneWidget);
  });

  testWidgets(
      'SystemCheckScreen offline flow halts progression and shows SYSTEM OFFLINE with retry',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SystemCheckScreen(
          forceOffline: true,
          checkDuration: Duration(milliseconds: 200),
        ),
      ),
    );

    // Advance past check duration
    await tester.pump(const Duration(milliseconds: 250));

    // Offline state reached
    expect(find.text('SYSTEM OFFLINE'), findsOneWidget);
    expect(find.text('CONNECTION FAILED'), findsOneWidget);
    expect(find.byKey(const Key('retry_connection_button')), findsOneWidget);
    expect(find.byKey(const Key('back_to_sign_in_button')), findsOneWidget);

    // Crucially, it does NOT continue to app!
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LockControlScreen), findsNothing);
  });

  testWidgets(
      'Settings tab renders Biometric Credentials module and tests enrollment flow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: LockControlScreen(),
      ),
    );

    // Navigate to SETTINGS tab
    await tester.tap(find.byKey(const Key('bottom_nav_SETTINGS')));
    await tester.pumpAndSettle();

    // Verify Biometric Credentials section exists
    expect(find.text('BIOMETRIC CREDENTIALS'), findsOneWidget);
    expect(find.text('REGISTERED FINGERPRINTS'), findsOneWidget);
    expect(find.byKey(const Key('enroll_fingerprint_button')), findsOneWidget);

    // Scroll if needed and tap the enroll button
    await tester.ensureVisible(find.byKey(const Key('enroll_fingerprint_button')));
    await tester.tap(find.byKey(const Key('enroll_fingerprint_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify modal appears
    expect(find.text('BIOMETRIC ENROLLMENT'), findsOneWidget);
    expect(find.text('ES608 Optical Sensor Module'), findsOneWidget);
    expect(find.byKey(const Key('start_enrollment_button')), findsOneWidget);

    // Tap START ENROLLMENT
    await tester.ensureVisible(find.byKey(const Key('start_enrollment_button')));
    await tester.tap(find.byKey(const Key('start_enrollment_button')));
    await tester.pump();

    // Verify ongoing enrollment UI
    await tester.ensureVisible(find.byKey(const Key('cancel_enrollment_button')));
    expect(find.byKey(const Key('cancel_enrollment_button')), findsOneWidget);

    // Step through the simulated hardware phases
    await tester.pump(const Duration(milliseconds: 1000)); // PLACE_FINGER_1
    expect(find.text('SCAN 1: PLACE FINGER'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300)); // REMOVE_FINGER
    expect(find.text('FIRST SCAN CAPTURED'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900)); // PLACE_FINGER_2
    expect(find.text('SCAN 2: PLACE SAME FINGER'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2100)); // PROCESSING
    expect(find.text('GENERATING BIOMETRIC MODEL'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2000)); // COMPLETED
    expect(find.text('ENROLLMENT COMPLETED!'), findsOneWidget);
    expect(find.byKey(const Key('enrollment_done_button')), findsOneWidget);

    // Tap DONE to finalize workflow
    await tester.ensureVisible(find.byKey(const Key('enrollment_done_button')));
    await tester.tap(find.byKey(const Key('enrollment_done_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify modal dismissed and back on Settings
    expect(find.text('BIOMETRIC ENROLLMENT'), findsNothing);
    expect(find.text('BIOMETRIC CREDENTIALS'), findsOneWidget);
  });
}

