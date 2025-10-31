import 'package:flutter/material.dart';
import 'package:werewolf_arena/router/router.dart';

class DialogUtil {
  static final DialogUtil instance = DialogUtil._();

  DialogUtil._();

  Future<void> show(String message, {String? title}) async {
    await showDialog(
      context: globalKey.currentContext!,
      builder: (context) => AlertDialog(
        title: Text(title ?? '提示'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('确定'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<bool> confirm(String message, {String? title}) async {
    final result = await showDialog<bool>(
      context: globalKey.currentContext!,
      builder: (context) => AlertDialog(
        title: Text(title ?? '提示'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('确定'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
