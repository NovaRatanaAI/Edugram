import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edugram/providers/user_provider.dart';
import 'package:edugram/resources/firestore_methods.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/utils/utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

// ignore_for_file: library_private_types_in_public_api
class AddPostScreen extends StatefulWidget {
  const AddPostScreen({Key? key}) : super(key: key);

  @override
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen>
    with TickerProviderStateMixin {
  Uint8List? _file;
  List<Uint8List> _postFiles = const [];
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _storyTextController = TextEditingController();
  final FocusNode _storyTextFocus = FocusNode();
  bool isLoading = false;
  bool _isEditingDetails = false;
  int _selectedModeIndex = 0;
  bool _isGalleryLoading = true;
  bool _galleryPermissionDenied = false;
  String? _galleryError;
  AssetEntity? _selectedAsset;
  String? _selectedAssetId;
  int _editorPreviewPage = 0;
  bool _isMultiSelect = false;
  bool _isGalleryLimited = false;
  bool _isDraggingStoryText = false;
  double _storyTextX = 0.5;
  double _storyTextY = 0.45;
  final List<AssetEntity> _galleryAssets = [];
  final List<AssetEntity> _selectedAssets = [];
  final Map<String, Future<Uint8List?>> _previewThumbnailFutures = {};
  final Map<String, Future<Uint8List?>> _gridThumbnailFutures = {};
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late AnimationController _storyCaretController;
  late Animation<double> _storyCaretOpacity;

  bool get _isStoryMode => _selectedModeIndex == 1;
  String get _pickerTitle => _isStoryMode ? 'New Story' : 'New Post';
  String get _nextLabel => _isStoryMode ? 'Share' : 'Next';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _storyCaretController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _storyCaretOpacity = Tween<double>(begin: 0.15, end: 1).animate(
      CurvedAnimation(parent: _storyCaretController, curve: Curves.easeInOut),
    );
    _storyTextFocus.addListener(_handleStoryTextFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGalleryAssets();
    });
  }

  @override
  void dispose() {
    _storyTextFocus.removeListener(_handleStoryTextFocusChange);
    _descriptionController.dispose();
    _storyTextController.dispose();
    _storyTextFocus.dispose();
    _animController.dispose();
    _storyCaretController.dispose();
    super.dispose();
  }

  void _handleStoryTextFocusChange() {
    if (_storyTextFocus.hasFocus) {
      _storyCaretController.repeat(reverse: true);
    } else {
      _storyCaretController.stop();
      _storyCaretController.value = 0;
    }
    if (mounted) setState(() {});
  }

  Future<void> postImage(String uid, String username, String profImage) async {
    if (isLoading || _file == null) return;
    final postFiles = _postFiles.isNotEmpty ? _postFiles : <Uint8List>[_file!];
    final description = _descriptionController.text;
    final uploadFiles = List<Uint8List>.from(postFiles);
    final uploadFuture = _uploadPostInBackground(
      description: description,
      files: uploadFiles,
      uid: uid,
      username: username,
      profImage: profImage,
    );
    Navigator.of(context).pop({
      'kind': 'post',
      'status': uploadFuture,
    });
  }

  Future<bool> _uploadPostInBackground({
    required String description,
    required List<Uint8List> files,
    required String uid,
    required String username,
    required String profImage,
  }) async {
    if (files.isEmpty) return false;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final res = await FirestoreMethods().uploadPost(
          description,
          files.first,
          uid,
          username,
          profImage,
          files: files,
          useLocalFallback: false,
        );
        if (res == 'firebase_success') return true;
        debugPrint('Post upload attempt $attempt failed: $res');
      } catch (err) {
        debugPrint('Post upload attempt $attempt failed: $err');
      }
      if (attempt == 1) {
        await Future<void>.delayed(const Duration(milliseconds: 850));
      }
    }
    return false;
  }

  Future<void> _loadGalleryAssets() async {
    try {
      if (kIsWeb) {
        setState(() {
          _isGalleryLoading = false;
          _galleryPermissionDenied = true;
          _galleryError = 'Gallery grid is only available on mobile.';
        });
        return;
      }

      setState(() {
        _isGalleryLoading = true;
        _galleryPermissionDenied = false;
        _galleryError = null;
      });

      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );
      if (!mounted) return;
      if (!permission.hasAccess) {
        setState(() {
          _isGalleryLoading = false;
          _galleryPermissionDenied = true;
          _galleryError = null;
        });
        return;
      }

      final assets = await _getRecentGalleryAssets();
      if (!mounted) return;
      setState(() {
        _galleryAssets
          ..clear()
          ..addAll(assets);
        if (_file == null && assets.isNotEmpty) {
          _selectedAsset = assets.first;
          _selectedAssetId = assets.first.id;
          _selectedAssets
            ..clear()
            ..add(assets.first);
        }
        _isGalleryLoading = false;
        _galleryPermissionDenied = false;
        _galleryError = null;
      });
      if (assets.isNotEmpty) {
        _animController.forward(from: 0);
      }
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _isGalleryLoading = false;
        _galleryPermissionDenied = false;
        _galleryError =
            'Gallery plugin needs a full app restart. Stop the app and run it again.';
      });
    } catch (error) {
      debugPrint('Could not load gallery: $error');
      if (!mounted) return;
      setState(() {
        _isGalleryLoading = false;
        _galleryPermissionDenied = false;
        _galleryError = 'Could not load gallery: ${error.toString()}';
      });
    }
  }

  Future<List<AssetEntity>> _getRecentGalleryAssets() async {
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      ).timeout(const Duration(seconds: 30));
      if (albums.isEmpty) return <AssetEntity>[];
      return albums.first
          .getAssetListPaged(page: 0, size: 80)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      return PhotoManager.getAssetListPaged(
        page: 0,
        pageCount: 80,
        type: RequestType.image,
      ).timeout(const Duration(seconds: 30));
    }
  }

  List<AssetEntity> _activeSelectedAssets() {
    if (_selectedAssets.isNotEmpty) {
      return List<AssetEntity>.from(_selectedAssets);
    }
    final asset = _selectedAsset;
    return asset == null ? <AssetEntity>[] : <AssetEntity>[asset];
  }

  Future<List<Uint8List>> _selectedPostImageBytes() async {
    if (_file != null) return <Uint8List>[_file!];
    final assets = _activeSelectedAssets();
    final bytes = <Uint8List>[];
    for (final asset in assets) {
      final data = await _originBytesFor(asset);
      if (data != null) bytes.add(data);
    }
    return bytes;
  }

  Future<Uint8List?> _previewThumbnailFor(AssetEntity asset) {
    return _previewThumbnailFutures.putIfAbsent(
      asset.id,
      () => _thumbnailFor(
        asset,
        const ThumbnailSize(1080, 1080),
        quality: 88,
      ),
    );
  }

  Future<Uint8List?> _gridThumbnailFor(AssetEntity asset) {
    return _gridThumbnailFutures.putIfAbsent(
      asset.id,
      () => _thumbnailFor(
        asset,
        const ThumbnailSize(300, 300),
        quality: 82,
      ),
    );
  }

  Future<Uint8List?> _thumbnailFor(
    AssetEntity asset,
    ThumbnailSize size, {
    required int quality,
  }) async {
    try {
      return await asset
          .thumbnailDataWithSize(size, quality: quality)
          .timeout(const Duration(seconds: 12), onTimeout: () => null);
    } catch (error) {
      debugPrint('Could not load gallery thumbnail ${asset.id}: $error');
      return null;
    }
  }

  Future<Uint8List?> _originBytesFor(AssetEntity asset) async {
    try {
      final thumbnailBytes = await _thumbnailFor(
        asset,
        const ThumbnailSize(1440, 1440),
        quality: 92,
      );
      if (thumbnailBytes != null) return thumbnailBytes;

      return await asset
          .thumbnailDataWithSize(
            const ThumbnailSize(1080, 1080),
            quality: 88,
          )
          .timeout(
            const Duration(seconds: 18),
            onTimeout: () => null,
          );
    } on OutOfMemoryError catch (error) {
      debugPrint('Could not load gallery image ${asset.id}: $error');
      return null;
    } catch (error) {
      debugPrint('Could not load gallery image ${asset.id}: $error');
      return null;
    }
  }

  Future<Uint8List?> _pickedImageBytes(ImageSource source) async {
    try {
      return await _pickCompressedPostImage(source);
    } catch (error) {
      debugPrint('Could not pick image from $source: $error');
      if (mounted) {
        showSnackBar('Could not open this image. Try another photo.', context);
      }
      return null;
    }
  }

  Future<void> _pickCameraImage() async {
    final file = await _pickedImageBytes(ImageSource.camera);
    if (!mounted || file == null) return;
    _setPickedImage(file);
  }

  Future<Uint8List?> _pickCompressedPostImage(ImageSource source) async {
    try {
      return await pickImage(
        source,
        imageQuality: 72,
        maxWidth: 1440,
        maxHeight: 1440,
      );
    } catch (error) {
      debugPrint('Could not pick compressed image from $source: $error');
      return null;
    }
  }

  Future<void> _selectGalleryAsset(AssetEntity asset) async {
    if (!_isMultiSelect && _selectedAssetId == asset.id && _file == null) {
      return;
    }

    if (_isMultiSelect) {
      setState(() {
        final existingIndex =
            _selectedAssets.indexWhere((item) => item.id == asset.id);
        if (existingIndex >= 0) {
          _selectedAssets.removeAt(existingIndex);
        } else {
          _selectedAssets.add(asset);
        }
        _selectedAsset =
            _selectedAssets.isNotEmpty ? _selectedAssets.first : null;
        _selectedAssetId = _selectedAsset?.id;
        _file = null;
        _postFiles = const [];
        _editorPreviewPage = 0;
        _isEditingDetails = false;
      });
      return;
    }
    setState(() {
      _selectedAsset = asset;
      _selectedAssetId = asset.id;
      _selectedAssets
        ..clear()
        ..add(asset);
      _file = null;
      _postFiles = const [];
      _editorPreviewPage = 0;
      _isEditingDetails = false;
    });
  }

  Future<void> _handleNext() async {
    if (_file == null && _activeSelectedAssets().isEmpty) {
      showSnackBar('Choose a photo first.', context);
      return;
    }
    if (_selectedModeIndex == 1) {
      final user = Provider.of<UserProvider>(context, listen: false).getUser;
      final pickedFile = _file;
      final assets = _activeSelectedAssets();
      final storyText = _storyTextController.text;
      final storyTextX = _storyTextX;
      final storyTextY = _storyTextY;
      final uploadFuture = _uploadStoryInBackground(
        pickedFile: pickedFile,
        assets: assets,
        uid: user.uid,
        username: user.username,
        userPhotoUrl: user.photoUrl,
        text: storyText,
        textX: storyTextX,
        textY: storyTextY,
      );
      Navigator.of(context).pop({
        'kind': 'story',
        'status': uploadFuture,
      });
      return;
    }
    setState(() => isLoading = true);
    final selectedFiles = await _selectedPostImageBytes();
    if (!mounted) return;
    setState(() => isLoading = false);
    if (selectedFiles.isEmpty) {
      showSnackBar('Could not load this photo. Try another image.', context);
      return;
    }
    final bytes = selectedFiles.first;
    setState(() {
      _file = bytes;
      _postFiles = selectedFiles;
      _editorPreviewPage = 0;
      _isEditingDetails = true;
    });
    _animController.forward(from: 0);
  }

  Future<bool> _uploadStoryInBackground({
    required Uint8List? pickedFile,
    required List<AssetEntity> assets,
    required String uid,
    required String username,
    required String userPhotoUrl,
    required String text,
    required double textX,
    required double textY,
  }) async {
    try {
      final selectedFiles = pickedFile != null
          ? <Uint8List>[pickedFile]
          : await _imageBytesFromAssets(assets);
      if (selectedFiles.isEmpty) {
        debugPrint('Story upload failed: no image bytes selected.');
        return false;
      }
      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          final res = await FirestoreMethods().uploadStory(
            file: selectedFiles.first,
            uid: uid,
            username: username,
            userPhotoUrl: userPhotoUrl,
            text: text,
            textX: textX,
            textY: textY,
          );
          if (res == 'success') return true;
          debugPrint('Story upload attempt $attempt failed: $res');
        } catch (err) {
          debugPrint('Story upload attempt $attempt failed: $err');
        }
        if (attempt == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 850));
        }
      }
      return false;
    } catch (err) {
      debugPrint('Story upload failed: $err');
      return false;
    }
  }

  Future<List<Uint8List>> _imageBytesFromAssets(
      List<AssetEntity> assets) async {
    final bytes = <Uint8List>[];
    for (final asset in assets) {
      final data = await _originBytesFor(asset);
      if (data != null) bytes.add(data);
    }
    return bytes;
  }

  Future<void> _manageGalleryAccess() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              _GalleryAccessOption(
                title: 'Limit access',
                subtitle: 'Show only 5 recent photos in $_pickerTitle.',
                icon: Icons.photo_library_outlined,
                selected: _isGalleryLimited,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _setGalleryLimit(true);
                },
              ),
              const SizedBox(height: 8),
              _GalleryAccessOption(
                title: 'Full access',
                subtitle: 'Show all recent photos loaded from your gallery.',
                icon: Icons.collections_rounded,
                selected: !_isGalleryLimited,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _setGalleryLimit(false);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  if (kIsWeb) {
                    showSnackBar(
                        'Gallery grid is only available on mobile.', context);
                    return;
                  }
                  await PhotoManager.openSetting();
                },
                child: const Text('Open phone photo settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setGalleryLimit(bool limited) {
    setState(() {
      _isGalleryLimited = limited;
      final visibleAssets = _visibleGalleryAssets();
      if (visibleAssets.isNotEmpty &&
          (_selectedAsset == null ||
              !visibleAssets.any((asset) => asset.id == _selectedAssetId))) {
        _selectedAsset = visibleAssets.first;
        _selectedAssetId = visibleAssets.first.id;
        _selectedAssets
          ..clear()
          ..add(visibleAssets.first);
        _file = null;
        _postFiles = const [];
        _editorPreviewPage = 0;
      }
    });
  }

  void _toggleMultiSelect() {
    if (_isStoryMode) {
      showSnackBar('Stories use one photo at a time.', context);
      return;
    }
    setState(() {
      _isMultiSelect = !_isMultiSelect;
      if (_isMultiSelect && _selectedAssets.isEmpty && _selectedAsset != null) {
        _selectedAssets.add(_selectedAsset!);
      }
      if (!_isMultiSelect && _selectedAssets.length > 1) {
        final first = _selectedAssets.first;
        _selectedAssets
          ..clear()
          ..add(first);
        _selectedAsset = first;
        _selectedAssetId = first.id;
      }
      _file = null;
      _postFiles = const [];
      _editorPreviewPage = 0;
    });
  }

  void _setMode(int mode) {
    if (_selectedModeIndex == mode) return;
    setState(() {
      _selectedModeIndex = mode;
      if (_isStoryMode) {
        _isMultiSelect = false;
        if (_selectedAssets.length > 1) {
          final first = _selectedAssets.first;
          _selectedAssets
            ..clear()
            ..add(first);
          _selectedAsset = first;
          _selectedAssetId = first.id;
        }
      }
    });
  }

  void _addStoryText() {
    if (isLoading) return;
    setState(() {
      if (_storyTextController.text.trim().isEmpty) {
        _storyTextController.text = 'Text';
        _storyTextController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _storyTextController.text.length,
        );
      }
      _storyTextX = 0.5;
      _storyTextY = 0.45;
    });
    _focusStoryText(selectAll: true);
  }

  void _focusStoryText({bool selectAll = false}) {
    if (isLoading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isLoading) return;
      if (selectAll) {
        _storyTextController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _storyTextController.text.length,
        );
      }
      FocusScope.of(context).requestFocus(_storyTextFocus);
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  List<AssetEntity> _visibleGalleryAssets() {
    if (!_isGalleryLimited) return _galleryAssets;
    return _galleryAssets.take(5).toList();
  }

  void _setPickedImage(Uint8List file) {
    setState(() {
      _file = file;
      _postFiles = <Uint8List>[file];
      _editorPreviewPage = 0;
      _selectedAsset = null;
      _selectedAssetId = null;
      _selectedAssets.clear();
      _isMultiSelect = false;
      _isEditingDetails = false;
    });
    _animController.forward(from: 0);
  }

  void clearImage() => setState(() {
        _file = null;
        _postFiles = const [];
        _editorPreviewPage = 0;
        _selectedAsset = null;
        _selectedAssetId = null;
        _selectedAssets.clear();
        _isMultiSelect = false;
        _isEditingDetails = false;
        _descriptionController.clear();
        _storyTextController.clear();
        _storyTextX = 0.5;
        _storyTextY = 0.45;
        _animController.reset();
      });

  void _backToPicker() => setState(() => _isEditingDetails = false);

  Widget _buildSelectedPostPreview(double height) {
    final files = _postFiles.isNotEmpty
        ? _postFiles
        : (_file == null ? const <Uint8List>[] : <Uint8List>[_file!]);
    if (files.isEmpty) return const SizedBox.shrink();

    final page = _editorPreviewPage.clamp(0, files.length - 1);

    return Container(
      width: double.infinity,
      height: height,
      color: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: files.length,
            onPageChanged: (value) {
              setState(() => _editorPreviewPage = value);
            },
            itemBuilder: (context, index) {
              return Image.memory(files[index], fit: BoxFit.contain);
            },
          ),
          if (files.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${page + 1}/${files.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (files.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  files.length,
                  (dotIndex) => Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotIndex == page
                          ? const Color(0xFF4C7DFF)
                          : Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);

    if (!_isEditingDetails) {
      return _buildPickerView(context, userProvider, isDark, bgColor);
    }
    return _buildEditorView(context, userProvider, isDark, bgColor);
  }

  Widget _buildPickerView(
    BuildContext context,
    UserProvider userProvider,
    bool isDark,
    Color bgColor,
  ) {
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.58) : Colors.black54;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final previewColor = isDark ? const Color(0xFF06090F) : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close_rounded, color: textColor, size: 30),
                  ),
                  Expanded(
                    child: Text(
                      _pickerTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: isLoading ? null : _handleNext,
                    child: Text(
                      isLoading ? 'Sharing...' : _nextLabel,
                      style: TextStyle(
                        color: _file == null && _activeSelectedAssets().isEmpty
                            ? const Color(0xFF5B6EA9).withValues(alpha: 0.55)
                            : const Color(0xFF6D7FE3),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            Divider(height: 1, color: dividerColor),
            Expanded(
              child: SingleChildScrollView(
                physics: _isDraggingStoryText
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _isStoryMode
                          ? _buildStoryPickerPreview(
                              userProvider,
                              textColor,
                              mutedColor,
                            )
                          : _buildPostPickerPreview(
                              previewColor,
                              textColor,
                              mutedColor,
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                      child: Row(
                        children: [
                          Text(
                            _isStoryMode ? 'Story photo' : 'Recents',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: textColor, size: 26),
                          const Spacer(),
                          if (!_isStoryMode)
                            _PickerActionButton(
                              icon: Icons.filter_none_rounded,
                              label: _isMultiSelect
                                  ? '${_selectedAssets.length}'
                                  : 'Select',
                              onTap: _toggleMultiSelect,
                            )
                          else
                            _PickerActionButton(
                              icon: Icons.text_fields_rounded,
                              label: 'Add text',
                              onTap: isLoading ? () {} : _addStoryText,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _isGalleryLimited
                                  ? 'Limited access: showing 5 photos.'
                                  : (_isStoryMode
                                      ? 'Choose one vertical photo. It will fill the story screen.'
                                      : (_isMultiSelect
                                          ? 'Select multiple photos for one post.'
                                          : 'Choose a photo for your post.')),
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _manageGalleryAccess,
                            child: Text(
                              'Manage',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildGalleryGrid(textColor, mutedColor),
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Align(
            alignment: Alignment.centerRight,
            heightFactor: 1,
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModePillButton(
                    label: 'POST',
                    selected: _selectedModeIndex == 0,
                    onTap: () => _setMode(0),
                  ),
                  _ModePillButton(
                    label: 'STORY',
                    selected: _selectedModeIndex == 1,
                    onTap: () => _setMode(1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostPickerPreview(
    Color previewColor,
    Color textColor,
    Color mutedColor,
  ) {
    return AspectRatio(
      key: const ValueKey<String>('post-preview'),
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        color: previewColor,
        child: _file == null && _activeSelectedAssets().isEmpty
            ? GestureDetector(
                onTap: _loadGalleryAssets,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: mutedColor, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      'Choose a photo',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pick from camera or gallery',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (_file != null)
                    Image.memory(_file!, fit: BoxFit.contain)
                  else
                    _GalleryAssetPreview(
                      asset: _selectedAsset!,
                      thumbnailFuture: _previewThumbnailFor(_selectedAsset!),
                    ),
                  Positioned(
                    left: 14,
                    bottom: 14,
                    child: GestureDetector(
                      onTap: _loadGalleryAssets,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStoryPickerPreview(
    UserProvider userProvider,
    Color textColor,
    Color mutedColor,
  ) {
    final hasSelection = _file != null || _activeSelectedAssets().isNotEmpty;

    return Container(
      key: const ValueKey<String>('story-preview'),
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.72,
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!hasSelection)
                    GestureDetector(
                      onTap: _loadGalleryAssets,
                      child: Container(
                        color: const Color(0xFF151515),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_edu_rounded,
                                color: mutedColor, size: 52),
                            const SizedBox(height: 12),
                            Text(
                              'Choose a story photo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Vertical photos look best',
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_file != null)
                    Image.memory(_file!, fit: BoxFit.cover)
                  else
                    _GalleryAssetPreview(
                      asset: _selectedAsset!,
                      thumbnailFuture: _previewThumbnailFor(_selectedAsset!),
                      fit: BoxFit.cover,
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.48),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.52),
                        ],
                      ),
                    ),
                  ),
                  _buildHiddenStoryTextInput(),
                  _buildDraggableStoryText(),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: hasSelection ? 0.42 : 0,
                            minHeight: 3,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.28),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            LocalImage(
                              url: userProvider.getUser.photoUrl,
                              radius: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                userProvider.getUser.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.58),
                              ),
                            ),
                            child: Text(
                              'Send message...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.send_outlined,
                          color: Colors.white,
                          size: 25,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 60,
                    child: GestureDetector(
                      onTap: _loadGalleryAssets,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.crop_portrait_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableStoryText() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _storyTextController,
      builder: (context, value, _) {
        final text = value.text.trim();
        if (text.isEmpty) return const SizedBox.shrink();

        return Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              return Stack(
                children: [
                  Align(
                    alignment: Alignment(
                      (_storyTextX * 2) - 1,
                      (_storyTextY * 2) - 1,
                    ),
                    child: Listener(
                      onPointerDown: (_) {
                        if (isLoading) return;
                        _focusStoryText();
                        setState(() => _isDraggingStoryText = true);
                      },
                      onPointerUp: (_) =>
                          setState(() => _isDraggingStoryText = false),
                      onPointerCancel: (_) =>
                          setState(() => _isDraggingStoryText = false),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: isLoading ? null : () => _focusStoryText(),
                        onPanEnd: (_) =>
                            setState(() => _isDraggingStoryText = false),
                        onPanCancel: () =>
                            setState(() => _isDraggingStoryText = false),
                        onPanUpdate: (details) {
                          if (isLoading) return;
                          setState(() {
                            _storyTextX =
                                (_storyTextX + details.delta.dx / width)
                                    .clamp(0.08, 0.92)
                                    .toDouble();
                            _storyTextY =
                                (_storyTextY + details.delta.dy / height)
                                    .clamp(0.16, 0.84)
                                    .toDouble();
                          });
                        },
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: width * 0.78),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.34),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.38),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    text,
                                    textAlign: TextAlign.center,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      height: 1.12,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black87,
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_storyTextFocus.hasFocus) ...[
                                  const SizedBox(width: 3),
                                  FadeTransition(
                                    opacity: _storyCaretOpacity,
                                    child: const Text(
                                      '|',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        height: 1,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black87,
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHiddenStoryTextInput() {
    return Positioned(
      left: 16,
      right: 16,
      top: 88,
      child: SizedBox(
        height: 56,
        child: Opacity(
          opacity: 0,
          child: IgnorePointer(
            child: TextField(
              controller: _storyTextController,
              focusNode: _storyTextFocus,
              enabled: !isLoading,
              maxLength: 80,
              maxLines: 1,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              enableInteractiveSelection: false,
              cursorColor: Colors.transparent,
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 22,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryGrid(Color textColor, Color mutedColor) {
    final visibleAssets = _visibleGalleryAssets();

    if (_isGalleryLoading) {
      return SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(color: textColor),
        ),
      );
    }

    if (_galleryPermissionDenied) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(Icons.photo_library_outlined, color: mutedColor, size: 34),
              const SizedBox(height: 10),
              Text(
                'Allow photo access to show your gallery here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _manageGalleryAccess,
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    if (_galleryError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, color: mutedColor, size: 34),
              const SizedBox(height: 10),
              Text(
                _galleryError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadGalleryAssets,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleAssets.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _MediaPickTile(
            icon: Icons.camera_alt_rounded,
            onTap: _pickCameraImage,
          );
        }
        final asset = visibleAssets[index - 1];
        final selectionIndex =
            _selectedAssets.indexWhere((item) => item.id == asset.id);
        return _GalleryAssetTile(
          asset: asset,
          thumbnailFuture: _gridThumbnailFor(asset),
          selected: selectionIndex >= 0 || _selectedAssetId == asset.id,
          selectionIndex:
              _isMultiSelect && selectionIndex >= 0 ? selectionIndex + 1 : null,
          onTap: () => _selectGalleryAsset(asset),
        );
      },
    );
  }

  Widget _buildEditorView(BuildContext context, UserProvider userProvider,
      bool isDark, Color bgColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtleTextColor =
        isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black54;
    final inputColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.035);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          onPressed: _backToPicker,
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black, size: 20),
        ),
        title: Text(
          'Create Post',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: isLoading
                ? null
                : () => postImage(
                      userProvider.getUser.uid,
                      userProvider.getUser.username,
                      userProvider.getUser.photoUrl,
                    ),
            child: Text(
              isLoading ? 'Sharing...' : 'Share',
              style: TextStyle(
                color: isLoading
                    ? const Color(0xFF0095F6).withValues(alpha: 0.45)
                    : const Color(0xFF0095F6),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: (screenWidth - 32) * 0.78,
                      color: Colors.black,
                      child:
                          _buildSelectedPostPreview((screenWidth - 32) * 0.78),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: GestureDetector(
                        onTap: _backToPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Change',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  LocalImage(url: userProvider.getUser.photoUrl, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userProvider.getUser.username,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: inputColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: dividerColor),
                ),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 7,
                  minLines: 4,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write a caption...',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _descriptionController,
                builder: (_, value, __) {
                  final count = value.text.length;
                  final countColor =
                      count > 2000 ? const Color(0xFFE1306C) : subtleTextColor;
                  return Row(
                    children: [
                      Text(
                        'Caption',
                        style: TextStyle(
                          color: subtleTextColor,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$count/2200',
                        style: TextStyle(color: countColor, fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(color: dividerColor),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () => postImage(
                        userProvider.getUser.uid,
                        userProvider.getUser.username,
                        userProvider.getUser.photoUrl,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0095F6),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF0095F6).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Share Post',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 19),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryAccessOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GalleryAccessOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0095F6).withValues(alpha: 0.14)
              : textColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF0095F6).withValues(alpha: 0.65)
                : textColor.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF0095F6) : textColor,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.58),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF0095F6),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaPickTile extends StatelessWidget {
  final IconData? icon;
  final VoidCallback onTap;

  const _MediaPickTile({
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: isDark ? const Color(0xFF151515) : const Color(0xFFEDEDED),
          child: Icon(
            icon ?? Icons.photo_library_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _GalleryAssetPreview extends StatelessWidget {
  final AssetEntity asset;
  final Future<Uint8List?> thumbnailFuture;
  final BoxFit fit;

  const _GalleryAssetPreview({
    required this.asset,
    required this.thumbnailFuture,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: thumbnailFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white54),
          );
        }
        return Image.memory(bytes, fit: fit);
      },
    );
  }
}

class _GalleryAssetTile extends StatelessWidget {
  final AssetEntity asset;
  final Future<Uint8List?> thumbnailFuture;
  final bool selected;
  final int? selectionIndex;
  final VoidCallback onTap;

  const _GalleryAssetTile({
    required this.asset,
    required this.thumbnailFuture,
    required this.selected,
    this.selectionIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: thumbnailFuture,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) {
                return Container(
                  color: const Color(0xFF151515),
                  alignment: Alignment.center,
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                        ),
                );
              }
              return Image.memory(bytes, fit: BoxFit.cover);
            },
          ),
          if (selected)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          if (selectionIndex != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF0095F6),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${selectionIndex!}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModePillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModePillButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 17),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? textColor : textColor.withValues(alpha: 0.48),
            fontSize: 15,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

