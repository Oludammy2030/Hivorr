import 'package:flutter/material.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/gallery/gallery.dart';

void main() => runApp(const GalleryApp());

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hivorr Design System',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Hivorr Design System'),
          actions: <Widget>[
            IconButton(
              icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => setState(() => _dark = !_dark),
              tooltip: 'Toggle theme',
            ),
          ],
        ),
        body: const Gallery(),
      ),
    );
  }
}
