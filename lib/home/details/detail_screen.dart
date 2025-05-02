import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/todo.dart';
import '../../data/user_stats.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class DetailScreen extends StatefulWidget {
  final Todo todo;

  const DetailScreen({super.key, required this.todo});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TextEditingController _textController;
  DateTime? _selectedDueDate;
  final _userStatsService = UserStatsService();
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.todo.text);
    _selectedDueDate = widget.todo.dueAt;
    _isCompleted = widget.todo.completedAt != null;
  }

  Future<void> _delete() async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Todo deleted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete todo: $e')),
        );
      }
    }
  }

  Future<void> _updateText(String newText) async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).update({'text': newText});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todo updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update todo: $e')),
        );
      }
    }
  }

  Future<void> _updateDescription(String newDescription) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({'description': newDescription.isNotEmpty ? newDescription : null});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Description updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update description: $e')),
        );
      }
    }
  }

  Future<void> _updateDueDate(DateTime? newDueDate) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({'dueAt': newDueDate == null ? null : Timestamp.fromDate(newDueDate)});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update todo: $e')),
        );
      }
    }
  }

  Future<bool> _requestNotificationPermission() async {
    final isGranted = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false;
    return isGranted;
  }

  void _showPermissionDeniedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You need to enable notifications to set due date.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Open Settings',
          textColor: Colors.white,
          onPressed: () {
            AppSettings.openAppSettings(
              type: AppSettingsType.notification,
            );
          },
        ),
      ),
    );
  }

  Future<void> _initializeNotifications() async {
    final initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> _scheduleNotification(
    String todoId,
    DateTime dueDate,
    String text,
  ) async {
    final tzDateTime = tz.TZDateTime.from(dueDate, tz.local);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      todoId.hashCode,
      'Task due',
      text,
      tzDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general_channel',
          'General Notifications',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> _toggleCompletion(bool? isCompleted) async {
    if (isCompleted == _isCompleted) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final updateData = {
        'completedAt': isCompleted == true ? FieldValue.serverTimestamp() : null
      };
      
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).update(updateData);
      
      // Update the user's completion counter
      if (isCompleted == true) {
        await _userStatsService.incrementCompletedCount(user.uid);
      } else {
        await _userStatsService.decrementCompletedCount(user.uid);
      }
      
      setState(() {
        _isCompleted = isCompleted ?? false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isCompleted == true ? 'Task completed!' : 'Task marked as incomplete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            icon: Icon(_isCompleted ? Icons.check_circle : Icons.check_circle_outline),
            color: _isCompleted ? Colors.green : null,
            onPressed: () => _toggleCompletion(!_isCompleted),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Todo'),
                  content: const Text('Are you sure you want to delete this todo?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _delete();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              controller: _textController,
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
              onSubmitted: (newText) async {
                if (newText.isNotEmpty && newText != widget.todo.text) {
                  await _updateText(newText);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14.0), // Adjust alignment to the first line
                  child: const Icon(Icons.notes, size: 16, color: Colors.grey),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    controller: TextEditingController(text: widget.todo.description),
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    onSubmitted: (newDescription) async {
                      if (newDescription.isNotEmpty && newDescription != widget.todo.description) {
                        await _updateDescription(newDescription);
                      }
                    },
                  ),
                ),
              ],
            ),
            ListTile(
              title: const Text('Due Date'),
              subtitle: Text(_selectedDueDate?.toLocal().toString().split('.')[0] ?? 'No due date'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedDueDate != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        _updateDueDate(null);
                        setState(() {
                          _selectedDueDate = null;
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final isGranted = await _requestNotificationPermission();
                      if (!context.mounted) return;

                      if (!isGranted) {
                        _showPermissionDeniedSnackbar(context);
                        return;
                      }

                      await _initializeNotifications();
                      if (!context.mounted) return;

                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2050),
                      );
                      if (!context.mounted) return;
                      if (selectedDate == null) return;

                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime:
                            _selectedDueDate != null ? TimeOfDay.fromDateTime(_selectedDueDate!) : TimeOfDay.now(),
                      );
                      if (selectedTime == null) return;

                      final DateTime dueDate = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      setState(() {
                        _selectedDueDate = dueDate;
                      });

                      await _updateDueDate(dueDate);
                      await _scheduleNotification(
                        widget.todo.id,
                        dueDate,
                        widget.todo.text,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
