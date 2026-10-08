import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:salesvista/phase_2_models/user_model.dart';
import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userBox = Hive.box<UserModel>('users_box');

    return BaseScaffold(
      title: "Users",
      currentRoute: AppRoutes.users,
      body: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: userBox.listenable(),
            builder: (context, Box<UserModel> box, _) {
              if (box.isEmpty) return const Center(child: Text("No users available"));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: box.length,
                itemBuilder: (context, index) {
                  final user = box.getAt(index)!;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Email: ${user.email}\nRole: ${user.role}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => user.delete(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => _showAddUserDialog(context),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final roleController = TextEditingController();

    final userBox = Hive.box<UserModel>('users_box');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
            const SizedBox(height: 10),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            const SizedBox(height: 10),
            TextField(controller: roleController, decoration: const InputDecoration(labelText: "Role")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty || emailController.text.isEmpty || roleController.text.isEmpty) return;

              final newUser = UserModel(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                email: emailController.text.trim(),
                role: roleController.text.trim(),
              );

              userBox.add(newUser);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
