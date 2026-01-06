import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Convert image to base64 for storage in Firestore
  Future<String?> _convertImageToBase64(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      debugPrint('✅ Image converted to base64 (${bytes.length} bytes)');
      return base64String;
    } catch (e) {
      debugPrint('❌ Error converting image: $e');
      return null;
    }
  }

  void _addProduct() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final descController = TextEditingController();
    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price (₱)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stock Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 70,
                      );
                      if (image != null) {
                        setDialogState(() {
                          selectedImage = image;
                        });
                      }
                    } catch (e) {
                      debugPrint('❌ Error picking image: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to pick image: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(
                    selectedImage != null
                        ? 'Image Selected ✓'
                        : 'Pick Product Image',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: selectedImage != null
                        ? Colors.green
                        : null,
                  ),
                ),
                if (selectedImage != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(selectedImage!.path),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    priceController.text.isEmpty ||
                    stockController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                    ),
                  );
                  return;
                }

                if (_userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User not authenticated')),
                  );
                  return;
                }

                // Capture messenger before async operations
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);

                try {
                  String? imageBase64;

                  // Convert selected image to base64
                  if (selectedImage != null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Processing image...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    imageBase64 = await _convertImageToBase64(selectedImage!);
                  }

                  await _firestore.collection('products').add({
                    'name': nameController.text,
                    'price': double.parse(priceController.text),
                    'stock': int.parse(stockController.text),
                    'description': descController.text,
                    'imageBase64': imageBase64,
                    'ownerId': _userId,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Product added successfully')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error adding product: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976d2),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _editProduct(String productId, Map<String, dynamic> product) {
    final nameController = TextEditingController(text: product['name']);
    final priceController = TextEditingController(
      text: product['price'].toString(),
    );
    final stockController = TextEditingController(
      text: product['stock'].toString(),
    );
    final descController = TextEditingController(text: product['description']);
    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price (₱)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stock Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 70,
                      );
                      if (image != null) {
                        setDialogState(() {
                          selectedImage = image;
                        });
                      }
                    } catch (e) {
                      debugPrint('❌ Error picking image: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to pick image: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(
                    selectedImage != null
                        ? 'New Image Selected ✓'
                        : 'Change Product Image',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: selectedImage != null
                        ? Colors.green
                        : null,
                  ),
                ),
                if (selectedImage != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(selectedImage!.path),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ] else if (product['imageBase64'] != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(product['imageBase64']),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Capture messenger and navigator before async operations
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                try {
                  String? imageBase64 = product['imageBase64'];

                  // Convert new image to base64 if selected
                  if (selectedImage != null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Processing image...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    imageBase64 = await _convertImageToBase64(selectedImage!);
                  }

                  await _firestore
                      .collection('products')
                      .doc(productId)
                      .update({
                        'name': nameController.text,
                        'price': double.parse(priceController.text),
                        'stock': int.parse(stockController.text),
                        'description': descController.text,
                        if (imageBase64 != null) 'imageBase64': imageBase64,
                      });

                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Product updated successfully'),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error updating product: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976d2),
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteProduct(String productId, String productName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$productName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Capture messenger and navigator before async operations
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);

              try {
                await _firestore.collection('products').doc(productId).delete();

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Product deleted')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error deleting product: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleHighlight(String productId, bool currentlyHighlighted) async {
    // Capture messenger before async operations
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _firestore.collection('products').doc(productId).update({
        'isHighlighted': !currentlyHighlighted,
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            !currentlyHighlighted
                ? 'Product highlighted successfully'
                : 'Product unhighlighted',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error updating product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Products'),
          backgroundColor: const Color(0xFF1976d2),
        ),
        body: const Center(child: Text('User not authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        backgroundColor: const Color(0xFF1976d2),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('products')
            .where('ownerId', isEqualTo: _userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final products = snapshot.data?.docs ?? [];

          if (products.isEmpty) {
            return const Center(
              child: Text('No products yet. Add your first product!'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final doc = products[index];
              final product = doc.data() as Map<String, dynamic>;
              final productId = doc.id;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: product['imageBase64'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(product['imageBase64']),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: const Color(0xFF1976d2),
                          child: Text(
                            product['name'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                  title: Text(
                    product['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['description'] ?? ''),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '₱${product['price']}',
                            style: const TextStyle(
                              color: Color(0xFF1976d2),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: product['stock'] > 10
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Stock: ${product['stock']}',
                              style: TextStyle(
                                fontSize: 10,
                                color: product['stock'] > 10
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) {
                      final isHighlighted = product['isHighlighted'] ?? false;
                      return [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'highlight',
                          child: Row(
                            children: [
                              Icon(
                                isHighlighted ? Icons.star : Icons.star_border,
                                size: 18,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              Text(isHighlighted ? 'Unhighlight' : 'Highlight'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editProduct(productId, product);
                      } else if (value == 'delete') {
                        _deleteProduct(productId, product['name']);
                      } else if (value == 'highlight') {
                        _toggleHighlight(
                          productId,
                          product['isHighlighted'] ?? false,
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        backgroundColor: const Color(0xFF1976d2),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}
