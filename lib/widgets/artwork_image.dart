import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'artwork_cache.dart';

class ArtworkImage extends StatefulWidget {
  const ArtworkImage({
    super.key,
    required this.path,
    required this.hasArtwork,
    required this.size,
    required this.borderRadius,
    required this.placeholderColor,
    this.placeholderChild,
  });

  final String     path;
  final bool       hasArtwork;
  final double     size;
  final double     borderRadius;
  final Color      placeholderColor;
  final Widget?    placeholderChild;

  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends State<ArtworkImage> {
  Uint8List? _bytes;
  bool       _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.hasArtwork) _load();
  }

  @override
  void didUpdateWidget(ArtworkImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      setState(() { _bytes = null; _loaded = false; });
      if (widget.hasArtwork) _load();
    }
  }

  Future<void> _load() async {
    final bytes = await ArtworkCache.instance.get(widget.path);
    if (mounted) setState(() { _bytes = bytes; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.size, height: widget.size,
        child: _loaded && _bytes != null
        ? Image.memory(_bytes!, width: widget.size, height: widget.size, fit: BoxFit.cover)
        : Container(
          color: widget.placeholderColor,
          child: widget.placeholderChild,
        ),
      ),
    );
  }
}
