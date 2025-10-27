extends Node
class_name Products

## Central catalogue of weapons, ammunition, and support gear available to the free market UI.
## The data lives on an autoload so it is available before any desktop window opens.

# Keep the enums in one place so other systems (for example, Sellers) can safely reference
# the numeric identifiers while still being able to turn them back into display strings.
enum EquipmentType {
        SMALL_ARMS,
        AMMUNITION,
        HEAVY_WEAPON,
        SUPPORT,
        VEHICLE
}

enum Manufacturer {
        KALASHNIKOV_CONCERN,
        COLT_DEFENSE,
        FN_HERSTAL,
        NORINCO,
        IWI,
        GENERAL_DYNAMICS,
        ROSOBORONEXPORT
}

## Master list of all products. Populated during _ready so any other script can immediately
## query the catalogue without worrying about construction order.
var ALL_PRODUCTS: Array[Dictionary] = []

func _ready() -> void:
        ALL_PRODUCTS = [
                _create_product(
                        "AK-47",
                        "Kalashnikov AK-47",
                        EquipmentType.SMALL_ARMS,
                        Manufacturer.KALASHNIKOV_CONCERN,
                        "7.62x39mm",
                        "Soviet Union",
                        "~75 million",
                        true,
                        950
                ),
                _create_product(
                        "AKM-63",
                        "Hungarian AKM Export",
                        EquipmentType.SMALL_ARMS,
                        Manufacturer.KALASHNIKOV_CONCERN,
                        "7.62x39mm",
                        "Hungary",
                        "800,000",
                        false,
                        780
                ),
                _create_product(
                        "M4A1",
                        "Colt M4A1 Carbine",
                        EquipmentType.SMALL_ARMS,
                        Manufacturer.COLT_DEFENSE,
                        "5.56x45mm NATO",
                        "United States",
                        "~8 million",
                        true,
                        1100
                ),
                _create_product(
                        "MK19",
                        "MK19 Mod 3 AGL",
                        EquipmentType.HEAVY_WEAPON,
                        Manufacturer.GENERAL_DYNAMICS,
                        "40x53mm",
                        "United States",
                        "35,000",
                        true,
                        42000
                ),
                _create_product(
                        "PKM-74",
                        "PKM General Purpose MG",
                        EquipmentType.HEAVY_WEAPON,
                        Manufacturer.KALASHNIKOV_CONCERN,
                        "7.62x54mmR",
                        "Russia",
                        "1 million",
                        true,
                        8800
                ),
                _create_product(
                        "9MM-BX",
                        "Commercial 9x19mm Ball",
                        EquipmentType.AMMUNITION,
                        Manufacturer.FN_HERSTAL,
                        "9x19mm",
                        "Belgium",
                        "Hundreds of millions",
                        true,
                        320
                ),
                _create_product(
                        "5.56-SS109",
                        "SS109 5.56x45mm",
                        EquipmentType.AMMUNITION,
                        Manufacturer.IWI,
                        "5.56x45mm NATO",
                        "Israel",
                        "Tens of millions",
                        true,
                        410
                ),
                _create_product(
                        "QLZ87",
                        "QLZ-87 Automatic Grenade Launcher",
                        EquipmentType.HEAVY_WEAPON,
                        Manufacturer.NORINCO,
                        "35x32mm",
                        "China",
                        "Unknown",
                        false,
                        26000
                ),
                _create_product(
                        "UAZ-469",
                        "UAZ-469 Utility Vehicle",
                        EquipmentType.VEHICLE,
                        Manufacturer.ROSOBORONEXPORT,
                        "N/A",
                        "Soviet Union",
                        "~2.4 million",
                        false,
                        12500
                ),
                _create_product(
                        "RPG-7",
                        "RPG-7 Launcher Kit",
                        EquipmentType.HEAVY_WEAPON,
                        Manufacturer.ROSOBORONEXPORT,
                        "PG-7V",
                        "Russia",
                        "9 million",
                        true,
                        6500
                )
        ]

func _create_product(
        equipment_code: String,
        name: String,
        equipment_type: EquipmentType,
        manufacturer: Manufacturer,
        ammo_type: String,
        country_of_origin: String,
        estimated_production_numbers: String,
        currently_being_produced: bool,
        base_price: int
) -> Dictionary:
        return {
                "equipment_code": equipment_code,
                "name": name,
                "type": equipment_type,
                "manufacturer": manufacturer,
                "ammo_type": ammo_type,
                "country_of_origin": country_of_origin,
                "estimated_production_numbers": estimated_production_numbers,
                "currently_being_produced": currently_being_produced,
                "base_price": base_price
        }
