import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'package:file_picker/file_picker.dart';

class GalleryManager extends StatefulWidget {
  const GalleryManager({
    super.key,
    required this.title,
    required this.isAdmin,
    this.restaurantId,
    this.productId,
  }) : assert(
         restaurantId != null || productId != null,
         'Fournir restaurantId ou productId',
       );

  final String title;
  final bool isAdmin;
  final int? restaurantId;
  final int? productId;

  @override
  State<GalleryManager> createState() => _GalleryManagerState();
}

class _GalleryManagerState extends State<GalleryManager> {
  List<Map<String, dynamic>> _images = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  bool get _isProduct => widget.productId != null;

  // Récupère ApiClient (avec token) depuis AppState
  ApiClient get _api => context.read<AppState>().api;

  String get _origin =>
      AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+$'), '');

  String _absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return path.startsWith('/') ? '$_origin$path' : '$_origin/$path';
  }

  @override
  void initState() {
    super.initState();
    // On ne peut pas utiliser context.read avant que le widget soit monté
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> images;
      if (widget.isAdmin) {
        if (_isProduct) {
          images = await _api.adminProductGallery(widget.productId!);
        } else {
          images = await _api.adminRestaurantGallery(widget.restaurantId!);
        }
      } else {
        if (_isProduct) {
          images = await _api.partnerProductGallery(widget.productId!);
        } else {
          images = await _api.partnerRestaurantGallery();
        }
      }

      if (!mounted) return;
      setState(() {
        _images = images;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger la galerie.';
        _loading = false;
      });
    }
  }

  // ... dans _GalleryManagerState ...

  Future<void> _upload() async {
    // 1. Sélection du fichier (API v13)
    final files = await FilePicker.pickFiles(
      type: FileType.image,
      // withData est déprécié, on ne l'utilise plus
    );

    // En v13, on reçoit une List<PlatformFile> (vide si annulé)
    if (files.isEmpty) return;

    final file = files.first;

    // 2. Lecture des bytes via la méthode du PlatformFile (v13)
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      if (mounted) {
        showAppSnack(context, "Impossible de lire le fichier.", error: true);
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      // 3. Upload via ApiClient
      final imageUrl = await _api.uploadImageBytes(
        bytes: bytes,
        fileName: file.name,
      );

      // 4. Enregistrement dans la galerie
      if (widget.isAdmin) {
        if (_isProduct) {
          await _api.addAdminProductImage(widget.productId!, imageUrl);
        } else {
          await _api.addAdminRestaurantImage(widget.restaurantId!, imageUrl);
        }
      } else {
        if (_isProduct) {
          await _api.addPartnerProductImage(widget.productId!, imageUrl);
        } else {
          await _api.addPartnerRestaurantImage(imageUrl);
        }
      }

      if (!mounted) return;
      showAppSnack(context, 'Image ajoutée avec succès.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, "Impossible d'ajouter l'image.", error: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(int imageId) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer cette image ?',
      message: 'Elle sera définitivement retirée de la galerie.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!confirmed || !mounted) return;

    try {
      if (widget.isAdmin) {
        if (_isProduct) {
          await _api.deleteAdminProductImage(imageId);
        } else {
          await _api.deleteAdminRestaurantImage(imageId);
        }
      } else {
        if (_isProduct) {
          await _api.deletePartnerProductImage(imageId);
        } else {
          await _api.deletePartnerRestaurantImage(imageId);
        }
      }

      if (!mounted) return;
      showAppSnack(context, 'Image supprimée.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnack(context, e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Impossible de supprimer.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _uploading ? null : _upload,
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Ajouter une image',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView(label: 'Chargement...');
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_images.isEmpty) {
      return EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Aucune image',
        message: 'Ajoutez des photos pour égayer votre galerie.',
        action: FilledButton.icon(
          onPressed: _uploading ? null : _upload,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Ajouter une image'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final image = _images[index];
          final imageId = (image['id'] as num?)?.toInt() ?? 0;
          final rawUrl = (image['image_url'] ?? image['url'] ?? '') as String;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  _absoluteUrl(rawUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppColors.peach,
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.line,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _delete(imageId),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 16,
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
  }
}
