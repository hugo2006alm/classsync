import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _CreateMutexNative =
    IntPtr Function(Pointer<Void>, Int32, Pointer<Utf16>);
typedef _CreateMutexDart = int Function(Pointer<Void>, int, Pointer<Utf16>);
typedef _GetLastErrorNative = Uint32 Function();
typedef _GetLastErrorDart = int Function();
typedef _CloseHandleNative = Int32 Function(IntPtr);
typedef _CloseHandleDart = int Function(int);
typedef _FindWindowNative = IntPtr Function(Pointer<Utf16>, Pointer<Utf16>);
typedef _FindWindowDart = int Function(Pointer<Utf16>, Pointer<Utf16>);
typedef _ShowWindowNative = Int32 Function(IntPtr, Int32);
typedef _ShowWindowDart = int Function(int, int);
typedef _SetForegroundWindowNative = Int32 Function(IntPtr);
typedef _SetForegroundWindowDart = int Function(int);

class SingleInstanceService {
  static final List<int> _heldMutexes = [];

  static bool acquire() {
    if (!Platform.isWindows) return true;
    if (_heldMutexes.isNotEmpty) return true;
    final kernel = DynamicLibrary.open('kernel32.dll');
    final createMutex = kernel
        .lookupFunction<_CreateMutexNative, _CreateMutexDart>('CreateMutexW');
    final getLastError = kernel
        .lookupFunction<_GetLastErrorNative, _GetLastErrorDart>('GetLastError');
    final closeHandle = kernel
        .lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');
    final name = 'Local\\ClassSync.Desktop.Singleton'.toNativeUtf16();
    final handle = createMutex(nullptr, 1, name);
    calloc.free(name);
    if (handle == 0) return false;
    if (getLastError() == 183) {
      closeHandle(handle);
      _activateExistingWindow();
      return false;
    }
    _heldMutexes.add(handle);
    return true;
  }

  static void _activateExistingWindow() {
    final user32 = DynamicLibrary.open('user32.dll');
    final findWindow = user32
        .lookupFunction<_FindWindowNative, _FindWindowDart>('FindWindowW');
    final showWindow = user32
        .lookupFunction<_ShowWindowNative, _ShowWindowDart>('ShowWindow');
    final foreground = user32
        .lookupFunction<_SetForegroundWindowNative, _SetForegroundWindowDart>(
          'SetForegroundWindow',
        );
    final title = 'ClassSync'.toNativeUtf16();
    final window = findWindow(nullptr, title);
    calloc.free(title);
    if (window == 0) return;
    showWindow(window, 9);
    foreground(window);
  }
}
