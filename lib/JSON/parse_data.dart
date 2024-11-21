import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:Ulayaw/screens/button_item.dart'; // Import the class where CategoryButtonItem is defined

// Function to load the JSON data from the assets file
Future<List<CategoryButtonItem>> loadCategoryButtonItems() async {
  // Load the JSON file as a string
  String jsonString = await rootBundle.loadString('assets/data.json');

  // Decode the JSON string into a List of dynamic objects
  List<dynamic> jsonData = jsonDecode(jsonString);

  // Convert the JSON data into a list of CategoryButtonItem objects
  return jsonData.map((json) => CategoryButtonItem.fromJson(json)).toList();
}
