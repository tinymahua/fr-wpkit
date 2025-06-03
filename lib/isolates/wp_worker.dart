import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:easy_isolate/easy_isolate.dart' as easy_isolate;


class WpConfig {
  String id;
  String title;
  String iTitle;
  String hImgUrl;
  String fkUrl;
  String pvUrl;
  String fvUrl;

  WpConfig({
    required this.id,
    required this.title,
    required this.iTitle,
    required this.hImgUrl,
    required this.fkUrl,
    required this.pvUrl,
    required this.fvUrl,
  });

  factory WpConfig.fromJson(Map<String, dynamic> json) {
    return WpConfig(
      id: json['id'].toString(),
      title: json['title'],
      iTitle: json['img_title'],
      hImgUrl: json['high_img'],
      fkUrl: json['img_4k'],
      pvUrl: json['preview_video_url'],
      fvUrl: json['down_4k_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'img_title': iTitle,
      'high_img': hImgUrl,
      'img_4k': fkUrl,
      'preview_video_url': pvUrl,
      'down_4k_url': fvUrl,
    };
  }
}

Future<void> downloadFile(String url, String saveFilePath)async{
  final dio = Dio();
  var resp = await dio.get(url, options: Options(responseType: ResponseType.stream));
  Stream<Uint8List> contentStream = resp.data.stream;
  print("Download stream:  ${contentStream}");
  var file = File(saveFilePath);
  if (file.existsSync()){
    file.deleteSync();
  }

  file.createSync(recursive: true);

  contentStream.listen((d){
    file.writeAsBytesSync(d, mode: FileMode.append);
  });
}

String pickleImgUrl(WpConfig config){
  if (config.fkUrl.isNotEmpty){
    return config.fkUrl;
  }
  if (config.hImgUrl.isNotEmpty){
    return config.hImgUrl;
  }
  return '';
}

pickleVidUrl(WpConfig config){
  return config.pvUrl;
}


downloadImg(WpConfig config, String saveToImgDir)async{
  var imgUrl = pickleImgUrl(config);
  if (imgUrl.isNotEmpty) {
    await downloadFile(imgUrl, p.join(saveToImgDir, "${config.id}.jpg"));
  }
}


downloadVid(WpConfig config, String saveToVidDir)async{
  var vidUrl = pickleVidUrl(config);
  if (vidUrl.isNotEmpty) {
    await downloadFile(vidUrl, p.join(saveToVidDir, "${config.id}.mp4"));
  }
}

class WpWorker{
  WpWorker(this.onNotifyProgress);

  final Function(WpProcessProgressEvent event) onNotifyProgress;
  final worker = easy_isolate.Worker();

  Future<void> init() async {
    await worker.init(
      mainMessageHandler,
      isolateMessageHandler,
      errorHandler: print,
    );

  }

  sendWpTask(WpTask task){
    worker.sendMessage(task);
  }

  /// Handle the messages coming from the isolate
  void mainMessageHandler(dynamic data, SendPort isolateSendPort) {
    if (data is WpProcessProgressEvent) {
      onNotifyProgress(data);
    }
  }

  /// Handle the messages coming from the main
  static isolateMessageHandler(
      dynamic data,
      SendPort mainSendPort,
      easy_isolate.SendErrorFunction sendError,
      ) async {
    print('isolate received data: ${data}');
    if (data is WpTask) {
      var task = data;
      var configJson = task.configJson;
      var config = WpConfig.fromJson(configJson);
      print(configJson);
      print("${config.toJson()}");
      await  downloadImg(config, p.join(task.saveToDir, 'img'));
      await  downloadVid(config, p.join(task.saveToDir, 'vid'));
    }
    sleep(Duration(seconds: 3));
  }
}


class WpTask {
  String id;
  bool done  = false;
  int microTs;
  Map<String, dynamic> configJson;
  String saveToDir;

  WpTask(this.id, this.done, this.microTs, this.configJson, this.saveToDir);

  factory WpTask.fromJson(Map<String, dynamic> json) {
    return WpTask(
      json['id'],
      json['done'],
      json['micro_ts'],
      json['config_json'],
      json['save_to_dir'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'done': done,
      'micro_ts': microTs,
      'config_json': configJson,
      'save_to_dir': saveToDir,
    };
  }
}

class WpProcessProgressEvent {
  String taskId;
  int progress;

  WpProcessProgressEvent(this.taskId, this.progress);
}
