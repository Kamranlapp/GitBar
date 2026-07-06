import AppKit

private let columnWidth: CGFloat = 150
private let rightColumnWidth: CGFloat = 160
private let popoverWidth = columnWidth + rightColumnWidth
private let columnContentWidth: CGFloat = columnWidth - 20
private let projectButtonWidth: CGFloat = columnContentWidth
private let actionButtonWidth: CGFloat = 120
private let controlHeight: CGFloat = 32
private let buttonVerticalSpacing: CGFloat = 6
private let actionButtonCount: CGFloat = 8
private let contentVerticalInset: CGFloat = 8
private let headerHeight: CGFloat = 18
private let headerContentSpacing: CGFloat = 10
private let columnHorizontalInset: CGFloat = 10
private let columnTopInset: CGFloat = 14
private let columnBottomInset: CGFloat = 12
private let contentPanelHeight = contentVerticalInset + (actionButtonCount * controlHeight) + ((actionButtonCount - 1) * buttonVerticalSpacing) + contentVerticalInset
private let popoverHeight = columnTopInset + headerHeight + headerContentSpacing + contentPanelHeight + columnBottomInset

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store = ProjectStore()
    private var controller: PopoverViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installEditMenu()

        if let button = statusItem.button {
            button.image = makeStatusBarIcon()
            button.imagePosition = .imageOnly
            button.title = ""
            button.action = #selector(togglePopover)
            button.target = self
        }

        let controller = PopoverViewController(store: store)
        self.controller = controller
        popover.contentSize = NSSize(width: popoverWidth, height: popoverHeight)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = controller
    }

    private func makeStatusBarIcon() -> NSImage? {
        let sourceImage = Bundle.main.url(forResource: "GitBar", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "terminal", accessibilityDescription: "GitBar")
        guard let sourceImage else { return nil }

        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 4, yRadius: 4).addClip()
        sourceImage.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            controller?.refreshForOpen()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            makePopoverBackgroundTransparent()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func makePopoverBackgroundTransparent() {
        guard let window = popover.contentViewController?.view.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func installEditMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit GitBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

struct Project: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var path: String
    var repoURL: String?
    var devCommand: String
    var localhostURL: String
    var lastUsedAt: Date
}

final class ProjectStore {
    private let defaultsKey = "projects.v1"
    private let selectedKey = "selectedProjectID.v1"

    private(set) var projects: [Project] = []
    private(set) var selectedID: UUID?

    init() {
        load()
    }

    var sortedProjects: [Project] {
        projects.sorted { lhs, rhs in
            if lhs.lastUsedAt == rhs.lastUsedAt {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.lastUsedAt > rhs.lastUsedAt
        }
    }

    var selectedProject: Project? {
        if let selectedID, let project = projects.first(where: { $0.id == selectedID }) {
            return project
        }
        return sortedProjects.first
    }

    func select(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].lastUsedAt = Date()
        selectedID = project.id
        save()
    }

    func add(path: String) -> Project {
        let url = URL(fileURLWithPath: path)
        let project = Project(
            id: UUID(),
            name: url.lastPathComponent.isEmpty ? path : url.lastPathComponent,
            path: path,
            repoURL: "",
            devCommand: "npm run dev",
            localhostURL: "http://localhost:3000",
            lastUsedAt: Date()
        )
        projects.append(project)
        selectedID = project.id
        save()
        return project
    }

    func update(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
        save()
    }

    func removeSelected() {
        guard let selectedID else { return }
        projects.removeAll { $0.id == selectedID }
        self.selectedID = sortedProjects.first?.id
        save()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
        }
        if let selected = UserDefaults.standard.string(forKey: selectedKey) {
            selectedID = UUID(uuidString: selected)
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
        if let selectedID {
            UserDefaults.standard.set(selectedID.uuidString, forKey: selectedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedKey)
        }
    }
}

final class PopoverViewController: NSViewController, NSTextFieldDelegate, NSMenuDelegate {
    private let store: ProjectStore
    private let runner = CommandRunner()

    private let backgroundEffect = NSVisualEffectView()
    private let rootStack = NSStackView()
    private let settingsOverlay = NSView()
    private let forceActionOverlay = NSView()
    private let forceActionTitleLabel = NSTextField(labelWithString: "")
    private let forceActionMessageLabel = NSTextField(labelWithString: "")
    private var forceActionButton: GlassButton?
    private let projectStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "Actions")
    private let settingsStack = NSStackView()
    private let actionsStack = NSStackView()
    private let nameField = NSTextField()
    private let pathField = NSTextField()
    private let repoField = NSTextField()
    private let devCommandField = NSTextField()
    private let localhostField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "Ready")
    private let logView = NSTextView()
    private let projectMenu = NSMenu()
    private let appControlMenu = NSMenu()

    private var orderedProjects: [Project] = []
    private var pendingForceAction: PendingForceAction?
    private var statusResetWorkItem: DispatchWorkItem?

    private enum PendingForceAction {
        case push(Project)
        case pull(Project)
    }

    init(store: ProjectStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        buildBackground()
        buildLayout()
        reloadProjects()
    }

    func refreshForOpen() {
        reloadProjects()
    }

    private func buildBackground() {
        backgroundEffect.material = .menu
        backgroundEffect.blendingMode = .behindWindow
        backgroundEffect.state = .active
        backgroundEffect.alphaValue = 0.0
        backgroundEffect.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundEffect)

        NSLayoutConstraint.activate([
            backgroundEffect.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundEffect.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundEffect.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundEffect.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func buildLayout() {
        rootStack.orientation = .horizontal
        rootStack.spacing = 0
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let left = buildProjectColumn()
        let right = buildActionColumn()
        rootStack.addArrangedSubview(left)
        rootStack.addArrangedSubview(right)

        NSLayoutConstraint.activate([
            left.widthAnchor.constraint(equalToConstant: columnWidth),
            right.widthAnchor.constraint(equalToConstant: rightColumnWidth)
        ])

        buildSettingsOverlay()
        buildForceActionOverlay()
    }

    private func buildSettingsOverlay() {
        settingsOverlay.translatesAutoresizingMaskIntoConstraints = false
        settingsOverlay.isHidden = true
        view.addSubview(settingsOverlay)

        let title = NSTextField(labelWithString: "Settings")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.alignment = .right
        title.translatesAutoresizingMaskIntoConstraints = false
        settingsOverlay.addSubview(title)

        let contentPanel = ContentPanelView()
        contentPanel.translatesAutoresizingMaskIntoConstraints = false
        settingsOverlay.addSubview(contentPanel)

        configureTextField(nameField, placeholder: "Project name")
        configureTextField(pathField, placeholder: "Path")
        configureTextField(repoField, placeholder: "https://github.com/user/repo.git")
        configureTextField(devCommandField, placeholder: "Dev command")
        configureTextField(localhostField, placeholder: "Localhost URL")

        settingsStack.orientation = .vertical
        settingsStack.alignment = .width
        settingsStack.spacing = 10
        settingsStack.translatesAutoresizingMaskIntoConstraints = false

        let settingRows = [
            labeledField("Name", nameField),
            labeledField("Path", pathInputView()),
            labeledField("Repo", repoField),
            labeledField("Dev", devCommandField),
            labeledField("URL", localhostField)
        ]
        settingRows.forEach { settingsStack.addArrangedSubview($0) }

        let doneButton = actionButton("Done", #selector(closeProjectSettings))
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        contentPanel.addSubview(settingsStack)
        contentPanel.addSubview(doneButton)

        NSLayoutConstraint.activate([
            settingsOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            settingsOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            title.leadingAnchor.constraint(equalTo: settingsOverlay.leadingAnchor, constant: 14),
            title.trailingAnchor.constraint(equalTo: settingsOverlay.trailingAnchor, constant: -14),
            title.topAnchor.constraint(equalTo: settingsOverlay.topAnchor, constant: columnTopInset),
            title.heightAnchor.constraint(equalToConstant: headerHeight),

            contentPanel.leadingAnchor.constraint(equalTo: settingsOverlay.leadingAnchor, constant: columnHorizontalInset),
            contentPanel.trailingAnchor.constraint(equalTo: settingsOverlay.trailingAnchor, constant: -columnHorizontalInset),
            contentPanel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: headerContentSpacing),
            contentPanel.bottomAnchor.constraint(equalTo: settingsOverlay.bottomAnchor, constant: -columnBottomInset),

            settingsStack.leadingAnchor.constraint(equalTo: contentPanel.leadingAnchor, constant: contentVerticalInset),
            settingsStack.trailingAnchor.constraint(equalTo: contentPanel.trailingAnchor, constant: -contentVerticalInset),
            settingsStack.topAnchor.constraint(equalTo: contentPanel.topAnchor, constant: contentVerticalInset),

            doneButton.trailingAnchor.constraint(equalTo: contentPanel.trailingAnchor, constant: -contentVerticalInset),
            doneButton.bottomAnchor.constraint(equalTo: contentPanel.bottomAnchor, constant: -contentVerticalInset)
        ])
    }

    private func buildForceActionOverlay() {
        forceActionOverlay.translatesAutoresizingMaskIntoConstraints = false
        forceActionOverlay.isHidden = true
        forceActionOverlay.wantsLayer = true
        forceActionOverlay.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.42).cgColor
        view.addSubview(forceActionOverlay)

        let panel = ContentPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 0.98).cgColor
        forceActionOverlay.addSubview(panel)

        forceActionTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        forceActionTitleLabel.textColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        forceActionTitleLabel.alignment = .center
        forceActionTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        forceActionMessageLabel.font = .systemFont(ofSize: 13, weight: .regular)
        forceActionMessageLabel.textColor = NSColor(calibratedWhite: 0.34, alpha: 1)
        forceActionMessageLabel.alignment = .center
        forceActionMessageLabel.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = actionButton("Cancel", #selector(cancelForceAction), width: 108)
        let forceButton = actionButton("Force Push", #selector(confirmForceAction), width: 108)
        forceActionButton = forceButton

        let buttonRow = NSStackView(views: [cancelButton, forceButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        panel.addSubview(forceActionTitleLabel)
        panel.addSubview(forceActionMessageLabel)
        panel.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            forceActionOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            forceActionOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            forceActionOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            forceActionOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            panel.leadingAnchor.constraint(equalTo: forceActionOverlay.leadingAnchor, constant: 18),
            panel.trailingAnchor.constraint(equalTo: forceActionOverlay.trailingAnchor, constant: -18),
            panel.centerYAnchor.constraint(equalTo: forceActionOverlay.centerYAnchor),
            panel.heightAnchor.constraint(equalToConstant: 132),

            forceActionTitleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            forceActionTitleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            forceActionTitleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),

            forceActionMessageLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            forceActionMessageLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            forceActionMessageLabel.topAnchor.constraint(equalTo: forceActionTitleLabel.bottomAnchor, constant: 6),

            buttonRow.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -18),
            cancelButton.heightAnchor.constraint(equalToConstant: controlHeight),
            forceButton.heightAnchor.constraint(equalToConstant: controlHeight)
        ])
    }

    private func buildProjectColumn() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Projects")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let powerButton = PowerButton(target: self, action: #selector(showAppControlMenu))
        powerButton.toolTip = "App Controls"
        powerButton.translatesAutoresizingMaskIntoConstraints = false

        let addButton = AddProjectButton(target: self, action: #selector(addProject))
        addButton.toolTip = "Add Project"
        addButton.translatesAutoresizingMaskIntoConstraints = false

        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(powerButton)
        header.addSubview(title)
        header.addSubview(addButton)

        projectMenu.delegate = self
        projectMenu.autoenablesItems = false
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openProjectSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.isEnabled = true
        let removeItem = NSMenuItem(title: "Remove", action: #selector(removeProject), keyEquivalent: "")
        removeItem.target = self
        removeItem.isEnabled = true
        projectMenu.addItem(settingsItem)
        projectMenu.addItem(removeItem)

        appControlMenu.autoenablesItems = false
        let restartItem = NSMenuItem(title: "Restart", action: #selector(restartApp), keyEquivalent: "")
        restartItem.target = self
        restartItem.isEnabled = true
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        quitItem.isEnabled = true
        appControlMenu.addItem(restartItem)
        appControlMenu.addItem(quitItem)

        let contentPanel = ContentPanelView()
        contentPanel.translatesAutoresizingMaskIntoConstraints = false

        projectStack.orientation = .vertical
        projectStack.alignment = .centerX
        projectStack.spacing = buttonVerticalSpacing
        projectStack.translatesAutoresizingMaskIntoConstraints = false
        contentPanel.addSubview(projectStack)

        container.addSubview(header)
        container.addSubview(contentPanel)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: columnTopInset),
            header.heightAnchor.constraint(equalToConstant: headerHeight),
            powerButton.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            powerButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            powerButton.widthAnchor.constraint(equalToConstant: 18),
            powerButton.heightAnchor.constraint(equalToConstant: 18),
            title.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            addButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 18),
            addButton.heightAnchor.constraint(equalToConstant: 18),

            contentPanel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: columnHorizontalInset),
            contentPanel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -columnHorizontalInset),
            contentPanel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: headerContentSpacing),
            contentPanel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -columnBottomInset),

            projectStack.leadingAnchor.constraint(equalTo: contentPanel.leadingAnchor),
            projectStack.trailingAnchor.constraint(equalTo: contentPanel.trailingAnchor),
            projectStack.topAnchor.constraint(equalTo: contentPanel.topAnchor, constant: contentVerticalInset)
        ])

        return container
    }

    private func buildActionColumn() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(divider)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.alignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let header = NSStackView(views: [spacer, titleLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let contentPanel = ContentPanelView()
        contentPanel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentPanel)

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .width
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentPanel.addSubview(contentStack)

        actionsStack.orientation = .vertical
        actionsStack.alignment = .centerX
        actionsStack.spacing = buttonVerticalSpacing
        [
            actionButton("Clone", #selector(runClone)),
            actionButton("Pull", #selector(runPull)),
            actionButton("Commit & Push", #selector(runPush)),
            actionButton("Status", #selector(runStatus)),
            actionButton("Open Git", #selector(openGit)),
            actionButton("Start LH", #selector(startLocalhost)),
            actionButton("Stop LH", #selector(stopLocalhost)),
            actionButton("Open LH", #selector(openLocalhost))
        ].forEach { actionsStack.addArrangedSubview($0) }

        let actionsContainer = NSView()
        actionsContainer.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsContainer.addSubview(actionsStack)
        contentStack.addArrangedSubview(actionsContainer)
        NSLayoutConstraint.activate([
            actionsContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            actionsStack.centerXAnchor.constraint(equalTo: actionsContainer.centerXAnchor),
            actionsStack.topAnchor.constraint(equalTo: actionsContainer.topAnchor),
            actionsStack.bottomAnchor.constraint(equalTo: actionsContainer.bottomAnchor)
        ])

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.textColor = .white
        logView.backgroundColor = .clear

        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.topAnchor.constraint(equalTo: container.topAnchor),
            divider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: columnTopInset),
            header.heightAnchor.constraint(equalToConstant: headerHeight),

            contentPanel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: columnHorizontalInset),
            contentPanel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -columnHorizontalInset),
            contentPanel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: headerContentSpacing),
            contentPanel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -columnBottomInset),

            contentStack.leadingAnchor.constraint(equalTo: contentPanel.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentPanel.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: contentPanel.topAnchor, constant: contentVerticalInset),
            contentStack.bottomAnchor.constraint(equalTo: contentPanel.bottomAnchor, constant: -contentVerticalInset)
        ])

        return container
    }

    private func configureTextField(_ field: NSTextField, placeholder: String) {
        field.placeholderString = placeholder
        field.delegate = self
        field.target = self
        field.action = #selector(fieldChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func labeledField(_ label: String, _ control: NSView) -> NSView {
        let caption = NSTextField(labelWithString: label)
        caption.font = .systemFont(ofSize: 11)
        caption.textColor = .secondaryLabelColor
        caption.widthAnchor.constraint(equalToConstant: 42).isActive = true

        let row = NSStackView(views: [caption, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.distribution = .fill
        return row
    }

    private func pathInputView() -> NSView {
        let folderImage = NSImage(systemSymbolName: "folder", accessibilityDescription: "Choose folder")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular))
        let browseButton = NSButton(image: folderImage ?? NSImage(), target: self, action: #selector(chooseProjectPath))
        browseButton.bezelStyle = .rounded
        browseButton.imagePosition = .imageOnly
        browseButton.toolTip = "Choose folder"
        browseButton.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [pathField, browseButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.distribution = .fill

        NSLayoutConstraint.activate([
            browseButton.widthAnchor.constraint(equalToConstant: controlHeight),
            browseButton.heightAnchor.constraint(equalToConstant: controlHeight)
        ])

        return row
    }

    private func actionButton(_ title: String, _ action: Selector, width: CGFloat = actionButtonWidth) -> GlassButton {
        let button = GlassButton(title: title, target: self, action: action)
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: controlHeight).isActive = true
        return button
    }

    private func reloadProjects() {
        orderedProjects = store.sortedProjects
        rebuildProjectButtons()

        guard let selected = store.selectedProject else {
            clearFields()
            return
        }

        populateFields(selected)
    }

    private func rebuildProjectButtons() {
        projectStack.arrangedSubviews.forEach { view in
            projectStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, project) in orderedProjects.enumerated() {
            let button = ProjectButton(title: project.name, target: self, action: #selector(projectButtonClicked))
            button.widthAnchor.constraint(equalToConstant: projectButtonWidth).isActive = true
            button.heightAnchor.constraint(equalToConstant: controlHeight).isActive = true
            button.tag = index
            button.contextMenu = projectMenu
            projectStack.addArrangedSubview(button)
        }
    }

    private func clearFields() {
        nameField.stringValue = ""
        pathField.stringValue = ""
        repoField.stringValue = ""
        devCommandField.stringValue = ""
        localhostField.stringValue = ""
    }

    private func populateFields(_ project: Project) {
        nameField.stringValue = project.name
        pathField.stringValue = project.path
        repoField.stringValue = project.repoURL ?? ""
        devCommandField.stringValue = project.devCommand
        localhostField.stringValue = project.localhostURL
    }

    private func currentProject() -> Project? {
        store.selectedProject
    }

    private func persistCurrentFields() {
        guard var project = currentProject() else { return }
        project.name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        project.path = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        project.repoURL = repoField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        project.devCommand = devCommandField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        project.localhostURL = localhostField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        store.update(project)
        orderedProjects = store.sortedProjects
        rebuildProjectButtons()
    }

    @objc private func fieldChanged() {
        persistCurrentFields()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        persistCurrentFields()
    }

    @objc private func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"

        if panel.runModal() == .OK, let url = panel.url {
            _ = store.add(path: url.path)
            reloadProjects()
            setStatus("Project Added")
        }
    }

    @objc private func chooseProjectPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"

        let currentPath = pathField.stringValue
        if FileManager.default.fileExists(atPath: currentPath) {
            panel.directoryURL = URL(fileURLWithPath: currentPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            pathField.stringValue = url.path
            persistCurrentFields()
            setStatus("Path Updated")
        }
    }

    @objc private func removeProject() {
        store.removeSelected()
        reloadProjects()
        setStatus("Removed")
    }

    @objc private func openProjectSettings() {
        guard currentProject() != nil else { return }
        rootStack.isHidden = true
        settingsOverlay.isHidden = false
        view.window?.makeFirstResponder(nameField)
        setStatus("Settings")
    }

    @objc private func closeProjectSettings() {
        persistCurrentFields()
        settingsOverlay.isHidden = true
        rootStack.isHidden = false
        view.window?.makeFirstResponder(nil)
        setStatus("Ready")
    }

    @objc private func runStatus() {
        persistCurrentFields()
        guard let project = currentProject() else {
            setStatus("Add A Project")
            return
        }

        let command = "git fetch --quiet && git status --short --branch"
        setStatus("Checking")
        appendLog("$ \(command)\n")

        runner.run(command, in: project.path) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self?.setStatus(Self.shortGitStatus(from: output))
                    self?.appendLog(output.isEmpty ? "(no output)\n" : output)
                case .failure(let error):
                    self?.setStatus("Status Fail")
                    self?.appendLog("\(error.localizedDescription)\n")
                    self?.showCommandFailure(title: "status failed", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func runClone() {
        persistCurrentFields()
        guard let project = currentProject() else {
            setStatus("Add A Project")
            return
        }

        setStatus("Cloning...")
        appendLog("$ git clone \(project.repoURL ?? "") \(project.path)\n")

        runner.clone(project: project) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self?.setStatus("Clone Done")
                    self?.appendLog(output.isEmpty ? "(no output)\n" : output)
                case .failure(let error):
                    self?.setStatus("Clone Failed")
                    self?.appendLog("\(error.localizedDescription)\n")
                    self?.showCommandFailure(title: "clone failed", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func runPull() {
        persistCurrentFields()
        guard let project = currentProject() else {
            setStatus("Add A Project")
            return
        }

        let command = Self.safePullCommand()
        setStatus("Running Pull...")
        appendLog("$ \(command)\n")

        runner.run(command, in: project.path) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self?.setStatus("Pull Complete")
                    self?.appendLog(output.isEmpty ? "(no output)\n" : output)
                case .failure(let error):
                    self?.setStatus("Pull Failed")
                    self?.appendLog("\(error.localizedDescription)\n")
                    if Self.isForcePullError(error.localizedDescription) {
                        self?.showForcePullOverlay(for: project)
                    } else {
                        self?.showCommandFailure(title: "pull failed", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    @objc private func runPush() {
        persistCurrentFields()
        guard let project = currentProject() else {
            setStatus("Add A Project")
            return
        }

        setStatus("Running Sync")
        appendLog("$ git add -A && git commit && git push\n")

        runner.push(project: project) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self?.setStatus("Sync Done")
                    self?.appendLog(output.isEmpty ? "(no output)\n" : output)
                case .failure(let error):
                    self?.setStatus("Sync Failed")
                    self?.appendLog("\(error.localizedDescription)\n")
                    if Self.isNonFastForwardPushError(error.localizedDescription) {
                        self?.showForcePushOverlay(for: project)
                    } else {
                        self?.showCommandFailure(title: "sync failed", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    @objc private func confirmForceAction() {
        guard let action = pendingForceAction else {
            hideForceActionOverlay()
            return
        }

        hideForceActionOverlay()

        switch action {
        case .push(let project):
            runForcePush(project)
        case .pull(let project):
            runForcePull(project)
        }
    }

    private func runForcePush(_ project: Project) {
        setStatus("Force Pushing")
        appendLog("$ git push --force\n")

        runner.forcePush(project: project) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self?.setStatus("Force Pushed")
                    self?.appendLog(output.isEmpty ? "(no output)\n" : output)
                case .failure(let error):
                    self?.setStatus("Force Failed")
                    self?.appendLog("\(error.localizedDescription)\n")
                    self?.showCommandFailure(title: "force push failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func runForcePull(_ project: Project) {
        setStatus("Force Pulling")
        appendLog("$ git fetch && git reset --hard\n")

        runner.forcePull(project: project) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self?.setStatus("Force Pulled")
                    self?.appendLog(output.isEmpty ? "(no output)\n" : output)
                case .failure(let error):
                    self?.setStatus("Force Failed")
                    self?.appendLog("\(error.localizedDescription)\n")
                    self?.showCommandFailure(title: "force pull failed", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func cancelForceAction() {
        let status: String
        switch pendingForceAction {
        case .pull:
            status = "Pull Blocked"
        case .push:
            status = "Push Blocked"
        case nil:
            status = "Cancelled"
        }
        hideForceActionOverlay()
        setStatus(status)
    }

    @objc private func startLocalhost() {
        persistCurrentFields()
        guard let project = currentProject(), !project.devCommand.isEmpty else {
            setStatus("No Dev")
            return
        }
        do {
            try runner.startServer(project: project) { [weak self] output in
                self?.appendLog(output)
            }
            setStatus("LH Started")
            appendLog("$ \(project.devCommand)\n")
        } catch {
            setStatus("Start Failed")
            appendLog("\(error.localizedDescription)\n")
        }
    }

    @objc private func stopLocalhost() {
        guard let project = currentProject() else { return }
        runner.stopServer(project: project)
        setStatus("LH Stopped")
    }

    @objc private func showAppControlMenu(_ sender: NSControl) {
        appControlMenu.items.forEach { $0.isEnabled = true }
        NSMenu.popUpContextMenu(appControlMenu, with: NSApp.currentEvent ?? NSEvent(), for: sender)
    }

    @objc private func restartApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]
        try? process.run()
        NSApp.terminate(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func openGit() {
        persistCurrentFields()
        guard let project = currentProject(),
              let repoURL = project.repoURL,
              !repoURL.isEmpty,
              let url = URL(string: repoURL) else {
            setStatus("No Repo URL")
            return
        }
        NSWorkspace.shared.open(url)
        setStatus("Opened Repo")
    }

    @objc private func openLocalhost() {
        persistCurrentFields()
        guard let project = currentProject(),
              let url = URL(string: project.localhostURL),
              !project.localhostURL.isEmpty else {
            setStatus("No LC URL")
            return
        }
        NSWorkspace.shared.open(url)
        setStatus("Open LH")
    }

    private static func safePullCommand() -> String {
        "if ! git diff --quiet || ! git diff --cached --quiet; then echo \"Local changes found. Commit & Push before Pull:\"; git status --short; exit 1; fi; git pull --ff-only && git clean -fd"
    }

    private static func shortGitStatus(from output: String) -> String {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        guard let branchLine = lines.first else { return "Synced" }

        let hasChanges = lines.dropFirst().contains { line in
            line.hasPrefix(" M") || line.hasPrefix("M ") || line.hasPrefix("A ") ||
            line.hasPrefix("D ") || line.hasPrefix("R ") || line.hasPrefix("C ") ||
            line.hasPrefix("UU") || line.hasPrefix("AA") || line.hasPrefix("DD") ||
            line.hasPrefix("??")
        }

        if branchLine.contains("ahead") && branchLine.contains("behind") { return "Both Changed" }
        if branchLine.contains("behind") { return "Need Pull" }
        if branchLine.contains("ahead") { return "Need Push" }
        if hasChanges { return "Changed" }
        return "Synced"
    }

    private static func isNonFastForwardPushError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("non-fast-forward") ||
            lowercased.contains("fetch first") ||
            lowercased.contains("updates were rejected")
    }

    private static func isForcePullError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("local changes found") ||
            lowercased.contains("not possible to fast-forward") ||
            lowercased.contains("divergent branches") ||
            lowercased.contains("would be overwritten by merge") ||
            lowercased.contains("need to specify how to reconcile")
    }

    private func showForcePushOverlay(for project: Project) {
        pendingForceAction = .push(project)
        forceActionTitleLabel.stringValue = "Git was updated."
        forceActionMessageLabel.stringValue = "Force push?"
        forceActionButton?.setTitle("Force Push")
        settingsOverlay.isHidden = true
        forceActionOverlay.isHidden = false
        setStatus("Force Push?")
    }

    private func showForcePullOverlay(for project: Project) {
        pendingForceAction = .pull(project)
        forceActionTitleLabel.stringValue = "Local was updated."
        forceActionMessageLabel.stringValue = "Force pull?"
        forceActionButton?.setTitle("Force Pull")
        settingsOverlay.isHidden = true
        forceActionOverlay.isHidden = false
        setStatus("Force Pull?")
    }

    private func hideForceActionOverlay() {
        pendingForceAction = nil
        forceActionOverlay.isHidden = true
    }

    private func runShort(_ command: String, label: String) {
        persistCurrentFields()
        guard let project = currentProject() else {
            setStatus("Add A Project")
            return
        }

        let titleLabel = Self.titleCasedStatus(label)
        setStatus(label == "status" ? "Running..." : "Running \(titleLabel)...")
        appendLog("$ \(command)\n")

        runner.run(command, in: project.path) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self?.setStatus(label == "status" ? "Done" : "\(titleLabel) Complete")
                    self?.appendLog(output.isEmpty ? "(no output)\n" : output)
                case .failure(let error):
                    self?.setStatus("\(titleLabel) Failed")
                    self?.appendLog("\(error.localizedDescription)\n")
                    self?.showCommandFailure(title: "\(label) failed", message: error.localizedDescription)
                }
            }
        }
    }

    private static func titleCasedStatus(_ text: String) -> String {
        text
            .split(separator: " ")
            .map { word in
                guard let first = word.first else { return "" }
                return first.uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private func setStatus(_ text: String) {
        statusLabel.stringValue = text
        statusResetWorkItem?.cancel()

        guard settingsOverlay.isHidden else { return }
        if text == "Ready" {
            titleLabel.stringValue = "Actions"
            return
        }

        titleLabel.stringValue = text
        let resetWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.settingsOverlay.isHidden else { return }
            self.titleLabel.stringValue = "Actions"
        }
        statusResetWorkItem = resetWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: resetWorkItem)
    }

    private func showCommandFailure(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func appendLog(_ text: String) {
        DispatchQueue.main.async {
            self.logView.textStorage?.append(NSAttributedString(string: text))
            self.logView.scrollToEndOfDocument(nil)
        }
    }

    @objc private func projectButtonClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < orderedProjects.count else { return }
        let project = orderedProjects[row]
        store.select(project)
        reloadProjects()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.forEach { $0.isEnabled = true }
    }
}

final class ContentPanelView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }
}

class GlassButton: NSControl {
    private let effectView = NSVisualEffectView()
    private let dimView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isPressed = false {
        didSet { updateState() }
    }
    private var isHovering = false {
        didSet { updateState() }
    }

    init(title: String, target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        setup(title: title)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup(title: "")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false

        if bounds.contains(convert(event.locationInWindow, from: nil)), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    func setTitle(_ title: String) {
        titleLabel.stringValue = title
        setAccessibilityLabel(title)
    }

    private func setup(title: String) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        effectView.material = .popover
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 8
        effectView.layer?.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        dimView.layer?.cornerRadius = 8
        dimView.layer?.masksToBounds = true
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        setAccessibilityRole(.button)
        setAccessibilityLabel(title)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateState()
    }

    private func updateState() {
        let alpha: CGFloat
        if isPressed {
            alpha = 0.64
        } else if isHovering {
            alpha = 0.44
        } else {
            alpha = 0.5
        }
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(alpha).cgColor
    }
}

final class ProjectButton: GlassButton {
    var contextMenu: NSMenu?

    override func rightMouseDown(with event: NSEvent) {
        if let action {
            NSApp.sendAction(action, to: target, from: self)
        }
        if let contextMenu {
            contextMenu.items.forEach { $0.isEnabled = true }
            NSMenu.popUpContextMenu(contextMenu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }
}

final class AddProjectButton: NSControl {
    private var isPressed = false

    init(target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setAccessibilityRole(.button)
        setAccessibilityLabel("Add Project")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let lineLength: CGFloat = 12
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let plusPath = NSBezierPath()
        plusPath.lineWidth = 2.1
        plusPath.lineCapStyle = .round
        plusPath.move(to: CGPoint(x: center.x - lineLength / 2, y: center.y))
        plusPath.line(to: CGPoint(x: center.x + lineLength / 2, y: center.y))
        plusPath.move(to: CGPoint(x: center.x, y: center.y - lineLength / 2))
        plusPath.line(to: CGPoint(x: center.x, y: center.y + lineLength / 2))

        NSColor.labelColor.withAlphaComponent(isPressed ? 0.55 : 0.85).setStroke()
        plusPath.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        needsDisplay = true

        if bounds.contains(convert(event.locationInWindow, from: nil)), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }
}

final class PowerButton: NSControl {
    private var isPressed = false

    init(target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setAccessibilityRole(.button)
        setAccessibilityLabel("App Controls")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let strokeColor = NSColor.labelColor.withAlphaComponent(isPressed ? 0.55 : 0.85)
        strokeColor.setStroke()

        let center = CGPoint(x: bounds.midX, y: bounds.midY + 0.3)
        let radius: CGFloat = 6.1
        let powerPath = NSBezierPath()
        powerPath.lineWidth = 2.1
        powerPath.lineCapStyle = .round
        powerPath.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 132,
            endAngle: 408,
            clockwise: false
        )
        powerPath.stroke()

        let stemPath = NSBezierPath()
        stemPath.lineWidth = 2.1
        stemPath.lineCapStyle = .round
        stemPath.move(to: CGPoint(x: center.x, y: bounds.maxY - 2.3))
        stemPath.line(to: CGPoint(x: center.x, y: center.y + 1.2))
        stemPath.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        needsDisplay = true

        if bounds.contains(convert(event.locationInWindow, from: nil)), let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }
}

enum CommandError: LocalizedError {
    case invalidPath(String)
    case notGitRepository(String)
    case missingRepoURL
    case alreadyGitRepository(String)
    case alreadyRunning
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid project path: \(path)"
        case .notGitRepository(let path):
            return "Not a git repository: \(path)"
        case .missingRepoURL:
            return "Repo URL is empty. Add a GitHub repo URL in Settings before first push."
        case .alreadyGitRepository(let path):
            return "Already a git repository: \(path)"
        case .alreadyRunning:
            return "Localhost is already running for this project."
        case .launchFailed(let message):
            return message
        }
    }
}

final class CommandRunner {
    private let serversQueue = DispatchQueue(label: "GitBar.CommandRunner.servers")
    private var servers: [UUID: Process] = [:]

    func run(_ command: String, in path: String, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let output = try self.runBlocking(command, in: path)
                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func clone(project: Project, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let repoURL = project.repoURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !repoURL.isEmpty else {
                    throw CommandError.missingRepoURL
                }
                if self.isGitRepository(at: project.path) {
                    throw CommandError.alreadyGitRepository(project.path)
                }
                let output = try self.runShell(Self.cloneCommand(repoURL: repoURL, path: project.path), in: "/")
                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func push(project: Project, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let output: String
                if self.isGitRepository(at: project.path) {
                    output = try self.runShell(Self.existingRepositoryPushCommand(repoURL: project.repoURL), in: project.path)
                } else {
                    guard let repoURL = project.repoURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !repoURL.isEmpty else {
                        throw CommandError.missingRepoURL
                    }
                    output = try self.runShell(Self.initialPushCommand(repoURL: repoURL), in: project.path)
                }
                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func forcePush(project: Project, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard self.isGitRepository(at: project.path) else {
                    throw CommandError.notGitRepository(project.path)
                }
                let output = try self.runShell(Self.existingRepositoryForcePushCommand(repoURL: project.repoURL), in: project.path)
                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func forcePull(project: Project, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard self.isGitRepository(at: project.path) else {
                    throw CommandError.notGitRepository(project.path)
                }
                let output = try self.runShell(Self.forcePullCommand(repoURL: project.repoURL), in: project.path)
                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func startServer(project: Project, output: @escaping (String) -> Void) throws {
        guard FileManager.default.fileExists(atPath: project.path) else {
            throw CommandError.invalidPath(project.path)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", project.devCommand]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            output(text)
        }

        process.terminationHandler = { [weak self, weak process] _ in
            self?.serversQueue.async { [weak self] in
                guard let self, let process else { return }
                if self.servers[project.id] === process {
                    self.servers[project.id] = nil
                }
            }
            pipe.fileHandleForReading.readabilityHandler = nil
        }

        let didReserve = serversQueue.sync {
            guard servers[project.id] == nil else { return false }
            servers[project.id] = process
            return true
        }
        guard didReserve else { throw CommandError.alreadyRunning }

        do {
            try process.run()
        } catch {
            serversQueue.sync {
                if servers[project.id] === process {
                    servers[project.id] = nil
                }
            }
            throw CommandError.launchFailed(error.localizedDescription)
        }
    }

    func stopServer(project: Project) {
        guard let process = serversQueue.sync(execute: { servers.removeValue(forKey: project.id) }) else { return }
        process.terminate()
    }

    private func runBlocking(_ command: String, in path: String) throws -> String {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CommandError.invalidPath(path)
        }
        try validateGitRepository(at: path)
        return try runShell(command, in: path)
    }

    private static func cloneCommand(repoURL: String, path: String) -> String {
        "git clone \(shellSingleQuoted(repoURL)) \(shellSingleQuoted(path))"
    }

    private static func shellSingleQuoted(_ value: String) -> String {
        let quote = String(UnicodeScalar(39)!)
        return quote + value.replacingOccurrences(of: quote, with: quote + "\\" + quote + quote) + quote
    }

    private func runShell(_ command: String, in path: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            return output
        }
        throw CommandError.launchFailed(output.isEmpty ? "Command failed with code \(process.terminationStatus)" : output)
    }

    private static func existingRepositoryPushCommand(repoURL: String?) -> String {
        guard let repoURL = repoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !repoURL.isEmpty else {
            return syncPushCommand()
        }
        let escapedRepoURL = repoURL.replacingOccurrences(of: "'", with: "'\\''")
        return """
        if git remote get-url origin >/dev/null 2>&1; then
          git remote set-url origin '\(escapedRepoURL)'
        else
          git remote add origin '\(escapedRepoURL)'
        fi &&
        \(syncPushCommand())
        """
    }

    private static func existingRepositoryForcePushCommand(repoURL: String?) -> String {
        let remoteSetup: String
        if let repoURL = repoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !repoURL.isEmpty {
            let escapedRepoURL = repoURL.replacingOccurrences(of: "'", with: "'\\''")
            remoteSetup = """
            if git remote get-url origin >/dev/null 2>&1; then
              git remote set-url origin '\(escapedRepoURL)'
            else
              git remote add origin '\(escapedRepoURL)'
            fi &&
            """
        } else {
            remoteSetup = ""
        }

        return """
        \(remoteSetup)
        if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
          echo 'Nothing to push yet. Add project files and try again.'
          exit 0
        fi &&
        current_branch=$(git branch --show-current)
        if [ -z "$current_branch" ]; then
          current_branch=main
          git branch -M "$current_branch"
        fi &&
        if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
          git push --force
        else
          git push --force -u origin "$current_branch"
        fi
        """
    }

    private static func forcePullCommand(repoURL: String?) -> String {
        let remoteSetup: String
        if let repoURL = repoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !repoURL.isEmpty {
            let escapedRepoURL = repoURL.replacingOccurrences(of: "'", with: "'\\''")
            remoteSetup = """
            if git remote get-url origin >/dev/null 2>&1; then
              git remote set-url origin '\(escapedRepoURL)'
            else
              git remote add origin '\(escapedRepoURL)'
            fi &&
            """
        } else {
            remoteSetup = ""
        }

        return """
        \(remoteSetup)
        current_branch=$(git branch --show-current)
        if [ -z "$current_branch" ]; then
          echo 'Cannot force pull while HEAD is detached.'
          exit 1
        fi &&
        git fetch origin "$current_branch" &&
        if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
          git reset --hard @{u}
        else
          git reset --hard "origin/$current_branch"
        fi &&
        git clean -fd
        """
    }

    private static func initialPushCommand(repoURL: String) -> String {
        let escapedRepoURL = repoURL.replacingOccurrences(of: "'", with: "'\\''")
        return """
        git init &&
        git branch -M main &&
        git remote add origin '\(escapedRepoURL)' &&
        \(syncPushCommand())
        """
    }

    private static func syncPushCommand() -> String {
        """
        git add -A &&
        if git diff --cached --quiet; then
          echo 'No local changes to commit.'
        else
          changed_count=$(git diff --cached --name-only | wc -l | tr -d ' ')
          if [ "$changed_count" = "1" ]; then
            commit_message="Update $(basename "$(git diff --cached --name-only | head -n 1)")"
          else
            commit_message="Update $changed_count files"
          fi
          git commit -m "$commit_message"
        fi &&
        if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
          echo 'Nothing to push yet. Add project files and try again.'
          exit 0
        fi &&
        if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
          git push
        else
          current_branch=$(git branch --show-current)
          if [ -z "$current_branch" ]; then
            current_branch=main
            git branch -M "$current_branch"
          fi
          git push -u origin "$current_branch"
        fi
        """
    }

    private func validateGitRepository(at path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--show-toplevel"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CommandError.notGitRepository(path)
        }
    }

    private func isGitRepository(at path: String) -> Bool {
        do {
            try validateGitRepository(at: path)
            return true
        } catch {
            return false
        }
    }
}
