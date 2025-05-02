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
  StreamSubscription<List<Todo>>? _todoSubscription;
  StreamSubscription<UserStats>? _userStatsSubscription;
  List<Todo> _todos = [];
  List<Todo>? _filteredTodos;
  UserStats? _userStats;
  String _selectedPriority = 'none';
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
                              return ListTile(
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
                                        final int index = _filteredTodos!.indexOf(todo);

                                        // Archive theTODO in Firestore
                                        await FirebaseFirestore.instance.collection('todos').doc(todo.id).update({'isArchived': true});

                                        setState(() {
                                          _filteredTodos!.removeAt(index);
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
                                                  // Ensure theTodo is not duplicated in the filtered list
                                                  if (!_filteredTodos!.contains(todo)) {
                                                    _filteredTodos!.insert(index, todo);
                                                  }

                                                  // Ensure theTodo is not duplicated in the main list
                                                  if (!_todos.any((t) => t.id == todo.id)) {
                                                    _todos.add(todo);
                                                  }

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
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailScreen(todo: todo, todos: _todos),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  Container(
                    color: Colors.green[100],
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
                                  labelText: 'Description',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
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
                        ElevatedButton(
                          onPressed: () async {
                            if (user != null && _controller.text.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('todos').add({
                                'text': _controller.text,
                                'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
                                'createdAt': FieldValue.serverTimestamp(),
                                'uid': user.uid,
                                'priority': _selectedPriority,
                              });
                              _controller.clear();
                              _descriptionController.clear();
                              setState(() {
                                _selectedPriority = 'none'; // Reset priority
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
