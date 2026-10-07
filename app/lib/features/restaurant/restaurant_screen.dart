import 'package:flutter/material.dart';

class RestaurantScreen extends StatelessWidget {
  const RestaurantScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('식당 $id')));
}
