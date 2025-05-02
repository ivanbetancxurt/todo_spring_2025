import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/todo.dart';

class ArchivedTodosScreen extends StatefulWidget {
  final List<Todo> todos;

  const ArchivedTodosScreen({super.key, required this.todos});

  @override
  State<ArchivedTodosScreen> createState() => _ArchivedTodosScreenState();
}

class _ArchivedTodosScreenState extends State<ArchivedTodosScreen> {
  late List<Todo> _archivedTodos;

  @override
  void initState() {
    super.initState();
    _archivedTodos = widget.todos;
    _archivedTodos.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by date (newest first)
  }

  Future<void> _unarchiveTodo(Todo todo) async {
    final int index = _archivedTodos.indexOf(todo);

    // Update Firestore to unarchive theGTodo
    await FirebaseFirestore.instance
        .collection('todos')
        .doc(todo.id)
        .update({'isArchived': false});

    setState(() {
      // Remove theTodo from the archived list
      _archivedTodos.removeAt(index);
    });

    // Show SnackBar with Undo action
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Todo un-archived!'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            // Revert the unarchive action in Firestore
            await FirebaseFirestore.instance
                .collection('todos')
                .doc(todo.id)
                .update({'isArchived': true});

            setState(() {
              // Add theTodo back to the archived list if not already present
              if (!_archivedTodos.contains(todo)) {
                _archivedTodos.insert(index, todo);
              }
            });
          },
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived TODOs')),
      body: _archivedTodos.isEmpty
          ? const Center(child: Text('No archived TODOs'))
          : ListView.builder(
        itemCount: _archivedTodos.length,
        itemBuilder: (context, index) {
          final todo = _archivedTodos[index];
          return ListTile(
            title: Text(todo.text),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (todo.description != null && todo.description!.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          todo.description!,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                if (todo.dueAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    todo.dueAt!.toLocal().toString().split(' ')[0],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.unarchive),
                  onPressed: () => _unarchiveTodo(todo),
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
                      await FirebaseFirestore.instance.collection('todos').doc(todo.id).delete();
                      setState(() {
                        _archivedTodos.remove(todo);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Todo deleted!')),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}