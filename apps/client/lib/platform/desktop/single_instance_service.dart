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
typedef _FindWindowNative =
    IntPtr Function(IntPtr, IntPtr, Pointer<Utf16>, Pointer<Utf16>);
typedef _FindWindowDart =
    int Function(int, int, Pointer<Utf16>, Pointer<Utf16>);

typedef _WindowProcessNative = Uint32 Function(IntPtr, Pointer<Uint32>);
typedef _WindowProcessDart = int Function(int, Pointer<Uint32>);

typedef _GetWindowStyleNative = IntPtr Function(IntPtr, Int32);
typedef _GetWindowStyleDart = int Function(int, int);
typedef _SetWindowStyleNative = IntPtr Function(IntPtr, Int32, IntPtr);
typedef _SetWindowStyleDart = int Function(int, int, int);
typedef _ShowWindowNative = Int32 Function(IntPtr, Int32);
typedef _ShowWindowDart = int Function(int, int);
typedef _SetForegroundWindowNative = Int32 Function(IntPtr);
typedef _SetForegroundWindowDart = int Function(int);

class SingleInstanceService {
  static final List<int> _heldMutexes = [];

  static bool acquire({bool activateExisting = true}) {
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
      if (activateExisting) _activateExistingWindow();
      return false;
    }
    _heldMutexes.add(handle);
    return true;
  }

  static void _activateExistingWindow() {
    final user32 = DynamicLibrary.open('user32.dll');
    final findWindow = user32
        .lookupFunction<_FindWindowNative, _FindWindowDart>('FindWindowExW');
    final windowProcess = user32
        .lookupFunction<_WindowProcessNative, _WindowProcessDart>(
          'GetWindowThreadProcessId',
        );
    final getStyle = user32
        .lookupFunction<_GetWindowStyleNative, _GetWindowStyleDart>(
          'GetWindowLongPtrW',
        );
    final setStyle = user32
        .lookupFunction<_SetWindowStyleNative, _SetWindowStyleDart>(
          'SetWindowLongPtrW',
        );
    final showWindow = user32
        .lookupFunction<_ShowWindowNative, _ShowWindowDart>('ShowWindow');
    final foreground = user32
        .lookupFunction<_SetForegroundWindowNative, _SetForegroundWindowDart>(
          'SetForegroundWindow',
        );
    final title = 'ClassSync'.toNativeUtf16();
    final owner = calloc<Uint32>();
    try {
      var window = 0;
      while ((window = findWindow(0, window, nullptr, title)) != 0) {
        windowProcess(window, owner);
        // Flutter has already created this second process's hidden native
        // window. Activate the original process, never our own duplicate.
        if (owner.value == pid) continue;
        // Reverse window_manager's skip-taskbar style when opening from a
        // shortcut after a tray-only login or close-to-tray.
        showWindow(window, 0);
        setStyle(window, -20, (getStyle(window, -20) & ~0x80) | 0x40000);
        showWindow(window, 9);
        foreground(window);
        return;
      }
    } finally {
      calloc.free(owner);
      calloc.free(title);
    }
  }
}
