extends Node
class_name Sellers

## Curated roster of brokers and fronts that can list equipment on the market.
## Each seller has optional constraints on the equipment types or manufacturers they
## are willing to handle. When left empty they will trade anything in the catalogue.

var ALL_SELLERS: Array[Dictionary] = []

func _ready() -> void:
        ALL_SELLERS = [
                _create_seller(
                        "Balkan Intertrade",
                        [Products.EquipmentType.SMALL_ARMS, Products.EquipmentType.AMMUNITION],
                        [Products.Manufacturer.KALASHNIKOV_CONCERN, Products.Manufacturer.ROSOBORONEXPORT]
                ),
                _create_seller(
                        "Tri-County Brokers",
                        [Products.EquipmentType.SMALL_ARMS, Products.EquipmentType.HEAVY_WEAPON],
                        [Products.Manufacturer.COLT_DEFENSE, Products.Manufacturer.GENERAL_DYNAMICS]
                ),
                _create_seller(
                        "LibreLogistics",
                        [],
                        []
                ),
                _create_seller(
                        "Sinodefense Exports",
                        [Products.EquipmentType.HEAVY_WEAPON, Products.EquipmentType.VEHICLE],
                        [Products.Manufacturer.NORINCO]
                ),
                _create_seller(
                        "Mediterranean Secure Holdings",
                        [Products.EquipmentType.AMMUNITION, Products.EquipmentType.SUPPORT, Products.EquipmentType.SMALL_ARMS],
                        [Products.Manufacturer.FN_HERSTAL, Products.Manufacturer.IWI]
                )
        ]

func _create_seller(name: String, allowed_types: Array, allowed_manufacturers: Array) -> Dictionary:
        return {
                "name": name,
                "allowed_types": allowed_types,
                "allowed_manufacturers": allowed_manufacturers
        }
