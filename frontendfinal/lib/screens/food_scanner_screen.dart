import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  XFile? _imageFile;
  Uint8List? _imageBytes;

  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (!mounted) return;

      setState(() {
        _imageFile = picked;
        _imageBytes = bytes;
        _analysisResult = null;
      });

      await _analyzeImage(picked, bytes);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not select image: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _analyzeImage(
    XFile image,
    Uint8List bytes,
  ) async {
    if (!mounted) return;

    setState(() => _isAnalyzing = true);

    try {
      // IMPORTANT:
      // Do not use image.path on Flutter Web.
      // The ApiClient method must upload bytes, not File.fromPath().
      final res = await ApiClient.uploadFoodImageBytes(
        '/food-logs/scan',
        bytes,
        filename: image.name.isNotEmpty ? image.name : 'food.jpg',
      );

      if (!mounted) return;

      final result = res['analysis'] ?? res['log'];

      if (result is Map<String, dynamic>) {
        setState(() {
          _analysisResult = result;
        });
      } else {
        throw Exception('Server returned no meal analysis.');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recognition failed: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Widget _buildImagePreview() {
    if (_imageBytes == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF5EBE1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 44,
              color: Color(0xFF8D4F28),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Snap a photo of Teff Injera, Shiro, or Kinche',
            style: TextStyle(
              color: Color(0xFF78716C),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // Image.memory works on Android, Windows, Web, etc.
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: Image.memory(
        _imageBytes!,
        width: double.infinity,
        height: 230,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA),
      appBar: AppBar(
        title: const Text(
          'AI Food Photo Recognition',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17.5,
          ),
        ),
        backgroundColor: const Color(0xFF542E13),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 230,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFEADBCE),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF542E13).withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildImagePreview(),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Camera',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF542E13),
                      side: const BorderSide(
                        color: Color(0xFFEADBCE),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(
                      Icons.photo_library_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Gallery',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF542E13),
                      side: const BorderSide(
                        color: Color(0xFFEADBCE),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_isAnalyzing)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEADBCE),
                    ),
                  ),
                  child: const Column(
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF542E13),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Identifying Ethiopian dish...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF542E13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_analysisResult != null) ...[
              const SizedBox(height: 20),
              _buildAnalysisResult(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResult() {
    final result = _analysisResult!;

    final foodName =
        result['foodName']?.toString() ?? 'Identified Meal';

    final calories = result['calories'] ?? 0;
    final protein = result['proteinGrams'] ?? 0;
    final carbs = result['carbsGrams'] ?? 0;
    final fats = result['fatsGrams'] ?? 0;

    final aiUnavailable =
        result['aiUnavailable'] == true ||
        foodName == 'Food could not be identified';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEADBCE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    foodName,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF542E13),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EBE1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    aiUnavailable ? 'Unavailable' : 'AI Match',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8D4F28),
                    ),
                  ),
                ),
              ],
            ),

            const Divider(
              height: 22,
              color: Color(0xFFEFE8DF),
            ),

            if (aiUnavailable)
              Text(
                result['description']?.toString() ??
                    'The AI service could not analyze this image.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF78716C),
                ),
              )
            else ...[
              Text(
                'Calories: $calories kcal',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Protein: ${protein}g  •  '
                'Carbs: ${carbs}g  •  '
                'Fats: ${fats}g',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF78716C),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
