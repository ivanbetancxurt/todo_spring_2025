import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/todo.dart';
import '../../data/user_stats.dart';


final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class DetailScreen extends StatefulWidget {
  final Todo todo;
  final List<Todo> todos;


  const DetailScreen({super.key, required this.todo, required this.todos});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TextEditingController _textController;
  late TextEditingController _subtaskController;
  late TextEditingController _descriptionController;
  DateTime? _selectedDueDate;
  final _userStatsService = UserStatsService();
  bool _isCompleted = false;
  late String _priority;
  String? _recurrence;
  int? _color;


  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.todo.text);
    _subtaskController = TextEditingController();
    _descriptionController = TextEditingController(text: widget.todo.description ?? '');
    _selectedDueDate = widget.todo.dueAt;
    _isCompleted = widget.todo.completedAt != null;
    _priority = widget.todo.priority;
    _recurrence = widget.todo.recurrence;
    _color = widget.todo.color;
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
    _subtaskController.dispose();
    _descriptionController.dispose();
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
            icon: const Icon(Icons.archive),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('todos')
                  .doc(widget.todo.id)
                  .update({'isArchived': true});
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Todo archived!')),
                );
              }
            },
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      onChanged: (value) async {
                        await FirebaseFirestore.instance
                            .collection('todos')
                            .doc(widget.todo.id)
                            .update({'text': value});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.todo.subtasks.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.checklist, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                      ],
                    ),
                    ...widget.todo.subtasks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final subtask = entry.value;
                      return Row(
                        children: [
                          Checkbox(
                            value: subtask['completed'] ?? false,
                            shape: const CircleBorder(),
                            onChanged: (value) async {
                              final updatedSubtasks = List<Map<String, dynamic>>.from(widget.todo.subtasks);
                              updatedSubtasks[index]['completed'] = value;
                              await FirebaseFirestore.instance
                                  .collection('todos')
                                  .doc(widget.todo.id)
                                  .update({'subtasks': updatedSubtasks});
                              setState(() {
                                widget.todo.subtasks[index]['completed'] = value;
                              });
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: subtask['text']),
                              maxLines: null,
                              textInputAction: TextInputAction.newline,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                              onChanged: (value) async {
                                final updatedSubtasks = List<Map<String, dynamic>>.from(widget.todo.subtasks);
                                updatedSubtasks[index]['text'] = value;
                                await FirebaseFirestore.instance
                                    .collection('todos')
                                    .doc(widget.todo.id)
                                    .update({'subtasks': updatedSubtasks});
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final updatedSubtasks = List<Map<String, dynamic>>.from(widget.todo.subtasks)
                                ..removeAt(index);
                              await FirebaseFirestore.instance
                                  .collection('todos')
                                  .doc(widget.todo.id)
                                  .update({'subtasks': updatedSubtasks});
                              setState(() {
                                widget.todo.subtasks.removeAt(index);
                              });
                            },
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.add, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _subtaskController,
                      decoration: const InputDecoration(
                        hintText: 'Add Subtask',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) async {
                        if (value.isNotEmpty) {
                          final updatedSubtasks = List<Map<String, dynamic>>.from(widget.todo.subtasks)
                            ..add({'text': value, 'completed': false});
                          await FirebaseFirestore.instance
                              .collection('todos')
                              .doc(widget.todo.id)
                              .update({'subtasks': updatedSubtasks});
                          setState(() {
                            widget.todo.subtasks.add({'text': value, 'completed': false});
                          });
                          _subtaskController.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.notes, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: InputBorder.none,
                      ),
                      onChanged: (value) async {
                        await FirebaseFirestore.instance
                            .collection('todos')
                            .doc(widget.todo.id)
                            .update({'description': value.isNotEmpty ? value : null});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.priority_high, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _priority,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None')),
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: (value) async {
                      setState(() {
                        _priority = value ?? 'none';
                      });
                      await FirebaseFirestore.instance
                          .collection('todos')
                          .doc(widget.todo.id)
                          .update({'priority': _priority});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.repeat, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _recurrence,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('None')),
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    ],
                    onChanged: (value) async {
                      setState(() {
                        _recurrence = value;
                      });
                      await FirebaseFirestore.instance
                          .collection('todos')
                          .doc(widget.todo.id)
                          .update({'recurrence': _recurrence});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.color_lens, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final color = await showDialog<Color?>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Pick a color'),
                          content: SingleChildScrollView(
                            child: Column(
                              children: [
                                BlockPicker(
                                  pickerColor: _color != null ? Color(_color!) : Colors.white,
                                  onColorChanged: (selectedColor) {
                                    Navigator.of(context).pop(selectedColor);
                                  },
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(null); // No color selected
                                  },
                                  child: const Text('No Color'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      if (color != null || _color != null) {
                        setState(() {
                          _color = color?.toARGB32(); // Set to null if "No Color" is selected
                        });
                        await FirebaseFirestore.instance
                            .collection('todos')
                            .doc(widget.todo.id)
                            .update({'color': _color});
                      }
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _color != null ? Color(_color!) : Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDueDate = date;
                        });
                        await FirebaseFirestore.instance
                            .collection('todos')
                            .doc(widget.todo.id)
                            .update({'dueAt': Timestamp.fromDate(date)});
                      }
                    },
                    child: Text(
                      _selectedDueDate != null
                          ? 'Due: ${_selectedDueDate!.toLocal().toString().split(' ')[0]}'
                          : 'Set Due Date',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
