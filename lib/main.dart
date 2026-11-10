import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'app.auralis.playback',
    androidNotificationChannelName: 'Auralis',
    androidNotificationOngoing: true,
  );
  runApp(const AuralisApp());
}
