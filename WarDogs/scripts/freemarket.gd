# -----------------------------------------------------------------------------
# 3. FREE MARKET LOGIC (FreeMarket.gd) - UPDATED FOR SPECIFIC DISPLAY
# -----------------------------------------------------------------------------
# INSTRUCTIONS:
# Replace the code in your FreeMarket.gd with this version.
#
extends Control

# --- Node References ---
@onready var item_list: ItemList = $ItemList
@onready var new_order_timer: Timer = $NewOrderTimer
@onready var purchase_confirmation_panel: Panel = $PurchaseConfirmationPanel
@onready var detail_label: Label = $PurchaseConfirmationPanel/DetailLabel
@onready var quantity_spinbox: SpinBox = $PurchaseConfirmationPanel/QuantitySpinBox
@onready var buy_partial_button: Button = $PurchaseConfirmationPanel/BuyPartialButton
@onready var buy_all_button: Button = $PurchaseConfirmationPanel/BuyAllButton
@onready var cancel_button: Button = $PurchaseConfirmationPanel/CancelButton

# --- Market Configuration ---
@export var max_market_items = 100
@export var listing_duration_seconds = 1440
@export var item_list_width = 300
@export var min_ttl_seconds := 60
@export var max_ttl_seconds := 600

# --- Internal State ---
var _current_selection = null


func _ready() -> void:
	randomize()
	purchase_confirmation_panel.hide()
	item_list.icon_mode = ItemList.ICON_MODE_TOP
	item_list.fixed_column_width = 300

	# Using 'call_deferred' to ensure this runs after the autoload scripts are fully ready.
	call_deferred("populate_initial_market")
	
	new_order_timer.one_shot = false
	if not new_order_timer.timeout.is_connected(_on_new_order_timer_timeout):
		new_order_timer.timeout.connect(_on_new_order_timer_timeout)
	new_order_timer.wait_time = randf_range(10.0, 100.0)
	new_order_timer.start()
	
	if not item_list.item_selected.is_connected(_on_item_list_item_selected):
		item_list.item_selected.connect(_on_item_list_item_selected)
	buy_all_button.pressed.connect(_on_buy_all_pressed)
	buy_partial_button.pressed.connect(_on_buy_partial_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)


func populate_initial_market():
	# This function is called after a short delay to ensure Products.gd has loaded the CSV.
	for i in range(5):
		generate_new_sell_order()


func generate_new_sell_order() -> void:
	if item_list.get_item_count() >= max_market_items: return
	if Products.ALL_PRODUCTS.is_empty(): return

	var seller = Sellers.ALL_SELLERS.pick_random()
	var eligible_products: Array = []
	for product in Products.ALL_PRODUCTS:
		if not product.has("type") or not product.has("manufacturer"): continue
		var type_ok := seller.allowed_types.is_empty() or product.type in seller.allowed_types
		var mfg_ok := seller.allowed_manufacturers.is_empty() or product.manufacturer in seller.allowed_manufacturers
		if type_ok and mfg_ok:
			eligible_products.append(product)
	if eligible_products.is_empty(): return

	var product_to_sell = eligible_products.pick_random()
	var quantity := randi_range(1, 5)
	var price_modifier := randf_range(0.85, 1.15)
	var price_per_unit := int(product_to_sell.base_price * price_modifier)
	var now := Time.get_unix_time_from_system()
	
	# Dynamic TTL: better (cheaper) deals disappear faster.
	var discount := clamp((product_to_sell.base_price - float(price_per_unit)) / max(1.0, float(product_to_sell.base_price)), 0.0, 1.0)
	var ttl := int(lerpf(float(max_ttl_seconds), float(min_ttl_seconds), discount))
	var expiration_timestamp := now + ttl
	
	# Probability the listing will be "bought" vs "cancelled" on expiration
	var buy_prob := lerpf(0.30, 0.90, discount)

	var sell_order := {
		"seller_name": seller.name,
		"product_name": product_to_sell.name,
		"quantity": quantity,
		"price_per_unit": price_per_unit,
		"created_at": now,
		"expires_at": expiration_timestamp,
		"buy_prob": buy_prob,
		"original_product_data": product_to_sell
	}
	add_order_to_list(sell_order)


func _format_display_text(order_data: Dictionary) -> String:
	var eta_text := ""
	if order_data.has("expires_at"):
		var remaining := int(order_data.expires_at - Time.get_unix_time_from_system())
		if remaining < 0:
			eta_text = " (expired)"
		else:
			var mins := int(ceil(remaining / 60.0))
			eta_text = "  ⏳ %dm" % mins
	return "%s
%s (x%d) | $%d each%s" % [
		order_data.seller_name,
		order_data.product_name,
		order_data.quantity,
		order_data.price_per_unit,
		eta_text
	]


func add_order_to_list(order_data: Dictionary) -> void:
	var display_text := _format_display_text(order_data)
	var new_index := item_list.add_item(display_text)
	item_list.set_item_metadata(new_index, order_data)
	item_list.move_item(new_index, 0)


func _process(_delta: float) -> void:
	var current_time := Time.get_unix_time_from_system()
	# Update visible rows text with live countdown
	for i in range(item_list.get_item_count()):
		var meta := item_list.get_item_metadata(i)
		if meta:
			item_list.set_item_text(i, _format_display_text(meta))
	
	# Remove expired and report outcome
	for i in range(item_list.get_item_count() - 1, -1, -1):
		var metadata := item_list.get_item_metadata(i)
		if metadata and metadata.has("expires_at") and current_time > int(metadata.expires_at):
			var was_selected_item := (_current_selection and _current_selection.index == i)
			# Decide outcome
			var bought := randf() < (metadata.has("buy_prob") ? float(metadata.buy_prob) : 0.5)
			if bought:
				print("[MARKET] Bought: %s x%d @ $%d" % [metadata.product_name, int(metadata.quantity), int(metadata.price_per_unit)])
			else:
				print("[MARKET] Cancelled: %s listing expired" % [metadata.product_name])
			item_list.remove_item(i)
			if was_selected_item:
				_on_cancel_pressed()
			elif _current_selection and i < _current_selection.index:
				_current_selection.index -= 1


func _format_seconds_to_string(total_seconds: int) -> String:
	if total_seconds < 0: return "Expired"
	var days = total_seconds / 86400
	var hours = (total_seconds % 86400) / 3600
	var minutes = (total_seconds % 3600) / 60
	return "%dd %dh %dm" % [days, hours, minutes]


# --- Signal Callbacks ---

func _on_item_list_item_selected(index: int) -> void:
	item_list.deselect(index)
	var order_data = item_list.get_item_metadata(index)
	if not order_data: return
	
	_current_selection = { "data": order_data, "index": index }
	
	# --- UPDATED DYNAMIC DISPLAY ---
	var details_string = ""
	var product_info = order_data.original_product_data
	
	# Define the specific list of keys you want to display, in order.
	var keys_to_display = [
		"equipment_code", "name", "type", "ammo_type", 
		"country_of_origin", "estimated_production_numbers", "currently_being_produced"
	]
	
	# Add the fixed order details first.
	details_string += "Seller: %s\n" % order_data.seller_name
	details_string += "Available: %d\n" % order_data.quantity
	details_string += "Price: $%d / unit\n" % order_data.price_per_unit
	var seconds_remaining = order_data.expires_at - Time.get_unix_time_from_system()
	details_string += "Time Left: %s\n\n" % _format_seconds_to_string(seconds_remaining)
	
	details_string += "--- Item Specs ---\n"
	# Now, loop through your specific list of keys.
	for key in keys_to_display:
		if product_info.has(key): # Check if the key exists in the data
			var value = product_info[key]
			# If the value is an enum, we need its string name.
			if key == "type": value = Products.EquipmentType.find_key(value).replace("_", " ")
			if key == "manufacturer": value = Products.Manufacturer.find_key(value).replace("_", " ")
			
			var formatted_key = key.replace("_", " ").capitalize()
			details_string += "%s: %s\n" % [formatted_key, value]

	detail_label.text = details_string

	quantity_spinbox.min_value = 1
	quantity_spinbox.max_value = order_data.quantity
	quantity_spinbox.value = 1
	
	purchase_confirmation_panel.show()


func _on_cancel_pressed() -> void:
	purchase_confirmation_panel.hide()
	_current_selection = null


func _on_new_order_timer_timeout() -> void:
	generate_new_sell_order()
	new_order_timer.wait_time = randf_range(10.0, 100.0)


func _on_buy_all_pressed() -> void:
	if not _current_selection: return
	var order_data = _current_selection.data
	var index = _current_selection.index
	print("Attempting to buy ALL: %d of %s" % [order_data.quantity, order_data.product_name])
	item_list.remove_item(index)
	_on_cancel_pressed()


func _on_buy_partial_pressed() -> void:
	if not _current_selection: return
	var order_data = _current_selection.data
	var index = _current_selection.index
	var quantity_to_buy = int(quantity_spinbox.value)
	print("Attempting to buy PARTIAL: %d of %s" % [quantity_to_buy, order_data.product_name])
	var new_quantity = order_data.quantity - quantity_to_buy
	if new_quantity <= 0:
		item_list.remove_item(index)
	else:
		var updated_order_data = order_data.duplicate()
		updated_order_data.quantity = new_quantity
		item_list.set_item_text(index, _format_display_text(updated_order_data))
		item_list.set_item_metadata(index, updated_order_data)
	_on_cancel_pressed()
