import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';


class AddTodoScreen extends StatefulWidget {
  const AddTodoScreen({super.key});

  @override
  State<AddTodoScreen> createState() => _AddTodoScreenState();
}

class _AddTodoScreenState extends State<AddTodoScreen> {
  final _textController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subtaskController = TextEditingController();
  String _priority = 'none';
  String? _recurrence;
  DateTime? _dueDate;
  int? _color;
  final List<Map<String, dynamic>> _subtasks = [];

  Future<void> _addTodo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _textController.text.isNotEmpty) {
      await FirebaseFirestore.instance.collection('todos').add({
        'text': _textController.text,
        'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': user.uid,
        'priority': _priority,
        'recurrence': _recurrence,
        'dueAt': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
        'color': _color,
        'subtasks': _subtasks,
      });
      if (mounted) {
        Navigator.pop(context); // Navigate back to HomeScreen
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add TODO')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task title
            TextField(
              controller: _textController,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(labelText: 'Task'),
            ),
            const SizedBox(height: 16),
            // Subtask input
            const SizedBox(height: 16),
            // Subtask list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _subtasks.length,
              itemBuilder: (context, index) {
                final subtask = _subtasks[index];
                return Row(
                  children: [
                    Checkbox(
                      value: subtask['completed'],
                      shape: const CircleBorder(),
                      onChanged: (value) {
                        setState(() {
                          _subtasks[index]['completed'] = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        subtask['text'],
                        style: TextStyle(
                          decoration: subtask['completed']
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _subtasks.removeAt(index);
                        });
                      },
                    ),
                  ],
                );
              },
            ),
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
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          _subtasks.add({'text': value, 'completed': false});
                        });
                        _subtaskController.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
            TextField(
              controller: _descriptionController,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('priority  '),
                DropdownButton<String>(
                  value: _priority,
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _priority = value ?? 'none';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('recurrence  '),
                DropdownButton<String>(
                  value: _recurrence,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _recurrence = value;
                    });
                  },
                ),
              ],
            ),
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
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() {
                    _dueDate = date;
                  });
                }
              },
              child: Text(
                _dueDate != null
                    ? 'Due Date: ${_dueDate!.toLocal().toString().split(' ')[0]}'
                    : 'Set Due Date',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addTodo,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}