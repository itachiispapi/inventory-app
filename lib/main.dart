import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

class Item {
  final String? id;
  final String name;
  final int quantity;
  final double price;
  final String category;
  final DateTime createdAt;
  const Item({
    this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.category,
    required this.createdAt,
  });
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Item.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final ts = data['createdAt'] as Timestamp?;
    return Item(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      quantity: (data['quantity'] ?? 0) as int,
      price: (data['price'] ?? 0).toDouble(),
      category: (data['category'] ?? '') as String,
      createdAt: ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
  Item copyWith({
    String? id,
    String? name,
    int? quantity,
    double? price,
    String? category,
    DateTime? createdAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class FirestoreService {
  static final FirestoreService I = FirestoreService._();
  FirestoreService._();
  final _col = FirebaseFirestore.instance
      .collection('items')
      .withConverter<Item>(
        fromFirestore: (snap, _) => Item.fromDoc(snap),
        toFirestore: (item, _) => item.toMap(),
      );
  Stream<List<Item>> itemsStream() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data().copyWith(id: d.id)).toList());
  }

  Future<void> addItem(Item item) async {
    await _col.add(item);
  }

  Future<void> updateItem(Item item) async {
    if (item.id == null) return;
    await _col.doc(item.id!).set(item);
  }

  Future<void> deleteItem(String id) async {
    await _col.doc(id).delete();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const InventoryHomePage(),
    );
  }
}

class InventoryHomePage extends StatelessWidget {
  const InventoryHomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: StreamBuilder<List<Item>>(
        stream: FirestoreService.I.itemsStream(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) return const Center(child: Text('No items'));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return ListTile(
                title: Text(item.name),
                subtitle: Text(
                  'Qty: ${item.quantity} • \$${item.price.toStringAsFixed(2)} • ${item.category}',
                ),
                trailing: Text(
                  '\$${(item.quantity * item.price).toStringAsFixed(2)}',
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () {},
      ),
    );
  }
}
