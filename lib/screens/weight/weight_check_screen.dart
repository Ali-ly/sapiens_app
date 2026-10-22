import 'package:flutter/material.dart';

import '../../models/selected_image.dart';
import '../../services/api_service.dart';
import '../../services/feed_service.dart';
import '../../services/image_service.dart';

class WeightCheckScreen extends StatefulWidget {
  const WeightCheckScreen({super.key});

  @override
  State<WeightCheckScreen> createState() => _WeightCheckScreenState();
}

class _WeightCheckScreenState extends State<WeightCheckScreen> {
  final ImageService _imageService = ImageService();

  final List<SelectedImage> _selectedImages = [];

  bool _isPredictingWeight = false;
  bool _isCalculatingFeed = false;

  bool get _isBusy => _isPredictingWeight || _isCalculatingFeed;

  double? _estimatedWeight;
  double? _predictionSpread;

  int _numValidImages = 0;

  List<dynamic> _rejectedFiles = [];

  String? _weightError;
  String? _feedError;

  // ============================================================
  // FEED
  // ============================================================

  String _selectedTarget = 'pemeliharaan';

  bool _rumputSelected = true;
  bool _jeramiSelected = false;
  bool _dedakSelected = false;

  Map<String, dynamic>? _feedResult;

  final List<Map<String, String>> _targets = [
    {
      'value': 'pemeliharaan',
      'label': 'Pemeliharaan',
    },
    {
      'value': 'pertumbuhan',
      'label': 'Pertumbuhan',
    },
    {
      'value': 'penggemukan',
      'label': 'Penggemukan',
    },
  ];

  // ============================================================
  // IMAGE PICKER
  // ============================================================

  Future<void> _pickImages() async {
    try {
      final images = await _imageService.pickImages();

      if (images.isEmpty) {
        return;
      }

      final remainingSlots = 4 - _selectedImages.length;

      if (remainingSlots <= 0) {
        _showMessage('Maksimal 4 foto sapi.');
        return;
      }

      final newImages = images.take(remainingSlots).toList();
      if (!mounted) return;

      setState(() {
        _selectedImages.addAll(newImages);

        _estimatedWeight = null;
        _predictionSpread = null;
        _numValidImages = 0;
        _rejectedFiles = [];

        _feedResult = null;

        _weightError = null;
        _feedError = null;
      });

      if (images.length > remainingSlots) {
        _showMessage(
          'Maksimal 4 foto. Hanya $remainingSlots foto yang ditambahkan.',
        );
      }
    } catch (e) {
      _showMessage('Gagal memilih foto: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);

      _estimatedWeight = null;
      _predictionSpread = null;
      _numValidImages = 0;
      _rejectedFiles = [];

      _feedResult = null;

      _weightError = null;
      _feedError = null;
    });
  }

  void _clearImages() {
    setState(() {
      _selectedImages.clear();

      _estimatedWeight = null;
      _predictionSpread = null;
      _numValidImages = 0;
      _rejectedFiles = [];

      _feedResult = null;

      _weightError = null;
      _feedError = null;
    });
  }

  // ============================================================
  // WEIGHT PREDICTION
  // ============================================================

  Future<void> _predictWeight() async {
    if (_selectedImages.isEmpty) {
      _showMessage('Pilih minimal 1 foto sapi.');
      return;
    }

    setState(() {
      _isPredictingWeight = true;

      _weightError = null;

      _estimatedWeight = null;
      _predictionSpread = null;
      _numValidImages = 0;
      _rejectedFiles = [];

      _feedResult = null;
      _feedError = null;
    });

    try {
      final data = await ApiService.predictWeight(_selectedImages);
      if (!mounted) return;

      final estimatedWeight = data['estimated_weight_kg'];

      final predictionSpread = data['prediction_spread_kg'];

      setState(() {
        _estimatedWeight = estimatedWeight == null
            ? null
            : (estimatedWeight as num).toDouble();

        _predictionSpread =
            predictionSpread == null ? 0 : (predictionSpread as num).toDouble();

        _numValidImages = (data['num_valid_images'] as num?)?.toInt() ?? 0;

        _rejectedFiles = List<dynamic>.from(
          data['rejected_files'] ?? [],
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weightError = 'Tidak dapat terhubung ke Weight API.\n\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPredictingWeight = false;
        });
      }
    }
  }

  // ============================================================
  // FEED CALCULATOR
  // ============================================================

  List<String> _getAvailableFeeds() {
    final feeds = <String>[];

    if (_rumputSelected) {
      feeds.add('rumput');
    }

    if (_jeramiSelected) {
      feeds.add('jerami');
    }

    if (_dedakSelected) {
      feeds.add('dedak');
    }

    return feeds;
  }

  Future<void> _calculateFeed() async {
    if (_estimatedWeight == null) {
      _showMessage(
        'Estimasi berat sapi terlebih dahulu.',
      );
      return;
    }

    final feeds = _getAvailableFeeds();

    if (feeds.isEmpty) {
      _showMessage(
        'Pilih minimal satu jenis pakan.',
      );
      return;
    }

    setState(() {
      _isCalculatingFeed = true;
      _feedError = null;
      _feedResult = null;
    });

    try {
      final result = await FeedService.calculateFeed(
        weight: _estimatedWeight!,
        target: _selectedTarget,
        availableFeeds: feeds,
      );

      if (!mounted) return;
      setState(() {
        _feedResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring(
          'Exception: '.length,
        );
      }

      setState(() {
        _feedError = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingFeed = false;
        });
      }
    }
  }

  // ============================================================
  // HELPER
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) {
      return text;
    }

    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SAPITA',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 850,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIntroduction(),
                  const SizedBox(height: 24),
                  _buildPhotoSection(),
                  const SizedBox(height: 24),
                  if (_estimatedWeight != null) ...[
                    _buildWeightResult(),
                    const SizedBox(height: 24),
                    _buildFeedSection(),
                  ],
                  if (_weightError != null) ...[
                    const SizedBox(height: 20),
                    _buildErrorCard(
                      _weightError!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroduction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estimasi Berat Sapi',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Unggah 1–4 foto sapi. Untuk hasil yang lebih baik, gunakan 3–4 foto dengan sudut pengambilan yang berbeda.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Colors.black.withOpacity(0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Foto Sapi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_selectedImages.length}/4',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedImages.isEmpty)
            _buildEmptyPhotoBox()
          else
            _buildImageGrid(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isBusy || _selectedImages.length >= 4)
                      ? null
                      : _pickImages,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                  ),
                  label: const Text(
                    'Pilih Foto',
                  ),
                ),
              ),
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _isBusy ? null : _clearImages,
                  child: const Text(
                    'Hapus Semua',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isBusy ? null : _predictWeight,
              icon: _isPredictingWeight
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.monitor_weight_outlined,
                    ),
              label: Text(
                _isPredictingWeight ? 'Mengestimasi...' : 'Estimasi Berat',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPhotoBox() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withOpacity(0.1),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 48,
              color: Colors.black.withOpacity(0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada foto sapi',
              style: TextStyle(
                color: Colors.black.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _selectedImages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemBuilder: (context, index) {
        final selectedImage = _selectedImages[index];

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                selectedImage.bytes,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withOpacity(0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isBusy
                        ? null
                        : () {
                            _removeImage(index);
                          },
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeightResult() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              SizedBox(width: 10),
              Text(
                'Hasil Estimasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  '${_estimatedWeight!.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Estimasi berat sapi',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          _infoRow(
            'Foto valid',
            '$_numValidImages dari ${_selectedImages.length}',
          ),
          if (_predictionSpread != null)
            _infoRow(
              'Prediction spread',
              '${_predictionSpread!.toStringAsFixed(1)} kg',
            ),
          if (_rejectedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_rejectedFiles.length} foto tidak digunakan karena objek sapi tidak terdeteksi atau file tidak dapat diproses.',
                style: const TextStyle(
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Hasil ini merupakan estimasi AI dan bukan pengukuran timbangan langsung.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.black.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Rekomendasi Pakan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rekomendasi dihitung berdasarkan berat estimasi, target pemeliharaan, dan pakan yang tersedia.',
            style: TextStyle(
              height: 1.4,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Target',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTarget,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: _targets.map((target) {
              return DropdownMenuItem<String>(
                value: target['value'],
                child: Text(
                  target['label']!,
                ),
              );
            }).toList(),
            onChanged: _isBusy
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _selectedTarget = value;
                      _feedResult = null;
                      _feedError = null;
                    });
                  },
          ),
          const SizedBox(height: 24),
          const Text(
            'Pakan yang tersedia',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rumput hijauan'),
            value: _rumputSelected,
            onChanged: _isBusy
                ? null
                : (value) {
                    setState(() {
                      _rumputSelected = value ?? false;
                      _feedResult = null;
                      _feedError = null;
                    });
                  },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Jerami padi'),
            value: _jeramiSelected,
            onChanged: _isBusy
                ? null
                : (value) {
                    setState(() {
                      _jeramiSelected = value ?? false;
                      _feedResult = null;
                      _feedError = null;
                    });
                  },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dedak padi'),
            value: _dedakSelected,
            onChanged: _isBusy
                ? null
                : (value) {
                    setState(() {
                      _dedakSelected = value ?? false;
                      _feedResult = null;
                      _feedError = null;
                    });
                  },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isBusy ? null : _calculateFeed,
              icon: _isCalculatingFeed
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.grass),
              label: Text(
                _isCalculatingFeed
                    ? 'Menghitung...'
                    : 'Hitung Rekomendasi Pakan',
              ),
            ),
          ),
          if (_feedError != null) ...[
            const SizedBox(height: 18),
            _buildErrorCard(
              _feedError!,
            ),
          ],
          if (_feedResult != null) ...[
            const SizedBox(height: 24),
            _buildFeedResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedResult() {
    final result = _feedResult!;

    final dynamic feeds =
        result['recommendation'] ?? result['feeds'] ?? result['feed_amounts'];

    final warning = result['warning'];
    final notes = result['notes'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          'Hasil Rekomendasi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _infoRow(
          'Berat sapi',
          '${_estimatedWeight!.toStringAsFixed(1)} kg',
        ),
        _infoRow(
          'Target',
          _capitalize(_selectedTarget),
        ),
        if (result['total_dry_matter_kg'] != null)
          _infoRow(
            'Total bahan kering',
            '${result['total_dry_matter_kg']} kg/hari',
          ),
        if (feeds is Map)
          ...feeds.entries.map(
            (entry) => _buildFeedItem(
              entry.key.toString(),
              entry.value,
            ),
          ),
        if (warning != null && warning.toString().trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _messageBox(
            icon: Icons.warning_amber_rounded,
            title: 'Perhatian',
            message: warning.toString(),
          ),
        ],
        if (notes != null) ...[
          const SizedBox(height: 16),
          _buildNotes(notes),
        ],
      ],
    );
  }

  Widget _buildFeedItem(
    String feedName,
    dynamic value,
  ) {
    String amountText = '';
    String? ratioText;

    if (value is Map) {
      final asFed =
          value['as_fed_kg'] ?? value['as_fed'] ?? value['kg_per_day'];

      final ratio = value['ratio_dm'] ?? value['ratio'] ?? value['dm_ratio'];

      if (asFed != null) {
        amountText = '$asFed kg/hari';
      } else {
        amountText = value.toString();
      }

      if (ratio != null) {
        double? ratioNumber;

        if (ratio is num) {
          ratioNumber = ratio.toDouble();
        }

        if (ratioNumber != null) {
          final percentage = ratioNumber <= 1 ? ratioNumber * 100 : ratioNumber;

          ratioText = '${percentage.toStringAsFixed(0)}% bahan kering';
        }
      }
    } else {
      amountText = value.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            child: Icon(Icons.grass),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _capitalize(feedName),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (ratioText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    ratioText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            amountText,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes(dynamic notes) {
    List<String> noteList = [];

    if (notes is List) {
      noteList = notes
          .map(
            (item) => item.toString(),
          )
          .toList();
    } else {
      noteList = [
        notes.toString(),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Catatan',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...noteList.map(
            (note) => Padding(
              padding: const EdgeInsets.only(
                bottom: 6,
              ),
              child: Text(
                '• $note',
                style: const TextStyle(
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBox({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(
    String message,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withOpacity(0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
