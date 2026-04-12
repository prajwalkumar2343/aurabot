using System;
using System.Windows.Automation;
using System.Windows.Automation.Text;
using System.Windows;
using System.Runtime.InteropServices;

namespace GlobalCaretPosition
{
    class Program
    {
        static void Main(string[] args)
        {
            try
            {
                // Try to get focused element via UI Automation
                AutomationElement focusedElement = AutomationElement.FocusedElement;
                if (focusedElement != null)
                {
                    // Check if it supports TextPattern
                    object patternObj;
                    if (focusedElement.TryGetCurrentPattern(TextPattern.Pattern, out patternObj))
                    {
                        TextPattern textPattern = (TextPattern)patternObj;
                        TextPatternRange[] selection = textPattern.GetSelection();
                        
                        if (selection != null && selection.Length > 0)
                        {
                            Rect[] rects = selection[0].GetBoundingRectangles();
                            if (rects != null && rects.Length > 0)
                            {
                                Rect caretRect = rects[0];
                                Console.WriteLine(string.Format("{{\"x\": {0}, \"y\": {1}, \"height\": {2}, \"width\": {3}}}", (int)caretRect.X, (int)caretRect.Y, (int)caretRect.Height, (int)caretRect.Width));
                                return;
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                // Ignore UIA errors and fallback
            }

            // Fallback to GetGUIThreadInfo for Classic Windows Apps (Notepad, Word, etc.)
            FallbackWin32Caret();
        }

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
            public Rect rcCaret;
        }

        [DllImport("user32.dll")]
        static extern bool GetGUIThreadInfo(uint idThread, ref GUITHREADINFO lpgui);

        [DllImport("user32.dll")]
        static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll")]
        static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);

        static void FallbackWin32Caret()
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
                        pt.X = (int)guiInfo.rcCaret.X;
                        pt.Y = (int)guiInfo.rcCaret.Y;

                        ClientToScreen(guiInfo.hwndCaret, ref pt);

                        Console.WriteLine(string.Format("{{\"x\": {0}, \"y\": {1}, \"height\": {2}}}", pt.X, pt.Y, (int)guiInfo.rcCaret.Height));
                        return;
                    }
                }
            }
            Console.WriteLine("{\"error\": \"Could not get caret position\"}");
        }
    }
}
