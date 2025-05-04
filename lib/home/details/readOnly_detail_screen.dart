import 'package:flutter/material.dart';
import '../../data/todo.dart';

class ReadOnlyDetailScreen extends StatelessWidget {
  final Todo todo;

  const ReadOnlyDetailScreen({super.key, required this.todo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    todo.text,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (todo.subtasks.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                    ],
                  ),
                  ...todo.subtasks.map((subtask) => Row(
                    children: [
                      Checkbox(
                        value: subtask['completed'] ?? false,
                        shape: const CircleBorder(),
                        onChanged: null, // Read-only
                      ),
                      Text(subtask['text']),
                    ],
                  )),
                ],
              ),
            const SizedBox(height: 16),
            if (todo.description != null && todo.description!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.notes, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      todo.description!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.priority_high, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  todo.priority,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (todo.recurrence != null)
              Row(
                children: [
                  const Icon(Icons.repeat, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${todo.recurrence}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (todo.color != null)
              Row(
                children: [
                  const Icon(Icons.color_lens, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(todo.color!),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (todo.dueAt != null)
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Due Date: ${todo.dueAt!.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
