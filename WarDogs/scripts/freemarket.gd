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
	item_list.fixed_column_width = item_list_width

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
	if item_list.get_item_count() >= max_market_items:
		return
	if Products.ALL_PRODUCTS.is_empty() or Sellers.ALL_SELLERS.is_empty():
		return

	var seller: Dictionary = Sellers.ALL_SELLERS.pick_random()
	var eligible_products: Array[Dictionary] = []
	for product_data: Dictionary in Products.ALL_PRODUCTS:
		if not product_data.has("type") or not product_data.has("manufacturer"):
			continue
		var type_id := int(product_data.get("type", 0))
		var manufacturer_id := int(product_data.get("manufacturer", 0))
		var type_ok := seller.get("allowed_types", []).is_empty() or type_id in seller.get("allowed_types", [])
		var mfg_ok := seller.get("allowed_manufacturers", []).is_empty() or manufacturer_id in seller.get("allowed_manufacturers", [])
		if type_ok and mfg_ok:
			eligible_products.append(product_data)
	if eligible_products.is_empty():
		return

	var product_to_sell: Dictionary = eligible_products.pick_random()
	var quantity := randi_range(1, 5)
	var price_modifier := randf_range(0.85, 1.15)
	var base_price := float(product_to_sell.get("base_price", 0))
	var price_per_unit := int(round(base_price * price_modifier))
	var now := Time.get_unix_time_from_system()

	# Dynamic TTL: better (cheaper) deals disappear faster.
	var discount := clamp((base_price - float(price_per_unit)) / max(1.0, base_price), 0.0, 1.0)
	var ttl := int(lerpf(float(max_ttl_seconds), float(min_ttl_seconds), discount))
	var expiration_timestamp := now + ttl

	# Probability the listing will be "bought" vs "cancelled" on expiration
	var buy_prob := lerpf(0.30, 0.90, discount)

	var sell_order := {
		"seller_name": seller.get("name", "Anonymous Seller"),
		"product_name": product_to_sell.get("name", "Unknown Product"),
		"quantity": quantity,
		"price_per_unit": price_per_unit,
		"created_at": now,
		"expires_at": expiration_timestamp,
		"buy_prob": buy_prob,
		"original_product_data": product_to_sell.duplicate(true)
	}
	add_order_to_list(sell_order)


func _format_display_text(order_data: Dictionary) -> String:
	var seller_name := String(order_data.get("seller_name", "Unknown"))
	var product_name := String(order_data.get("product_name", ""))
	var quantity := int(order_data.get("quantity", 0))
	var price := int(order_data.get("price_per_unit", 0))

	var eta_text := ""
	if order_data.has("expires_at"):
		var remaining := int(order_data.get("expires_at", 0) - Time.get_unix_time_from_system())
		if remaining < 0:
			eta_text = " (expired)"
		else:
			var mins := int(ceil(remaining / 60.0))
			eta_text = "  ⏳ %dm" % mins

	return "%s — %s (x%d) | $%d each%s" % [
		seller_name,
		product_name,
		quantity,
		price,
		eta_text
	]


func add_order_to_list(order_data: Dictionary) -> void:
	var display_text := _format_display_text(order_data)
	var new_index := item_list.add_item(display_text)
	item_list.set_item_metadata(new_index, order_data.duplicate(true))
	item_list.move_item(new_index, 0)


func _process(_delta: float) -> void:
	var current_time := Time.get_unix_time_from_system()
	# Update visible rows text with live countdown
	for i in range(item_list.get_item_count()):
		var meta: Dictionary = item_list.get_item_metadata(i)
		if meta.is_empty():
			continue
		item_list.set_item_text(i, _format_display_text(meta))
	
	# Remove expired and report outcome
	for i in range(item_list.get_item_count() - 1, -1, -1):
		var metadata: Dictionary = item_list.get_item_metadata(i)
		if metadata.is_empty() or not metadata.has("expires_at"):
			continue
		if current_time <= int(metadata.get("expires_at", 0)):
			continue

		var was_selected_item := (_current_selection and _current_selection.index == i)
		# Decide outcome
		var bought := randf() < float(metadata.get("buy_prob", 0.5))
		var log_name := String(metadata.get("product_name", "Lot"))
		if bought:
			var qty := int(metadata.get("quantity", 0))
			var unit_price := int(metadata.get("price_per_unit", 0))
			print("[MARKET] Bought: %s x%d @ $%d" % [log_name, qty, unit_price])
		else:
			print("[MARKET] Cancelled: %s listing expired" % log_name)

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
	var order_data: Dictionary = item_list.get_item_metadata(index)
	if order_data.is_empty():
		return

	_current_selection = { "data": order_data.duplicate(true), "index": index }

	# --- UPDATED DYNAMIC DISPLAY ---
	var details_string = ""
	var product_info: Dictionary = order_data.get("original_product_data", {})

	# Define the specific list of keys you want to display, in order.
	var keys_to_display = [
		"equipment_code", "name", "type", "manufacturer", "ammo_type",
		"country_of_origin", "estimated_production_numbers", "currently_being_produced"
	]

	# Add the fixed order details first.
	details_string += "Seller: %s\n" % order_data.get("seller_name", "Unknown")
	details_string += "Available: %d\n" % int(order_data.get("quantity", 0))
	details_string += "Price: $%d / unit\n" % int(order_data.get("price_per_unit", 0))
	var seconds_remaining := int(order_data.get("expires_at", Time.get_unix_time_from_system()) - Time.get_unix_time_from_system())
	details_string += "Time Left: %s\n\n" % _format_seconds_to_string(seconds_remaining)

	details_string += "--- Item Specs ---\n"
	# Now, loop through your specific list of keys.
	for key in keys_to_display:
		if product_info.has(key): # Check if the key exists in the data
			var value = product_info[key]
			# If the value is an enum, we need its string name.
                        if key == "type":
                                var type_key := Products.EquipmentType.find_key(int(value))
                                if type_key:
                                        value = String(type_key).replace("_", " ")
                                else:
                                        value = String(value)
                        elif key == "manufacturer":
                                var mfg_key := Products.Manufacturer.find_key(int(value))
                                if mfg_key:
                                        value = String(mfg_key).replace("_", " ")
                                else:
                                        value = String(value)

			if value is bool:
				value = value ? "Yes" : "No"
			var formatted_key = key.replace("_", " ").capitalize()
			details_string += "%s: %s\n" % [formatted_key, value]

	detail_label.text = details_string

	quantity_spinbox.min_value = 1
	quantity_spinbox.max_value = max(1, int(order_data.get("quantity", 1)))
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
	var order_data: Dictionary = _current_selection.data
	var index: int = _current_selection.index
	print("Attempting to buy ALL: %d of %s" % [int(order_data.get("quantity", 0)), order_data.get("product_name", "Unknown")])
	item_list.remove_item(index)
	_on_cancel_pressed()


func _on_buy_partial_pressed() -> void:
	if not _current_selection: return
	var order_data: Dictionary = _current_selection.data
	var index: int = _current_selection.index
	var quantity_to_buy := int(quantity_spinbox.value)
	print("Attempting to buy PARTIAL: %d of %s" % [quantity_to_buy, order_data.get("product_name", "Unknown")])
	var new_quantity := int(order_data.get("quantity", 0)) - quantity_to_buy
	if new_quantity <= 0:
		item_list.remove_item(index)
	else:
		var updated_order_data: Dictionary = order_data.duplicate(true)
		updated_order_data["quantity"] = new_quantity
		item_list.set_item_text(index, _format_display_text(updated_order_data))
		item_list.set_item_metadata(index, updated_order_data)
		_current_selection = { "data": updated_order_data, "index": index }
	_on_cancel_pressed()
