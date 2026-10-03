import 'package:flutter/material.dart';

//Isse bina BuildContext ke bhi overlay (message bubble), dialog ya navigation
//kar sakte hain, jaise API layer ya viewmodel se.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNavigator',
);