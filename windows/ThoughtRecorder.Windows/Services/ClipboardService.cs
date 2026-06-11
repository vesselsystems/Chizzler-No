using System;
using System.Runtime.InteropServices;
using System.Threading;
using WpfClipboard = System.Windows.Clipboard;
using WpfTextDataFormat = System.Windows.TextDataFormat;

namespace ThoughtRecorder.Windows.Services;

internal sealed class ClipboardService
{
    public enum PasteResult
    {
        Pasted,
        Copied
    }

    public bool WriteTextToClipboard(string text)
    {
        for (var attempt = 0; attempt < 3; attempt++)
        {
            try
            {
                WpfClipboard.Clear();
                WpfClipboard.SetText(text, WpfTextDataFormat.UnicodeText);
                return WpfClipboard.ContainsText() && WpfClipboard.GetText(WpfTextDataFormat.UnicodeText) == text;
            }
            catch (ExternalException)
            {
                Thread.Sleep(75);
            }
        }

        return false;
    }

    public PasteResult PasteTranscript(string text)
    {
        if (!WriteTextToClipboard(text))
        {
            throw new InvalidOperationException("Could not update the clipboard.");
        }

        return SendCtrlV() ? PasteResult.Pasted : PasteResult.Copied;
    }

    private static bool SendCtrlV()
    {
        var inputs = new[]
        {
            KeyboardInput(VirtualKey.Control, keyUp: false),
            KeyboardInput(VirtualKey.V, keyUp: false),
            KeyboardInput(VirtualKey.V, keyUp: true),
            KeyboardInput(VirtualKey.Control, keyUp: true)
        };

        return SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Input>()) == inputs.Length;
    }

    private static Input KeyboardInput(ushort virtualKey, bool keyUp)
    {
        return new Input
        {
            Type = InputKeyboard,
            Data = new InputUnion
            {
                Keyboard = new KeyboardInputData
                {
                    VirtualKey = virtualKey,
                    Flags = keyUp ? KeyEventKeyUp : 0
                }
            }
        };
    }

    private const int InputKeyboard = 1;
    private const uint KeyEventKeyUp = 0x0002;

    private static class VirtualKey
    {
        public const ushort Control = 0x11;
        public const ushort V = 0x56;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Input
    {
        public int Type;
        public InputUnion Data;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)]
        public KeyboardInputData Keyboard;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KeyboardInputData
    {
        public ushort VirtualKey;
        public ushort ScanCode;
        public uint Flags;
        public uint Time;
        public nint ExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint numberOfInputs, Input[] inputs, int sizeOfInputStructure);
}
