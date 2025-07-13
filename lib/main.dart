import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/services.dart';
import 'radio_stations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
//import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(MyApp());
}

Future<bool> isServiceRunning() async {
  final service = FlutterBackgroundService();
  return await service.isRunning();
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(),
  );
  if (!await isServiceRunning()) {
    service.startService();
  }
}

void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Устанавливаем уведомление для работы в фоновом режиме
    service.setForegroundNotificationInfo(
      title: "Radio Player",
      content: "Playing in background",
    );
  }

  // Бесконечный цикл для поддержания работы сервиса
  while (true) {
    await Future.delayed(Duration(seconds: 1));
  }

  // Таймер для поддержания работы сервиса (пустой оператор)
  // Timer.periodic(Duration(seconds: 5), (timer) {
  //   // Ничего не делаем
  // });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Internet Radio',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: RadioScreen(),
    );
  }
}

class RadioScreen extends StatefulWidget {
  @override
  _RadioScreenState createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  int _isPressedIndex = -1; // -1 = нет нажатия
  final AudioPlayer _audioPlayer = AudioPlayer();
  RadioStation? _currentStation;
  bool _isPlaying = false;
  final List<RadioStation> _stations = radioStations;

  @override
  void initState() {
    super.initState();
    _setupAudioSession();
    _setupAudioPlayer();
  }

  // Настройка аудиосессии
  Future<void> _setupAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );
  }

  // Настройка прослушивания состояния аудиоплеера
  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      setState(() => _isPlaying = state.playing);
    });
  }

  // Метод для воспроизведения радиостанции
  Future<void> _playRadio(RadioStation station) async {
    if (_currentStation == station && _isPlaying) return;

    setState(() {
      _currentStation = station;
    });

    try {
      await _audioPlayer.setUrl(station.url); // Установка URL потока
      await _audioPlayer.play(); // Воспроизведение
    } catch (e) {
      print("Ошибка воспроизведения: $e");
      setState(() {
        _currentStation = null;
      });
    }
  }

  // Метод для остановки воспроизведения
  Future<void> _stopRadio() async {
    await _audioPlayer.stop();
    setState(() {
      _currentStation = null;
    });
  }

  void _exitApp() {
    _audioPlayer.dispose();
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: Text(_currentStation?.name ?? "Punk Radio"),
        //backgroundColor: Colors.transparent,
        backgroundColor: Colors.black, // фон шапки
        elevation: 0,

        leading: IconButton(
          icon: Image.asset(
            'assets/images/icon.png', // Путь к вашей иконке
            width: 50, // Размер иконки
            height: 50,
          ),
          onPressed: () {
            print("Custom icon pressed");
          },
        ),

        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.5), Colors.transparent],
            ),
          ),
        ),

        foregroundColor: Colors.yellow, // Цвет текста и иконок
        title: Text(
          _currentStation?.name ?? "Punk Radio",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.orange[800]!, // тень
                blurRadius: 2,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      ),

      body: Stack(
        children: [
          // Фоновое изображение на весь экран
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/poster.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Основной контент с SafeArea
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _stations.length,
                    itemBuilder: (context, index) {
                      final station = _stations[index];
                      final isSelected = _currentStation == station;

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        child: GestureDetector(
                          onTap: () => _playRadio(station),
                          onTapDown:
                              (_) => setState(() => _isPressedIndex = index),
                          onTapUp: (_) => setState(() => _isPressedIndex = -1),
                          onTapCancel:
                              () => setState(() => _isPressedIndex = -1),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 100),
                            decoration: BoxDecoration(
                              color:
                                  _isPressedIndex == index
                                      ? Colors.white.withOpacity(0.3)
                                      : (isSelected
                                          ? Colors.blue.withOpacity(0.5)
                                          : Colors.white.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(12.0),
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: Colors.blueAccent,
                                        width: 2.0,
                                      )
                                      : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                station.name,
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 2,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Кнопка воспроизведения/паузы
                      GestureDetector(
                        onTap:
                            _isPlaying
                                ? _audioPlayer.pause
                                : () =>
                                    _currentStation != null
                                        ? _playRadio(_currentStation!)
                                        : null,
                        onTapDown: (_) => setState(() => _isPressedIndex = -2),
                        onTapUp: (_) => setState(() => _isPressedIndex = -1),
                        onTapCancel: () => setState(() => _isPressedIndex = -1),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            color:
                                _isPressedIndex == -2
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: Colors.grey,
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 36.0),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.green,
                            size: 36.0,
                          ),
                        ),
                      ),

                      // Кнопка стоп
                      GestureDetector(
                        onTap: _stopRadio,
                        onTapDown: (_) => setState(() => _isPressedIndex = -3),
                        onTapUp: (_) => setState(() => _isPressedIndex = -1),
                        onTapCancel: () => setState(() => _isPressedIndex = -1),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            color:
                                _isPressedIndex == -3
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: Colors.grey,
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 36.0),
                          child: Icon(
                            Icons.stop,
                            color: Colors.yellow,
                            size: 36.0,
                          ),
                        ),
                      ),

                      // Кнопка выхода
                      GestureDetector(
                        onTap: _exitApp,
                        onTapDown: (_) => setState(() => _isPressedIndex = -4),
                        onTapUp: (_) => setState(() => _isPressedIndex = -1),
                        onTapCancel: () => setState(() => _isPressedIndex = -1),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            color:
                                _isPressedIndex == -4
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: Colors.grey,
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 36.0),
                          child: Icon(
                            Icons.exit_to_app,
                            color: Colors.red,
                            size: 36.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
