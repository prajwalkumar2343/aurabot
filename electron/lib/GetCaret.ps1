Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName WindowsBase

try {
    $element = [System.Windows.Automation.AutomationElement]::FocusedElement
    if ($element) {
        $pattern = $null
        if ($element.TryGetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern, [ref]$pattern)) {
            $textPattern = $pattern -as [System.Windows.Automation.TextPattern]
            $selections = $textPattern.GetSelection()
            if ($selections -and $selections.Count -gt 0) {
                $rects = $selections[0].GetBoundingRectangles()
                if ($rects -and $rects.Count -gt 0) {
                    $rect = $rects[0]
                    Write-Output "{`"x`": $($rect.X), `"y`": $($rect.Y), `"width`": $($rect.Width), `"height`": $($rect.Height)}"
                    exit
                }
            }
        }
    }
} catch {
}
Write-Output "{`"error`": `"Could not get caret position`"}"
