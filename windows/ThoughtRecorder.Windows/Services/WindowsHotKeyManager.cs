using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace ThoughtRecorder.Windows.Services;

internal sealed class WindowsHotKeyManager : IDisposable
{
    public enum EventKind
    {
        RecordKeyDown,
        RecordKeyUp,
        Cancel
    }

    private readonly Action<EventKind> handler;
    private readonly HashSet<int> pressedKeys = new();
    private readonly LowLevelKeyboardProc keyboardProc;

    private nint hookHandle;
    private bool recordChordActive;
    private bool disposed;

    public WindowsHotKeyManager(Action<EventKind> handler)
    {
        this.handler = handler;
        keyboardProc = HandleKeyboardEvent;
    }

    public void Start()
    {
        using var currentProcess = Process.GetCurrentProcess();
        using var currentModule = currentProcess.MainModule;
        var moduleHandle = currentModule is null ? nint.Zero : GetModuleHandle(currentModule.ModuleName);

        hookHandle = SetWindowsHookEx(WhKeyboardLl, keyboardProc, moduleHandle, 0);
        if (hookHandle == nint.Zero)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not install the global keyboard hook.");
        }
    }

    private nint HandleKeyboardEvent(int code, nint wParam, nint lParam)
    {
        if (code < 0)
        {
            return CallNextHookEx(hookHandle, code, wParam, lParam);
        }

        var eventCode = wParam.ToInt32();
        var keyboardEvent = Marshal.PtrToStructure<KeyboardHookStruct>(lParam);
        var virtualKey = (int)keyboardEvent.VirtualKeyCode;

        if (eventCode is WmKeyDown or WmSysKeyDown)
        {
            pressedKeys.Add(virtualKey);

            if (virtualKey == VirtualKey.Escape)
            {
                handler(EventKind.Cancel);
            }

            if (!recordChordActive && IsRecordChordPressed())
            {
                recordChordActive = true;
                handler(EventKind.RecordKeyDown);
            }
        }
        else if (eventCode is WmKeyUp or WmSysKeyUp)
        {
            pressedKeys.Remove(virtualKey);

            if (recordChordActive && !IsRecordChordPressed())
            {
                recordChordActive = false;
                handler(EventKind.RecordKeyUp);
            }
        }

        return CallNextHookEx(hookHandle, code, wParam, lParam);
    }

    private bool IsRecordChordPressed()
    {
        return pressedKeys.Contains(VirtualKey.Space)
            && HasPressedKey(VirtualKey.Control, VirtualKey.LeftControl, VirtualKey.RightControl)
            && HasPressedKey(VirtualKey.Menu, VirtualKey.LeftMenu, VirtualKey.RightMenu)
            && HasPressedKey(VirtualKey.Shift, VirtualKey.LeftShift, VirtualKey.RightShift);
    }

    private bool HasPressedKey(params int[] virtualKeys)
    {
        foreach (var virtualKey in virtualKeys)
        {
            if (pressedKeys.Contains(virtualKey))
            {
                return true;
            }
        }

        return false;
    }

    public void Dispose()
    {
        if (disposed)
        {
            return;
        }

        disposed = true;
        if (hookHandle != nint.Zero)
        {
            UnhookWindowsHookEx(hookHandle);
            hookHandle = nint.Zero;
        }
    }

    private const int WhKeyboardLl = 13;
    private const int WmKeyDown = 0x0100;
    private const int WmKeyUp = 0x0101;
    private const int WmSysKeyDown = 0x0104;
    private const int WmSysKeyUp = 0x0105;

    private static class VirtualKey
    {
        public const int Space = 0x20;
        public const int Escape = 0x1B;
        public const int Control = 0x11;
        public const int LeftControl = 0xA2;
        public const int RightControl = 0xA3;
        public const int Shift = 0x10;
        public const int LeftShift = 0xA0;
        public const int RightShift = 0xA1;
        public const int Menu = 0x12;
        public const int LeftMenu = 0xA4;
        public const int RightMenu = 0xA5;
    }

    private delegate nint LowLevelKeyboardProc(int code, nint wParam, nint lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct KeyboardHookStruct
    {
        public uint VirtualKeyCode;
        public uint ScanCode;
        public uint Flags;
        public uint Time;
        public nint ExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern nint SetWindowsHookEx(int hookType, LowLevelKeyboardProc callback, nint moduleHandle, uint threadId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(nint hookHandle);

    [DllImport("user32.dll")]
    private static extern nint CallNextHookEx(nint hookHandle, int code, nint wParam, nint lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern nint GetModuleHandle(string? moduleName);
}
