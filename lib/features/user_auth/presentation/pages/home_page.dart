import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../global/common/toast.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController _nameController = TextEditingController();
  TextEditingController _detailsController = TextEditingController();
  double? latitude;
  double? longitude;
  File? _image;

  @override
  void initState() {
    super.initState();
    _getLocation(); // Call _getLocation function when the homepage loads
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle poppinsStyle = TextStyle(
      fontFamily: 'Poppins',
    );

    return Scaffold(
      backgroundColor: Color(0xFFA090FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(""),
        elevation: 0.0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("leads").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No Leads Yet", style: poppinsStyle));
          }
          final leads = snapshot.data!.docs;
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: leads.length,
            itemBuilder: (context, index) {
              var lead = leads[index];
              return Container(
                margin: EdgeInsets.only(top: 8.0, bottom: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Dismissible(
                  key: UniqueKey(),
                  onDismissed: (direction) async {
                    await _deleteLead(lead.id);
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20.0),
                    child: Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  child: ListTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Name:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          lead['placeName'],
                          style: poppinsStyle,
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 5),
                        Text(
                          'Details:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          lead['placeDetails'],
                          style: poppinsStyle,
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Latitude: ${lead['latitude']}, Longitude: ${lead['longitude']}',
                          style: poppinsStyle,
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        _showDeleteConfirmationDialog(lead.id);
                      },
                    ),
                    onTap: () {
                      // Add any action when the lead tile is tapped
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: GestureDetector(
        onTap: () {
          FirebaseAuth.instance.signOut();
          Navigator.pushNamed(context, "/login");
          showToast(message: "Successfully signed out");
        },
        child: Container(
          height: 45,
          width: double.infinity,
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              "Sign out",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showLeadForm(context);
          _getLocation();
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _showLeadForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Place Name'),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _detailsController,
                decoration: InputDecoration(labelText: 'Place Details'),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      initialValue: latitude != null ? latitude.toString() : '',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      initialValue: longitude != null ? longitude.toString() : '',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(height: 10), // Add some space between buttons
              ElevatedButton(
                onPressed: _sendLeadDetails, // Call method to send lead details
                child: Text('Send Lead'), //
              ),
            ],
          ),
        );
      },
    );
  }

  void _getLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
    } catch (e) {
      print('Error getting location: $e');
      // Handle location retrieval errors here
    }
  }

  void _sendLeadDetails() {
    String placeName = _nameController.text;
    String placeDetails = _detailsController.text;
    double? lat = latitude;
    double? long = longitude;

    // Check if all fields are filled
    if (placeName.isNotEmpty &&
        placeDetails.isNotEmpty &&
        lat != null &&
        long != null) {
      // Create a new lead document in Firestore
      FirebaseFirestore.instance.collection('leads').add({
        'placeName': placeName,
        'placeDetails': placeDetails,
        'latitude': lat,
        'longitude': long,
        'timestamp': DateTime.now(), // Add timestamp for tracking
      }).then((value) {
        // Clear text fields after sending lead details
        _nameController.clear();
        _detailsController.clear();
        setState(() {
          latitude = null;
          longitude = null;
        });
        // Show toast message or any other feedback
        // Show toast message or any other feedback to the user
        showToast(message: 'Lead details sent successfully');
      }).catchError((error) {
        // Handle errors if any
        print('Error sending lead details: $error');
        showToast(message: 'Failed to send lead details');
      });
    } else {
      // Show error message if any field is empty
      showToast(message: 'Please fill all fields before sending');
    }
  }

  Future<void> _deleteLead(String leadId) async {
    try {
      await FirebaseFirestore.instance.collection('leads').doc(leadId).delete();
    } catch (e) {
      print('Error deleting lead: $e');
    }
  }

  Future<void> _showDeleteConfirmationDialog(String leadId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete this lead?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _deleteLead(leadId);
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text(
                "Delete",
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_image != null) {
      // Implement image upload to Firebase Storage here
    } else {
      showToast(message: 'Please select an image first');
    }
  }
}
