import 'package:chat/centralized_import.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

class PickupLayout extends StatelessWidget {
  final Widget? child;

  PickupLayout({this.child});

  @override
  Widget build(BuildContext context) {
    String uid = getStringAsync(userId);
    if (uid.isEmpty) {
      return child ?? SizedBox();
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: callService.callStream(uid: uid),
      builder: (context, snap) {
        if (snap.hasData && snap.data!.data() != null) {
          CallModel call =
              CallModel.fromJson(snap.data!.data() as Map<String, dynamic>);

          if (!call.hasDialed!) {
            return PickUpScreen(callModel: call);
          } else
            return child!;
        }
        return child!;
      },
    );
  }
}
