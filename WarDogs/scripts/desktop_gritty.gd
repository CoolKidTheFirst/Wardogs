
extends Control

# --- Node refs ---
@onready var clock_label: Label = $TopBar/Clock
@onready var status_label: Label = $TopBar/Status
@onready var boot_overlay: ColorRect = $BootOverlay
@onready var login_overlay: ColorRect = $LoginOverlay
@onready var login_prompt: Label = $LoginOverlay/CenterBox/Prompt
@onready var login_mask: Label = $LoginOverlay/CenterBox/Mask

@onready var task_clock: Label = $Taskbar/TaskClock
@onready var start_button: Button = $Taskbar/StartButton
@onready var start_menu: Panel = $StartMenu
@onready var menu_overlay: ColorRect = $MenuOverlay
@onready var search_edit: LineEdit = $StartMenu/MenuVBox/Search
@onready var results: ItemList = $StartMenu/MenuVBox/Results
@onready var window_list_box: HBoxContainer = $Taskbar/WindowList

# App windows
@onready var btn_market: Button = $Dock/button_market
@onready var win_market: Window = $Dock/button_market/market
@onready var btn_bank: Button = $Dock/button_bank
@onready var win_bank: Window = $Dock/button_bank/bank

# Market UI
@onready var offers: ItemList = $Dock/button_market/market/MarketRoot/Offers
@onready var buy_btn: Button = $Dock/button_market/market/MarketRoot/MarketButtons/BuyBtn
@onready var market_close_btn: Button = $Dock/button_market/market/MarketRoot/MarketButtons/CloseBtn

# Bank UI
@onready var bank_login_box: VBoxContainer = $Dock/button_bank/bank/BankRoot/BankLogin
@onready var bank_prompt: Label = $Dock/button_bank/bank/BankRoot/BankLogin/BankPrompt
@onready var bank_mask: Label = $Dock/button_bank/bank/BankRoot/BankLogin/BankMask
@onready var bank_content: VBoxContainer = $Dock/button_bank/bank/BankRoot/BankContent
@onready var bank_balance_label: Label = $Dock/button_bank/bank/BankRoot/BankContent/Balance
@onready var bank_close_btn: Button = $Dock/button_bank/bank/BankRoot/BankContent/BankButtons/BankCloseBtn

# --- Config (RENAMED to avoid any cached const conflicts) ---
@export var desktop_login_len_cfg: int = 11
@export var bank_login_len_cfg: int = 8

# --- State (RENAMED to avoid any cached const conflicts) ---
var desktop_type_count: int = 0
var bank_type_count: int = 0
var has_logged_in_desktop: bool = false
var has_logged_in_bank: bool = false

var balance: int = 50000

var market_offers: Array[Dictionary] = [
	{"name": "7.62×39mm AK Rounds (1k)", "price": 2100},
	{"name": "5.56×45mm NATO (2k)", "price": 4300},
	{"name": "AKM Rifles (20 units)", "price": 18800},
	{"name": "M4A1 Rifles (10 units)", "price": 21500},
	{"name": "9×19mm Parabellum (5k)", "price": 3500}
]

var apps: Array[Dictionary] = [
	{"name": "Market", "button_path": "Dock/button_market"},
	{"name": "Bank", "button_path": "Dock/button_bank"},
	{"name": "Gov Contracts", "button_path": "Dock/button_govt"},
	{"name": "Logistics", "button_path": "Dock/button_logistics"},
	{"name": "News", "button_path": "Dock/button_news"},
	{"name": "Products", "button_path": "Dock/button_products"},
	{"name": "Messenger", "button_path": "Dock/button_messager"},
	{"name": "Black Market", "button_path": "Dock/button_black"}
]

var window_taskbuttons: Dictionary = {}    # Window -> Button

func _ready() -> void:
	# Boot
	boot_overlay.visible = true
	login_overlay.visible = false
	status_label.text = "BOOTING..."
	await get_tree().create_timer(0.5).timeout
	status_label.text = "LOADING DRIVERS"
	await get_tree().create_timer(0.7).timeout
	status_label.text = "APPLYING SECURITY POLICIES"
	await get_tree().create_timer(0.7).timeout
	status_label.text = "STARTING SERVICES"
	await get_tree().create_timer(0.6).timeout
	status_label.text = "READY"
	await get_tree().create_timer(0.4).timeout
	boot_overlay.visible = false
	_show_desktop_login()

	# Start menu wiring
	start_button.pressed.connect(_on_start_pressed)
	menu_overlay.gui_input.connect(_on_menu_overlay_input)
	search_edit.text_changed.connect(_on_search_changed)
	results.item_activated.connect(_on_result_activated)
	_populate_results("") 

	# Window [X] close -> hide
	win_market.close_requested.connect(func(): _hide_window(win_market))
	win_bank.close_requested.connect(func(): _hide_window(win_bank))

	# Ensure taskbar buttons appear when opening windows via dock buttons
	btn_market.pressed.connect(func(): _ensure_task_button_for(win_market, "Market"))
	btn_bank.pressed.connect(func(): _ensure_task_button_for(win_bank, "Bank"))

	# Market setup
	offers.clear()
	for o in market_offers:
		var label: String = "%s — $%d" % [String(o["name"]), int(o["price"])]
		offers.add_item(label)
	buy_btn.pressed.connect(_on_buy_pressed)
	market_close_btn.pressed.connect(func(): _hide_window(win_market))

	# Bank setup
	bank_close_btn.pressed.connect(func(): _hide_window(win_bank))
	_update_bank_balance_label()

func _process(_dt: float) -> void:
	var t := Time.get_datetime_dict_from_system()
	clock_label.text = "%02d:%02d:%02d" % [t.hour, t.minute, t.second]
	task_clock.text = "%02d:%02d" % [t.hour, t.minute]

func _unhandled_input(event: InputEvent) -> void:
	# Desktop login
	var f = get_viewport().gui_get_focus_owner()
	if f is LineEdit or f is TextEdit:
		return
	if login_overlay.visible and event is InputEventKey and event.pressed and not event.echo:
		desktop_type_count += 1
		if desktop_type_count <= desktop_login_len_cfg:
			login_mask.text = "*".repeat(desktop_type_count)
		if desktop_type_count >= desktop_login_len_cfg:
			_accept_desktop_login()
		return

	# Bank login (if visible)
	if win_bank.visible and bank_login_box.visible and event is InputEventKey and event.pressed and not event.echo:
		bank_type_count += 1
		if bank_type_count <= bank_login_len_cfg:
			bank_mask.text = "*".repeat(bank_type_count)
		if bank_type_count >= bank_login_len_cfg:
			_accept_bank_login()
		return

	# ESC hides Start menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_hide_start_menu()

# --- Desktop login ---
func _show_desktop_login() -> void:
	login_overlay.visible = true
	login_mask.text = ""
	desktop_type_count = 0
	login_prompt.text = "User: CONTRACTOR\nPassword:"

func _accept_desktop_login() -> void:
	login_prompt.text = "ACCESS GRANTED"
	await get_tree().create_timer(0.25).timeout
	login_overlay.visible = false
	has_logged_in_desktop = true
	status_label.text = "WELCOME"

# --- Start menu ---
func _on_start_pressed() -> void:
	if start_menu.visible:
		_hide_start_menu()
	else:
		_show_start_menu()

func _show_start_menu() -> void:
	menu_overlay.visible = true
	start_menu.visible = true
	search_edit.clear()
	_populate_results("")
	search_edit.grab_focus()

func _hide_start_menu() -> void:
	menu_overlay.visible = false
	start_menu.visible = false

func _on_menu_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_start_menu()

func _on_search_changed(new_text: String) -> void:
	_populate_results(new_text)

func _populate_results(query: String) -> void:
	results.clear()
	var q: String = query.strip_edges().to_lower()
	for app in apps:
		var app_name: String = String(app["name"]) 
		if q == "" or app_name.to_lower().find(q) != -1:
			results.add_item(app_name)

func _on_result_activated(index: int) -> void:
	if index < 0 or index >= results.item_count:
		return
	var app_name: String = results.get_item_text(index)
	for app in apps:
		if String(app["name"]) == app_name:
			var btn_path: String = String(app["button_path"]) 
			var btn: Node = get_node(btn_path)
			if btn:
				btn.emit_signal("pressed")
				_hide_start_menu()
				return

# --- Taskbar window list ---
func _ensure_task_button_for(win: Window, label_text: String) -> Button:
	if window_taskbuttons.has(win):
		return window_taskbuttons[win]
	var b := Button.new()
	b.toggle_mode = true
	b.text = label_text
	b.button_pressed = true
	b.pressed.connect(func():
		if win.visible:
			_hide_window(win)
		else:
			_show_window(win)
	)
	window_list_box.add_child(b)
	window_taskbuttons[win] = b
	return b

func _show_window(win: Window) -> void:
	win.visible = true
	if window_taskbuttons.has(win):
		var tb: Button = window_taskbuttons[win]
		tb.button_pressed = true

func _hide_window(win: Window) -> void:
	win.visible = false
	if window_taskbuttons.has(win):
		var tb: Button = window_taskbuttons[win]
		tb.button_pressed = false

# --- Market ---
func _on_buy_pressed() -> void:
	var idx: PackedInt32Array = offers.get_selected_items()
	if idx.is_empty():
		return
	var i: int = idx[0]
	var offer: Dictionary = market_offers[i]
	var price: int = int(offer["price"]) 
	if balance < price:
		status_label.text = "INSUFFICIENT FUNDS"
		return
	balance -= price
	_update_bank_balance_label()
	status_label.text = "PURCHASED: %s" % String(offer["name"])

# --- Bank ---
func _update_bank_balance_label() -> void:
	bank_balance_label.text = "Balance: $%d" % balance

func _accept_bank_login() -> void:
	bank_prompt.text = "ACCESS GRANTED"
	await get_tree().create_timer(0.2).timeout
	bank_login_box.visible = false
	bank_content.visible = true
	has_logged_in_bank = true
	_update_bank_balance_label()
