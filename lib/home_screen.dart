import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Hamburger menu
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            print('Menu pressed');
          },
        ),
      ),

      body: Column(
        children: [
          // Buttons
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      print('Find Driver pressed');
                    },
                    child: Text('Find Driver'),
                  ),

                  SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      print('Find Passenger pressed');
                    },
                    child: Text('Find Passenger'),
                  ),
                ],
              ),
            ),
          ),

          // Message history area
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(child: Text('Message History')),
          ),
        ],
      ),
    );
  }
}
