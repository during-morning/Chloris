import 'package:flutter/material.dart';
import '../../app/widgets/decoded_network_image.dart';

Widget musicArtworkImage(String url, double size) =>
    DecodedNetworkImage(url: url, width: size, height: size, fit: BoxFit.cover);
