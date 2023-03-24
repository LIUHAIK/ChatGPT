import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const ChatApp());
}

//当前显示的聊天的文件名
String currentMessageFileName = '';
//目标文件夹
const String DIR = '/chatMessage';

//保存对话的来回次数
const int conversationTimes = 10;

//生成聊天文件的名称
Future<File> _getLocalFile(List<Message> messages) async {
  String dir = '${(await getApplicationDocumentsDirectory()).path}$DIR';
  String fileName = '';
  if (messages.isNotEmpty) {
    fileName = messages.first.content;
  }
  //保存新文件名
  DateTime now = DateTime.now();
  String formattedDate = DateFormat('yyyy-MM-dd-kk:mm').format(now);
  currentMessageFileName = '$dir/$fileName-$formattedDate.txt';
  return File(currentMessageFileName);
}

//将对话写入到文件中去
Future<File> writeMessages(List<Message> messages) async {
  final File file;
  //file是存在的
  if (currentMessageFileName != '') {
    //不创建文件名
    file = File(currentMessageFileName);
  } else {
    //创建文件名
    file = await _getLocalFile(messages);
  }
  return file
      .writeAsString(jsonEncode(messages.map((e) => e.toJson()).toList()));
}

//从文件中读取对话
Future<List<Message>?> readMessages(String dir) async {
  try {
    final file = File(dir);
    currentMessageFileName = dir;
    String contents = await file.readAsString();
    List<Message> messages = List<Message>.from(
        jsonDecode(contents).map((e) => Message.fromJson(e)));
    return messages;
  } catch (e) {
    return null;
  }
}

//删除对话文件
Future<void> deleteMessage(String filePath) async {
  try {
    final file = File(filePath);
    await file.delete();
  } catch (e) {
    print(e);
  }
}

//消息类
class Message {
  //说话人
  final String author;
  //时间戳
  final DateTime timestamp;
  //消息内容
  final String content;

  Message(this.author, this.timestamp, this.content);

  Map<String, dynamic> toJson() => {
    'author': author,
    'timestamp': timestamp.toIso8601String(),
    'content': content
  };

  static Message fromJson(Map<String, dynamic> json) => Message(
      json['author'], DateTime.parse(json['timestamp']), json['content']);
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatGPT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();

  //历史聊天记录
  List<String> _historyFiles = [];

  //当前显示的聊天记录
  List<Message> _messages = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  //获取历史聊天记录，即获取聊天文件
  Future<void> _getHistoryFiles() async {
    final directory = Directory.fromUri(
        Uri.parse('${(await getApplicationDocumentsDirectory()).path}$DIR'));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    } else {
      final files = await directory.list().toList();
      setState(() {
        _historyFiles = files.map((file) => file.path).toList();
      });
    }
  }

  //从文件中读取信息，此时不是新建文件
  Future<void> restoreMessage(String dir) async {
    List<Message>? historyMessages = await readMessages(dir);
    setState(() {
      //展示历史对话详情
      _messages = historyMessages!;
    });
  }

  //通过openai的api发送网络请求
  Future<String> _getResponse(String message) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
        'Bearer YOUR_API_KEY',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'user', 'content': message},
        ],
      }),
    );
    final responseJson = json.decode(utf8.decode(response.bodyBytes));
    return responseJson['choices'][0]['message']['content'];
  }

  void _handleSubmitted(String text) async {
    String allText = '';
    int beginIndex =
    _messages.length - conversationTimes * 2 < 0 ? 0 : _messages.length;
    for (int i = beginIndex; i < _messages.length; i++) {
      allText += '${_messages[i].content}\n';
    }

    _textController.clear();
    setState(() {
      _messages.add(Message('用户', DateTime.now(), text));
    });

    final String response = await _getResponse('$allText 用户：$text');
    setState(() {
      _messages.add(Message('gpt', DateTime.now(), response.trim()));
    });
    writeMessages(_messages);
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: InputDecoration.collapsed(hintText: '发送消息'),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  _handleSubmitted(_textController.text);
                  writeMessages(_messages);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Chat'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("确认框"),
                      content: Text("您确定要开始新的聊天吗？"),
                      actions: [
                        TextButton(
                          child: Text("取消"),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: Text("确认"),
                          onPressed: () {
                            setState(() {
                              _messages = [];
                              currentMessageFileName = '';
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView.builder(
              itemCount: _historyFiles.length + 1,
              itemBuilder: (context, index) {
                EdgeInsets.all(index == 0 ? 0 : 8);
                if (index == 0) {
                  return SizedBox(
                    height: 60.0,
                    child: DrawerHeader(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '历史记录(长按删除)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.0,
                            ),
                          )
                        ],
                      ),
                      decoration: BoxDecoration(color: Colors.blue[500]),
                      margin: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                    ),
                  );
                }
                return ListTile(
                  title: Text(_historyFiles[index - 1].split('/').last),
                  onTap: () {
                    restoreMessage(_historyFiles[index - 1]);
                    Navigator.pop(context);
                  },
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text("确认框"),
                          content: Text("您确定要删除此条记录吗？"),
                          actions: [
                            TextButton(
                              child: Text("取消"),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: Text("确认"),
                              onPressed: () {
                                // 执行操作
                                deleteMessage(_historyFiles[index - 1]);
                                Navigator.of(context).pop();
                                _getHistoryFiles();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              }),
        ),
        onDrawerChanged: (isOpened) {
          if (isOpened) {
            // Do something when the drawer is opened
            _getHistoryFiles();
          }
        },
        body: Column(
          children: <Widget>[
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (_, int index) =>
                    _buildMessage(_messages[_messages.length - index - 1]),
              ),
            ),
            const Divider(height: 1.0),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
              ),
              child: _buildTextComposer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Message message) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: message.author == '用户' ? Colors.blue : Colors.green,
        child: Text(message.author),
      ),
      title: GestureDetector(
        child: Text(
          message.content,
        ),
      ),
      subtitle: Text(_formatTimestamp(message.timestamp)),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} 分钟前';
    } else {
      return '刚刚';
    }
  }
}
