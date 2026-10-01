import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/widgets/decoded_network_image.dart';

Widget musicArtworkImage(String url, double size) => url.startsWith('file:')
    ? Image.file(
        File.fromUri(Uri.parse(url)),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).round(),
        errorBuilder: (_, _, _) => const Icon(Icons.music_note),
      )
    : DecodedNetworkImage(
        url: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
