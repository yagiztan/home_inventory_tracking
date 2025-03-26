import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> categories = [
    'Sebze Meyve',
    'Hijyen',
    'Hazır gıda',
    'İçecekler',
    'Tatlı',
    'Atıştırmalıklar',
    'Temel İhtiyaçlar'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Envanter Takip'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: categories.map((String category) {
            return Tab(text: category);
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(categories.length, (index) {
          return CategoryView(categoryIndex: index);
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddProductScreen()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class CategoryView extends StatelessWidget {
  final int categoryIndex;

  CategoryView({required this.categoryIndex});

  @override
  Widget build(BuildContext context) {
    final CollectionReference products = FirebaseFirestore.instance.collection('evdeki_malzemeler');

    return SingleChildScrollView(
      child: StreamBuilder(
        stream: products.where('kategori', isEqualTo: categoryIndex).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          return Column(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              return ProductCard(
                id: document.id,
                imageUrl: data['urun_resmi'],
                name: data['urun_adi'],
                quantity: data['urun_adet'],
                percentage: data.containsKey('yuzdelik') ? data['yuzdelik'] : null,
                category: categoryIndex,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}


class ProductCard extends StatefulWidget {
  final String id;
  final String imageUrl;
  final String name;
  final int quantity;
  final int? percentage;
  final int category;

  ProductCard({
    required this.id,
    required this.imageUrl,
    required this.name,
    required this.quantity,
    required this.category,
    this.percentage,
  });

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  void updateQuantity(String id, int quantity) {
    FirebaseFirestore.instance.collection('evdeki_malzemeler').doc(id).update({
      'urun_adet': quantity,
    });
  }

  void updatePercentage(String id, int percentage) {
    FirebaseFirestore.instance.collection('evdeki_malzemeler').doc(id).update({
      'yuzdelik': percentage,
    });
  }

  void deleteProduct(String id, String imageUrl) async {
    // Firebase Storage'dan resmi silme
    FirebaseStorage storage = FirebaseStorage.instance;
    Reference ref = storage.refFromURL(imageUrl);
    await ref.delete();

    // Firestore'dan ürünü silme
    await FirebaseFirestore.instance.collection('evdeki_malzemeler').doc(id).delete();
  }

  void _showEditPercentageDialog() {
    TextEditingController controller = TextEditingController();
    if (widget.percentage != null) {
      controller.text = widget.percentage.toString();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Yüzdelik Güncelle'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Yüzdelik (%)'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                int percentage = int.parse(controller.text);
                updatePercentage(widget.id, percentage);
                Navigator.of(context).pop();
              },
              child: Text('Güncelle'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Card(
      margin: EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            FadeInImage.assetNetwork(
              placeholder: 'assets/loading.gif', // Yükleniyor simgesi için bir gif veya resim ekleyin
              image: widget.imageUrl,
              height: 150,
              fit: BoxFit.cover,
              imageErrorBuilder: (context, error, stackTrace) {
                return Center(child: Text('Resim yüklenemedi.'));
              },
              placeholderErrorBuilder: (context, error, stackTrace) {
                return Center(child: CircularProgressIndicator());
              },
            ),
            SizedBox(height: 10),
            Text(widget.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    if (widget.quantity > 0) {
                      updateQuantity(widget.id, widget.quantity - 1);
                    }
                  },
                ),
                Text(widget.quantity.toString(), style: TextStyle(fontSize: 20)),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    updateQuantity(widget.id, widget.quantity + 1);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete,color: Colors.red,),
                  onPressed: () {
                    deleteProduct(widget.id, widget.imageUrl);
                  },
                ),
              ],
            ),
            if ([1,2, 3, 6].contains(widget.category))
              Column(
                children: [
                  SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (widget.percentage ?? 0) / 100.0,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Yüzdelik: ${widget.percentage ?? 0}%',style: TextStyle(fontWeight: FontWeight.w700),),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: _showEditPercentageDialog,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  File? _image;
  final picker = ImagePicker();
  int _selectedCategory = 0;

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  Future<void> _takePhoto() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  void _addProduct() async {
    if (_nameController.text.isNotEmpty && _quantityController.text.isNotEmpty && _image != null) {
      // Firebase Storage'a yükleme işlemi
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child('evdeki_malzemeler/${DateTime.now().millisecondsSinceEpoch}.jpg');
      UploadTask uploadTask = ref.putFile(_image!);

      uploadTask.then((res) async {
        String imageUrl = await res.ref.getDownloadURL();

        // Firestore'a ürün ekleme işlemi
        FirebaseFirestore.instance.collection('products').add({
          'urun_adi': _nameController.text,
          'urun_adet': int.parse(_quantityController.text),
          'urun_resmi': imageUrl, // Resmin URL'sini kaydet
          'kategori': _selectedCategory,
          'yuzdelik': 100, // Varsayılan yüzdelik değeri 100 olarak ayarlanır
        }).then((value) {
          Navigator.pop(context);
        });
      }).catchError((error) {
        // Hata durumunda yapılacak işlemler
        print("Resim yükleme hatası: $error");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ürün Ekle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Ürün Adı'),
            ),
            TextField(
              controller: _quantityController,
              decoration: InputDecoration(labelText: 'Ürün Adedi'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _selectedCategory,
              items: List.generate(
                7,
                    (index) => DropdownMenuItem(
                  child: Text(_categoryName(index)),
                  value: index,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
              decoration: InputDecoration(labelText: 'Kategori'),
            ),
            SizedBox(height: 20),
            _image == null
                ? Text('Resim seçilmedi.')
                : Image.file(_image!, height: 150),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text('Galeriden Seç'),
                ),
                ElevatedButton(
                  onPressed: _takePhoto,
                  child: Text('Fotoğraf Çek'),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addProduct,
              child: Text('Ürün Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryName(int index) {
    switch (index) {
      case 0:
        return 'Sebze Meyve';
      case 1:
        return 'Hijyen';
      case 2:
        return 'Hazır gıda';
      case 3:
        return 'İçecekler';
      case 4:
        return 'Tatlı';
      case 5:
        return 'Atıştırmalıklar';
      case 6:
      default:
        return 'Temel İhtiyaçlar';
    }
  }
}
