import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fr_wpkit/isolates/wp_worker.dart';
import 'package:multi_column_list_view/multi_column_list_view.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_modal_sheet/top_modal_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

const String installedDirKey = 'installedDir';
const String saveToDirKey = 'saveToDir';
const String configJsonListKey = 'configJsonList';
const String targetConfigDirName = 'bkinfo';
const String targetConfigFileName = 'preview_config';
const String cachedConfigIdsListKey = 'cachedConfigIdsList';

const String tasksListKey = 'tasksList';
const String tasksDoneListKey = 'tasksDoneList';

class _HomePageState extends State<HomePage> {
  TextEditingController _installedDirController = TextEditingController();
  TextEditingController _saveToDirController = TextEditingController();

  String _installedDir = '';
  String _saveToDir = '';
  bool settingCheckedOk =  false;

  String _statusMsg = '';

  // easy_isolate.Worker _worker = easy_isolate.Worker();
  WpWorker? _wpWorker;
  SharedPreferences? _sharedPreferences;
  String _targetConfigDir = '';
  Timer? _checkConfigTimer;
  List<WpTask> _tasksList = [];
  List<WpTask> _tasksDoneList = [];

  @override
  void initState() {
    super.initState();
    setupEvents();
  }

  setupEvents() async {
    var sp = await SharedPreferences.getInstance();
    setState(() {
      _sharedPreferences = sp;
    });

    // await _sharedPreferences!.clear();

    var cachedInstalledDir = sp.getString(installedDirKey);
    var cachedSaveToDir = sp.getString(saveToDirKey);
    setState(() {
      _installedDir = cachedInstalledDir ?? _installedDir;
      _saveToDir = cachedSaveToDir ?? _saveToDir;
      _installedDirController.text = _installedDir;
      _saveToDirController.text = _saveToDir;
    });


    setState(() {
       _wpWorker = WpWorker(onNotifyProgress);
    });
    await _wpWorker!.init();

    var tasksList =_sharedPreferences!.getStringList(tasksListKey) ?? [];
    var tasksDoneList = _sharedPreferences!.getStringList(tasksDoneListKey) ?? [];
    setState(() {
      _tasksDoneList = tasksDoneList.map((e)=>WpTask.fromJson(jsonDecode(e))).toList();
      _tasksList = tasksList.map((e)=>WpTask.fromJson(jsonDecode(e))).toList();
    });
    List<String> doneTaskIds = _tasksDoneList.map((e)=>e.id).toList();
    for (var t in _tasksList){
      if (!doneTaskIds.contains(t.id)){
        _wpWorker!.sendWpTask(t);
      }
    }
  }

  checkConfig(Timer t)async{
    if (_targetConfigDir.isNotEmpty){
      // print('I found config');
      var configFilePath = p.join(_targetConfigDir, targetConfigFileName);
      var configFile = File(configFilePath);
      if (configFile.existsSync()){
        var configContent = configFile.readAsStringSync();
        Map<String, dynamic> configJson = jsonDecode(configContent);
        var configId = configJson['id'].toString();
        // print('Found config Id: ${configId}');
        var configIdList = _sharedPreferences!.getStringList(cachedConfigIdsListKey) ?? [];
        if (!configIdList.contains(configId)){
          print('Old Id list: ${configIdList}');
          configIdList.add(configId);
          _sharedPreferences!.setStringList(cachedConfigIdsListKey, configIdList);
          print('Cached Id: ${configId}');

          var configJsonList = _sharedPreferences!.getStringList(configJsonListKey);
          configJsonList = configJsonList ?? [];
          configJsonList.add(configContent);
          await _sharedPreferences!.setStringList(configJsonListKey, configJsonList);

          var task = WpTask(
              configId, false, DateTime.now().microsecondsSinceEpoch, configJson, _saveToDir);

          setState(() {
            _tasksList.add(task);
          });
          _wpWorker!.sendWpTask(task);
        }
      }
    }
  }

  presentAppConfig(){
    print('Check ${_installedDir}');
    setState(() {
      _statusMsg = '正在检测安装目录...';
    });
    var fsStream = Directory(_installedDir).list(recursive: true);
    fsStream.listen((item){
      print('FS item: ${item}');
      if (p.basename(item.path) == targetConfigDirName){
        setState(() {
           _targetConfigDir = item.path;
        });
      }
    }, onDone: (){
      if (_targetConfigDir.isNotEmpty){
        setState(() {
          _statusMsg = '安装目录已检测完成[OK]';
          _checkConfigTimer = Timer.periodic(Duration(milliseconds: 200), checkConfig);
        });
      }else{
        setState(() {
          _statusMsg = '安装目录检测未通过[请随机预览一次或重新设置]';
        });
      }
    });
  }

  onNotifyProgress(WpProcessProgressEvent event){
    if (event.progress == 100){
      var gotTask = _tasksList.firstWhere((e)=>e.id == event.taskId);
      var doneStringList = _sharedPreferences!.getStringList(tasksDoneListKey) ?? [];
      var doneTaskList = doneStringList.map((e)=>WpTask.fromJson(jsonDecode(e))).toList();
      var gotIndex = doneTaskList.indexWhere((e)=>e.id == event.taskId);
      if (gotIndex < 0){
        doneStringList.add(jsonEncode(gotTask));
        _sharedPreferences!.setStringList(tasksDoneListKey, doneStringList);
        setState(() {
          _tasksDoneList.add(gotTask);
        });
      }
    }
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
                SizedBox(width: 140, child: Text('设置安装目录')),
                Expanded(
                  child: TextField(
                    controller: _installedDirController,
                    decoration: InputDecoration(hintText: '请选择安装目录'),
                    onChanged: (v) {
                      setState(() {
                        _installedDir = v.trim();
                      });
                      print('Changed :${_installedDir}');
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
                SizedBox(width: 140, child: Text('设置保存目录')),
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
                  onPressed: () async{
                    await checkSetting();
                    presentAppConfig();
                  },
                  child: Text('检测设置'),
                ),
                SizedBox(width: 20,),
                Expanded(child: Text(_statusMsg.isNotEmpty ? _statusMsg : '')),
                // ElevatedButton(
                //     onPressed: settingCheckedOk ? (){
                //       setState(() {
                //         _checkConfigTimer =
                //       });
                //     }: null, child: Text('启动')),
                // ElevatedButton(
                //     onPressed: settingCheckedOk ? (){
                //       stopListen();
                //     }: null, child: Text('停止'))
              ],
            ),
            Row(
              children: [
                Expanded(child: Divider())
              ],
            ),
            Expanded(child: Row(
              children: [Expanded(child: MultiColumnListView(columnWidths: columnWidths, columnTitles: columnTitles, rowCellsBuilder: rowCellsBuilder))],
            ))
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
      _installedDir = selectedDirectory;
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
      _saveToDir = selectedDirectory;
    });
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
    await _sharedPreferences!.setString(installedDirKey, installedDir);
    await _sharedPreferences!.setString(saveToDirKey, saveToDir);
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

  @override
  void dispose() {
    super.dispose();
    if (_checkConfigTimer != null){
      _checkConfigTimer!.cancel();
    }
  }
}
