package quickenhance

import (
	"context"
	"runtime"
	"sync"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
	"screen-memory-assistant/internal/enhancer"
	"screen-memory-assistant/internal/overlay"
)

// QuickEnhance provides global hotkey functionality for text enhancement
type QuickEnhance struct {
	enhancer    *enhancer.Enhancer
	overlay     *overlay.Overlay
	ctx         context.Context
	cancel      context.CancelFunc
	running     bool
	mu          sync.RWMutex
	callback    func(text string)
	hotkeyID    int
}

// EnhancementResult is an alias to the enhancer package type
type EnhancementResult = enhancer.EnhancementResult

// MemoryInfo is an alias to the enhancer package type
type MemoryInfo = enhancer.MemoryInfo

// Windows API constants
const (
	modAlt         = 0x0001
	modControl     = 0x0002
	modShift       = 0x0004
	modWin         = 0x0008
	vkE            = 0x45
	wmHotkey       = 0x0312
	cfUnicodeText  = 13
)

var (
	user32DLL            = windows.NewLazySystemDLL("user32.dll")
	kernel32DLL          = windows.NewLazySystemDLL("kernel32.dll")
	procRegisterHotKey   = user32DLL.NewProc("RegisterHotKey")
	procUnregisterHotKey = user32DLL.NewProc("UnregisterHotKey")
	procPeekMessage      = user32DLL.NewProc("PeekMessageW")
	procTranslateMessage = user32DLL.NewProc("TranslateMessage")
	procDispatchMessage  = user32DLL.NewProc("DispatchMessageW")
	procOpenClipboard    = user32DLL.NewProc("OpenClipboard")
	procCloseClipboard   = user32DLL.NewProc("CloseClipboard")
	procEmptyClipboard   = user32DLL.NewProc("EmptyClipboard")
	procGetClipboardData = user32DLL.NewProc("GetClipboardData")
	procSetClipboardData = user32DLL.NewProc("SetClipboardData")
	procGlobalLock       = kernel32DLL.NewProc("GlobalLock")
	procGlobalUnlock     = kernel32DLL.NewProc("GlobalUnlock")
	procGlobalAlloc      = kernel32DLL.NewProc("GlobalAlloc")
	procGlobalFree       = kernel32DLL.NewProc("GlobalFree")
	procRtlMoveMemory    = kernel32DLL.NewProc("RtlMoveMemory")
	procGetCursorPos     = user32DLL.NewProc("GetCursorPos")
)

// New creates a new QuickEnhance instance
func New(enhancer *enhancer.Enhancer) *QuickEnhance {
	ctx, cancel := context.WithCancel(context.Background())
	return &QuickEnhance{
		enhancer: enhancer,
		ctx:      ctx,
		cancel:   cancel,
		hotkeyID: 1,
	}
}

// SetCallback sets the function to call when text is captured
func (q *QuickEnhance) SetCallback(callback func(text string)) {
	q.mu.Lock()
	q.callback = callback
	q.mu.Unlock()
}

// Start begins listening for the global hotkey and starts overlay
func (q *QuickEnhance) Start() error {
	q.mu.Lock()
	if q.running {
		q.mu.Unlock()
		return nil
	}
	q.running = true
	q.mu.Unlock()

	// Create and start overlay
	ov, err := overlay.NewOverlay(q.handleOverlayClick)
	if err != nil {
		return err
	}
	q.overlay = ov
	
	if err := ov.Start(); err != nil {
		return err
	}

	// Start hotkey listener
	go q.hotkeyListener()

	return nil
}

// Stop stops the hotkey listener and overlay
func (q *QuickEnhance) Stop() {
	q.cancel()
	q.unregisterHotkey()
	if q.overlay != nil {
		q.overlay.Stop()
	}
	q.mu.Lock()
	q.running = false
	q.mu.Unlock()
}

// handleOverlayClick is called when user clicks the floating button
func (q *QuickEnhance) handleOverlayClick() {
	// Trigger the callback
	q.mu.RLock()
	callback := q.callback
	q.mu.RUnlock()
	
	if callback != nil {
		callback("")
	}
}

// ShowOverlay shows the floating button at cursor position
func (q *QuickEnhance) ShowOverlay() {
	if q.overlay == nil {
		return
	}
	
	var pt struct {
		X int32
		Y int32
	}
	procGetCursorPos.Call(uintptr(unsafe.Pointer(&pt)))
	q.overlay.Show(int(pt.X), int(pt.Y))
}

// HideOverlay hides the floating button
func (q *QuickEnhance) HideOverlay() {
	if q.overlay != nil {
		q.overlay.Hide()
	}
}

// hotkeyListener listens for the global hotkey
func (q *QuickEnhance) hotkeyListener() {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	// Register hotkey: Ctrl+Alt+E
	if !q.registerHotkey() {
		return
	}
	defer q.unregisterHotkey()

	// Message loop
	var msg struct {
		Hwnd    windows.HWND
		Message uint32
		WParam  uintptr
		LParam  uintptr
		Time    uint32
		PtX     int32
		PtY     int32
	}
	
	for {
		select {
		case <-q.ctx.Done():
			return
		default:
		}

		// PeekMessage with PM_REMOVE = 1
		ret, _, _ := procPeekMessage.Call(
			uintptr(unsafe.Pointer(&msg)),
			0, 0, 0, 1,
		)

		if ret != 0 {
			if msg.Message == wmHotkey && int(msg.WParam) == q.hotkeyID {
				go q.handleHotkey()
			}
			procTranslateMessage.Call(uintptr(unsafe.Pointer(&msg)))
			procDispatchMessage.Call(uintptr(unsafe.Pointer(&msg)))
		}

		time.Sleep(10 * time.Millisecond)
	}
}

// registerHotkey registers the global hotkey
func (q *QuickEnhance) registerHotkey() bool {
	// Try Ctrl+Alt+E
	mods := uint32(modControl | modAlt)
	ret, _, _ := procRegisterHotKey.Call(0, uintptr(q.hotkeyID), uintptr(mods), uintptr(vkE))
	
	if ret == 0 {
		// Try Win+Shift+E as fallback
		mods = uint32(modWin | modShift)
		ret, _, _ = procRegisterHotKey.Call(0, uintptr(q.hotkeyID), uintptr(mods), uintptr(vkE))
		if ret == 0 {
			return false
		}
	}
	
	return true
}

// unregisterHotkey unregisters the global hotkey
func (q *QuickEnhance) unregisterHotkey() {
	procUnregisterHotKey.Call(0, uintptr(q.hotkeyID))
}

// handleHotkey processes the hotkey press
func (q *QuickEnhance) handleHotkey() {
	// Get selected text by copying it
	text := q.getSelectedText()
	
	// Show overlay at cursor position
	var pt struct {
		X int32
		Y int32
	}
	procGetCursorPos.Call(uintptr(unsafe.Pointer(&pt)))
	q.overlay.Show(int(pt.X), int(pt.Y))
	
	// Call the callback with the captured text
	q.mu.RLock()
	callback := q.callback
	q.mu.RUnlock()
	
	if callback != nil {
		callback(text)
	}
}

// getSelectedText copies the current selection and returns it
func (q *QuickEnhance) getSelectedText() string {
	// Save current clipboard
	savedClipboard := q.getClipboardText()
	
	// Small delay
	time.Sleep(50 * time.Millisecond)
	
	// Clear clipboard
	q.setClipboardText("")
	time.Sleep(20 * time.Millisecond)
	
	// Send Ctrl+C using keybd_event
	q.sendCtrlC()
	
	// Wait for clipboard
	time.Sleep(100 * time.Millisecond)
	
	// Read clipboard
	text := q.getClipboardText()
	
	// Restore original clipboard after delay
	go func() {
		time.Sleep(200 * time.Millisecond)
		q.setClipboardText(savedClipboard)
	}()
	
	return text
}

// sendCtrlC simulates Ctrl+C
func (q *QuickEnhance) sendCtrlC() {
	// Use keybd_event to send Ctrl+C
	// VK_CONTROL = 0x11, VK_C = 0x43
	keybdEvent := user32DLL.NewProc("keybd_event")
	
	// Press Ctrl
	keybdEvent.Call(0x11, 0, 0, 0)
	// Press C
	keybdEvent.Call(0x43, 0, 0, 0)
	// Release C
	keybdEvent.Call(0x43, 0, 2, 0)
	// Release Ctrl
	keybdEvent.Call(0x11, 0, 2, 0)
}

// getClipboardText gets text from clipboard
func (q *QuickEnhance) getClipboardText() string {
	// Open clipboard
	ret, _, _ := procOpenClipboard.Call(0)
	if ret == 0 {
		return ""
	}
	defer procCloseClipboard.Call()

	// Get clipboard data
	handle, _, _ := procGetClipboardData.Call(cfUnicodeText)
	if handle == 0 {
		return ""
	}

	// Lock memory
	ptr, _, _ := procGlobalLock.Call(handle)
	if ptr == 0 {
		return ""
	}
	defer procGlobalUnlock.Call(handle)

	// Convert to Go string (UTF-16)
	return windows.UTF16PtrToString((*uint16)(unsafe.Pointer(ptr)))
}

// setClipboardText sets text to clipboard
func (q *QuickEnhance) setClipboardText(text string) bool {
	// Open clipboard
	ret, _, _ := procOpenClipboard.Call(0)
	if ret == 0 {
		return false
	}
	defer procCloseClipboard.Call()

	// Empty clipboard
	procEmptyClipboard.Call()

	if text == "" {
		return true
	}

	// Convert to UTF-16
	utf16Text, err := windows.UTF16FromString(text)
	if err != nil {
		return false
	}

	// Calculate size
	size := len(utf16Text) * 2

	// Allocate global memory
	hGlobal, _, _ := procGlobalAlloc.Call(0x0042, uintptr(size)) // GHND = 0x0042
	if hGlobal == 0 {
		return false
	}

	// Lock memory
	ptr, _, _ := procGlobalLock.Call(hGlobal)
	if ptr == 0 {
		procGlobalFree.Call(hGlobal)
		return false
	}

	// Copy data
	procRtlMoveMemory.Call(ptr, uintptr(unsafe.Pointer(&utf16Text[0])), uintptr(size))
	procGlobalUnlock.Call(hGlobal)

	// Set clipboard data
	ret, _, _ = procSetClipboardData.Call(cfUnicodeText, hGlobal)
	return ret != 0
}

// EnhancePrompt enhances the given prompt
func (q *QuickEnhance) EnhancePrompt(prompt string) (*EnhancementResult, error) {
	ctx, cancel := context.WithTimeout(q.ctx, 10*time.Second)
	defer cancel()
	
	return q.enhancer.Enhance(ctx, prompt, "", 5)
}

// PasteEnhanced pastes the enhanced text
func (q *QuickEnhance) PasteEnhanced(text string) {
	// Save current clipboard
	savedClipboard := q.getClipboardText()
	
	// Set enhanced text
	q.setClipboardText(text)
	time.Sleep(50 * time.Millisecond)
	
	// Send Ctrl+V
	q.sendCtrlV()
	
	// Restore original clipboard
	go func() {
		time.Sleep(500 * time.Millisecond)
		q.setClipboardText(savedClipboard)
	}()
}

// sendCtrlV simulates Ctrl+V
func (q *QuickEnhance) sendCtrlV() {
	keybdEvent := user32DLL.NewProc("keybd_event")
	
	// Press Ctrl
	keybdEvent.Call(0x11, 0, 0, 0)
	// Press V
	keybdEvent.Call(0x56, 0, 0, 0)
	// Release V
	keybdEvent.Call(0x56, 0, 2, 0)
	// Release Ctrl
	keybdEvent.Call(0x11, 0, 2, 0)
}

// GetSelectedText gets currently selected text (public method for app.go)
func (q *QuickEnhance) GetSelectedText() string {
	return q.getSelectedText()
}
