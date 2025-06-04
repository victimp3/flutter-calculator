import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator Logic',
      home: CalculatorUI(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CalculatorController {
  double? firstNumber;
  String? operation;

  String calculate(String secondNumberStr) {
    double secondNumber = double.tryParse(secondNumberStr) ?? 0;
    if (firstNumber == null || operation == null) return 'Error';

    double result = 0;
    switch (operation) {
      case '+':
        result = firstNumber! + secondNumber;
        break;
      case '-':
        result = firstNumber! - secondNumber;
        break;
      case '*':
        result = firstNumber! * secondNumber;
        break;
      case '/':
        result = secondNumber != 0 ? firstNumber! / secondNumber : double.nan;
        break;
      default:
        return 'Error';
    }

    if (result == result.toInt()) {
      return result.toInt().toString();
    } else {
      return result.toString();
    }
  }
}

class CalculatorUI extends StatefulWidget {
  @override
  _CalculatorUIState createState() => _CalculatorUIState();
}

class _CalculatorUIState extends State<CalculatorUI> {
  final List<String> buttons = [
    'C', '/', '*', '-',
    '7', '8', '9', '+',
    '4', '5', '6', '=',
    '1', '2', '3', '.',
    '0',
  ];

  String display = '0';
  String input = '';
  final controller = CalculatorController();

  void saveToFirestore(String expression, String result) async {
    final now = DateTime.now();
    final formattedTime =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await FirebaseFirestore.instance.collection('history').add({
      'expression': expression,
      'result': result,
      'timestamp': formattedTime,
    });
  }

  void onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        display = '0';
        input = '';
      } else if (value == '=') {
        try {
          Parser p = Parser();
          Expression exp = p.parse(input);
          ContextModel cm = ContextModel();
          double eval = exp.evaluate(EvaluationType.REAL, cm);
          String result = eval.toStringAsFixed(
              eval.truncateToDouble() == eval ? 0 : 2);

          saveToFirestore(input, result);

          display = result;
          input = '';
        } catch (e) {
          display = 'Error';
        }
      } else {
        input += value;
        display = input;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Calculator', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.swap_horiz),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => KmToMileConverter()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.bottomRight,
                padding: EdgeInsets.all(24),
                child: Text(
                  display,
                  style: TextStyle(color: Colors.white, fontSize: 48),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: GridView.builder(
                itemCount: buttons.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  return ElevatedButton(
                    onPressed: () => onButtonPressed(buttons[index]),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[850],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      buttons[index],
                      style: TextStyle(fontSize: 24),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KmToMileConverter extends StatefulWidget {
  @override
  _KmToMileConverterState createState() => _KmToMileConverterState();
}

class _KmToMileConverterState extends State<KmToMileConverter> {
  String kmInput = '';
  String result = '';

  void convert() {
    double km = double.tryParse(kmInput) ?? 0;
    double miles = km * 0.621371;
    setState(() {
      result = '${miles.toStringAsFixed(2)} miles';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Km to Mile Converter',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter km',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => kmInput = value,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: convert,
              child: Text('Convert', style: TextStyle(fontSize: 24)),
            ),
            SizedBox(height: 20),
            Text(
              result,
              style: TextStyle(color: Colors.white, fontSize: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<List<String>> loadHistory() async {
    final query = await FirebaseFirestore.instance
        .collection('history')
        .orderBy('timestamp', descending: true)
        .get();
    return query.docs
        .map((doc) =>
    '${doc['expression']} = ${doc['result']} (${doc['timestamp']})')
        .toList()
        .cast<String>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('History', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<String>>(
        future: loadHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Error loading history',
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text('No history yet.',
                    style: TextStyle(color: Colors.white)));
          }
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              return Text(
                snapshot.data![index],
                style: TextStyle(color: Colors.white, fontSize: 18),
              );
            },
          );
        },
      ),
    );
  }
}