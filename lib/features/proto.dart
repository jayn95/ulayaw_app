/// main_page.dart is the core screen of the application that handles buttons,
/// tab navigation, drawer navigation, and button management features.
///
/// Key features include:
/// 1. Tab-based navigation for different button categories
/// 2. Sound playback on button press
/// 3. Button management (add/delete buttons)
/// 4. Interactive viewing with zoom and pan capabilities
/// 5. Persistent storage of button data from user added files/buttons

// Importing necessary libraries
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importing necessary dart files
import '../screens/all.dart';
import '../screens/button_item.dart';
import '../screens/category1.dart';
import '../screens/category2.dart';
import '../screens/category3.dart';
import '../JSON/parse_data.dart';

// Load data from JSON
Future<List<CategoryButtonItem>> loadCategoryButtonItems() async {
  String jsonString = await rootBundle.loadString('assets/data.json');
  List<dynamic> jsonData = jsonDecode(jsonString);
  // print("Loaded JSON: $jsonData"); // Add this print statement
  return jsonData.map((json) => CategoryButtonItem.fromJson(json)).toList();
}

class UlayawMainPage extends StatefulWidget {
  const UlayawMainPage({Key? key}) : super(key: key);

  @override
  _UlayawMainPageState createState() => _UlayawMainPageState();
}

class _UlayawMainPageState extends State<UlayawMainPage>
    with TickerProviderStateMixin {
  late Future<List<CategoryButtonItem>> _buttonsFuture;

  // Controller for tab navigation: This controls switching between different categories
  late TabController _tabController;

  // Button Management State: This tracks if user is currently deleting buttons and the IDs of the
  // buttons selected for deletion
  bool ButtonDeleteMode = false;
  List<String> selectedItemIds = [];

  // Dialog state for adding new buttons
  bool showAddNewDialog = false;

  // Audio player instance for sound playback
  AudioPlayer audioPlayer = AudioPlayer();

  // Category Management: Tracks currently selected category and active button
  String selectedCategory = 'all';
  String activeButton = '';

  // Button Data: Stores all button data and controls button press animation
  List<CategoryButtonItem> buttons = [];
  List<AnimationController> _animationControllers = [];

  // New Button Creation: Temporarili stores image and sound for new button added by user
  File? newItemImage;
  String? newItemSound;

  // Interactive viewer control for zoom and pan functionality
  final TransformationController _transformationController =
      TransformationController();
  final double _minScale = 1.0;
  final double _maxScale = 2.0;

  /// Initializes the state of the widget
  /// Sets up controllers and loads saved buttons from user
  @override
  void initState() {
    super.initState();
    _loadAddedButtons();
    _tabController = TabController(length: 4, vsync: this);
    _transformationController.addListener(_onTransformationChanged);

    // Loads data after widget is initialized
    _buttonsFuture = loadCategoryButtonItems();
  }

  // Method for lifecycle: Cleans up resources when a widget (button) is disposed
  @override
  void dispose() {
    _tabController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    // Dispose all button animation controllers
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    // Dispose audio player
    audioPlayer.dispose();
    super.dispose();
  }

  // Zoom and Pan Control: Allows the user to zoom and pan the section for the buttons
  void _onTransformationChanged() {
    // Get current scale level from transformation matrix
    final double scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale < _minScale) {
      // Reset to minimum scale if zoomed out too far. This is needed to make sure
      // that the button interface will go back to its standard size when zoomed out.
      _transformationController.value = Matrix4.identity();
      // Limit maximum zoom level
    } else if (scale > _maxScale) {
      final Matrix4 matrix = Matrix4.copy(_transformationController.value);
      matrix.scale(_maxScale / scale);
      _transformationController.value = matrix;
    }
  }

  Future<void> _loadAddedButtons() async {
    final prefs = await SharedPreferences.getInstance();
    final buttonData = prefs.getStringList('buttons') ?? [];

    setState(() {
      buttons = buttonData.isEmpty
          ? List.generate(
              12,
              (index) => CategoryButtonItem(
                id: 'placeholder_$index',
                text: 'Button ${index + 1}',
                isPlaceholder: true,
              ),
            )
          : buttonData
              .map((item) => CategoryButtonItem.fromJson(json.decode(item)))
              .toList();
    });

    _setupButtonAnimations();
  }

  void _setupButtonAnimations() {
    _animationControllers = List.generate(
      buttons.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 100),
        vsync: this,
      ),
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      buttons[index].isSelected = !buttons[index].isSelected;
    });
  }

  // Audio Playback: Plays sound if path exists and is valid
  Future<void> _playItemSound(String? soundPath) async {
    if (soundPath != null && soundPath.isNotEmpty) {
      await audioPlayer.play(DeviceFileSource(soundPath));
    }
  }

  // Button Animation: Creates animation for the button when it is pressed
  void _animateButtonPress(int index) {
    _animationControllers[index].forward().then((_) {
      _animationControllers[index].reverse();
    });
  }

  // UI Building methods
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // App bar containing the icon for drawer, add, and delete buttons
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              color: const Color(0xFF4D8FF8),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            color: const Color(0xFF4D8FF8),
            onPressed: () {
              setState(() {
                ButtonDeleteMode = false;
                selectedItemIds = [];
                // Deselect all buttons
                for (var button in buttons) {
                  button.isSelected = false;
                }
              });
            },
          ),
        ],
      ),

      // Side navigation drawer: Contains the navigation to tutorial_page.dart and about_page.dart

      body: FutureBuilder<List<CategoryButtonItem>>(
        future: _buttonsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            buttons = snapshot.data as List<CategoryButtonItem>;

            return ListView.builder(
              itemCount: buttons.length,
              itemBuilder: (context, index) {
                final button = buttons[index];
                return ListTile(
                  title: Text(button.text), // Display button label
                  subtitle: Text(button.soundPath ??
                      'No sound available'), // Display sound path
                );
              },
            );
          } else {
            return Center(child: Text('No data available.'));
          }
        },
      ),
    );
  }
}
