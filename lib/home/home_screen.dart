import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/todo.dart';
import '../data/user_stats.dart';
import 'details/detail_screen.dart';
import 'filter/filter_sheet.dart';
import 'archive/archive_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subtaskController = TextEditingController();
  StreamSubscription<List<Todo>>? _todoSubscription;
  StreamSubscription<UserStats>? _userStatsSubscription;
  List<Todo> _todos = [];
  List<Todo>? _filteredTodos;
  UserStats? _userStats;
  String _selectedPriority = 'none';
  String? _selectedRecurrence;
  Color? _selectedColor;
  final List<Map<String, dynamic>> _subtasks = [];
  final _userStatsService = UserStatsService();
  FilterSheetResult _filters = FilterSheetResult(
    sortBy: 'date',
    order: 'descending',
    priority: 'none',
  );

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _todoSubscription = getTodosForUser(user.uid).listen((todos) {
        setState(() {
          _todos = todos;
          _filteredTodos = filterTodos();
        });
      });
      
      _userStatsSubscription = _userStatsService.getUserStatsStream(user.uid).listen((stats) {
        setState(() {
          _userStats = stats;
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _todoSubscription?.cancel();
    _userStatsSubscription?.cancel();
    _subtaskController.dispose();
    super.dispose();
  }

  List<Todo> filterTodos() {
    List<Todo> filteredTodos = _todos.where((todo) {
      return !todo.isArchived && todo.text.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();



    if (_filters.sortBy == 'date') {
      filteredTodos.sort((a, b) => _filters.order == 'ascending'
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt));
    } else if (_filters.sortBy == 'completed') {
      filteredTodos.sort((a, b) => _filters.order == 'ascending'
          ? (a.completedAt ?? DateTime(0)).compareTo(b.completedAt ?? DateTime(0))
          : (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
    } else if (_filters.sortBy  == 'priority') {
        const priorityOrder = {'none': 0, 'low': 1, 'medium': 2, 'high': 3};
        filteredTodos.sort((a, b) => _filters.order == 'ascending'
            ? priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!)
            : priorityOrder[b.priority]!.compareTo(priorityOrder[a.priority]!));
    }

    return filteredTodos;
  }

  List<Todo> handleRecurringTodos(List<Todo> todos) {
    final now = DateTime.now();
    List<Todo> updatedTodos = [];

    for (var todo in todos) {
      if (todo.recurrence == 'daily' && todo.dueAt != null) {
        while (todo.dueAt!.isBefore(now)) {
          todo = todo.copyWith(dueAt: todo.dueAt!.add(Duration(days: 1)));
        }
      } else if (todo.recurrence == 'weekly' && todo.dueAt != null) {
        while (todo.dueAt!.isBefore(now)) {
          todo = todo.copyWith(dueAt: todo.dueAt!.add(Duration(days: 7)));
        }
      } else if (todo.recurrence == 'monthly' && todo.dueAt != null) {
        while (todo.dueAt!.isBefore(now)) {
          todo = todo.copyWith(dueAt: DateTime(
            todo.dueAt!.year,
            todo.dueAt!.month + 1,
            todo.dueAt!.day,
          ));
        }
      }
      updatedTodos.add(todo);
    }

    return updatedTodos;
  }

  Stream<List<Todo>> getTodosForUser(String userId) {
    return FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs.map((doc) => Todo.fromSnapshot(doc)).toList());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArchivedTodosScreen(todos: _todos.where((todo) => todo.isArchived).toList()),
                ),
              );
            },
            child: const Text('Archived'),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${_userStats?.completedCount ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 600;
          return Center(
            child: SizedBox(
              width: isDesktop ? 600 : double.infinity,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: 'Search TODOs',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.filter_list),
                          onPressed: () async {
                            final result = await showModalBottomSheet<FilterSheetResult>(
                              context: context,
                              builder: (context) {
                                return FilterSheet(initialFilters: _filters);
                              },
                            );

                            if (result != null) {
                              setState(() {
                                _filters = result;
                                _filteredTodos = filterTodos();
                              });
                            }
                          },
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filteredTodos = filterTodos();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _filteredTodos?.isEmpty ?? true
                        ? const Center(child: Text('No TODOs found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            itemCount: _filteredTodos?.length ?? 0,
                            itemBuilder: (context, index) {
                              final todo = _filteredTodos?[index];
                              if (todo == null) return const SizedBox.shrink();
                              return Container(
                                  key: ValueKey(todo.id),
                                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                                  decoration: BoxDecoration(
                                    color: todo.color != null ? Color(todo.color!) : Colors.white,
                                    borderRadius: BorderRadius.circular(8.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withValues(),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                child: ListTile(
                                leading:
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(value: todo.completedAt != null,
                                      onChanged: (bool? value) async {
                                        final user = FirebaseAuth.instance.currentUser;
                                        if (user != null) {
                                          final updateData = {
                                            'completedAt': value == true ? FieldValue.serverTimestamp() : null
                                          };
                                          await FirebaseFirestore.instance.collection('todos').doc(todo.id).update(updateData);

                                          // Update the user's completion counter
                                          if (value == true) {
                                            await _userStatsService.incrementCompletedCount(user.uid);
                                          } else if (todo.completedAt != null) {
                                            await _userStatsService.decrementCompletedCount(user.uid);
                                          }
                                        }
                                      },
                                    ),
                                SizedBox(
                                  width: 16, // Adjust the size as needed
                                  height: 16,
                                  child: CircleAvatar(
                                    backgroundColor: todo.priority == 'high'
                                        ? Colors.red
                                        : todo.priority == 'medium'
                                        ? Colors.orange
                                        : todo.priority == 'low'
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                ],
                                  ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.archive),
                                      onPressed: () async {

                                        // Archive theTODO in Firestore
                                        await FirebaseFirestore.instance.collection('todos').doc(todo.id).update({'isArchived': true});

                                        setState(() {
                                          _todos = _todos.map((t) {
                                            if (t.id == todo.id) {
                                              return t.copyWith(isArchived: true);
                                            }
                                            return t;
                                          }).toList();
                                          _filteredTodos = filterTodos();
                                        });

                                        // Show SnackBar with Undo action
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Todo archived!'),
                                            action: SnackBarAction(
                                              label: 'Undo',
                                              onPressed: () async {
                                                // Revert the archive action in Firestore
                                                await FirebaseFirestore.instance.collection('todos').doc(todo.id).update({'isArchived': false});

                                                setState(() {

                                                  _todos = _todos.map((t) {
                                                    if (t.id == todo.id) {
                                                      return t.copyWith(isArchived: false);
                                                    }
                                                    return t;
                                                  }).toList();

                                                  // Reapply filters to maintain consistency
                                                  _filteredTodos = filterTodos();
                                                });
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const Icon(Icons.arrow_forward_ios),
                                  ],
                                ),
                                title: Text(
                                  todo.text,
                                  style: todo.completedAt != null
                                      ? const TextStyle(decoration: TextDecoration.lineThrough)
                                      : null,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (todo.subtasks.isNotEmpty)
                                      ...todo.subtasks.map((subtask) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Checkbox(
                                              value: subtask['completed'] ?? false,
                                              shape: const CircleBorder(),
                                              onChanged: (value) async {
                                                final updatedSubtasks = List<Map<String, dynamic>>.from(todo.subtasks);
                                                updatedSubtasks[todo.subtasks.indexOf(subtask)]['completed'] = value;
                                                await FirebaseFirestore.instance
                                                    .collection('todos')
                                                    .doc(todo.id)
                                                    .update({'subtasks': updatedSubtasks});
                                                setState(() {
                                                  todo.subtasks[todo.subtasks.indexOf(subtask)]['completed'] = value;
                                                });
                                              },
                                            ),
                                            Expanded(
                                              child: Text(
                                                subtask['text'],
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                    if (todo.description != null && todo.description!.isNotEmpty)
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final textSpan = TextSpan(
                                            text: todo.description,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          );
                                          final textPainter = TextPainter(
                                            text: textSpan,
                                            maxLines: 2,
                                            textDirection: TextDirection.ltr,
                                          )..layout(maxWidth: constraints.maxWidth);

                                          final isOverflowing = textPainter.didExceedMaxLines;

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                todo.description!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                              if (isOverflowing)
                                                GestureDetector(
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => DetailScreen(todo: todo, todos: _todos),
                                                      ),
                                                    );
                                                  },
                                                  child: const Text(
                                                    'Read More',
                                                    style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    if (todo.dueAt != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        todo.dueAt!.toLocal().toString().split(' ')[0],
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                    if (todo.recurrence != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.repeat, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Repeats: ${todo.recurrence}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailScreen(todo: todo, todos: _todos),
                                    ),
                                  );
                                },
                                ),
                              );
                            },
                          ),
                  ),

                  Container(
                    color: Colors.blue[100],
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      // crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                      TextField(
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                            controller: _controller,
                            maxLines: null,
                            decoration: const InputDecoration(
                              labelText: 'Task',
                              border: InputBorder.none,
                            ),
                          ),
                        Column(
                          children: [
                            // Display the list of subtasks
                            ListView.builder(
                              shrinkWrap: true,
                              itemCount: _subtasks.length,
                              itemBuilder: (context, index) {
                                final subtask = _subtasks[index];
                                return Row(
                                  children: [
                                    Checkbox(
                                      value: subtask['completed'] ?? false,
                                      shape: const CircleBorder(),
                                      onChanged: (value) {
                                        setState(() {
                                          _subtasks[index]['completed'] = value;
                                        });
                                      },
                                    ),
                                    Text(subtask['text']),
                                  ],
                                );
                              },
                            ),
                            // Input field for adding subtasks
                            TextField(
                              controller: _subtaskController,
                              decoration: const InputDecoration(
                                hintText: 'Add Subtask',
                                border: InputBorder.none, // Removes the bounding box
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
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.notes, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                controller: _descriptionController,
                                maxLines: null,
                                decoration: const InputDecoration(
                                  labelText: 'description',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                      Row(
                        children: [
                          const Text('priority  ', style: TextStyle(fontSize: 16)),
                          DropdownButton<String>(
                            value: _selectedPriority,
                            items: const [
                              DropdownMenuItem(value: 'none', child: Text('None')),
                              DropdownMenuItem(value: 'low', child: Text('Low')),
                              DropdownMenuItem(value: 'medium', child: Text('Medium')),
                              DropdownMenuItem(value: 'high', child: Text('High')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedPriority = value ?? 'none';
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('repeat  ', style: TextStyle(fontSize: 16)),
                          DropdownButton<String>(
                            value: _selectedRecurrence,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('None')),
                              DropdownMenuItem(value: 'daily', child: Text('Daily')),
                              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedRecurrence = value;
                              });
                            },
                          ),
                        ],
                      ),
                        ElevatedButton(
                          onPressed: () async {
                            if (user != null && _controller.text.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('todos').add({
                                'text': _controller.text,
                                'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
                                'createdAt': FieldValue.serverTimestamp(),
                                'uid': user.uid,
                                'priority': _selectedPriority,
                                'recurrence': _selectedRecurrence,
                                'color': _selectedColor?.toARGB32(),
                                'subtasks': _subtasks,
                              });
                              _controller.clear();
                              _descriptionController.clear();
                              _subtasks.clear();
                              setState(() {
                                _selectedPriority = 'none';// Reset priority
                                _selectedRecurrence = null;
                              });
                            }
                          },
                          child: const Text('Add'),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
