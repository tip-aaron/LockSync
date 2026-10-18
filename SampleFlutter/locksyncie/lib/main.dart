import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const LockSyncApp());
}

class LockSyncApp extends StatelessWidget {
  const LockSyncApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LockSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const LockerDashboardScreen(),
    );
  }
}

class LockerDashboardScreen extends StatefulWidget {
  const LockerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<LockerDashboardScreen> createState() => _LockerDashboardScreenState();
}

class _LockerDashboardScreenState extends State<LockerDashboardScreen> {
  final DatabaseReference _lockerRef =
      FirebaseDatabase.instance.ref('lockers/locker_01');

  // Trigger Remote Lock Toggle
  Future<void> _toggleLock(bool currentLockState) async {
    await _lockerRef.update({
      'isLocked': !currentLockState,
      'lastAction': !currentLockState ? 'REMOTE_LOCKED' : 'REMOTE_UNLOCKED',
    });
  }

  // Start Biometric Enrollment Flow
  Future<void> _startEnrollment() async {
    final String workflowId = 'WF_${DateTime.now().millisecondsSinceEpoch}';
    await _lockerRef.update({
      'enrollStatus': 'START_ENROLL',
      'workflowId': workflowId,
      'lastAction': 'APP_INITIATED_ENROLL',
    });
  }

  // Reset Enrollment State
  Future<void> _resetEnrollStatus() async {
    await _lockerRef.update({
      'enrollStatus': 'IDLE',
    });
  }

  // Clear Tamper Alarm
  Future<void> _disarmTamperAlert() async {
    await _lockerRef.update({
      'tamperAlert': false,
      'lastAction': 'ALERT_DISARMED_BY_APP',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LockSync Locker 01'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _lockerRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

          final bool isLocked = data['isLocked'] ?? true;
          final bool motionDetected = data['motionDetected'] ?? false;
          final bool tamperAlert = data['tamperAlert'] ?? false;
          final String enrollStatus = data['enrollStatus'] ?? 'IDLE';
          final String lastAction = data['lastAction'] ?? 'None';
          final Map<String, dynamic> registeredSlots = data['registeredSlots'] != null
              ? Map<String, dynamic>.from(data['registeredSlots'] as Map)
              : {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. TAMPER ALERT BANNER
                if (tamperAlert) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 36),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TAMPER ALERT DETECTED',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text('Unauthorized door activity flagged.'),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _disarmTamperAlert,
                          child: const Text('DISARM', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 2. MAIN LOCK CARD
                Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: isLocked
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          child: Icon(
                            isLocked ? Icons.lock : Icons.lock_open,
                            size: 48,
                            color: isLocked ? Colors.redAccent : Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isLocked ? 'LOCKER ENGAGED' : 'LOCKER UNLOCKED',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isLocked ? Colors.redAccent : Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Last Action: $lastAction',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () => _toggleLock(isLocked),
                            icon: Icon(isLocked ? Icons.lock_open : Icons.lock),
                            label: Text(
                              isLocked ? 'Remote Unlock' : 'Remote Lock',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLocked ? const Color(0xFF38BDF8) : Colors.orangeAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. HARDWARE TELEMETRY ROW
                Row(
                  children: [
                    Expanded(
                      child: _buildTelemetryTile(
                        icon: Icons.sensors,
                        label: 'PIR Sensor',
                        value: motionDetected ? 'Motion Detected' : 'Clear',
                        color: motionDetected ? Colors.amber : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTelemetryTile(
                        icon: Icons.fingerprint,
                        label: 'Biometric Unit',
                        value: '${registeredSlots.length} Stored',
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 4. BIOMETRIC ENROLLMENT WIZARD CARD
                Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Biometric Registration Wizard',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildEnrollmentStatusWidget(enrollStatus),
                        const SizedBox(height: 16),
                        if (enrollStatus == 'IDLE')
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _startEnrollment,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: const Text('Add New Fingerprint'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF38BDF8)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: TextButton(
                              onPressed: _resetEnrollStatus,
                              child: const Text('Cancel / Reset State', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 5. STORED BIOMETRIC SLOTS LIST
                Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registered Fingerprint Memory Slots',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (registeredSlots.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('No fingerprint slots registered on ES608 sensor.',
                                style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: registeredSlots.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                            itemBuilder: (context, index) {
                              final key = registeredSlots.keys.elementAt(index);
                              final slot = Map<String, dynamic>.from(registeredSlots[key] as Map);
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.fingerprint, color: Color(0xFF38BDF8)),
                                title: Text(slot['label'] ?? key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('Hardware Slot ID: #${slot['slotId'] ?? 'N/A'}'),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Helper Widget: Telemetry Tile ---
  Widget _buildTelemetryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  // --- Helper Widget: Enrollment Wizard Instructions ---
  Widget _buildEnrollmentStatusWidget(String status) {
    IconData icon = Icons.info_outline;
    Color color = Colors.grey;
    String text = 'Ready to add biometrics.';

    switch (status) {
      case 'START_ENROLL':
        icon = Icons.sync;
        color = const Color(0xFF38BDF8);
        text = 'Initializing ES608 sensor...';
        break;
      case 'PLACE_FINGER_1':
        icon = Icons.touch_app;
        color = Colors.amber;
        text = 'STEP 1: Place your finger on the locker scanner.';
        break;
      case 'REMOVE_FINGER':
        icon = Icons.pan_tool_outlined;
        color = Colors.cyan;
        text = 'STEP 2: Lift your finger off the scanner.';
        break;
      case 'PLACE_FINGER_2':
        icon = Icons.touch_app;
        color = Colors.amber;
        text = 'STEP 3: Place the SAME finger on the scanner again.';
        break;
      case 'PROCESSING':
        icon = Icons.hourglass_top;
        color = Colors.purpleAccent;
        text = 'Validating and saving template model...';
        break;
      case 'COMPLETED':
        icon = Icons.check_circle;
        color = Colors.greenAccent;
        text = 'SUCCESS: Fingerprint saved to sensor hardware!';
        break;
      case 'TIMEOUT':
        icon = Icons.timer_off;
        color = Colors.redAccent;
        text = 'Enrollment timed out. Please try again.';
        break;
      case 'ERROR_PRINTS_DONT_MATCH':
        icon = Icons.error_outline;
        color = Colors.redAccent;
        text = 'Scans did not match. Please try again.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
