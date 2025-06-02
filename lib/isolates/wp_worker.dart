import 'dart:isolate';

import 'package:easy_isolate/easy_isolate.dart' as easy_isolate;
import 'package:fr_wpkit/src/rust/frb_generated.dart';


wpWorkerMainMessageHandler(dynamic data, SendPort isolateSendPort){
  print('in main func');
}

wpWorkerIsolateMessageHandler(dynamic data, SendPort isolateSendPort, easy_isolate.SendErrorFunction sendError,)async{
  print('in isolate func： ${data}');
  try {
    await RustLib.init();
  } catch (e) {
    //
  }
  if (data is OperateEvent){
    if (data.operate == Operate.start) {
      print('222');
      print('do start');
    }else if (data.operate == Operate.stop){
      print('do stop');
    }
  }
}


enum Operate {
  start,
  stop,
}

class OperateEvent {
  Operate operate;
  OperateEvent(this.operate);
}