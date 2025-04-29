import 'package:cloud_firestore/cloud_firestore.dart';

class UserStats {
  final String uid;
  final int completedCount;

  UserStats({
    required this.uid,
    required this.completedCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'completedCount': completedCount,
    };
  }

  factory UserStats.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return UserStats(
      uid: snapshot.id,
      completedCount: data['completedCount'] ?? 0,
    );
  }

  UserStats copyWith({
    String? uid,
    int? completedCount,
  }) {
    return UserStats(
      uid: uid ?? this.uid,
      completedCount: completedCount ?? this.completedCount,
    );
  }
}

class UserStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserStats> getUserStats(String uid) async {
    final doc = await _firestore.collection('user_stats').doc(uid).get();
    if (doc.exists) {
      return UserStats.fromSnapshot(doc);
    } else {
      // Initialize stats if they don't exist
      final newStats = UserStats(uid: uid, completedCount: 0);
      await _firestore.collection('user_stats').doc(uid).set(newStats.toMap());
      return newStats;
    }
  }

  Stream<UserStats> getUserStatsStream(String uid) {
    return _firestore.collection('user_stats').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return UserStats.fromSnapshot(snapshot);
      } else {
        // Return default stats if document doesn't exist yet
        return UserStats(uid: uid, completedCount: 0);
      }
    });
  }

  Future<void> incrementCompletedCount(String uid) async {
    await _firestore.collection('user_stats').doc(uid).set(
      {'completedCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  Future<void> decrementCompletedCount(String uid) async {
    final stats = await getUserStats(uid);
    if (stats.completedCount > 0) {
      await _firestore.collection('user_stats').doc(uid).update(
        {'completedCount': FieldValue.increment(-1)},
      );
    }
  }
} 