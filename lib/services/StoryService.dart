import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:chat/centralized_import.dart';

class StoryService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;
  FirebaseStorage storage = FirebaseStorage.instance;

  StoryService() {
    ref = fireStore.collection(STORY_COLLECTION);
  }

  Future<DocumentReference> addStory(StoryModel data,
      {required String userId}) async {
    final doc = ref!.doc();

    await doc.set({
      ...data.toJson(),
      'id': doc.id,
      'userId': userId,
    });

    return doc;
  }

  Stream<List<StoryModel>> getAllStory() {
    return ref!.snapshots().map((snap) => snap.docs
        .map((e) => StoryModel.fromJson(e.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> updateStory(
      String storyId, Map<String, dynamic> updatedFields) async {
    try {
      await ref!.doc(storyId).update(updatedFields);
    } catch (e) {
      debugPrint('Error updating story: $e');
      rethrow;
    }
  }

  Future<void> addUserToSeenStatus(String storyId, int statusIndex,
      String seenId, String name, String imagePath) async {
    try {
      try {
        DocumentReference storyDoc = ref!.doc(storyId);

        Map<String, dynamic> userDetails = {
          'userId': seenId,
          'userName': name,
          'imagePath': imagePath,
        };

        await storyDoc.update({
          'seenUserList': FieldValue.arrayUnion([userDetails]),
        });

        print("User added to seenUserList successfully!");
      } catch (e) {
        print("Error adding user to seenUserList: $e");
      }
    } catch (e, s) {
      print("---------------118>>: $e");
      print("---------------119>>: $s");
    }
  }

  Stream<List<StoryModel>> getMyStory({String? uid}) {
    return ref!.where('userId', isEqualTo: uid).snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) =>
                StoryModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<String> uploadImage(File? image, String? filePath) async {
    String imageUrl = '';

    if (image != null) {
      Reference storageRef =
          FirebaseStorage.instance.ref().child(filePath ?? '');

      UploadTask uploadTask = storageRef.putFile(image);

      await uploadTask.then((e) async {
        await e.ref.getDownloadURL().then((value) async {
          imageUrl = value;
        });
      });
    }
    return imageUrl;
  }

  Future<File> urlToFile(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    final documentDirectory = await getTemporaryDirectory();
    final filePath = '${documentDirectory.path}/temp_image.jpg';
    final file = File(filePath);
    return file.writeAsBytes(response.bodyBytes);
  }

  Future<void> deleteStory({String? id, String? url}) async {
    log("-------110>>${id}");

    Reference fileRef = storage.refFromURL(url ?? '');

    await fileRef.delete().then((value) {
      ref!.doc(id).delete();
    }).catchError((e, s) {
      log("-------115>>${e.toString()}");
      log("-------118>>${s.toString()}");
    });
  }

  Future<void> deleteStoryText({String? id}) async {
    await ref!.doc(id).delete();
  }

  Future<List<StoryModel>> getStoriesData() async {
    try {
      var value = await ref!.get();
      return value.docs.map((y) {
        return StoryModel.fromJson(y.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      toast('error : $e', print: true);
      throw e;
    }
  }

  // Future<List<StoryModel>> getStoriesData() async {
  //   return ref!.get().then((value) {
  //     return value.docs.map((y) {
  //       return StoryModel.fromJson(y.data() as Map<String, dynamic>);
  //     }).toList();
  //   }).catchError((e) {
  //     toast('error : $e', print: true);
  //     throw e;
  //   });
  // }

  // Update Excluded/Included List
  // Future<void> updateStoryUsers(String storyId, List<String>? excludedUserList, List<String>? includedUserList) async {
  //   await ref!.doc(storyId).update({
  //     'excludedUserList': excludedUserList,
  //     'includedUserList': includedUserList,
  //   });
  // }
}
