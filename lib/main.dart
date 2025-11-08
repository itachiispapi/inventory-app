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
    final data = doc.data() ?? const {};
    final ts = data['createdAt'];
    final qty =
        (data['quantity'] as num?)?.toInt() ??
        int.tryParse('${data['quantity']}') ??
        0;
    final price =
        (data['price'] as num?)?.toDouble() ??
        double.tryParse('${data['price']}') ??
        0.0;

    return Item(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      quantity: qty,
      price: price,
      category: (data['category'] ?? '').toString(),
      createdAt: ts is Timestamp
          ? ts.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
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

class InventoryHomePage extends StatefulWidget {
  const InventoryHomePage({super.key});
  @override
  State<InventoryHomePage> createState() => _InventoryHomePageState();
}

class _InventoryHomePageState extends State<InventoryHomePage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search by name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Item>>(
              stream: FirestoreService.I.itemsStream(),
              builder: (context, snap) {
                if (snap.hasError)
                  return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                var items = snap.data!;
                if (_query.isNotEmpty) {
                  items = items
                      .where((i) => i.name.toLowerCase().contains(_query))
                      .toList();
                }
                if (items.isEmpty) return const Center(child: Text('No items'));
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(Icons.delete),
                      ),
                      onDismissed: (_) {
                        if (item.id != null) {
                          FirestoreService.I.deleteItem(item.id!);
                        }
                      },
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          'Qty: ${item.quantity} • \$${item.price.toStringAsFixed(2)} • ${item.category}',
                        ),
                        trailing: Text(
                          '\$${(item.quantity * item.price).toStringAsFixed(2)}',
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddEditItemScreen(initial: item),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddEditItemScreen()));
        },
      ),
    );
  }
}

class AddEditItemScreen extends StatefulWidget {
  final Item? initial;
  const AddEditItemScreen({super.key, this.initial});
  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  late final TextEditingController _category;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _quantity = TextEditingController(text: i?.quantity.toString() ?? '');
    _price = TextEditingController(text: i?.price.toString() ?? '');
    _category = TextEditingController(text: i?.category ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    _category.dispose();
    super.dispose();
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _isInt(String? v) {
    if (_req(v) != null) return 'Required';
    return int.tryParse(v!.trim()) == null ? 'Enter a whole number' : null;
  }

  String? _isDouble(String? v) {
    if (_req(v) != null) return 'Required';
    return double.tryParse(v!.trim()) == null ? 'Enter a number' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final base = Item(
      id: widget.initial?.id,
      name: _name.text.trim(),
      quantity: int.parse(_quantity.text.trim()),
      price: double.parse(_price.text.trim()),
      category: _category.text.trim(),
      createdAt: widget.initial?.createdAt ?? now,
    );
    if (widget.initial == null) {
      await FirestoreService.I.addItem(base);
    } else {
      await FirestoreService.I.updateItem(base);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Item' : 'Add Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: _req,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantity,
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: _isInt,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                decoration: const InputDecoration(labelText: 'Price'),
                validator: _isDouble,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: _req,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(editing ? 'Save Changes' : 'Add Item'),
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
