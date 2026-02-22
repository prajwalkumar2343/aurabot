package overlay

import (
	"context"
	"fmt"
	"log"
	"runtime"
	"sync"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

// Point represents a point
type Point struct {
	X int32
	Y int32
}

// Rect represents a rectangle
type Rect struct {
	Left   int32
	Top    int32
	Right  int32
	Bottom int32
}

// Overlay creates a system-wide floating button that appears near text selections
type Overlay struct {
	hwnd       uintptr
	visible    bool
	mu         sync.RWMutex
	onClick    func()
	ctx        context.Context
	cancel     context.CancelFunc
	lastPos    Point
}

const (
	wsExToolWindow  = 0x00000080
	wsExNoActivate  = 0x08000000
	wsExTopMost     = 0x00000008
	wsExLayered     = 0x00080000
	wsPopup         = 0x80000000
	wsVisible       = 0x10000000
	cwUseDefault    = 0x80000000
	swShow          = 5
	swHide          = 0
	wmPaint         = 0x000F
	wmClose         = 0x0010
	wmLButtonUp     = 0x0202
	colorWindow     = 5
)

var (
	user32DLL              = windows.NewLazySystemDLL("user32.dll")
	kernel32DLL            = windows.NewLazySystemDLL("kernel32.dll")
	gdi32DLL               = windows.NewLazySystemDLL("gdi32.dll")
	procCreateWindowEx     = user32DLL.NewProc("CreateWindowExW")
	procShowWindow         = user32DLL.NewProc("ShowWindow")
	procUpdateWindow       = user32DLL.NewProc("UpdateWindow")
	procDefWindowProc      = user32DLL.NewProc("DefWindowProcW")
	procPeekMessage        = user32DLL.NewProc("PeekMessageW")
	procTranslateMessage   = user32DLL.NewProc("TranslateMessage")
	procDispatchMessage    = user32DLL.NewProc("DispatchMessageW")
	procGetCursorPos       = user32DLL.NewProc("GetCursorPos")
	procSetWindowPos       = user32DLL.NewProc("SetWindowPos")
	procInvalidateRect     = user32DLL.NewProc("InvalidateRect")
	procBeginPaint         = user32DLL.NewProc("BeginPaint")
	procEndPaint           = user32DLL.NewProc("EndPaint")
	procFillRect           = user32DLL.NewProc("FillRect")
	procCreateSolidBrush   = gdi32DLL.NewProc("CreateSolidBrush")
	procDeleteObject       = gdi32DLL.NewProc("DeleteObject")
	procSetLayeredWindowAttributes = user32DLL.NewProc("SetLayeredWindowAttributes")
	procGetModuleHandle    = kernel32DLL.NewProc("GetModuleHandleW")
	procGetSysColorBrush   = user32DLL.NewProc("GetSysColorBrush")
	procRegisterClassEx    = user32DLL.NewProc("RegisterClassExW")
	procPostMessage        = user32DLL.NewProc("PostMessageW")
)

// WndClassEx structure
type WndClassEx struct {
	CbSize        uint32
	Style         uint32
	LpfnWndProc   uintptr
	CbClsExtra    int32
	CbWndExtra    int32
	HInstance     uintptr
	HIcon         uintptr
	HCursor       uintptr
	HbrBackground uintptr
	LpszMenuName  *uint16
	LpszClassName *uint16
	HIconSm       uintptr
}

// PaintStruct structure
type PaintStruct struct {
	Hdc         uintptr
	FErase      int32
	RcPaint     Rect
	FRestore    int32
	FIncUpdate  int32
	RgbReserved [32]byte
}

// Msg structure
type Msg struct {
	Hwnd    uintptr
	Message uint32
	WParam  uintptr
	LParam  uintptr
	Time    uint32
	Pt      Point
}

// NewOverlay creates a new system overlay
func NewOverlay(onClick func()) (*Overlay, error) {
	ctx, cancel := context.WithCancel(context.Background())
	
	o := &Overlay{
		onClick: onClick,
		ctx:     ctx,
		cancel:  cancel,
	}
	
	return o, nil
}

// Start initializes the overlay window
func (o *Overlay) Start() error {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	if err := o.createWindow(); err != nil {
		return fmt.Errorf("failed to create overlay window: %w", err)
	}

	go o.messageLoop()
	go o.positionTracker()

	log.Println("[Overlay] System overlay started")
	return nil
}

// Stop closes the overlay
func (o *Overlay) Stop() {
	o.cancel()
	if o.hwnd != 0 {
		procPostMessage.Call(o.hwnd, wmClose, 0, 0)
	}
}

// createWindow creates the overlay window
func (o *Overlay) createWindow() error {
	className, _ := windows.UTF16PtrFromString("AuraBotOverlay")
	windowName, _ := windows.UTF16PtrFromString("AuraBot Overlay")

	// Get module handle
	modHandle, _, _ := procGetModuleHandle.Call(0)

	// Register window class
	var wc WndClassEx
	wc.CbSize = uint32(unsafe.Sizeof(wc))
	wc.LpfnWndProc = windows.NewCallback(o.windowProc)
	wc.HInstance = modHandle
	wc.HbrBackground, _, _ = procGetSysColorBrush.Call(colorWindow)
	wc.LpszClassName = className
	
	procRegisterClassEx.Call(uintptr(unsafe.Pointer(&wc)))

	// Create layered, transparent, topmost window (48x48 button)
	ret, _, err := procCreateWindowEx.Call(
		uintptr(wsExToolWindow|wsExNoActivate|wsExTopMost|wsExLayered),
		uintptr(unsafe.Pointer(className)),
		uintptr(unsafe.Pointer(windowName)),
		uintptr(wsPopup),
		uintptr(cwUseDefault),
		uintptr(cwUseDefault),
		uintptr(48),
		uintptr(48),
		uintptr(0),
		uintptr(0),
		modHandle,
		uintptr(unsafe.Pointer(o)),
	)
	
	if ret == 0 {
		return fmt.Errorf("CreateWindowEx failed: %v", err)
	}
	
	o.hwnd = ret
	
	// Make window fully transparent background with opaque content
	procSetLayeredWindowAttributes.Call(
		o.hwnd,
		0,
		255,
		0x00000001, // LWA_ALPHA
	)
	
	return nil
}

// windowProc handles Windows messages
func (o *Overlay) windowProc(hwnd uintptr, msg uint32, wParam uintptr, lParam uintptr) uintptr {
	switch msg {
	case wmPaint:
		o.paint(hwnd)
		return 0
		
	case wmLButtonUp:
		if o.onClick != nil {
			go o.onClick()
		}
		return 0
		
	case wmClose:
		procShowWindow.Call(hwnd, uintptr(swHide))
		o.mu.Lock()
		o.visible = false
		o.mu.Unlock()
		return 0
	}
	
	ret, _, _ := procDefWindowProc.Call(
		hwnd,
		uintptr(msg),
		wParam,
		lParam,
	)
	return ret
}

// paint draws the floating button
func (o *Overlay) paint(hwnd uintptr) {
	var ps PaintStruct
	
	procBeginPaint.Call(hwnd, uintptr(unsafe.Pointer(&ps)))
	defer procEndPaint.Call(hwnd, uintptr(unsafe.Pointer(&ps)))
	
	// Create gradient brush (purple - 0x8B5CF6)
	brush, _, _ := procCreateSolidBrush.Call(0xF56E3C) // Orange-ish color for visibility
	defer procDeleteObject.Call(brush)
	
	// Fill entire window
	rect := Rect{Left: 0, Top: 0, Right: 48, Bottom: 48}
	procFillRect.Call(ps.Hdc, uintptr(unsafe.Pointer(&rect)), brush)
}

// Show displays the overlay at the specified position
func (o *Overlay) Show(x, y int) {
	if o.hwnd == 0 {
		return
	}
	
	// Offset slightly so it doesn't cover the text
	x += 10
	y += 10
	
	const (
		swpShowWindow  = 0x0040
		swpNoActivate  = 0x0010
		hwndTopMost    = ^uintptr(0) // -1 as uintptr
	)
	
	procSetWindowPos.Call(
		o.hwnd,
		uintptr(hwndTopMost),
		uintptr(x),
		uintptr(y),
		uintptr(48),
		uintptr(48),
		uintptr(swpShowWindow|swpNoActivate),
	)
	
	procShowWindow.Call(o.hwnd, uintptr(swShow))
	procInvalidateRect.Call(o.hwnd, 0, 1)
	
	o.mu.Lock()
	o.visible = true
	o.lastPos.X = int32(x)
	o.lastPos.Y = int32(y)
	o.mu.Unlock()
}

// Hide hides the overlay
func (o *Overlay) Hide() {
	if o.hwnd == 0 {
		return
	}
	
	procShowWindow.Call(o.hwnd, uintptr(swHide))
	
	o.mu.Lock()
	o.visible = false
	o.mu.Unlock()
}

// IsVisible returns whether the overlay is visible
func (o *Overlay) IsVisible() bool {
	o.mu.RLock()
	defer o.mu.RUnlock()
	return o.visible
}

// messageLoop runs the Windows message loop
func (o *Overlay) messageLoop() {
	var msg Msg
	
	for {
		select {
		case <-o.ctx.Done():
			return
		default:
		}
		
		ret, _, _ := procPeekMessage.Call(
			uintptr(unsafe.Pointer(&msg)),
			0, 0, 0, 1,
		)
		
		if ret != 0 {
			procTranslateMessage.Call(uintptr(unsafe.Pointer(&msg)))
			procDispatchMessage.Call(uintptr(unsafe.Pointer(&msg)))
		}
		
		time.Sleep(10 * time.Millisecond)
	}
}

// positionTracker tracks cursor position to auto-hide when cursor moves away
func (o *Overlay) positionTracker() {
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	
	for {
		select {
		case <-o.ctx.Done():
			return
		case <-ticker.C:
			o.mu.RLock()
			visible := o.visible
			lastX := o.lastPos.X
			lastY := o.lastPos.Y
			o.mu.RUnlock()
			
			if visible {
				var pt Point
				procGetCursorPos.Call(uintptr(unsafe.Pointer(&pt)))
				
				// Hide if cursor moves far from button (100 pixels)
				dx := pt.X - lastX
				dy := pt.Y - lastY
				if dx*dx+dy*dy > 10000 {
					o.Hide()
				}
			}
		}
	}
}

// SetOnClick sets the click handler
func (o *Overlay) SetOnClick(handler func()) {
	o.onClick = handler
}
