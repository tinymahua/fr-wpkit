import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fr_wpkit/isolates/wp_worker.dart';
import 'package:path/path.dart' as p;
import 'package:top_modal_sheet/top_modal_sheet.dart';
import 'package:easy_isolate/easy_isolate.dart' as easy_isolate;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController _installedDirController = TextEditingController();
  TextEditingController _saveToDirController = TextEditingController();

  String _installedDir = '';
  String _saveToDir = '';
  bool settingCheckedOk =  false;

  easy_isolate.Worker _worker = easy_isolate.Worker();

  @override
  void initState() {
    super.initState();
    setupEvents();
  }

  setupEvents() async {
    setState(() {
      _installedDirController.text = _installedDir;
      _saveToDirController.text = _saveToDir;
    });

    await _worker.init(wpWorkerMainMessageHandler,
        wpWorkerIsolateMessageHandler);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 12, left: 12, right: 50),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: 140, child: Text('设置壁纸安装目录')),
                Expanded(
                  child: TextField(
                    controller: _installedDirController,
                    decoration: InputDecoration(hintText: '请选择安装目录'),
                    onChanged: (v) {
                      setState(() {
                        _installedDir = v.trim();
                      });
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    selectInstalledDir();
                  },
                  icon: Icon(Icons.folder),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                SizedBox(width: 140, child: Text('设置壁纸保存目录')),
                Expanded(
                  child: TextField(
                    controller: _saveToDirController,
                    decoration: InputDecoration(hintText: '请选择保存目录'),
                    onChanged: (v) {
                      setState(() {
                        _saveToDir = v.trim();
                      });
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    selectSaveToDir();
                  },
                  icon: Icon(Icons.folder),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () {
                    checkSetting();
                  },
                  child: Text('检测设置'),
                ),
                ElevatedButton(
                    onPressed: settingCheckedOk ? (){
                      startListen();
                    }: null, child: Text('启动')),
                ElevatedButton(
                    onPressed: settingCheckedOk ? (){
                      stopListen();
                    }: null, child: Text('停止'))
              ],
            ),
          ],
        ),
      ),
    );
  }

  selectInstalledDir() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {
      return;
    }
    print('Selected dir: ${selectedDirectory}');
    setState(() {
      _installedDirController.text = selectedDirectory;
    });
  }

  selectSaveToDir() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {
      return;
    }
    print('Selected dir: ${selectedDirectory}');
    setState(() {
      _saveToDirController.text = selectedDirectory;
    });
  }


  startListen()async{
    var ok = await checkSetting();
    if (!ok){
      return;
    }
    _worker.sendMessage(OperateEvent(Operate.start));
  }

  stopListen()async{
    var ok = await checkSetting();
    if (!ok){
      return;
    }
    _worker.sendMessage(OperateEvent(Operate.stop));
  }

  Future<bool> checkSetting() async {
    String installedDir = _installedDirController.text;
    String saveToDir = _saveToDirController.text;

    if (installedDir.isEmpty){
       await checkPrompt("安装目录必须设置");
       return false;
    }
    if (p.isRelative(installedDir)) {
      await checkPrompt("安装目录必须为绝对路径");
      return false;
    }
    if (!Directory(installedDir).existsSync()){
      await checkPrompt("安装目录不存在");
      return false;
    }
    if (saveToDir.isEmpty){
      await checkPrompt("保存目录必须设置");
      return false;
    }
    if (p.isRelative(saveToDir)) {
      await checkPrompt("保存目录必须为绝对路径");
      return false;
    }
    if (!Directory(saveToDir).existsSync()){
      await checkPrompt("保存目录不存在");
      return false;
    }
    setState(() {
       settingCheckedOk = true;
    });
    return true;
  }


  checkPrompt(String msg) async {
    var _ = await showTopModalSheet(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      context,
      Container(
        width: MediaQuery.of(context).size.height * 0.8,
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(msg),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('确定'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
