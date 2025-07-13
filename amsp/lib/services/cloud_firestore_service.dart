import 'package:amsp/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class CloudFirestoreService {
  static final CloudFirestoreService _instance = 
  CloudFirestoreService._internal();
  final FirebaseFirestore _cloudFirestore = FirebaseFirestore.instance;

  factory CloudFirestoreService() {
    return _instance;
  }

  CloudFirestoreService._internal();
  
  Stream<List<UserModel>> getUser(String collection) {
    return _cloudFirestore.collection(collection).snapshots().map((Snapshot) {
      return Snapshot.docs
      .map((doc) => UserModel
      .fromDocumentSnapshot(doc))
      .toList();
      
      }
    );
  }
  

}