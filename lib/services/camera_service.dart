import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../screens/camera_screen.dart';

class CameraService {
  static final CameraService instance = CameraService._init();
  CameraService._init();

  List<CameraDescription>? _cameras;

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      print('✅ CameraService: ${_cameras?.length ?? 0} câmera(s) encontrada(s)');
    } catch (e) {
      print('⚠️ Erro ao inicializar câmera: $e');
      _cameras = [];
    }
  }

  bool get hasCameras => _cameras != null && _cameras!.isNotEmpty;

  Future<String?> takePicture(BuildContext context) async {
    if (!hasCameras) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Nenhuma câmera disponível'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    final camera = _cameras!.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      if (!context.mounted) return null;
      
      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(controller: controller),
          fullscreenDialog: true,
        ),
      );

      return imagePath;
    } catch (e) {
      print('❌ Erro ao abrir câmera: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir câmera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return null;
    } finally {
      controller.dispose();
    }
  }

  Future<String> savePicture(XFile image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'task_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savePath = path.join(appDir.path, 'images', fileName);
      
      final imageDir = Directory(path.join(appDir.path, 'images'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      
      final savedImage = await File(image.path).copy(savePath);
      print('✅ Foto salva: ${savedImage.path}');
      return savedImage.path;
    } catch (e) {
      print('❌ Erro ao salvar foto: $e');
      rethrow;
    }
  }

  Future<bool> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro ao deletar foto: $e');
      return false;
    }
  }
}
```

#### 4.2 Criar `lib/screens/camera_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';

class CameraScreen extends StatefulWidget {
  final CameraController controller;

  const CameraScreen({
    super.key,
    required this.controller,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    
    if (!widget.controller.value.isInitialized) {
      widget.controller.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _takePicture() async {
    if (_isCapturing || !widget.controller.value.isInitialized) return;

    setState(() => _isCapturing = true);

    try {
      final image = await widget.controller.takePicture();
      final savedPath = await CameraService.instance.savePicture(image);
      
      if (mounted) {
        Navigator.pop(context, savedPath);
      }
    } catch (e) {
      print('❌ Erro ao capturar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: CameraPreview(widget.controller)),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _isCapturing 
                        ? null 
                        : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    ),

                    GestureDetector(
                      onTap: _isCapturing ? null : _takePicture,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _isCapturing 
                            ? Colors.grey.withOpacity(0.5)
                            : Colors.transparent,
                        ),
                        child: _isCapturing
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.camera, color: Colors.white, size: 40),
                      ),
                    ),

                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}