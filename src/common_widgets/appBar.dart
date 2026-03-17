import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../features/authentication/controllers/login_controller.dart';

class NAppBar extends StatelessWidget implements PreferredSize {
  final Widget? title;

  final List<Widget>? actions;
  final loginController = Get.put(LoginController());

  final IconData? leadingIcon;

  final VoidCallback? leadingOnPressed;

  final bool showBackArrow;

  NAppBar(
      {super.key,
      this.title,
      this.actions,
      this.leadingIcon,
      this.leadingOnPressed,
      required this.showBackArrow });

  @override
  Widget build(BuildContext context) {
    return (Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: child,
    ));
    throw UnimplementedError();
  }

  @override
  // TODO: implement preferredSize
  Size get preferredSize => Size.fromHeight(50);

  @override
  // TODO: implement child
  Widget get child => (AppBar(
        automaticallyImplyLeading: false,
        title: Obx(() => Text(loginController.user.value.name)),
        actions: actions,
        leading: showBackArrow
            ? IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios))
            : leadingIcon != null
                ? IconButton(
                    onPressed: leadingOnPressed, icon: Icon(leadingIcon))
                : null,
      ));
}
