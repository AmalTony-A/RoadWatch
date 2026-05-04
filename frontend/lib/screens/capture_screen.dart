import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/road_network_item.dart';
import '../providers/app_state.dart';
import '../widgets/road_score_gauge.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _selectedDemoAsset;
  bool _busy = false;
  String _selectedDistrict = 'ALL';
  String _roadSearchQuery = '';
  bool _autoDistrictApplied = false;

  void _syncLiveDistrict(AppState state) {
    final suggested = state.liveSuggestedDistrict;
    if (suggested == null || _autoDistrictApplied) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoDistrictApplied) {
        return;
      }
      final liveRoads = state.roadsForDistrict(suggested);
      setState(() {
        _selectedDistrict = suggested;
        _roadSearchQuery = '';
        _autoDistrictApplied = true;
      });
      if (liveRoads.isNotEmpty) {
        state.selectRoadNetworkItem(liveRoads.first);
      }
    });
  }

  List<RoadNetworkItem> _filteredRoads(AppState state) {
    return state.searchRoadsForDistrict(_selectedDistrict, _roadSearchQuery);
  }

  void _selectRoad(AppState state, RoadNetworkItem road) {
    setState(() {
      _selectedDistrict = road.districts.isNotEmpty ? road.districts.first : _selectedDistrict;
      _roadSearchQuery = road.name;
      _autoDistrictApplied = true;
    });
    state.selectRoadNetworkItem(road);
  }

  Future<void> _runDetectionIfReady(AppState state) async {
    final imageBytes = _selectedImageBytes;
    if (imageBytes == null || _busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await state.runDetection(
        imageBytes: imageBytes,
        fileName: _selectedImageName ?? 'capture.jpg',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  RoadNetworkItem? _selectedRoad(AppState state) {
    final current = state.selectedRoadNetwork;
    if (current != null) {
      return current;
    }
    final filtered = _filteredRoads(state);
    return filtered.isNotEmpty ? filtered.first : null;
  }

  Future<void> _pickImage(ImageSource source) async {
    final state = context.read<AppState>();
    final file = await _picker.pickImage(source: source, imageQuality: 80);
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();

    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName = file.name.isNotEmpty ? file.name : 'capture.jpg';
      _selectedDemoAsset = null;
    });

    await _runDetectionIfReady(state);
  }

  Future<void> _runDemo(String imageId) async {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedDemoAsset = 'assets/demo/$imageId';
      _busy = true;
    });
    await context.read<AppState>().runDemoDetection(imageId);
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final detection = appState.lastDetection;
    _syncLiveDistrict(appState);
    final selectedRoad = _selectedRoad(appState);
    final filteredRoads = _filteredRoads(appState);
    final districtOptions = ['ALL', ...appState.roadNetworkDistricts];
    final analysisMessage = detection == null
      ? null
      : detection.sceneMessage ??
        (detection.detections.isEmpty
          ? 'No visible road issue detected. Please reupload a clearer road photo.'
          : 'Road issue detected.');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF102A43), Color(0xFF1D4E89)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Damage Detection',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appState.isOnline
                          ? 'Capture and detect potholes and cracks with immediate overlay feedback.'
                          : 'Offline mode: captures are queued and synced later.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose capture source',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Upload'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Road selection for detection',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDistrict,
                      decoration: InputDecoration(
                        labelText: 'District',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: districtOptions
                          .map(
                            (district) => DropdownMenuItem<String>(
                              value: district,
                              child: Text(district == 'ALL' ? 'All districts' : district),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) {
                          return;
                        }
                        final nextRoads = appState.roadsForDistrict(value);
                        setState(() {
                          _selectedDistrict = value;
                          _roadSearchQuery = '';
                          _autoDistrictApplied = true;
                        });
                        if (nextRoads.isNotEmpty) {
                          appState.selectRoadNetworkItem(nextRoads.first);
                          await _runDetectionIfReady(appState);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _roadSearchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Search road',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (appState.liveSuggestedDistrict != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConfig.safeGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppConfig.safeGreen.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    'Live location suggests ${appState.liveSuggestedDistrict}; the road list is pre-filtered for you.',
                    style: const TextStyle(color: AppConfig.deepNavy, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 12),
              if (_selectedDistrict != 'ALL' && filteredRoads.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: filteredRoads
                      .map(
                        (road) => ActionChip(
                          label: Text(road.name),
                          onPressed: () async {
                            _selectRoad(appState, road);
                            await _runDetectionIfReady(appState);
                          },
                        ),
                      )
                      .toList(),
                )
              else if (_selectedDistrict == 'ALL')
                const Text(
                  'Pick a district first to narrow the road list.',
                  style: TextStyle(color: AppConfig.skySlate),
                )
              else if (filteredRoads.isEmpty)
                const Text(
                  'No roads match your search in this district.',
                  style: TextStyle(color: AppConfig.skySlate),
                ),
              if (selectedRoad != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Selected for detection: ${selectedRoad.name}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _selectRoad(appState, selectedRoad),
                        child: const Text('Use this road'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Demo scenes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _demoCard('demo_pothole_1.svg', 'Pothole Scene'),
                    _demoCard('demo_crack_2.svg', 'Crack Scene'),
                    _demoCard('demo_good_road.svg', 'Good Road'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(minHeight: 240, maxHeight: 340),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: (_selectedImageBytes == null && _selectedDemoAsset == null)
                    ? const Center(
                        child: Text(
                          'No image selected yet.\nCapture, upload, or choose a demo scene.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFB8C8D9)),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final aspectRatio = detection != null
                                ? detection.imageWidth / detection.imageHeight
                                : 16 / 9;
                            var previewWidth = constraints.maxWidth;
                            var previewHeight = previewWidth / aspectRatio;
                            if (previewHeight > constraints.maxHeight) {
                              previewHeight = constraints.maxHeight;
                              previewWidth = previewHeight * aspectRatio;
                            }

                            return Center(
                              child: SizedBox(
                                width: previewWidth,
                                height: previewHeight,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_selectedImageBytes != null)
                                      Image.memory(
                                        _selectedImageBytes!,
                                        fit: BoxFit.fill,
                                      )
                                    else if (_selectedDemoAsset != null)
                                      SvgPicture.asset(
                                        _selectedDemoAsset!,
                                        fit: BoxFit.fill,
                                      ),
                                    if (detection != null)
                                      ...detection.detections.map((box) {
                                        final sourceWidth = detection.imageWidth.toDouble();
                                        final sourceHeight = detection.imageHeight.toDouble();
                                        final x1 = box.bbox[0] / sourceWidth * previewWidth;
                                        final y1 = box.bbox[1] / sourceHeight * previewHeight;
                                        final x2 = box.bbox[2] / sourceWidth * previewWidth;
                                        final y2 = box.bbox[3] / sourceHeight * previewHeight;
                                        final color = box.severity == 'high'
                                            ? AppConfig.dangerRed
                                            : box.severity == 'medium'
                                                ? AppConfig.cautionYellow
                                                : AppConfig.safeGreen;
                                        return Positioned(
                                          left: x1,
                                          top: y1,
                                          width: (x2 - x1).clamp(24, previewWidth).toDouble(),
                                          height: (y2 - y1).clamp(18, previewHeight).toDouble(),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(color: color, width: 2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Align(
                                              alignment: Alignment.topLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                color: color,
                                                child: Text(
                                                  '${box.label} ${box.severity}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (_busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 14),
        if (detection != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppConfig.deepNavy.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoadScoreGauge(score: detection.score.roadHealthScore, label: 'Detection Score'),
                const SizedBox(height: 12),
                Text(
                  analysisMessage ?? 'Detection complete.',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy),
                ),
                const SizedBox(height: 8),
                Text(
                  detection.sceneStatus == 'not_road'
                      ? 'Please upload a clear road photo for analysis.'
                      : detection.sceneStatus == 'no_issue'
                          ? 'No road damage was found. Reupload a clearer image if the damage is still visible.'
                          : detection.sceneStatus == 'uncertain'
                              ? 'The image is not clear enough. Please retake and upload a sharper road photo.'
                              : 'Road damage detected on the selected road.',
                  style: const TextStyle(color: AppConfig.skySlate),
                ),
                const SizedBox(height: 12),
                Text(
                  'Model: ${detection.model} | ${detection.inferenceMs} ms',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy),
                ),
                const SizedBox(height: 8),
                if (detection.sceneStatus == 'not_road')
                  const Text(
                    'This does not look like a road photo. Please upload a proper road image for analysis.',
                    style: TextStyle(color: AppConfig.dangerRed, fontWeight: FontWeight.w700),
                  )
                else if (detection.sceneStatus == 'no_issue')
                  const Text(
                    'No road issue was found. If damage is visible, reupload a clearer photo.',
                    style: TextStyle(color: AppConfig.cautionYellow, fontWeight: FontWeight.w700),
                  )
                else if (detection.detections.isEmpty)
                  const Text('No potholes or cracks detected in this image.'),
                ...detection.detections.map(
                  (box) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 10,
                            width: 10,
                            decoration: BoxDecoration(
                              color: box.severity == 'high'
                                  ? AppConfig.dangerRed
                                  : box.severity == 'medium'
                                      ? AppConfig.cautionYellow
                                      : AppConfig.safeGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${box.label.toUpperCase()} (${box.severity}) - confidence ${(box.confidence * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (detection.sceneStatus == 'issue_detected' && detection.detections.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<AppState>().fileComplaint(
                            description:
                                'AI detected ${detection.detections.length} issues with score ${detection.score.roadHealthScore}/100.',
                            imageRef: detection.imageId,
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Complaint generation triggered.')),
                      );
                    },
                    icon: const Icon(Icons.report_problem_rounded),
                    label: const Text('Generate Complaint from Detection'),
                  )
                else
                  const Text(
                    'Upload a proper road image with visible damage to generate a complaint.',
                    style: TextStyle(color: AppConfig.skySlate),
                  ),
              ],
            ),
          ),
        if (detection != null) ...[
          const SizedBox(height: 14),
        ]
      ],
    );
  }

  Widget _demoCard(String imageId, String label) {
    final selected = _selectedDemoAsset == 'assets/demo/$imageId';
    return GestureDetector(
      onTap: () => _runDemo(imageId),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: selected ? AppConfig.deepNavy : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppConfig.deepNavy : const Color(0xFFDCE4EE),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppConfig.deepNavy.withValues(alpha: selected ? 0.12 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: const Color(0xFFF8FAFC),
                    child: Center(
                      child: SvgPicture.asset('assets/demo/$imageId', fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppConfig.deepNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
