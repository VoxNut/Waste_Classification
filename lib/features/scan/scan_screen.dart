import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/data/local/local_image_store.dart';
import 'package:waste_classification/data/local/scan_repository.dart';
import 'package:waste_classification/data/models/scan_result.dart';
import 'package:waste_classification/features/result/result_screen.dart';
import 'package:waste_classification/features/scan/scan_frame_geometry.dart';
import 'package:waste_classification/services/classifier/classifier_providers.dart';
import 'package:waste_classification/services/classifier/waste_classifier_service.dart';
import 'package:waste_classification/services/image/camera_frame_cropper.dart';
import 'package:waste_classification/services/permission/camera_permission_service.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraPermissionState? _permissionState;
  _ScanViewState _state = _ScanViewState.initializing;
  String? _errorKey;
  bool _initializing = false;
  bool _torchEnabled = false;
  final GlobalKey _cameraPreviewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeController();
    } else if (state == AppLifecycleState.resumed &&
        _state != _ScanViewState.analyzing) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_initializing) return;
    _initializing = true;
    if (mounted) {
      setState(() {
        _state = _ScanViewState.initializing;
        _errorKey = null;
      });
    }

    try {
      final permission = await cameraPermissionService.request();
      _permissionState = permission;
      if (permission != CameraPermissionState.granted) {
        if (mounted) {
          setState(() => _state = _ScanViewState.permissionDenied);
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('camera_not_found', 'No camera found');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _controller?.dispose();
      setState(() {
        _controller = controller;
        _state = _ScanViewState.ready;
      });
    } on CameraException {
      if (mounted) {
        setState(() {
          _state = _ScanViewState.error;
          _errorKey = 'scan.camera_error';
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _state = _ScanViewState.error;
          _errorKey = 'scan.camera_error';
        });
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) await controller.dispose();
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final next = !_torchEnabled;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchEnabled = next);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('scan.torch_unavailable'.tr())));
      }
    }
  }

  Future<void> _captureAndClassify() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _state == _ScanViewState.analyzing) {
      return;
    }

    File? storedImage;
    File? croppedCapture;
    ui.Image? previewImage;
    try {
      final preview = _cameraPreviewKey.currentContext?.findRenderObject();
      if (preview is! RenderRepaintBoundary || !preview.hasSize) {
        throw StateError('Camera preview is not available.');
      }
      final viewportSize = preview.size;
      final frameRect = ScanFrameGeometry.frameFor(viewportSize).outerRect;
      final pixelRatio = View.of(context).devicePixelRatio;
      setState(() => _state = _ScanViewState.analyzing);
      previewImage = await preview.toImage(pixelRatio: pixelRatio);
      croppedCapture = await cameraFrameCropper.cropPreview(
        image: previewImage,
        viewportSize: viewportSize,
        frameRect: frameRect,
      );
      if (_torchEnabled) {
        await controller.setFlashMode(FlashMode.off);
        _torchEnabled = false;
      }
      storedImage = await localImageStore.persist(croppedCapture.path);
      final classification = await ref
          .read(classifierServiceProvider)
          .classify(storedImage);
      final scan = ScanResult(
        id: const Uuid().v4(),
        imagePath: storedImage.path,
        scannedAt: DateTime.now(),
        categoryId: classification.categoryId,
        modelLabel: classification.modelLabel,
        confidence: classification.confidence,
      );
      await scanRepository.insert(scan);

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ResultScreen(scanResult: scan, classification: classification),
        ),
      );
    } on ClassificationException catch (error) {
      if (storedImage != null) {
        await localImageStore.deleteIfExists(storedImage);
      }
      if (mounted) {
        setState(() {
          _state = _ScanViewState.error;
          _errorKey = switch (error.code) {
            ClassificationErrorCode.noConnection => 'errors.no_connection',
            ClassificationErrorCode.timeout => 'errors.timeout',
            ClassificationErrorCode.invalidResponse =>
              'errors.invalid_response',
            ClassificationErrorCode.unavailable => 'errors.model_unavailable',
          };
        });
      }
    } on Object {
      if (storedImage != null) {
        await localImageStore.deleteIfExists(storedImage);
      }
      if (mounted) {
        setState(() {
          _state = _ScanViewState.error;
          _errorKey = 'errors.model_unavailable';
        });
      }
    } finally {
      previewImage?.dispose();
      await _deleteTemporaryFile(croppedCapture);
    }
  }

  Future<void> _deleteTemporaryFile(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Cleanup failure must not replace the classification result or error.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _ScanViewState.permissionDenied) {
      return _PermissionDeniedView(
        permanentlyDenied:
            _permissionState == CameraPermissionState.permanentlyDenied,
        onRetry: _initializeCamera,
        onOpenSettings: cameraPermissionService.openSettings,
      );
    }
    if (_state == _ScanViewState.error) {
      return _ScanErrorView(
        messageKey: _errorKey ?? 'errors.model_unavailable',
        onRetry: _initializeCamera,
      );
    }

    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            RepaintBoundary(
              key: _cameraPreviewKey,
              child: _CoverCameraPreview(controller: controller),
            )
          else
            const ColoredBox(
              color: Color(0xFF101713),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_state == _ScanViewState.ready) ...[
            const _CameraShade(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CameraIconButton(
                          tooltip: 'common.back'.tr(),
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        _CameraIconButton(
                          tooltip: 'scan.torch'.tr(),
                          icon: _torchEnabled
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          onPressed: _toggleTorch,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'scan.instruction'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: const [Shadow(blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _CaptureButton(onPressed: _captureAndClassify),
                    const SizedBox(height: 12),
                    Text(
                      'scan.capture'.tr(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_state == _ScanViewState.analyzing) const _AnalyzingOverlay(),
        ],
      ),
    );
  }
}

enum _ScanViewState { initializing, permissionDenied, ready, analyzing, error }

class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _CameraShade extends StatelessWidget {
  const _CameraShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _CameraShadePainter()));
  }
}

class _CameraShadePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frame = ScanFrameGeometry.frameFor(size);
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(frame)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = AppColors.cameraOverlay);
    canvas.drawRRect(
      frame,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'scan.capture'.tr(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraIconButton extends StatelessWidget {
  const _CameraIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.42),
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xD91B2821),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
              const SizedBox(height: 20),
              Text(
                'scan.analyzing'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'scan.analyzing_hint'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.permanentlyDenied,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool permanentlyDenied;
  final VoidCallback onRetry;
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _CenteredState(
        icon: Icons.no_photography_outlined,
        title: 'permissions.camera_title'.tr(),
        message: 'permissions.camera_description'.tr(),
        buttonLabel:
            (permanentlyDenied
                    ? 'permissions.open_settings'
                    : 'permissions.try_again')
                .tr(),
        onPressed: permanentlyDenied
            ? () {
                onOpenSettings();
              }
            : onRetry,
      ),
    );
  }
}

class _ScanErrorView extends StatelessWidget {
  const _ScanErrorView({required this.messageKey, required this.onRetry});

  final String messageKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _CenteredState(
        icon: Icons.center_focus_weak_rounded,
        title: 'errors.title'.tr(),
        message: messageKey.tr(),
        buttonLabel: 'common.try_again'.tr(),
        onPressed: onRetry,
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.errorText),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 26),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
