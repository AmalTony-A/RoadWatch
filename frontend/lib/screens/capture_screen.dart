import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/road_network_item.dart';
import '../providers/app_state.dart';
import '../widgets/hover_road_chip.dart';
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
  String? _selectedRoadKey;
  bool _busy = false;
  String _selectedDistrict = 'ALL';
  String _roadSearchQuery = '';
  bool _autoDistrictApplied = false;
  int _visibleRoadCount = 10;

  String _roadUniqueKey(RoadNetworkItem road) {
    final id = road.id.trim();
    if (id.isNotEmpty) {
      return '${id}_${road.name.trim()}';
    }
    return '${road.name.trim()}_${road.route.trim()}_${road.districts.join('|')}';
  }

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
        _selectedRoadKey = liveRoads.isNotEmpty ? _roadUniqueKey(liveRoads.first) : null;
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
      _selectedRoadKey = _roadUniqueKey(road);
      _autoDistrictApplied = true;
    });
    state.selectRoadNetworkItem(road);
  }

  RoadNetworkItem? _selectedRoad(AppState appState) {
    final key = _selectedRoadKey;
    if (key != null) {
      return appState.networkRoadByUniqueKey(key);
    }
    return appState.selectedRoadNetwork;
  }

  Future<void> _pickImage(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, maxWidth: 2048);
    if (xfile == null) return;
    if (!mounted) return;
    final bytes = await xfile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName = xfile.name;
    });
    await _runDetectionIfReady(context.read<AppState>());
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final detection = appState.lastDetection;
    _syncLiveDistrict(appState);
    final selectedRoad = _selectedRoad(appState);
    final filteredRoads = _filteredRoads(appState);
    final districtOptions = <String>{'ALL', ...appState.roadNetworkDistricts, _selectedDistrict}
      .where((value) => value.trim().isNotEmpty)
      .toList()
      ..sort();
    final analysisMessage = detection == null
      ? null
      : detection.message.isNotEmpty
          ? detection.message
          : detection.sceneMessage ?? 'Detection complete.';

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
                      initialValue: _selectedDistrict,
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
                        if (value == null) return;
                        // Update UI selection immediately so the district appears
                        // selected while we fetch roads for it.
                        setState(() {
                          _selectedDistrict = value;
                          _roadSearchQuery = '';
                          _selectedRoadKey = null;
                          _autoDistrictApplied = true;
                          _visibleRoadCount = 10;
                        });

                        final nextRoads = await appState.loadRoadsForDistrict(value);
                        setState(() {
                          _selectedRoadKey = nextRoads.isNotEmpty ? _roadUniqueKey(nextRoads.first) : _selectedRoadKey;
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
                    'Live location suggests ${appState.liveSuggestedDistrict}; the road list is filtered for that district.',
                    style: const TextStyle(color: AppConfig.deepNavy, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 12),
              if (_selectedDistrict == 'ALL' && appState.liveSuggestedDistrict == null)
                const Text(
                  'Select district to load roads for this area.',
                  style: TextStyle(color: AppConfig.skySlate),
                ),
              const SizedBox(height: 12),
              if (appState.isLoadingRoadsForDistrict(_selectedDistrict))
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filteredRoads.isEmpty)
                const Text(
                  'Select a district to load roads.',
                  style: TextStyle(color: AppConfig.skySlate),
                )
                else
                LayoutBuilder(builder: (context, constraints) {
                  final spacing = 12.0;
                  final columns = constraints.maxWidth > 700 ? 2 : 1;
                  final selectedKey = _selectedRoadKey ?? (selectedRoad != null ? _roadUniqueKey(selectedRoad) : null);
                  final visibleRoads = filteredRoads.take(_visibleRoadCount).toList(growable: false);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: 8.8,
                    ),
                    itemCount: visibleRoads.length,
                    itemBuilder: (context, idx) {
                      final road = visibleRoads[idx];
                      return HoverRoadChip(
                        label: road.name,
                        selected: selectedKey == _roadUniqueKey(road),
                        onTap: () {
                          _selectRoad(appState, road);
                          _runDetectionIfReady(appState);
                        },
                        borderRadius: BorderRadius.circular(999),
                      );
                    },
                  );
                }),
              if (filteredRoads.length > _visibleRoadCount || appState.hasMoreRoadsForDistrict(_selectedDistrict))
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      if (_selectedDistrict != 'ALL') {
                        await appState.loadMoreRoadsForDistrict(_selectedDistrict);
                      }
                      setState(() {
                        _visibleRoadCount += 10;
                      });
                    },
                    icon: const Icon(Icons.expand_more_rounded),
                    label: const Text('Show More'),
                  ),
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
                child: _selectedImageBytes == null
                    ? const Center(
                        child: Text(
                          'No image selected yet.\nCapture or upload a real road image.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFB8C8D9)),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final imageWidth = detection?.imageWidth.toDouble() ?? 0;
                            final imageHeight = detection?.imageHeight.toDouble() ?? 0;
                            final aspectRatio = (imageWidth.isFinite &&
                                    imageHeight.isFinite &&
                                    imageWidth > 0 &&
                                    imageHeight > 0)
                                ? imageWidth / imageHeight
                                : 16 / 9;
                            final safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 16 / 9;

                            final maxWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                                ? constraints.maxWidth
                                : 320.0;
                            final maxHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0
                                ? constraints.maxHeight
                                : 240.0;

                            var previewWidth = maxWidth;
                            var previewHeight = previewWidth / safeAspectRatio;
                            if (!previewHeight.isFinite || previewHeight <= 0) {
                              previewHeight = maxHeight;
                              previewWidth = previewHeight * safeAspectRatio;
                            } else if (previewHeight > maxHeight) {
                              previewHeight = maxHeight;
                              previewWidth = previewHeight * safeAspectRatio;
                            }

                            if (!previewWidth.isFinite || previewWidth <= 0) {
                              previewWidth = maxWidth;
                            }
                            if (!previewHeight.isFinite || previewHeight <= 0) {
                              previewHeight = maxHeight;
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
                                    else
                                      const ColoredBox(color: Color(0xFF0D1B2A)),
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
                  detection.detected
                      ? '${detection.damageType ?? 'Road damage'} detected with ${detection.confidence}% confidence.'
                      : 'No damage detected.',
                  style: const TextStyle(color: AppConfig.skySlate),
                ),
                const SizedBox(height: 12),
                Text(
                  'Model: ${detection.model} | ${detection.inferenceMs} ms',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy),
                ),
                const SizedBox(height: 8),
                Text(
                  detection.explanation.isNotEmpty ? detection.explanation : detection.message,
                  style: const TextStyle(color: AppConfig.skySlate),
                ),
                const SizedBox(height: 8),
                if (detection.detected)
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<AppState>().fileComplaint(
                            description:
                                'AI detected ${detection.damageType ?? 'road damage'} with ${detection.confidence}% confidence.',
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
                    'Upload a real road image with visible damage to generate a complaint.',
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

  // _demoCard removed (unused)
}
