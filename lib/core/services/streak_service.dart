import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreakService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _userId => _auth.currentUser?.uid ?? '';

  // Get user's streak collection reference
  static CollectionReference get _streaksCollection {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('streaks');
  }

  // Initialize or update daily streak
  // --- MODIFIED: Now returns int? ---
  static Future<int?> recordDailyLogin() async {
    if (_userId.isEmpty) return null;

    try {
      final today = DateTime.now();
      final todayString = _formatDate(today);

      // Check if already logged in today
      final todayDoc = await _streaksCollection.doc(todayString).get();
      if (todayDoc.exists) {
        final data = todayDoc.data() as Map<String, dynamic>;
        if (data['isActive'] == true) {
          print('Already logged in today');
          return null; // Already logged in today, don't show popup
        }
      }

      // Get current streak count
      int newStreakCount = await _calculateNewStreakCount(today);

      // Record today's login
      await _streaksCollection.doc(todayString).set({
        'date': todayString,
        'isActive': true,
        'streakCount': newStreakCount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Daily login recorded: streak = $newStreakCount');
      return newStreakCount; // --- ADDED: Return the new streak count ---
    } catch (e) {
      print('Error recording daily login: $e');
      return null; // --- ADDED: Return null on error ---
    }
  }

  // Calculate new streak count based on previous days
  static Future<int> _calculateNewStreakCount(DateTime today) async {
    try {
      // Check yesterday
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayString = _formatDate(yesterday);
      final yesterdayDoc = await _streaksCollection.doc(yesterdayString).get();

      if (yesterdayDoc.exists) {
        final data = yesterdayDoc.data() as Map<String, dynamic>;
        if (data['isActive'] == true) {
          // Continue streak from yesterday
          return (data['streakCount'] ?? 0) + 1;
        }
      }

      // No streak to continue, start fresh
      return 1;
    } catch (e) {
      print('Error calculating streak: $e');
      return 1;
    }
  }

  // Get current streak count
  static Future<int> getCurrentStreakCount() async {
    if (_userId.isEmpty) return 0;

    try {
      final today = DateTime.now();
      final todayString = _formatDate(today);

      // Check if logged in today
      final todayDoc = await _streaksCollection.doc(todayString).get();

      if (todayDoc.exists) {
        final data = todayDoc.data() as Map<String, dynamic>;
        if (data['isActive'] == true) {
          return data['streakCount'] ?? 0;
        }
      }

      // If not logged in today, check if we can continue yesterday's streak
      // --- FIX: This logic was breaking streaks, now it correctly returns 0 if today is missed
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayString = _formatDate(yesterday);
      final yesterdayDoc = await _streaksCollection.doc(yesterdayString).get();

      if (yesterdayDoc.exists) {
        final data = yesterdayDoc.data() as Map<String, dynamic>;
        if (data['isActive'] == true) {
          // It was active yesterday, but not today. Streak is broken.
          return 0;
        }
      }

      // Not active today, and not active yesterday (or no data)
      return 0;
    } catch (e) {
      print('Error getting current streak: $e');
      return 0;
    }
  }


  // Get streak data for a date range (for calendar) - FIXED
  static Future<Map<String, bool>> getStreakDataForRange(
      DateTime startDate,
      DateTime endDate,
      ) async {
    if (_userId.isEmpty) return {};

    try {
      final Map<String, bool> streakData = {};

      // Generate all dates in range, formatted as strings
      DateTime currentDate = startDate;
      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        streakData[_formatDate(currentDate)] = false; // Default to false
        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Get actual login data from Firebase - FIXED with named parameters
      final snapshot = await _streaksCollection
          .where('date', isGreaterThanOrEqualTo: _formatDate(startDate))
          .where('date', isLessThanOrEqualTo: _formatDate(endDate))
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateString = data['date'] as String;
        final isActive = data['isActive'] as bool? ?? false;

        // Only update if it's active
        if (isActive) {
          streakData[dateString] = true;
        }
      }

      return streakData;
    } catch (e) {
      print('Error getting streak data for range: $e');
      return {};
    }
  }

  // Check if logged in today
  static Future<bool> isLoggedInToday() async {
    if (_userId.isEmpty) return false;

    try {
      final today = _formatDate(DateTime.now());
      final doc = await _streaksCollection.doc(today).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isActive'] as bool? ?? false;
      }

      return false;
    } catch (e) {
      print('Error checking if logged in today: $e');
      return false;
    }
  }

  // Get longest streak ever
  static Future<int> getLongestStreak() async {
    if (_userId.isEmpty) return 0;

    try {
      final snapshot = await _streaksCollection
          .orderBy('streakCount', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        return data['streakCount'] ?? 0;
      }

      return 0;
    } catch (e) {
      print('Error getting longest streak: $e');
      return 0;
    }
  }

  // Get streak data for a specific month (optimized for calendar display)
  static Future<Map<String, bool>> getMonthStreakData(DateTime month) async {
    if (_userId.isEmpty) return {};

    try {
      // Get first and last day of the month
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      return await getStreakDataForRange(firstDay, lastDay);
    } catch (e) {
      print('Error getting month streak data: $e');
      return {};
    }
  }

  // Format date to YYYY-MM-DD string
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Static method for external access (used in homescreen)
  static String formatDateStatic(DateTime date) {
    return _formatDate(date);
  }

  // Parse date string back to DateTime
  static DateTime parseDate(String dateString) {
    final parts = dateString.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static Future<DateTime> getAccountCreationDate() async {
    if (_userId.isEmpty) return DateTime.now();

    try {
      // Check if creation date is already stored in user document
      final userDoc = await _firestore.collection('users').doc(_userId).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['accountCreatedAt'] != null) {
          return (data['accountCreatedAt'] as Timestamp).toDate();
        }
      }

      // If not stored, check Firebase Auth user creation time as fallback
      final user = _auth.currentUser;
      if (user?.metadata.creationTime != null) {
        final creationDate = user!.metadata.creationTime!;
        // Store it in user document for faster future access
        await setAccountCreationDate(creationDate);
        return creationDate;
      }

      // Ultimate fallback - use current date
      final now = DateTime.now();
      await setAccountCreationDate(now);
      return now;
    } catch (e) {
      print('Error getting account creation date: $e');
      // Fallback to current date if error occurs
      return DateTime.now();
    }
  }

// Set/store account creation date in Firebase
  static Future<void> setAccountCreationDate(DateTime date) async {
    if (_userId.isEmpty) return;

    try {
      await _firestore.collection('users').doc(_userId).set({
        'accountCreatedAt': Timestamp.fromDate(date),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error setting account creation date: $e');
    }
  }

  // Force refresh streak data (useful for testing)
  static Future<void> refreshStreakData() async {
    // This method can be called to ensure streak data is up to date
    await recordDailyLogin();
  }
}