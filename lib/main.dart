import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mostrar la interfaz inmediatamente.
  runApp(const AuralisApp());

  // Inicializar el servicio de audio sin bloquear el arranque.
  unawaited(_initializeAudioBackground());
}

Future<void> _initializeAudioBackground() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'app.auralis.playback',
      androidNotificationChannelName: 'Auralis',
      androidNotificationOngoing: true,
    );
    debugPrint('Auralis: servicio de audio inicializado.');
  } catch (error, stackTrace) {
    debugPrint('Auralis: error al inicializar el audio: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
