class_name CitySignNames
extends RefCounted
## Invented names for the shops and buildings of Calder. Every word here is made up or
## an ordinary surname, trade or place word; none of it is a real business or brand.

const SURNAMES: Array[String] = [
	"HARLAN", "OKAFOR", "LINDQVIST", "BRANSCOMBE", "TOLLIVER", "CASTELLAN", "RUSSELMANN",
	"ABERNATHY", "PENHALLOW", "HAVERCROFT", "MARCHETTI", "SZABO", "NAKAMURA", "ODUYA", "PRUITT",
	"HALLORAN", "ESPOSITO", "KOWALCZYK", "DRAPER", "WHITCOMBE", "LAMBRECHT", "IBARRA",
	"VOSKUIL", "MERRIDEW", "ACHTERBERG", "DUVALL", "PETRAKIS", "OYELARAN", "TREMBATH",
	"MADDOX", "SORENSEN", "BELLAMY", "ROURKE", "TAVARES", "HOLLIS",
]
const PLACES: Array[String] = [
	"CALDER", "RIVERSIDE", "FRONT STREET", "LEVEE", "OLD TOWN", "COTTON ROW", "THIRD STREET",
	"STEAMBOAT", "TOWBOAT", "FERRY", "BARGE", "WHARF", "CUSTOMS HOUSE", "TWO RIVERS", "MILL",
]
const TRADES: Array[String] = [
	"HARDWARE", "BAKERY", "DELI", "TAILORS", "SHOE REPAIR", "PHARMACY", "BOOKS",
	"OPTICAL", "FLORIST", "BARBERS", "DINER", "CAFE", "LAUNDRY", "RECORDS", "CYCLES",
	"PRINTING", "LOCKSMITH", "TAQUERIA", "NOODLE BAR", "PIZZA", "WINE & SPIRITS",
	"HOME GOODS", "ANTIQUES", "PAWN & LOAN", "INSURANCE", "TRAVEL", "THRIFT", "MARKET",
	"PAINT", "LAMPS", "MUSIC", "TOYS", "CAMERAS", "COFFEE", "OYSTER BAR", "GROCERY",
]
## What the inside of a shop looks like, by trade (matches COLOR.b in building_glass.gdshader).
const KIND_GOODS: int = 0
const KIND_FOOD: int = 1
const KIND_SERVICE: int = 2
const KIND_CLOTHING: int = 3
const FOOD_TRADES: Array[String] = ["BAKERY", "DELI", "DINER", "CAFE", "TAQUERIA", "NOODLE BAR", "PIZZA", "COFFEE", "OYSTER BAR"]
const SERVICE_TRADES: Array[String] = ["SHOE REPAIR", "OPTICAL", "BARBERS", "LAUNDRY", "PRINTING", "LOCKSMITH", "INSURANCE", "TRAVEL"]
const CLOTHING_TRADES: Array[String] = ["TAILORS", "THRIFT"]
const OFFICE_FORMS: Array[String] = ["THE %s BUILDING", "%s BLOCK", "%s TRUST", "%s EXCHANGE", "%s HOUSE"]


static func shop(rng: RandomNumberGenerator) -> String:
	return shop_with_kind(rng)[0]


## A shop name and the kind of interior that goes with it: [name, KIND_*]. A name that does
## not say its trade ("HARLAN'S") gets a kind drawn from the same spread as the trade list.
static func shop_with_kind(rng: RandomNumberGenerator) -> Array:
	var who: String = SURNAMES[rng.randi() % SURNAMES.size()]
	var trade: String = TRADES[rng.randi() % TRADES.size()]
	var kind := trade_kind(trade)
	match rng.randi() % 6:
		0:
			return ["%s'S" % who, kind]
		1:
			return ["%s & %s" % [who, SURNAMES[rng.randi() % SURNAMES.size()]], kind]
		2:
			return ["%s %s" % [PLACES[rng.randi() % PLACES.size()], trade], kind]
		_:
			return ["%s %s" % [who, trade], kind]


static func trade_kind(trade: String) -> int:
	if FOOD_TRADES.has(trade):
		return KIND_FOOD
	if SERVICE_TRADES.has(trade):
		return KIND_SERVICE
	if CLOTHING_TRADES.has(trade):
		return KIND_CLOTHING
	return KIND_GOODS


static func building(rng: RandomNumberGenerator) -> String:
	var form: String = OFFICE_FORMS[rng.randi() % OFFICE_FORMS.size()]
	var word: String = SURNAMES[rng.randi() % SURNAMES.size()] if rng.randf() < 0.6 else PLACES[rng.randi() % PLACES.size()]
	return form % word


static func garage(rng: RandomNumberGenerator) -> String:
	return ["PUBLIC PARKING", "%s GARAGE" % PLACES[rng.randi() % PLACES.size()], "PARK"][rng.randi() % 3]
