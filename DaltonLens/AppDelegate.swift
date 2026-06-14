//
// Copyright (c) 2017, Nicolas Burrus
// This software may be modified and distributed under the terms
// of the BSD license.  See the LICENSE file for details.
//

import Cocoa
import ServiceManagement

// @NSApplicationMain

@objcMembers

class AppDelegate: NSObject, NSApplicationDelegate {

    private var window : NSWindow?
    private var daltonView : DaltonView?
    
    var statusItem : NSStatusItem?
    
    let launchAtStartupMenuItem = NSMenuItem(title: "Launch at Startup",
                                             action: #selector(AppDelegate.toggleLaunchAtStartup(sender:)),
                                             keyEquivalent: "")
    
    let protanopeMenuItem = NSMenuItem(title: "Protanope",
                                       action: #selector(AppDelegate.setBlindnessType(sender:)),
                                       keyEquivalent: "")
    
    let deuteranopeMenuItem = NSMenuItem(title: "Deuteranope",
                                         action: #selector(AppDelegate.setBlindnessType(sender:)),
                                         keyEquivalent: "")
    
    let tritanopeMenuItem = NSMenuItem(title: "Tritanope",
                                       action: #selector(AppDelegate.setBlindnessType(sender:)),
                                       keyEquivalent: "")
    
    let protanomalyMenuItem = NSMenuItem(title: "Protanomaly",
                                       action: #selector(AppDelegate.setBlindnessType(sender:)),
                                       keyEquivalent: "")
    
    let deuteranomalyMenuItem = NSMenuItem(title: "Deuteranomaly",
                                         action: #selector(AppDelegate.setBlindnessType(sender:)),
                                         keyEquivalent: "")
    
    let tritanomalyMenuItem = NSMenuItem(title: "Tritanomaly",
                                       action: #selector(AppDelegate.setBlindnessType(sender:)),
                                       keyEquivalent: "")
    
    var nothingMenuItem = NSMenuItem(title: "Nothing",
                                     action: #selector(AppDelegate.setProcessingMode(sender:)),
                                     keyEquivalent: "0")
    
    let simulateMenuItem = NSMenuItem(title: "Simulate Blindness",
                                      action: #selector(AppDelegate.setProcessingMode(sender:)),
                                      keyEquivalent: "3")
    
    let daltonizeV1MenuItem = NSMenuItem(title: "Daltonize Correction",
                                         action: #selector(AppDelegate.setProcessingMode(sender:)),
                                         keyEquivalent: "1")
    
    let dcklMenuItem = NSMenuItem(title: "DCKL",
                                        action: #selector(AppDelegate.setProcessingMode(sender:)),
                                        keyEquivalent: "9")
    
    let switchToggleSeverityMenuItem = NSMenuItem(title: "Toggle Severity",
                                           action: #selector(AppDelegate.setProcessingMode(sender:)),
                                           keyEquivalent: "2")
    
    let dcklParasMenuItem = NSMenuItem(title: "DCKL Parameters",
                                        action: #selector(AppDelegate.setProcessingMode(sender:)),
                                        keyEquivalent: "9")
    
    let switchRedBlueMenuItem = NSMenuItem(title: "Switch Red Blue",
                                           action: #selector(AppDelegate.setProcessingMode(sender:)),
                                           keyEquivalent: "4")
    
    let switchAndFlipRedBlueMenuItem = NSMenuItem(title: "Switch And Flip Red Blue",
                                                  action: #selector(AppDelegate.setProcessingMode(sender:)),
                                                  keyEquivalent: "5")
    
    let invertLightnessMenuItem = NSMenuItem(title: "Invert Lightness",
                                                  action: #selector(AppDelegate.setProcessingMode(sender:)),
                                                  keyEquivalent: "6")
    
    let highlightColorUnderMouseMenuItem = NSMenuItem(title: "Highlight Similar Color Under Cursor",
                                                      action: #selector(AppDelegate.setProcessingMode(sender:)),
                                                      keyEquivalent: "7")
    
    let highlightExactColorUnderMouseMenuItem = NSMenuItem(title: "Highlight Exact Color Under Cursor",
                                                      action: #selector(AppDelegate.setProcessingMode(sender:)),
                                                      keyEquivalent: "8")
    
    var menuItemsToProcessingMode : [NSMenuItem: DLProcessingMode];
    var processingModeToMenuItem : [UInt32: NSMenuItem];
    
    var menuItemsToBlindnessType : [NSMenuItem: DLBlindnessType];
    var blindnessTypeToMenuItem : [UInt32: NSMenuItem];
    
    override init () {
        
        let cmdAltCtrlMask = NSEvent.ModifierFlags(rawValue:
            NSEvent.ModifierFlags.command.rawValue
                | NSEvent.ModifierFlags.control.rawValue
                | NSEvent.ModifierFlags.option.rawValue)
        
        nothingMenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        daltonizeV1MenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        dcklMenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        switchToggleSeverityMenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        dcklParasMenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        simulateMenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        switchRedBlueMenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        switchAndFlipRedBlueMenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        invertLightnessMenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        highlightColorUnderMouseMenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        highlightExactColorUnderMouseMenuItem.keyEquivalentModifierMask = cmdAltCtrlMask
        
        menuItemsToProcessingMode = [
            nothingMenuItem: Nothing,
            daltonizeV1MenuItem: DaltonizeV1,
            dcklMenuItem: DCKL,
            simulateMenuItem: SimulateDaltonism,
            switchRedBlueMenuItem: SwitchCbCr,
            switchAndFlipRedBlueMenuItem: SwitchAndFlipCbCr,
            invertLightnessMenuItem: InvertLightness,
            highlightColorUnderMouseMenuItem: HighlightColorUnderMouse,
            highlightExactColorUnderMouseMenuItem: HighlightExactColorUnderMouse
        ];
        
        processingModeToMenuItem = [:];
        for (menuItem, processingMode) in menuItemsToProcessingMode {
            processingModeToMenuItem[processingMode.rawValue] = menuItem;
        }
        
        menuItemsToBlindnessType = [
            protanopeMenuItem: Protanope,
            deuteranopeMenuItem: Deuteranope,
            tritanopeMenuItem: Tritanope,
            protanomalyMenuItem: Protanomaly,
            deuteranomalyMenuItem: Deuteranomaly,
            tritanomalyMenuItem: Tritanomaly
        ];
        
        blindnessTypeToMenuItem = [:];
        for (menuItem, blindnessType) in menuItemsToBlindnessType {
            blindnessTypeToMenuItem[blindnessType.rawValue] = menuItem;
        }
        
        super.init()
        
    }
    
    func setBlindnessType (sender : NSMenuItem) {
        
        let menuItemsToBlindnessType = [
            protanopeMenuItem: Protanope,
            deuteranopeMenuItem: Deuteranope,
            tritanopeMenuItem: Tritanope,
            protanomalyMenuItem: Protanomaly,
            deuteranomalyMenuItem: Deuteranomaly,
            tritanomalyMenuItem: Tritanomaly]
        
        if let dview = daltonView {
            
            if let blindnessType = menuItemsToBlindnessType[sender] {
                dview.blindnessType = blindnessType
                
                let defaults = UserDefaults.standard;
                defaults.set(blindnessType.rawValue, forKey:"BlindnessType")
                defaults.synchronize();
            }
            else
            {
                assert (false, "Invalid menu item")
            }
            
            // Disable all items
            for item in menuItemsToBlindnessType.keys {
                item.state = .off
            }
            
            // Re-enable the current one. 
            sender.state = .on
        }
        else
        {
            assert (false, "Could not access VB");
        }
        
    }
    
    func toggleLaunchAtStartup (sender: NSMenuItem) {
        
        let wasEnabled = (sender.state == .on);
        let enabled = !wasEnabled;
        
        let changeApplied = SMLoginItemSetEnabled("org.daltonLens.DaltonLensLaunchAtLoginHelper" as CFString, enabled)
        
        if (changeApplied) {
            let defaults = UserDefaults.standard;
            defaults.set(enabled, forKey:"LaunchAtStartup")
            defaults.synchronize();
            
            sender.state = enabled ? .on : .off;
        }
        else
        {
            let alert = NSAlert()
            alert.window.title = "DaltonLens error";
            alert.alertStyle = .critical;
            alert.messageText = "Could not apply the change"
            alert.informativeText = "Please report the issue."
            alert.runModal();
        }
    }
    
    func setBlindnessType (blindnessType : DLBlindnessType) {
        
        if let menuItem = blindnessTypeToMenuItem[blindnessType.rawValue] {
            self.setBlindnessType (sender: menuItem);
        }
    }
    
    func setProcessingMode (sender : NSMenuItem) {
        
        if let dview = daltonView {
            
            if sender == switchToggleSeverityMenuItem
            {
                if dview.severity >= 10
                {
                    dview.severity = 0
                }
                else
                {
                    dview.severity = dview.severity + 1
                }
            }
            else if sender == dcklParasMenuItem
            {
                let alert = NSAlert()

                alert.messageText = "DCKL Parameters"

                let view =
                    NSView(
                        frame: NSRect(
                            x: 0,
                            y: 0,
                            width: 260,
                            height: 210))

                //----------------------------------
                // Labels
                //----------------------------------

                let severityLabel =
                    NSTextField(labelWithString: "Severity")

                severityLabel.frame =
                    NSRect(x: 10, y: 180, width: 80, height: 20)

                let simuLabel =
                    NSTextField(labelWithString: "Simulation")

                simuLabel.frame =
                    NSRect(x: 10, y: 150, width: 80, height: 20)

                let rgLabel =
                    NSTextField(labelWithString: "dckRG")

                rgLabel.frame =
                    NSRect(x: 10, y: 120, width: 80, height: 20)

                let rbLabel =
                    NSTextField(labelWithString: "dckRB")

                rbLabel.frame =
                    NSRect(x: 10, y: 90, width: 80, height: 20)

                let gbLabel =
                    NSTextField(labelWithString: "dckGB")

                gbLabel.frame =
                    NSRect(x: 10, y: 60, width: 80, height: 20)

                let preserveLumaLabel =
                    NSTextField(labelWithString: "Pres. Luma")

                preserveLumaLabel.frame =
                    NSRect(x: 10, y: 30, width: 80, height: 20)

                //----------------------------------
                // Fields
                //----------------------------------

                let severityField =
                    NSTextField(
                        frame: NSRect(
                            x: 100,
                            y: 175,
                            width: 120,
                            height: 24))

                severityField.stringValue =
                    String(dview.dcklSeverity)

                //----------------------------------
                // Simulation Popup
                //----------------------------------

                let simuPopup =
                    NSPopUpButton(
                        frame: NSRect(
                            x: 100,
                            y: 145,
                            width: 120,
                            height: 26),
                        pullsDown: false)

                simuPopup.addItems(
                    withTitles:
                    [
                        "Machado",
                        "Viénot"
                    ])

                simuPopup.selectItem(
                    at: Int(dview.dcklSimu))

                //----------------------------------

                let rgField =
                    NSTextField(
                        frame: NSRect(
                            x: 100,
                            y: 115,
                            width: 120,
                            height: 24))

                rgField.stringValue =
                    String(dview.dcklRG)

                let rbField =
                    NSTextField(
                        frame: NSRect(
                            x: 100,
                            y: 85,
                            width: 120,
                            height: 24))

                rbField.stringValue =
                    String(dview.dcklRB)

                let gbField =
                    NSTextField(
                        frame: NSRect(
                            x: 100,
                            y: 55,
                            width: 120,
                            height: 24))

                gbField.stringValue =
                    String(dview.dcklGB)

                let preserveLumaField =
                    NSTextField(
                        frame: NSRect(
                            x: 100,
                            y: 25,
                            width: 120,
                            height: 24))

                preserveLumaField.stringValue =
                    String(dview.dcklPreserveLuma)

                //----------------------------------

                view.addSubview(severityLabel)
                view.addSubview(simuLabel)
                view.addSubview(rgLabel)
                view.addSubview(rbLabel)
                view.addSubview(gbLabel)
                view.addSubview(preserveLumaLabel)

                view.addSubview(severityField)
                view.addSubview(simuPopup)
                view.addSubview(rgField)
                view.addSubview(rbField)
                view.addSubview(gbField)
                view.addSubview(preserveLumaField)

                alert.accessoryView = view

                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Cancel")

                let result = alert.runModal()

                //----------------------------------
                // OK ?
                //----------------------------------

                if result == .alertFirstButtonReturn
                {
                    dview.dcklSeverity =
                        Float(severityField.stringValue) ?? 3.0

                    dview.dcklSimu =
                        Int32(simuPopup.indexOfSelectedItem)

                    dview.dcklRG =
                        Float(rgField.stringValue) ?? 1.0

                    dview.dcklRB =
                        Float(rbField.stringValue) ?? 1.0

                    dview.dcklGB =
                        Float(gbField.stringValue) ?? 1.0

                    dview.dcklPreserveLuma =
                        Float(preserveLumaField.stringValue) ?? 1.0

                    dview.needsDisplay = true
                }
                let defaults = UserDefaults.standard

                defaults.set(dview.dcklSeverity,
                             forKey: "DCKLSeverity")

                defaults.set(dview.dcklSimu,
                             forKey: "DCKLSimu")

                defaults.set(dview.dcklRG,
                             forKey: "DCKLRG")

                defaults.set(dview.dcklRB,
                             forKey: "DCKLRB")

                defaults.set(dview.dcklGB,
                             forKey: "DCKLGB")

                defaults.set(dview.dcklPreserveLuma,
                             forKey: "DCKLPreserveLuma")

                defaults.synchronize()
                
            }
            else if let processingType = menuItemsToProcessingMode[sender] {
                
                // set default severity when enabling it to 5
                if sender == daltonizeV1MenuItem
                {
                    dview.severity = 5
                }
                                
                dview.processingMode = processingType
                dview.needsDisplay = true
                
                let defaults = UserDefaults.standard;
                defaults.set(processingType.rawValue, forKey:"ProcessingMode")
                defaults.synchronize();
            }
            else
            {
                assert (false, "Invalid menu item")
            }
            
            // Disable all items
            if !(sender == switchToggleSeverityMenuItem || sender == dcklParasMenuItem)
            {
                for item in menuItemsToProcessingMode.keys {
                    item.state = .off
                }
                sender.state = .on
            }
        }
        else
        {
            assert (false, "Could not access VB");
        }
    }
    
    func setProcessingMode (mode : DLProcessingMode) {
        
        if let menuItem = processingModeToMenuItem[mode.rawValue] {
            self.setProcessingMode (sender: menuItem);
        }
    }
    
    func createStatusBarItem () {
        
        // Do any additional setup after loading the view.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        let icon = NSImage(named:"DaltonLensIcon_32x32")
        icon!.isTemplate = true
        
        statusItem!.button!.image = icon!
        statusItem!.button!.cell!.isHighlighted = false
        
        let menu = NSMenu()

        func addBlindnessMenu () {
            let blindnessMenu = NSMenu()
            blindnessMenu.addItem(protanopeMenuItem)
            blindnessMenu.addItem(deuteranopeMenuItem)
            blindnessMenu.addItem(tritanopeMenuItem)
            blindnessMenu.addItem(protanomalyMenuItem)
            blindnessMenu.addItem(deuteranomalyMenuItem)
            blindnessMenu.addItem(tritanomalyMenuItem)
            protanopeMenuItem.state = .on // default is Protanope
            
            let blindnessMenuItem = NSMenuItem(title: "Blindness", action: nil, keyEquivalent: "")
            blindnessMenuItem.submenu = blindnessMenu
            menu.addItem(blindnessMenuItem)
        }
        
        func addProcessingMenu () {
            let processingMenu = NSMenu()
            processingMenu.addItem(nothingMenuItem)
            processingMenu.addItem(simulateMenuItem)
            processingMenu.addItem(daltonizeV1MenuItem)
            processingMenu.addItem(dcklMenuItem)
            processingMenu.addItem(switchRedBlueMenuItem)
            processingMenu.addItem(switchAndFlipRedBlueMenuItem)
            processingMenu.addItem(invertLightnessMenuItem)
            
            #if DEBUG
            processingMenu.addItem(highlightColorUnderMouseMenuItem)
            processingMenu.addItem(highlightExactColorUnderMouseMenuItem)
            #endif
            
            nothingMenuItem.state = .on // default is Nothing
            
            let processingMenuItem = NSMenuItem(title: "Processing", action: nil, keyEquivalent: "")
            processingMenuItem.submenu = processingMenu
            menu.addItem(processingMenuItem)
        }
        
        func addToolsMenu () {
            let toolsMenu = NSMenu()

            toolsMenu.addItem(switchToggleSeverityMenuItem)
            toolsMenu.addItem(dcklParasMenuItem)
                        
            let toolsMenuItem = NSMenuItem(title: "Tools", action: nil, keyEquivalent: "")
            toolsMenuItem.submenu = toolsMenu
            menu.addItem(toolsMenuItem)
        }
        
        
        addBlindnessMenu()
        addProcessingMenu()
        addToolsMenu()

        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(launchAtStartupMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: "q"))
        
        statusItem!.menu = menu
    }
    
    func createGlobalShortcuts () {
        
        // TODO: dont know how these shortcuts now handled in swift 4 ? I just replace them by teir old raw value.
        let cmdControlAlt = (1 << 20) |
            (1 << 18) |
            (1 << 19)
        
        //let cmdControlAlt = NSEventModifierFlagControl |
        //    NSEventModifierFlagControl |
        //    NSEventModifierFlagOption
        
        
        let shortcutNoProcessing = MASShortcut(keyCode:UInt(kVK_ANSI_0),
                                               modifierFlags:UInt(cmdControlAlt));
        
        let shortcutDaltonizeV1 = MASShortcut(keyCode:UInt(kVK_ANSI_1),
                                              modifierFlags:UInt(cmdControlAlt));
        
        let shortcutToggleSeverity = MASShortcut(keyCode:UInt(kVK_ANSI_2),
                                              modifierFlags:UInt(cmdControlAlt));
        
        let shortcutSimulate = MASShortcut(keyCode:UInt(kVK_ANSI_3),
                                                modifierFlags:UInt(cmdControlAlt));
        
        let shortcutSwitchRedBlue = MASShortcut(keyCode:UInt(kVK_ANSI_4),
                                                modifierFlags:UInt(cmdControlAlt));
        
        let shortcutSwitchAndFlipRedBlue = MASShortcut(keyCode:UInt(kVK_ANSI_5),
                                                       modifierFlags:UInt(cmdControlAlt));
        
        let shortcutInvertLightness = MASShortcut(keyCode:UInt(kVK_ANSI_6),
                                                  modifierFlags:UInt(cmdControlAlt));
        
        let shortcutHighlightColorUnderMouse = MASShortcut(keyCode:UInt(kVK_ANSI_7),
                                                           modifierFlags:UInt(cmdControlAlt));
        
        let shortcutHighlightExactColorUnderMouse = MASShortcut(keyCode:UInt(kVK_ANSI_8),
                                                                modifierFlags:UInt(cmdControlAlt));
        
        let shortcutDCKL = MASShortcut(keyCode:UInt(kVK_ANSI_9),
                                                                modifierFlags:UInt(cmdControlAlt));
        
        let shortcutUp = MASShortcut(keyCode:UInt(kVK_UpArrow),
                                     modifierFlags:UInt(cmdControlAlt));
        
        let shortcutDown = MASShortcut(keyCode:UInt(kVK_DownArrow),
                                       modifierFlags:UInt(cmdControlAlt));
        
        func incrProcessingMode (currentMode: DLProcessingMode) -> DLProcessingMode {
            let nextMode = (currentMode.rawValue + 1) % (NumProcessingModes.rawValue)
            return DLProcessingMode(nextMode)
        }
        
        func decrProcessingMode (currentMode: DLProcessingMode) -> DLProcessingMode {
            if currentMode.rawValue == 0 {
                return DLProcessingMode(NumProcessingModes.rawValue - 1)
            }
            return DLProcessingMode(currentMode.rawValue - 1)
        }
        
        func updateProcessingMode (nextMode: (DLProcessingMode)->DLProcessingMode) {
            
            if let dview = daltonView {
                self.setProcessingMode(mode: nextMode(dview.processingMode))
            }
            
        }
        
        MASShortcutMonitor.shared().register(shortcutNoProcessing) {
            updateProcessingMode() {prevMode in
                return Nothing
            };
        }
        
        MASShortcutMonitor.shared().register(shortcutDaltonizeV1) {
            updateProcessingMode() {prevMode in
                return DaltonizeV1
            };
        }
        
        MASShortcutMonitor.shared().register(shortcutDCKL) {
            updateProcessingMode() {prevMode in
                return DCKL
            };
        }
        
        MASShortcutMonitor.shared().register(shortcutToggleSeverity) {
            updateProcessingMode() {prevMode in
                return ToogleSeverity
            };
        }
        
        MASShortcutMonitor.shared().register(shortcutSimulate) {
            updateProcessingMode() {prevMode in
                return SimulateDaltonism
            };
        }
        
        MASShortcutMonitor.shared().register(shortcutSwitchRedBlue) {
            updateProcessingMode() {prevMode in
                return SwitchCbCr
            };
        }
        
        MASShortcutMonitor.shared().register(shortcutSwitchAndFlipRedBlue) {
            updateProcessingMode() {prevMode in
                return SwitchAndFlipCbCr
            };
        }
        
        MASShortcutMonitor.shared().register(shortcutInvertLightness) {
            updateProcessingMode() {prevMode in
                return InvertLightness
            };
        }
        
        #if DEBUG
        MASShortcutMonitor.shared().register(shortcutHighlightColorUnderMouse) {
            updateProcessingMode() {prevMode in
                return HighlightColorUnderMouse
            };
        }
        
        MASShortcutMonitor.shared().register(shortcutHighlightExactColorUnderMouse) {
            updateProcessingMode() {prevMode in
                return HighlightExactColorUnderMouse
            };
        }
        #endif
        
        // Disable the up/down shortcuts.
        #if false
        MASShortcutMonitor.shared().register(shortcutUp) {
            NSLog("Got up!");
            updateProcessingMode(nextMode: decrProcessingMode)
        }
        
        MASShortcutMonitor.shared().register(shortcutDown) {
            NSLog("Got down!");
            updateProcessingMode(nextMode: incrProcessingMode)
        }
        #endif
    }
    
    func makeClosableWindow () {
        
        window = NSWindow.init(contentRect: NSMakeRect(300, 300, 640, 400),
                               styleMask: [.fullSizeContentView,
                                           .resizable],
                               backing: NSWindow.BackingStoreType.buffered,
                               defer: true);
        
        window!.makeKeyAndOrderFront(self);
        window!.isOpaque = true
    }
    
    func makeAssistiveWindow () {
        
        self.window = NSWindow.init(contentRect: NSScreen.main!.frame,
                                    styleMask: [.fullSizeContentView],
                                    backing: NSWindow.BackingStoreType.buffered,
                                    defer: true);
        
        if let window = self.window {
        
            window.styleMask = .borderless;
            window.level = convertToNSWindowLevel(Int(CGWindowLevelKey.assistiveTechHighWindow.rawValue));
            //window.preferredBackingLocation = NSWindow.BackingLocation.videoMemory;
            window.collectionBehavior = [NSWindow.CollectionBehavior.stationary,
                                         //NSWindow.CollectionBehavior.canJoinAllSpaces,
                                        NSWindow.CollectionBehavior.moveToActiveSpace,
                                        NSWindow.CollectionBehavior.ignoresCycle];
                        
            // window.backgroundColor = NSColor.clear;
            // Using a tiny alpha value to make sure that windows below this window get refreshes.
            // Apps like Google Chrome or spotify won't redraw otherwise.
            window.alphaValue = 0.999;
            window.isOpaque = false;
            // window.orderFront (0);
            window.ignoresMouseEvents = true;
        }
    }
    
    func createWindowAndDaltonView () {

        makeAssistiveWindow ()
        // makeClosableWindow ()
        
        // Disabling sharing to avoid capturing this window.
        window!.sharingType = NSWindow.SharingType.none
        
        daltonView = DaltonView.init(frame: window!.frame)
        window!.contentView = daltonView
        
        // window!.delegate = daltonView;
    }
    
    @objc func activeSpaceChanged(
        _ notification: Notification)
    {
        if let window = self.window
        {
           window.orderFront(nil)
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        createStatusBarItem ()
        
        createGlobalShortcuts ()
        
        createWindowAndDaltonView ()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil)
        
        
        let defaults = UserDefaults.standard;
        
        if (defaults.value(forKey: "BlindnessType") != nil) {
            let intValue = defaults.integer(forKey:"BlindnessType")
            let blindnessType = DLBlindnessType(rawValue:UInt32(intValue))
            setBlindnessType(blindnessType:blindnessType)
        }
        
        if (defaults.value(forKey: "ProcessingMode") != nil) {
            let intValue2 = defaults.integer(forKey:"ProcessingMode")
            let processingType = DLProcessingMode(rawValue:UInt32(intValue2))
            daltonView?.processingMode = processingType
            setProcessingMode(mode:processingType)
        }
        
        if let dview = daltonView
        {
            if defaults.object(forKey: "DCKLSeverity") != nil
            {
                dview.dcklSeverity =
                    defaults.float(forKey: "DCKLSeverity")
            }

            if defaults.object(forKey: "DCKLSimu") != nil
            {
                dview.dcklSimu =
                    Int32(defaults.integer(forKey: "DCKLSimu"))
            }

            if defaults.object(forKey: "DCKLRG") != nil
            {
                dview.dcklRG =
                    defaults.float(forKey: "DCKLRG")
            }

            if defaults.object(forKey: "DCKLRB") != nil
            {
                dview.dcklRB =
                    defaults.float(forKey: "DCKLRB")
            }

            if defaults.object(forKey: "DCKLGB") != nil
            {
                dview.dcklGB =
                    defaults.float(forKey: "DCKLGB")
            }

            if defaults.object(forKey: "DCKLPreserveLuma") != nil
            {
                dview.dcklPreserveLuma =
                    defaults.float(forKey: "DCKLPreserveLuma")
            }
        }
        
        if (defaults.value(forKey: "LaunchAtStartup") != nil) {
            let enabled = defaults.bool(forKey:"LaunchAtStartup")
            launchAtStartupMenuItem.state = enabled ? .on : .off;
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func quit () {
        NSApplication.shared.terminate (self);
    }

}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSWindowLevel(_ input: Int) -> NSWindow.Level {
	return NSWindow.Level(rawValue: input)
}
