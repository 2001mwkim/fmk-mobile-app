import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const ListTile(
                leading: Icon(Icons.info_outline, color: AppColors.red),
                title: Text('포매코'),
                subtitle: Text('앱 설정 항목이 추가될 예정입니다.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
