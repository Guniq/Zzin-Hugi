import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('프로필 $uid')));
}
