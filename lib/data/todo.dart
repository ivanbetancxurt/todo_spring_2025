import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  final String id;
  final String text;
  final String? description;
  final String uid;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? dueAt;
  final bool isArchived;
  final String priority;
  final String? recurrence;
  final int? color;

  Todo({
    required this.id,
    required this.text,
    required this.description,
    required this.uid,
    required this.createdAt,
    required this.completedAt,
    required this.dueAt,
    required this.isArchived,
    required this.priority,
    this.recurrence,
    this.color,
  });

  Todo copyWith({
    String? id,
    String? text,
    String? description,
    String? uid,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? dueAt,
    bool? isArchived,
    String? priority,
    String? recurrence,
    int? color,
  }) {
    return Todo(
      id: id ?? this.id,
      text: text ?? this.text,
      description: description ?? this.description,
      uid: uid ?? this.uid,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      dueAt: dueAt ?? this.dueAt,
      isArchived: isArchived ?? this.isArchived,
      priority: priority ?? this.priority,
      recurrence: recurrence ?? this.recurrence,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'description': description,
      'uid': uid,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt!) : null,
      'isArchived': isArchived,
      'priority': priority,
      'recurrence': recurrence,
      'color': color,

    };
  }

  factory Todo.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Todo(
      id: snapshot.id,
      text: data['text'],
      uid: data['uid'],
      description: data['description'],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      dueAt: data['dueAt'] != null ? (data['dueAt'] as Timestamp).toDate() : null,
      isArchived: data['isArchived'] ?? false,
      priority: data['priority'] ?? 'none',
      recurrence: data['recurrence'],
      color: data['color'],
    );
  }
}
