using System;
using System.Runtime.InteropServices;
using System.Drawing;

class Program
{
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct GUITHREADINFO
    {
        public int cbSize;
        public int flags;
        public IntPtr hwndActive;
        public IntPtr hwndFocus;
        public IntPtr hwndCapture;
        public IntPtr hwndMenuOwner;
        public IntPtr hwndMoveSize;
        public IntPtr hwndCaret;
        public Rectangle rcCaret;
    }

    [DllImport("user32.dll")]
    static extern bool GetGUIThreadInfo(uint idThread, ref GUITHREADINFO lpgui);

    [DllImport("user32.dll")]
    static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);

    static void Main()
    {
        IntPtr hWnd = GetForegroundWindow();
        if (hWnd != IntPtr.Zero)
        {
            uint processId;
            uint threadId = GetWindowThreadProcessId(hWnd, out processId);

            GUITHREADINFO guiInfo = new GUITHREADINFO();
            guiInfo.cbSize = Marshal.SizeOf(guiInfo);

            if (GetGUIThreadInfo(threadId, ref guiInfo))
            {
                if (guiInfo.hwndCaret != IntPtr.Zero)
                {
                    POINT pt = new POINT();
                    pt.X = guiInfo.rcCaret.X;
                    pt.Y = guiInfo.rcCaret.Y;

                    ClientToScreen(guiInfo.hwndCaret, ref pt);

                    Console.WriteLine("{\"x\": " + pt.X + ", \"y\": " + pt.Y + ", \"height\": " + guiInfo.rcCaret.Height + "}");
                    return;
                }
            }
        }
        Console.WriteLine("{\"error\": \"Could not get caret position\"}");
    }
}
